#!/bin/bash
set -euo pipefail

SOURCE="${1:-}"
[ -z "$SOURCE" ] && { echo "Usage: $0 <SOURCE_PATH> [--google] [--no-hetzner]"; exit 1; }
SOURCE="${SOURCE%/}"

GOOGLE_MODE=0
NO_HETZNER=0
for arg in "${@:2}"; do
  case "$arg" in
    --google)     GOOGLE_MODE=1 ;;
    --no-hetzner) NO_HETZNER=1 ;;
  esac
done
export NO_HETZNER

IMMICH_URL="http://localhost:2283"
LOG_DIR="/Volumes/NAS-LOGO-DATA/journaux"
DIRNAME=$(basename "$SOURCE")
TIMESTAMP=$(date +%Y%m%d-%H%M%S)

echo "=== IMMICH IMPORT: $DIRNAME ==="
echo "Source: $SOURCE"
[ "$GOOGLE_MODE" = "1" ] && echo "Mode: --google (from-google-photos, include-unmatched)"
[ "$NO_HETZNER" = "1" ] && echo "Mode: --no-hetzner (Hetzner skipped)"
echo ""

# ── 0. Preflight ───────────────────────────────────────────────────────────────
echo "[0] Preflight..."
ASSETS_BEFORE=$(docker exec immich_postgres psql -U immich -d immich -t -c \
  "SELECT COUNT(*) FROM asset;" | tr -d ' ')
echo "    Assets in DB: $ASSETS_BEFORE"

API_KEY=$(ansible-vault view /Volumes/logousb/SSD/Projects/NAS-logo/inventory/group_vars/all/vault.yml \
  --vault-password-file ~/.nas-logo-vault-pass 2>/dev/null | \
  grep vault_immich_api_key | awk '{print $2}' | tr -d '"')
[ -z "$API_KEY" ] && { echo "ERROR: Cannot read API key from vault"; exit 1; }

HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
  -H "x-api-key: $API_KEY" "$IMMICH_URL/api/users/me")
[ "$HTTP_STATUS" != "200" ] && { echo "ERROR: API key invalid (HTTP $HTTP_STATUS)"; exit 1; }

USER_JSON=$(curl -s -H "x-api-key: $API_KEY" "$IMMICH_URL/api/users/me")
USER_EMAIL=$(echo "$USER_JSON" | python3 -c "import sys,json; print(json.load(sys.stdin)['email'])")
echo "    API key:   ✓ valid"
echo "    User:      $USER_EMAIL"

# Vérifier qu'aucun autre import n'est en cours
if pgrep -q "immich-go"; then
  echo "ERROR: An immich-go import is already running"
  echo "       Wait for it to complete or kill: pkill immich-go"
  exit 1
fi

# ── 1. Dump BD local seulement ─────────────────────────────────────────────────
echo "[1] Backup (dump local)..."
bash bin/immich-backup.sh && echo "    ✓ Backup OK" || echo "    (backup failed, continuing)"

# ── 2. Import direct via immich-go ─────────────────────────────────────────────
echo "[2] Importing directly from source..."
LOG="$LOG_DIR/immich-go-${DIRNAME}-${TIMESTAMP}.log"
if [ "$GOOGLE_MODE" = "1" ]; then
  immich-go upload from-google-photos \
    --server "$IMMICH_URL" \
    --api-key "$API_KEY" \
    --no-ui \
    --on-errors=continue \
    --include-unmatched \
    --log-file "$LOG" \
    "$SOURCE" \
    2>&1 | tee "$LOG"
else
  immich-go upload from-folder \
    --server "$IMMICH_URL" \
    --api-key "$API_KEY" \
    --no-ui \
    --on-errors=continue \
    --log-file "$LOG" \
    "$SOURCE" \
    2>&1 | tee "$LOG"
fi

# ── 3. POST-IMPORT ─────────────────────────────────────────────────────────────
echo ""
echo "=== POST-IMPORT ==="
ASSETS_AFTER=$(docker exec immich_postgres psql -U immich -d immich -t -c \
  "SELECT COUNT(*) FROM asset;" | tr -d ' ')
ADDED=$((ASSETS_AFTER - ASSETS_BEFORE))

echo "  Before: $ASSETS_BEFORE"
echo "  After:  $ASSETS_AFTER"
echo "  Added:  $ADDED"

echo ""
echo "Restarting Immich..."
docker-compose -f ~/immich/docker-compose.yml restart immich 2>&1 | grep -E 'immich|done|error' || true

echo ""
echo "Log: $LOG"
echo ""
echo "✓ Import complete"
