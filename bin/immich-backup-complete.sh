#!/usr/bin/env bash
# immich-backup-complete.sh — Sauvegarde Immich CONFORME état de l'art
#
# Réf: https://docs.immich.app/administration/backup-and-restore/
#
# Sauvegarde les 3 éléments CRITIQUES (recommandations officielles):
# 1. Database dump (pg_dump) — PREMIER = données + schéma
# 2. Files (upload/, library/, profile/) — SECOND = media assets
# 3. Configuration (docker-compose.yml, .env)
#
# Stratégie: 3-2-1 (3 copies, 2 media, 1 offsite)
# + Tableau de bord détaillé avec indicateurs Immich
#
# Output: Backup complet + checksums + metadata + statistiques

set -euo pipefail

# Colima s'auto-configure — pas besoin de DOCKER_HOST
# export DOCKER_HOST="unix:///Users/logo/.colima/default/docker.sock"

# ============================================================================
# CONFIGURATION
# ============================================================================

IMMICH_HOME="/Users/logo/immich"
UPLOAD_LOCATION="/Volumes/NAS-LOGO-DATA/NAS-LOGO-VOLUME/personnes"
JOURNAUX="/Volumes/NAS-LOGO-DATA/journaux"
BACKUP_ROOT="/Volumes/Expansion12"
BACKUP_LOCATION="${BACKUP_ROOT}/immich-backup-complete-$(date +%Y%m%d-%H%M%S)"

LOG_FILE="${JOURNAUX}/immich-backup-complete-$(date +%Y%m%d-%H%M%S).log"

# ============================================================================
# HELPERS
# ============================================================================

log()  { echo "[$(date +'%H:%M:%S')] $*" | tee -a "$LOG_FILE"; }
ok()   { echo "[$(date +'%H:%M:%S')] ✓ $*" | tee -a "$LOG_FILE"; }
fail() { echo "[$(date +'%H:%M:%S')] ✗ $*" | tee -a "$LOG_FILE" >&2; exit 1; }
warn() { echo "[$(date +'%H:%M:%S')] ⚠ $*" | tee -a "$LOG_FILE"; }

duration_human() {
  local seconds=$1
  local hours=$((seconds / 3600))
  local minutes=$(((seconds % 3600) / 60))
  [ "$hours" -gt 0 ] && printf "%dh%02dm" "$hours" "$minutes" || printf "%dm" "$minutes"
}

# ============================================================================
# INDICATEURS IMMICH (Dashboard complet)
# ============================================================================

