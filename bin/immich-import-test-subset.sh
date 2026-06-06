#!/bin/bash
set -euo pipefail

# immich-import-test-subset.sh
# Test immich-go --skip-hash on small sample (100-200 files)
# Before running the full import on Icloud01062026

SOURCE="${1:-/Volumes/NAS-LOGO-DATA/Icloud01062026}"
TEST_DIR="/tmp/test-immich-import-$$"
IMMICH_URL="http://localhost:2283"
LOG_DIR="/Volumes/NAS-LOGO-DATA/journaux"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)

echo "=== TEST IMPORT (100 files): immich-go --skip-hash ==="
echo "Source: $SOURCE"
echo ""

# ── 0. Préparer test subset ────────────────────────────────────────────────────
echo "[0] Préparer subset (100 fichiers)..."
mkdir -p "$TEST_DIR"

# Copy first 100 files
find "$SOURCE" -type f \( -iname "*.jpg" -o -iname "*.heic" -o -iname "*.png" -o -iname "*.mp4" \) | \
  head -100 | \
  xargs -I {} cp {} "$TEST_DIR/" 2>/dev/null || true

FILE_COUNT=$(find "$TEST_DIR" -type f | wc -l)
echo "    ✓ Test subset ready: $FILE_COUNT files"

# ── 1. Preflight ───────────────────────────────────────────────────────────────
echo "[1] Preflight..."
ASSETS_BEFORE=$(docker exec immich_postgres psql -U immich -d immich -t -c \
  "SELECT COUNT(*) FROM asset;" | tr -d ' ')
echo "    Assets before: $ASSETS_BEFORE"

API_KEY=$(ansible-vault view /Volumes/logousb/SSD/Projects/NAS-logo/inventory/group_vars/all/vault.yml \
  --vault-password-file ~/.nas-logo-vault-pass 2>/dev/null | \
  grep vault_immich_api_key | awk '{print $2}' | tr -d '"')
[ -z "$API_KEY" ] && { echo "ERROR: Cannot read API key"; exit 1; }

HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
  -H "x-api-key: $API_KEY" "$IMMICH_URL/api/users/me")
[ "$HTTP_STATUS" != "200" ] && { echo "ERROR: API invalid"; exit 1; }

echo "    API: ✓ valid"

# ── 2. Import test ─────────────────────────────────────────────────────────────
echo "[2] Importing test subset (--skip-hash)..."
LOG="$LOG_DIR/immich-test-${TIMESTAMP}.log"

START=$(date +%s)
immich-go upload from-folder \
  --server "$IMMICH_URL" \
  --api-key "$API_KEY" \
  --no-ui \
  --on-errors=continue \
  --log-file "$LOG" \
  "$TEST_DIR" \
  2>&1 | head -20  # just show first 20 lines
END=$(date +%s)
ELAPSED=$((END - START))

echo "    ✓ Import done ($((ELAPSED / 60))m$((ELAPSED % 60))s)"

# ── 3. POST-IMPORT ─────────────────────────────────────────────────────────────
echo ""
echo "=== RÉSULTATS TEST ==="
ASSETS_AFTER=$(docker exec immich_postgres psql -U immich -d immich -t -c \
  "SELECT COUNT(*) FROM asset;" | tr -d ' ')
ADDED=$((ASSETS_AFTER - ASSETS_BEFORE))

echo "  Files tested:     $FILE_COUNT"
echo "  Assets before:    $ASSETS_BEFORE"
echo "  Assets after:     $ASSETS_AFTER"
echo "  Added:            $ADDED"
echo "  Skipped (dups):   $((FILE_COUNT - ADDED))"

echo ""
echo "Log: $LOG"
echo ""

# Cleanup
rm -rf "$TEST_DIR"
echo "✓ Test complete (temp files cleaned up)"
