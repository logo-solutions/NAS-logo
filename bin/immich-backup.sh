#!/usr/bin/env bash
set -euo pipefail

JOURNAUX="/Volumes/NAS-LOGO-DATA/journaux"
IMMICH_DIR="/Users/logo/immich"
COLIMA_CONFIG="$HOME/.colima/default/colima.yaml"
HETZNER_HOST="88.99.49.100"
HETZNER_PORT="23"
TS=$(date +%Y%m%d-%H%M%S)
HETZNER_STATUS="OK"

log()  { echo "[$(date +'%H:%M:%S')] $*"; }
ok()   { echo "[$(date +'%H:%M:%S')] ✓ $*"; }
fail() { echo "[$(date +'%H:%M:%S')] ✗ $*" >&2; }

# Étape 1 — Dump PostgreSQL
log "1/5 — Dump PostgreSQL..."
docker exec immich_postgres pg_dumpall -U immich | \
  gzip > "$JOURNAUX/immich-db-${TS}.sql.gz"
DUMP="$JOURNAUX/immich-db-${TS}.sql.gz"

# Vérification intégrité dump
SIZE=$(stat -f%z "$DUMP" 2>/dev/null || stat -c%s "$DUMP")
if [ "$SIZE" -lt 10000000 ]; then
  fail "Dump trop petit (${SIZE} octets) — suspect"
  exit 1
fi
if ! gzip -t "$DUMP" 2>/dev/null; then
  fail "Dump corrompu (gzip -t échoué)"
  exit 1
fi
ok "Dump OK — $(ls -lh "$DUMP" | awk '{print $5}') — intégrité gzip vérifiée"

# Étape 2 — .env Immich
log "2/5 — Sauvegarde .env..."
cp "$IMMICH_DIR/.env" "$JOURNAUX/immich-env-${TS}.txt"
ok ".env sauvegardé"

# Étape 3 — config Colima
log "3/5 — Sauvegarde colima.yaml..."
cp "$COLIMA_CONFIG" "$JOURNAUX/colima-config-${TS}.yaml"
ok "colima.yaml sauvegardé"

# Étape 4 & 5 — Hetzner (skip si --no-hetzner)
if [ "${NO_HETZNER:-}" = "1" ]; then
  HETZNER_STATUS="SKIPPED"
  log "4/5 — Hetzner SKIPPED (--no-hetzner)"
else
  log "4/5 — Vérification connexion Hetzner (${HETZNER_HOST}:${HETZNER_PORT})..."
  if ! nc -zw5 "$HETZNER_HOST" "$HETZNER_PORT" 2>/dev/null; then
    fail "Hetzner injoignable (${HETZNER_HOST}:${HETZNER_PORT})"
    HETZNER_STATUS="KO"
  else
    ok "Connexion Hetzner OK"

    # Étape 5 — Push dump vers Hetzner
    log "5/5 — Envoi BD vers Hetzner..."
    rclone copy "$DUMP" hetzner-crypt:backups-db/
    ok "BD copiée sur Hetzner"
  fi
fi

# Résumé final
echo ""
echo "========================================="
echo "  Sauvegarde Immich — $(date +'%Y-%m-%d %H:%M')"
echo "  Dump local   : OK ($(ls -lh "$DUMP" | awk '{print $5}'))"
echo "  .env         : OK"
echo "  colima.yaml  : OK"
echo "  Hetzner      : ${HETZNER_STATUS}"
echo "========================================="
