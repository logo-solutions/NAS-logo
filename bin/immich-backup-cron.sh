#!/bin/bash
# Immich Backup — Cron daily (3h00)
# No LaunchDaemon, no sudo, no complications

set -e

export DOCKER_HOST=unix:///Users/logo/.colima/default/docker.sock
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
BACKUP_DIR="/Volumes/Expansion12/Backup"
LOG_FILE="/Volumes/NAS-LOGO-DATA/journaux/backup-cron-$TIMESTAMP.log"

{
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] === SAUVEGARDE IMMICH (CRON) ==="

  # 1. PostgreSQL dump
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] 1/3 PostgreSQL backup..."
  docker compose -f ~/immich/docker-compose.yml exec -T postgres pg_dump -U immich immich 2>/dev/null | gzip > "$BACKUP_DIR/immich-db-$TIMESTAMP.sql.gz"
  DB_SIZE=$(du -h "$BACKUP_DIR/immich-db-$TIMESTAMP.sql.gz" | cut -f1)
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] ✓ DB: $DB_SIZE"

  # 2. Immich assets (only metadata, not full copy)
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] 2/3 Assets metadata..."
  find /Volumes/NAS-LOGO-DATA/NAS-LOGO-VOLUME/personnes -type f \( -name "*.jpg" -o -name "*.png" -o -name "*.mp4" -o -name "*.mov" \) 2>/dev/null | wc -l > "$BACKUP_DIR/asset-count-$TIMESTAMP.txt"
  ASSET_COUNT=$(cat "$BACKUP_DIR/asset-count-$TIMESTAMP.txt")
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] ✓ Assets: $ASSET_COUNT files indexed"

  # 3. Colima VM state
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] 3/3 Colima state snapshot..."
  docker ps --all > "$BACKUP_DIR/docker-state-$TIMESTAMP.txt" 2>/dev/null
  docker images | head -20 >> "$BACKUP_DIR/docker-state-$TIMESTAMP.txt" 2>/dev/null
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] ✓ Container state saved"

  echo "[$(date '+%Y-%m-%d %H:%M:%S')] === SAUVEGARDE TERMINÉE ==="

} >> "$LOG_FILE" 2>&1

exit 0
