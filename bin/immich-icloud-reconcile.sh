#!/usr/bin/env bash
# immich-icloud-reconcile.sh — Réconciliation Icloud ↔ Immich (hash SHA1)
#
# Identifie les fichiers Icloud manquants dans Immich BD
# Importe seulement les manquants via immich-go
#
# Usage: bash bin/immich-icloud-reconcile.sh [ICLOUD_DIR]
# Défaut: /Volumes/NAS-LOGO-DATA/Icloud01062026/Photothèque.photoslibrary/originals

set -euo pipefail

# ============================================================================
# CONFIGURATION
# ============================================================================

ICLOUD_SOURCE="${1:-/Volumes/NAS-LOGO-DATA/Icloud01062026/Photothèque.photoslibrary/originals}"
IMMICH_URL="http://localhost:2283"
IMMICH_HOME="/Users/logo/immich"
TEMP_DIR="/Volumes/Expansion12/tmp"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)

ICLOUD_HASHES="$TEMP_DIR/icloud-sha1-${TIMESTAMP}.txt"
IMMICH_HASHES="$TEMP_DIR/immich-sha1-all.txt"
MISSING_HASHES="$TEMP_DIR/icloud-missing-${TIMESTAMP}.txt"
MISSING_FILES="$TEMP_DIR/icloud-missing-files-${TIMESTAMP}.txt"
LOG_FILE="$TEMP_DIR/immich-icloud-reconcile-${TIMESTAMP}.log"

# ============================================================================
# FONCTIONS
# ============================================================================

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

error() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $*" | tee -a "$LOG_FILE" >&2
  exit 1
}

# ============================================================================
# LOGS & VÉRIFICATIONS
# ============================================================================

{
  echo "=== IMMICH ICLOUD RECONCILIATION ==="
  echo "Timestamp: $(date)"
  echo "User: $(whoami)"
  echo ""
  echo "Directories:"
  echo "  ICLOUD_SOURCE: $ICLOUD_SOURCE"
  echo "  TEMP_DIR: $TEMP_DIR"
  echo "  LOG: $LOG_FILE"
  echo ""
} | tee "$LOG_FILE"

log "=== PRÉ-RECONCILIATION CHECKS ==="

# 1. Vérifier Icloud existe
if [ ! -d "$ICLOUD_SOURCE" ]; then
  error "ICLOUD_SOURCE not found: $ICLOUD_SOURCE"
fi
log "✓ ICLOUD_SOURCE existe"

# 2. Vérifier Immich hashes existent
if [ ! -f "$IMMICH_HASHES" ]; then
  error "IMMICH_HASHES not found: $IMMICH_HASHES"
  error "Créer d'abord avec: docker exec immich_postgres psql..."
fi
log "✓ IMMICH_HASHES existe ($(wc -l < "$IMMICH_HASHES") hashes)"

# 3. Vérifier Immich API
API_KEY=$(ansible-vault view /Volumes/logousb/SSD/Projects/NAS-logo/inventory/group_vars/all/vault.yml \
  --vault-password-file ~/.nas-logo-vault-pass 2>/dev/null | \
  grep vault_immich_api_key | awk '{print $2}' | tr -d '"') || error "Cannot read API key"

HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
  -H "x-api-key: $API_KEY" "$IMMICH_URL/api/users/me")
[ "$HTTP_STATUS" != "200" ] && error "API key invalid (HTTP $HTTP_STATUS)"
log "✓ Immich API accessible"

# ============================================================================
# PHASE 1: CALCULER SHA1 ICLOUD
# ============================================================================

log ""
log "=== PHASE 1: Calculer SHA1 Icloud ==="
log "Source: $ICLOUD_SOURCE"

START_TIME=$(date +%s)
FILE_COUNT=$(find "$ICLOUD_SOURCE" -type f 2>/dev/null | wc -l)
log "Fichiers à traiter: $FILE_COUNT"

find "$ICLOUD_SOURCE" -type f 2>/dev/null | \
  while read file; do
    shasum -a 1 "$file" 2>/dev/null | awk '{print $1}'
  done | sort > "$ICLOUD_HASHES"

