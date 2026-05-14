#!/usr/bin/env bash
set -euo pipefail

JOURNAUX="/Volumes/NAS-LOGO-DATA/journaux"
IMMICH_DIR="/Users/logo/immich"
COLIMA_CONFIG="$HOME/.colima/default/colima.yaml"
TS=$(date +%Y%m%d-%H%M%S)

log() { echo "[$(date +'%H:%M:%S')] $*"; }

# Étape 1 — Dump PostgreSQL
log "1/5 — Dump PostgreSQL..."
docker exec immich_postgres pg_dumpall -U immich | \
  gzip > "$JOURNAUX/immich-db-${TS}.sql.gz"
log "OK: $(ls -lh "$JOURNAUX/immich-db-${TS}.sql.gz" | awk '{print $5, $9}')"

# Étape 2 — .env Immich
log "2/5 — Sauvegarde .env..."
cp "$IMMICH_DIR/.env" "$JOURNAUX/immich-env-${TS}.txt"
log "OK: $JOURNAUX/immich-env-${TS}.txt"

# Étape 3 — config Colima
log "3/5 — Sauvegarde colima.yaml..."
cp "$COLIMA_CONFIG" "$JOURNAUX/colima-config-${TS}.yaml"
log "OK: $JOURNAUX/colima-config-${TS}.yaml"

# Étape 4 — Vérification Hetzner
log "4/5 — Vérification connexion Hetzner..."
rclone ls hetzner-crypt: --max-depth 1
log "OK: connexion Hetzner fonctionnelle"

# Étape 5 — Push dump vers Hetzner
log "5/5 — Envoi BD vers Hetzner..."
rclone copy "$JOURNAUX/immich-db-${TS}.sql.gz" hetzner-crypt:backups-db/
log "OK: BD copiée sur Hetzner"

log "=== Sauvegarde Immich complète OK ==="
