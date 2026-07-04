#!/usr/bin/env bash
# immich-backup-db-only.sh — Sauvegarde DB SEULEMENT (rapide, pour LaunchAgent quotidien)
#
# Fait JUSTE le dump PostgreSQL (étape 1).
# Pour un backup COMPLET avec fichiers médias, utiliser: immich-backup-complete.sh
#
# Usage: bash bin/immich-backup-db-only.sh
# Exécution: LaunchAgent com.nas-logo.backup à 03:00 chaque jour

set -euo pipefail

# ============================================================================
# CONFIGURATION
# ============================================================================

IMMICH_HOME="/Users/logo/immich"
JOURNAUX="/Volumes/NAS-LOGO-DATA/journaux"
BACKUP_ROOT="/Volumes/Expansion12/Backup"
BACKUP_LOCATION="${BACKUP_ROOT}/immich-backup-db-$(date +%Y%m%d-%H%M%S)"

LOG_FILE="${JOURNAUX}/immich-backup-db-only-$(date +%Y%m%d-%H%M%S).log"

export DOCKER_HOST=unix:///Users/logo/.colima/default/docker.sock

# ============================================================================
# TRACES DIAGNOSTIC (LaunchAgent debugging)
# ============================================================================

{
  echo "[DIAGNOSTIC] === TRACES DE DÉMARRAGE ==="
  echo "[DIAGNOSTIC] Timestamp: $(date)"
  echo "[DIAGNOSTIC] User: $(whoami)"
  echo "[DIAGNOSTIC] PID: $$"
  echo ""

  # 1. Vérifier Mac en sleep
  echo "[DIAGNOSTIC] 1. État Mac (sleep?):"
  pmset -g | grep -i "sleep\|idle" || echo "[DIAGNOSTIC]   (pmset non disponible)"
  echo ""

  # 2. Vérifier Colima
  echo "[DIAGNOSTIC] 2. Status Colima:"
  if command -v colima &> /dev/null; then
    colima status 2>&1 | head -5 || echo "[DIAGNOSTIC]   Colima: ERREUR"
  else
    echo "[DIAGNOSTIC]   colima: NOT FOUND"
  fi
  echo ""

  # 3. Vérifier SSD monté
  echo "[DIAGNOSTIC] 3. SSD monté?"
  if [ -d "/Volumes/logousb/SSD/NAS-LOGO-VOLUME" ]; then
    echo "[DIAGNOSTIC]   ✓ SSD monté"
    df -h "/Volumes/logousb/SSD/NAS-LOGO-VOLUME" | tail -1
  else
    echo "[DIAGNOSTIC]   ✗ SSD NON monté!"
    mount | grep -i ssd || echo "[DIAGNOSTIC]   (pas dans mount)"
  fi
  echo ""

  # 4. Vérifier HDD monté
  echo "[DIAGNOSTIC] 4. HDD monté?"
  if [ -d "/Volumes/NAS-LOGO-DATA" ]; then
    echo "[DIAGNOSTIC]   ✓ HDD monté"
    df -h "/Volumes/NAS-LOGO-DATA" | tail -1
  else
    echo "[DIAGNOSTIC]   ✗ HDD NON monté!"
    mount | grep -i nas-logo || echo "[DIAGNOSTIC]   (pas dans mount)"
  fi
  echo ""

  # 5. Vérifier Docker/Colima socket
  echo "[DIAGNOSTIC] 5. Docker socket:"
  if [ -S "/Users/logo/.colima/default/docker.sock" ]; then
    echo "[DIAGNOSTIC]   ✓ Socket existe"
  else
    echo "[DIAGNOSTIC]   ✗ Socket NOT FOUND!"
  fi

  # 6. Vérifier Docker accessible
  echo "[DIAGNOSTIC] 6. Docker accessible?"
  if docker ps > /dev/null 2>&1; then
    echo "[DIAGNOSTIC]   ✓ docker ps OK"
  else
    echo "[DIAGNOSTIC]   ✗ docker ps ERREUR"
    docker ps 2>&1 | head -3 || echo "[DIAGNOSTIC]   (docker command failed)"
  fi
  echo ""
  echo "[DIAGNOSTIC] === FIN DIAGNOSTIC ==="
  echo ""
} | tee -a "$LOG_FILE"

# ============================================================================
# HELPERS
# ============================================================================

log()  { echo "[$(date +'%H:%M:%S')] $*" | tee -a "$LOG_FILE"; }
ok()   { echo "[$(date +'%H:%M:%S')] ✓ $*" | tee -a "$LOG_FILE"; }
fail() { echo "[$(date +'%H:%M:%S')] ✗ $*" | tee -a "$LOG_FILE" >&2; exit 1; }

