#!/bin/bash
set -euo pipefail

# Restauration de dump Immich — usage: restore-dump.sh <dump_filename>
# Exemple: restore-dump.sh immich-db-20260514-092711.sql.gz

DUMP_FILE="${1:?Usage: $0 <dump_filename>}"
DUMP_PATH="/Volumes/NAS-LOGO-DATA/journaux/$DUMP_FILE"

LOG_FILE="/Volumes/NAS-LOGO-DATA/journaux/restore-$(date +%Y%m%d-%H%M%S).log"

log()  {
  MSG="[$(date +'%H:%M:%S')] $*"
  echo "$MSG"
  echo "$MSG" >> "$LOG_FILE"
}
ok()   {
  MSG="[$(date +'%H:%M:%S')] ✓ $*"
  echo "$MSG"
  echo "$MSG" >> "$LOG_FILE"
}
fail() {
  MSG="[$(date +'%H:%M:%S')] ✗ $*"
  echo "$MSG" >&2
  echo "$MSG" >> "$LOG_FILE"
  exit 1
}

# Vérifications AVANT
[ -f "$DUMP_PATH" ] || fail "Fichier non trouvé: $DUMP_PATH"
gzip -t "$DUMP_PATH" || fail "Dump corrompu (gzip check échoué)"
SIZE=$(stat -f%z "$DUMP_PATH" 2>/dev/null || stat -c%s "$DUMP_PATH")
log "Dump: $DUMP_FILE ($(( SIZE / 1024 / 1024 ))M)"

# Arrêter Immich
log "Arrêt Immich..."
docker-compose down

# Redémarrer PostgreSQL seul
log "Redémarrage PostgreSQL..."
docker-compose up -d database
sleep 5

# DROP la BD depuis user postgres (PAS DROP SCHEMA)
log "Suppression BD immich..."
docker exec immich_postgres psql -U postgres -d postgres -c "DROP DATABASE IF EXISTS immich;" || true
sleep 1
docker exec immich_postgres psql -U postgres -d postgres -c "CREATE DATABASE immich OWNER immich;" || true
sleep 2

# Restaurer dans la BD immich (avec -d immich spécifié)
log "Restauration du dump..."
gunzip -c "$DUMP_PATH" | docker exec -i immich_postgres psql -U immich -d immich 2>&1 | grep -v "^$" || true
ok "Dump restauré"

# Redémarrer tout Immich
log "Redémarrage Immich..."
docker-compose up -d
sleep 15

# Vérifications POST
log "Vérifications..."
ASSET_COUNT=$(docker exec immich_postgres psql -U immich -d immich -t -c "SELECT COUNT(*) FROM asset;" 2>/dev/null | tr -d ' ' || echo "ERROR")
if [ "$ASSET_COUNT" = "ERROR" ]; then
  fail "Impossible de lire le count d'assets"
fi
ok "Assets: $ASSET_COUNT"

# Chercher erreurs Immich
ERRORS=$(docker logs immich_server 2>&1 | grep -i "error\|migration fail" | head -3 || true)
if [ -n "$ERRORS" ]; then
  log "⚠️  Erreurs détectées:"
  echo "$ERRORS" | sed 's/^/  /'
fi

echo ""
docker-compose ps >> "$LOG_FILE"
echo ""

# Résumé final
SUMMARY="
========================================
Restauration complète
========================================
Dump restauré    : $DUMP_FILE
Fichier          : $DUMP_PATH
Taille           : $(( SIZE / 1024 / 1024 ))M
Assets restorés  : $ASSET_COUNT
Log              : $LOG_FILE
URL Immich       : http://localhost:2283
========================================"

echo "$SUMMARY"
echo "$SUMMARY" >> "$LOG_FILE"

ok "Restauration complète — logs dans $LOG_FILE"
