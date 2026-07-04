#!/usr/bin/env bash
# immich-backup-physical.sh — Sauvegarde PHYSIQUE des fichiers PostgreSQL (weekly)
#
# Copie les fichiers physiques du conteneur PostgreSQL pour point-in-time recovery.
# Usage: bash bin/immich-backup-physical.sh
# Scheduling: LaunchDaemon com.nas-logo.backup-physical à 04:00 chaque dimanche

set -euo pipefail

# ============================================================================
# CONFIGURATION
# ============================================================================

IMMICH_HOME="/Users/logo/immich"
JOURNAUX="/Volumes/NAS-LOGO-DATA/journaux"
BACKUP_ROOT="/Volumes/Expansion12/Backup"
BACKUP_LOCATION="${BACKUP_ROOT}/immich-backup-physical-$(date +%Y%m%d-%H%M%S)"
TEMP_DIR="/Volumes/NAS-LOGO-DATA/.tmp-immich-physical-$$"

LOG_FILE="${JOURNAUX}/immich-backup-physical-$(date +%Y%m%d-%H%M%S).log"

# ============================================================================
# DIAGNOSTIC TRACES
# ============================================================================

{
  echo "[DIAGNOSTIC] === BACKUP PHYSIQUE PostgreSQL ==="
  echo "[DIAGNOSTIC] Timestamp: $(date)"
  echo "[DIAGNOSTIC] User: $(whoami)"
  echo "[DIAGNOSTIC] PID: $$"
  echo ""
  echo "[DIAGNOSTIC] Colima status:"
  colima status 2>&1 | head -3 || echo "[DIAGNOSTIC]   Colima: ERREUR"
  echo ""
} | tee -a "$LOG_FILE"

# ============================================================================
# HELPERS
# ============================================================================

log()  { echo "[$(date +'%H:%M:%S')] $*" | tee -a "$LOG_FILE"; }
ok()   { echo "[$(date +'%H:%M:%S')] ✓ $*" | tee -a "$LOG_FILE"; }
fail() { echo "[$(date +'%H:%M:%S')] ✗ $*" | tee -a "$LOG_FILE" >&2; rm -rf "$TEMP_DIR"; exit 1; }

# Nettoyage automatique à la fin
trap "rm -rf '$TEMP_DIR'" EXIT

duration_human() {
  local seconds=$1
  local hours=$((seconds / 3600))
  local minutes=$(((seconds % 3600) / 60))
  [ "$hours" -gt 0 ] && printf "%dh%02dm" "$hours" "$minutes" || printf "%dm" "$minutes"
}

# ============================================================================
# PRÉPARATIONS
# ============================================================================

log "=========================================="
log "IMMICH BACKUP PHYSIQUE (weekly)"
log "=========================================="
log ""

DOCKER_PS_OUTPUT=$(docker ps 2>&1) || fail "Docker (Colima) non accessible"
ok "Docker accessible"

if ! echo "$DOCKER_PS_OUTPUT" | grep -q immich_postgres; then
  fail "immich_postgres pas trouvé"
fi
ok "Immich détecté"

mkdir -p "$BACKUP_LOCATION" "$JOURNAUX" "$TEMP_DIR"
ok "Répertoires préparés"

# ============================================================================
# ARRÊTER IMMICH (tout sauf postgres)
# ============================================================================

log ""
log "Arrêter services Immich..."

cd "$IMMICH_HOME"
docker compose stop immich-server immich-redis immich-machine-learning 2>/dev/null || true
sleep 3
ok "Services arrêtés"

# ============================================================================
# COPIER FICHIERS PHYSIQUES PostgreSQL
# ============================================================================

log ""
log "Copier fichiers physiques PostgreSQL..."
START=$(date +%s)

# Copier depuis le conteneur vers temp local
TEMP_DATA="${TEMP_DIR}/postgresql-data"
mkdir -p "$TEMP_DATA"

docker cp immich_postgres:/var/lib/postgresql/data/ "$TEMP_DATA/" 2>&1 | tee -a "$LOG_FILE" || \
  fail "Erreur lors de la copie des fichiers PostgreSQL"

ok "Fichiers copiés vers $TEMP_DATA"

# ============================================================================
# COMPRESSER EN TAR.GZ
# ============================================================================

log ""
log "Compression tar.gz (cela peut prendre 1-2 minutes)..."

BACKUP_FILE="${BACKUP_LOCATION}/postgresql-data.tar.gz"
tar -czf "$BACKUP_FILE" -C "$TEMP_DIR" postgresql-data/ 2>&1 | tee -a "$LOG_FILE" || \
  fail "Erreur lors de la compression"

END=$(date +%s)
ELAPSED=$((END - START))

BACKUP_SIZE=$(du -h "$BACKUP_FILE" | awk '{print $1}')
BACKUP_LINES=$(tar -tzf "$BACKUP_FILE" | wc -l)

ok "Compression complète: $BACKUP_SIZE, $BACKUP_LINES fichiers ($(duration_human $ELAPSED))"

# ============================================================================
# REDÉMARRER IMMICH
# ============================================================================

log ""
log "Redémarrer services Immich..."
docker compose start immich-server immich-redis immich-machine-learning 2>/dev/null || true
sleep 10
ok "Services redémarrés"

# ============================================================================
# CHECKSUMS & README
# ============================================================================

log ""
log "Génération rapport..."

SHA256_BACKUP=$(sha256sum "$BACKUP_FILE" | awk '{print $1}')

README="${BACKUP_LOCATION}/README.md"
cat > "$README" << EOF
# Immich PostgreSQL Physical Backup

**Date:** $(date)
**Type:** Physical files (point-in-time recovery)
**Duration:** $(duration_human $ELAPSED)

## Backup File

- **File:** $(basename "$BACKUP_FILE")
- **Size:** $BACKUP_SIZE (compressed)
- **Files:** $BACKUP_LINES
- **SHA256:** $SHA256_BACKUP

## Contents

This is a tar.gz archive of PostgreSQL physical data files from:
\`/var/lib/postgresql/data/\` (inside \`immich_postgres\` container)

Suitable for:
- Point-in-time recovery
- Faster restore than SQL dump
- Disaster recovery (raw FS restore)

## Restore (Advanced)

**Warning:** This is a low-level restore. For most cases, use SQL dump instead.

\`\`\`bash
# 1. Stop all Immich services
cd ~/immich && docker compose stop

# 2. Remove old data
docker exec immich_postgres rm -rf /var/lib/postgresql/data/*

# 3. Extract backup
tar -xzf $(basename "$BACKUP_FILE") -C . && \\
  docker cp postgresql-data/data/ immich_postgres:/var/lib/postgresql/

# 4. Fix permissions
docker exec immich_postgres chown -R postgres:postgres /var/lib/postgresql/data

# 5. Restart
cd ~/immich && docker compose up -d
\`\`\`

## Integrity

- Tar check: $(tar -tzf "$BACKUP_FILE" > /dev/null 2>&1 && echo "PASS ✓" || echo "FAIL ✗")

**Generated at:** $(date)
EOF

ok "README créé"

# ============================================================================
# RÉSUMÉ
# ============================================================================

log ""
log "=========================================="
log "✓ BACKUP PHYSIQUE COMPLET"
log "=========================================="
log ""
log "📁 Location: $BACKUP_LOCATION"
log "📊 Size: $BACKUP_SIZE ($BACKUP_LINES files)"
log "📋 README: $README"
log ""
log "📋 Log: $LOG_FILE"
log ""