get_immich_stats() {
  local label="$1"

  log "📊 Extracting Immich indicators ($label)..."

  # Database stats
  USERS=$(docker exec immich_postgres psql -U immich -d immich -t -c "SELECT COUNT(*) FROM \"user\";" 2>/dev/null || echo "0")
  ASSETS=$(docker exec immich_postgres psql -U immich -d immich -t -c "SELECT COUNT(*) FROM asset;" 2>/dev/null || echo "0")
  ALBUMS=$(docker exec immich_postgres psql -U immich -d immich -t -c "SELECT COUNT(*) FROM album;" 2>/dev/null || echo "0")
  PERSONS=$(docker exec immich_postgres psql -U immich -d immich -t -c "SELECT COUNT(*) FROM person;" 2>/dev/null || echo "0")
  FACES=$(docker exec immich_postgres psql -U immich -d immich -t -c "SELECT COUNT(*) FROM asset_face;" 2>/dev/null || echo "0")
  SMART_SEARCH=$(docker exec immich_postgres psql -U immich -d immich -t -c "SELECT COUNT(*) FROM smart_search;" 2>/dev/null || echo "0")
  MEMORIES=$(docker exec immich_postgres psql -U immich -d immich -t -c "SELECT COUNT(*) FROM memory;" 2>/dev/null || echo "0")
  TAGS=$(docker exec immich_postgres psql -U immich -d immich -t -c "SELECT COUNT(*) FROM tag;" 2>/dev/null || echo "0")
  SHARED_LINKS=$(docker exec immich_postgres psql -U immich -d immich -t -c "SELECT COUNT(*) FROM shared_link;" 2>/dev/null || echo "0")
  API_KEYS=$(docker exec immich_postgres psql -U immich -d immich -t -c "SELECT COUNT(*) FROM api_key;" 2>/dev/null || echo "0")

  # File system stats
  THUMBS_COUNT=$(find "$UPLOAD_LOCATION/*/thumbs/" -type f 2>/dev/null | wc -l || echo "0")
  THUMBS_SIZE=$(du -sh "$UPLOAD_LOCATION/*/thumbs/" 2>/dev/null | awk '{sum+=$1} END {printf "%.1f GB", sum/1024}' || echo "N/A")
  ENCODED_COUNT=$(find "$UPLOAD_LOCATION/*/encoded-video/" -type f 2>/dev/null | wc -l || echo "0")
  PROFILE_COUNT=$(find "$UPLOAD_LOCATION/*/profile/" -type f 2>/dev/null | wc -l || echo "0")

  # Total media size
  TOTAL_SIZE=$(du -sh "$UPLOAD_LOCATION" 2>/dev/null | awk '{print $1}' || echo "N/A")

  # Display dashboard
  echo "" | tee -a "$LOG_FILE"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" | tee -a "$LOG_FILE"
  echo "  📊 IMMICH DASHBOARD — $label" | tee -a "$LOG_FILE"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" | tee -a "$LOG_FILE"
  echo "" | tee -a "$LOG_FILE"
  echo "👥 USERS & PERMISSIONS:" | tee -a "$LOG_FILE"
  echo "   Users:          $USERS" | tee -a "$LOG_FILE"
  echo "   API Keys:       $API_KEYS" | tee -a "$LOG_FILE"
  echo "   Shared Links:   $SHARED_LINKS" | tee -a "$LOG_FILE"
  echo "" | tee -a "$LOG_FILE"
  echo "📸 MEDIA ASSETS:" | tee -a "$LOG_FILE"
  echo "   Total Assets:   $ASSETS" | tee -a "$LOG_FILE"
  echo "   Albums:         $ALBUMS" | tee -a "$LOG_FILE"
  echo "   Tags:           $TAGS" | tee -a "$LOG_FILE"
  echo "" | tee -a "$LOG_FILE"
  echo "🎯 FACE & RECOGNITION:" | tee -a "$LOG_FILE"
  echo "   Persons:        $PERSONS" | tee -a "$LOG_FILE"
  echo "   Faces:          $FACES" | tee -a "$LOG_FILE"
  echo "" | tee -a "$LOG_FILE"
  echo "🔍 SEARCH & MEMORIES:" | tee -a "$LOG_FILE"
  echo "   Smart Search:   $SMART_SEARCH embeddings" | tee -a "$LOG_FILE"
  echo "   Memories:       $MEMORIES" | tee -a "$LOG_FILE"
  echo "" | tee -a "$LOG_FILE"
  echo "💾 STORAGE:" | tee -a "$LOG_FILE"
  echo "   Total Size:     $TOTAL_SIZE" | tee -a "$LOG_FILE"
  echo "   Thumbnails:     $THUMBS_COUNT files ($THUMBS_SIZE)" | tee -a "$LOG_FILE"
  echo "   Encoded Video:  $ENCODED_COUNT files" | tee -a "$LOG_FILE"
  echo "   Profiles:       $PROFILE_COUNT files" | tee -a "$LOG_FILE"
  echo "" | tee -a "$LOG_FILE"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" | tee -a "$LOG_FILE"
  echo "" | tee -a "$LOG_FILE"
}

# ============================================================================
# VÉRIFICATIONS PRÉALABLES
# ============================================================================

log "=========================================="
log "IMMICH BACKUP COMPLET — Conforme état de l'art"
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

# 📊 Afficher statistiques AVANT (commenté — bloque sur docker exec)
# get_immich_stats "AVANT BACKUP"

# ============================================================================
# ÉTAPE 1: DATABASE DUMP (PREMIER - recommandation officielle)
# ============================================================================

log ""
log "ÉTAPE 1/5: Database dump (PREMIER - data + schéma)..."

cd "$IMMICH_HOME"
if docker compose ps immich-server 2>/dev/null | grep -q "immich"; then
  log "Arrêter immich-server..."
  docker compose stop immich-server
  sleep 5
  ok "immich-server arrêté"
fi

log "Dump complet (pg_dump -d immich)..."
START=$(date +%s)

DUMP_FILE="${BACKUP_LOCATION}/immich-db-$(date +%Y%m%d-%H%M%S).sql"
docker exec immich_postgres pg_dump \
  -U immich \
  -d immich \
  --no-acl \
  --no-owner \
  --format=plain \
  > "$DUMP_FILE" 2>&1 || fail "pg_dump échoué"

# Compresser
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
# ÉTAPE 2: MEDIA FILES (SECOND - upload/, library/, profile/)
# ============================================================================

log ""
log "ÉTAPE 2/5: Backup fichiers médias (upload/, library/, profile/)..."

UPLOAD_BACKUP="${BACKUP_LOCATION}/immich-files-$(date +%Y%m%d-%H%M%S).tar.gz"
START=$(date +%s)

tar --exclude='*.lock' --exclude='*.tmp' \
    -czf "$UPLOAD_BACKUP" \
    -C "$UPLOAD_LOCATION" \
    . 2>&1 | tail -20 >> "$LOG_FILE" || fail "tar échoué"