duration_human() {
  local seconds=$1
  local hours=$((seconds / 3600))
  local minutes=$(((seconds % 3600) / 60))
  [ "$hours" -gt 0 ] && printf "%dh%02dm" "$hours" "$minutes" || printf "%dm" "$minutes"
}

# ============================================================================
# VÉRIFICATIONS PRÉALABLES
# ============================================================================

log "=========================================="
log "IMMICH DB-ONLY BACKUP (rapide, quotidien)"
log "=========================================="
log ""

DOCKER_PS_OUTPUT=$(docker ps 2>&1) || fail "Docker (Colima) non accessible"
ok "Docker accessible"

if ! echo "$DOCKER_PS_OUTPUT" | grep -q immich_postgres; then
  fail "immich_postgres pas trouvé"
fi
ok "Immich détecté"

mkdir -p "$BACKUP_LOCATION" "$JOURNAUX"
ok "Répertoires préparés: $BACKUP_LOCATION"

# ============================================================================
# DATABASE DUMP ONLY
# ============================================================================

log ""
log "Database dump (pg_dump -d immich)..."

cd "$IMMICH_HOME"
if docker compose ps immich-server 2>/dev/null | grep -q "immich"; then
  log "Arrêter immich-server..."
  docker compose stop immich-server
  sleep 5
  ok "immich-server arrêté"
fi

log "Dump complet..."
START=$(date +%s)

DUMP_FILE="${BACKUP_LOCATION}/immich-db-$(date +%Y%m%d-%H%M%S).sql"
docker exec immich_postgres pg_dump \
  -U immich \
  -d immich \
  --no-acl \
  --no-owner \
  --format=plain \
  > "$DUMP_FILE" 2>&1 || fail "pg_dump échoué"

# Compresser (gzip -6 = bon compromis compression/vitesse)
gzip -6 "$DUMP_FILE"
DUMP_GZ="${DUMP_FILE}.gz"
END=$(date +%s)
ELAPSED=$((END - START))

DB_SIZE=$(du -h "$DUMP_GZ" | awk '{print $1}')
DB_LINES=$(gunzip -c "$DUMP_GZ" | wc -l)

if ! gzip -t "$DUMP_GZ"; then
  fail "Dump corrompu (gzip -t échoué)"
fi

ok "Database dump: $DB_SIZE, $DB_LINES lignes ($(duration_human $ELAPSED))"

# ============================================================================
# REDÉMARRER IMMICH
# ============================================================================

log ""
log "Redémarrer immich-server..."
docker compose start immich-server
sleep 5
ok "immich-server redémarré"

# ============================================================================
# RAPPORT FINAL
# ============================================================================

log ""
log "ÉTAPE 3/3: Génération rapport..."

# Calculer checksums
SHA256_DUMP=$(sha256sum "$DUMP_GZ" | awk '{print $1}')

# Compter les tables dans le dump
TABLES_COUNT=$(gunzip -c "$DUMP_GZ" | grep -c "^COPY public\." || echo "0")

# Créer README.md avec audit
README="$BACKUP_LOCATION/README.md"
cat > "$README" << EOF
# Immich Database Backup

**Date:** $(date)
**Duration:** $(duration_human $ELAPSED)

## Database Dump

- **File:** $(basename "$DUMP_GZ")
- **Size:** $DB_SIZE (compressed)
- **Lines:** $DB_LINES
- **Tables:** $TABLES_COUNT
- **SHA256:** $SHA256_DUMP

## Integrity

- Gzip validation: $(gzip -t "$DUMP_GZ" && echo "PASS ✓" || echo "FAIL ✗")

## Restore Command

\`\`\`bash
gunzip -c $(basename "$DUMP_GZ") | docker exec -i immich_postgres psql -U immich -d immich
\`\`\`

**Generated at:** $(date)
EOF

ok "README créé"

log ""
log "=========================================="
log "✓ BACKUP DB-ONLY PROFESSIONNEL COMPLET"
log "=========================================="
log ""
log "📁 Location: $BACKUP_LOCATION"
log "📊 DB dump: $DB_SIZE ($DB_LINES lignes)"
log "📋 README: $README"
log ""
log "Restore: gunzip -c $(basename "$DUMP_GZ") | docker exec -i immich_postgres psql -U immich -d immich"
log ""
log "📋 Log: $LOG_FILE"
log ""