END_TIME=$(date +%s)
ELAPSED=$((END_TIME - START_TIME))
ICLOUD_HASH_COUNT=$(wc -l < "$ICLOUD_HASHES")

log "✓ SHA1 calculés: $ICLOUD_HASH_COUNT fichiers"
log "  Durée: ${ELAPSED}s"

# ============================================================================
# PHASE 2: COMPARER AVEC BD IMMICH
# ============================================================================

log ""
log "=== PHASE 2: Comparer avec BD Immich ==="

# Fichiers manquants (dans Icloud mais PAS dans Immich)
comm -23 "$ICLOUD_HASHES" <(sort "$IMMICH_HASHES") > "$MISSING_HASHES"
MISSING_COUNT=$(wc -l < "$MISSING_HASHES")

log "Hashes manquants: $MISSING_COUNT"
log "  Pourcentage: $(( MISSING_COUNT * 100 / ICLOUD_HASH_COUNT ))%"

if [ "$MISSING_COUNT" -eq 0 ]; then
  log "✓ Tous les fichiers Icloud sont dans Immich!"
  exit 0
fi

# ============================================================================
# PHASE 3: MAPPER HASHES → FICHIERS
# ============================================================================

log ""
log "=== PHASE 3: Mapper les hashes manquants aux fichiers ==="

> "$MISSING_FILES"
while read missing_hash; do
  find "$ICLOUD_SOURCE" -type f 2>/dev/null | while read file; do
    file_hash=$(shasum -a 1 "$file" 2>/dev/null | awk '{print $1}')
    if [ "$file_hash" = "$missing_hash" ]; then
      echo "$file" >> "$MISSING_FILES"
      break
    fi
  done
done < "$MISSING_HASHES"

MISSING_FILE_COUNT=$(wc -l < "$MISSING_FILES")
log "Fichiers à importer: $MISSING_FILE_COUNT"

if [ "$MISSING_FILE_COUNT" -eq 0 ]; then
  log "❌ Pas de fichiers mappés (erreur?)"
  exit 1
fi

# ============================================================================
# PHASE 4: IMPORT VIA IMMICH-GO
# ============================================================================

log ""
log "=== PHASE 4: Import via immich-go ==="

# Vérifier que immich-go n'est pas déjà en cours
if pgrep -q "immich-go"; then
  error "An immich-go import is already running"
fi

# Créer répertoire temporaire pour les fichiers à importer
IMPORT_TEMP="/tmp/immich-icloud-missing-${TIMESTAMP}"
mkdir -p "$IMPORT_TEMP"

log "Préparation des fichiers pour immich-go..."
while read filepath; do
  cp "$filepath" "$IMPORT_TEMP/" 2>/dev/null || log "⚠ Cannot copy: $filepath"
done < "$MISSING_FILES"

IMPORT_FILE_COUNT=$(find "$IMPORT_TEMP" -type f | wc -l)
log "Fichiers copiés: $IMPORT_FILE_COUNT"

if [ "$IMPORT_FILE_COUNT" -eq 0 ]; then
  error "No files copied to import temp"
fi

# Lancer immich-go
log ""
log "Lancement immich-go upload..."
IMMICH_API_KEY="$API_KEY" immich-go upload -api "$IMMICH_URL/api" \
  -key "$API_KEY" "$IMPORT_TEMP" 2>&1 | tee -a "$LOG_FILE" || true

# Nettoyage
rm -rf "$IMPORT_TEMP"

# ============================================================================
# RÉSUMÉ
# ============================================================================

log ""
log "=== RÉSUMÉ ==="
log "✓ Réconciliation complétée"
log "  Fichiers Icloud: $ICLOUD_HASH_COUNT"
log "  Manquants: $MISSING_COUNT ($(( MISSING_COUNT * 100 / ICLOUD_HASH_COUNT ))%)"
log "  Importés: $IMPORT_FILE_COUNT"
log ""
log "Fichiers log:"
log "  Hashes Icloud: $ICLOUD_HASHES"
log "  Hashes manquants: $MISSING_HASHES"
log "  Fichiers manquants: $MISSING_FILES"
log "  Log complet: $LOG_FILE"

exit 0