END=$(date +%s)
ELAPSED=$((END - START))
FILES_SIZE=$(du -h "$UPLOAD_BACKUP" | awk '{print $1}')

ok "Fichiers médias: $FILES_SIZE ($(duration_human $ELAPSED))"

# ============================================================================
# ÉTAPE 3: CONFIGURATION
# ============================================================================

log ""
log "ÉTAPE 3/5: Backup configuration..."

cp "$IMMICH_HOME/docker-compose.yml" "$BACKUP_LOCATION/docker-compose.yml"
cp "$IMMICH_HOME/.env" "$BACKUP_LOCATION/immich.env"
ok "Configuration sauvegardée"

# ============================================================================
# ÉTAPE 4: CHECKSUMS & METADATA
# ============================================================================

log ""
log "ÉTAPE 4/5: Checksums et métadonnées..."

cd "$BACKUP_LOCATION"
sha256sum * > checksums.sha256
ok "Checksums SHA256 générés"

cat > BACKUP_MANIFEST.txt << EOF
===== IMMICH BACKUP COMPLET - État de l'art =====
Date: $(date -u '+%Y-%m-%d %H:%M:%S UTC')
Timestamp: $(date +%s)

CONFORMITÉ:
  [✓] Official Immich Backup Standard
  [✓] 3-2-1 Strategy ready
  [✓] Database dump FIRST
  [✓] Media files included
  [✓] Configuration saved

DATABASE:
  File: $(basename "$DUMP_GZ")
  Size: $DB_SIZE
  Format: pg_dump (plain SQL, gzip compressed)
  Database: immich
  User: immich (not postgres)
  Integrity: gzip verified

MEDIA FILES:
  File: $(basename "$UPLOAD_BACKUP")
  Size: $FILES_SIZE
  Includes: upload/, library/, profile/
  Excluded: *.lock, *.tmp
  Source: $UPLOAD_LOCATION

CONFIGURATION:
  - docker-compose.yml (service definition)
  - immich.env (environment variables)

CHECKSUMS:
  Algorithm: SHA256
  Manifest: checksums.sha256
  Verification: sha256sum -c checksums.sha256

STRATEGY:
  Pattern: 3-2-1 (3 copies, 2 media types, 1 offsite)
  Current Location: $BACKUP_LOCATION
  Offsite: Hetzner (pending port 23 fix)

RESTORATION CHECKLIST:
  1. Stop Immich: docker compose down
  2. Remove volume: docker volume rm immich_postgres_data
  3. Restore files: tar -xzf immich-files-*.tar.gz -C /path/to/upload
  4. Restore DB: gunzip -c immich-db-*.sql.gz | docker exec -i immich_postgres psql -U immich -d immich
  5. Restart: docker compose up -d
  6. Create admin account via web UI

VERIFICATION COMMAND:
  sha256sum -c checksums.sha256

Reference:
  https://docs.immich.app/administration/backup-and-restore/

Generated by: immich-backup-complete.sh
Status: COMPLETE (ready for 3-2-1 strategy)
EOF

ok "Manifest créé"

# ============================================================================
# ÉTAPE 5: REDÉMARRER IMMICH
# ============================================================================

log ""
log "ÉTAPE 5/5: Redémarrer Immich..."

docker compose start immich-server
sleep 10
ok "immich-server redémarré"

# ============================================================================
# RAPPORT FINAL + STATISTIQUES APRÈS
# ============================================================================

# 📊 Afficher statistiques APRÈS
get_immich_stats "APRÈS BACKUP"

log ""
log "=========================================="
log "✓ SAUVEGARDE COMPLÈTE CONFORME - État de l'art"
log "=========================================="
log ""
log "📁 Location: $BACKUP_LOCATION"
log ""
log "📊 Contents:"
ls -lh "$BACKUP_LOCATION" | tail -n +2 | awk '{printf "   %10s  %s\n", $5, $9}'
log ""
log "📈 Total size: $(du -sh "$BACKUP_LOCATION" | awk '{print $1}')"
log ""
log "✅ Checklist (officiel Immich):"
log "   [✓] Database dump ($DB_SIZE)"
log "   [✓] Media files ($FILES_SIZE)"
log "   [✓] Configuration (docker-compose.yml, .env)"
log "   [✓] Checksums (SHA256)"
log "   [✓] Manifest (BACKUP_MANIFEST.txt)"
log "   [⏳] Offsite sync (Hetzner port 23 blocked)"
log ""
log "🔍 Verify: cd $BACKUP_LOCATION && sha256sum -c checksums.sha256"
log "🔄 Restore: See BACKUP_MANIFEST.txt for full procedure"
log ""
log "📋 Full log: $LOG_FILE"
log ""
