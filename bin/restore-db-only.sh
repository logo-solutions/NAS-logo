#!/usr/bin/env bash
# restore-db-only.sh — Restauration Immich complète (best practices officielles)
#
# Usage: bash bin/restore-db-only.sh /Volumes/Expansion12/immich-backup-db-YYYYMMDD-HHMMSS/immich-db-*.sql.gz
# Ou:     bash bin/restore-db-only.sh immich-db-20260604-124753.sql.gz (depuis journaux)
#
# Restore procedure basée sur:
# - Immich official docs (backup-and-restore)
# - PostgreSQL best practices
# - Docker Compose v2 (no docker-compose)
#
# ⚠️  DESTRUCTIVE: Supprime la BD existante. Backup avant!

set -euo pipefail

# ============================================================================
# CONFIGURATION
# ============================================================================

DUMP_FILE="${1:?Usage: $0 <dump_file_path_or_name>}"
IMMICH_HOME="/Users/logo/immich"
JOURNAUX="/Volumes/NAS-LOGO-DATA/journaux"
RESTORE_LOG="${JOURNAUX}/restore-$(date +%Y%m%d-%H%M%S).log"

# ============================================================================
# HELPERS
# ============================================================================

log()  { echo "[$(date +'%H:%M:%S')] $*" | tee -a "$RESTORE_LOG"; }
ok()   { echo "[$(date +'%H:%M:%S')] ✓ $*" | tee -a "$RESTORE_LOG"; }
fail() { echo "[$(date +'%H:%M:%S')] ✗ $*" | tee -a "$RESTORE_LOG" >&2; exit 1; }
warn() { echo "[$(date +'%H:%M:%S')] ⚠️  $*" | tee -a "$RESTORE_LOG"; }

sql() {
  docker exec -i immich_postgres psql -U immich -d immich -t -c "$1" 2>/dev/null || echo "ERROR"
}

# ============================================================================
# ÉTAPE 0: RÉSOUDRE LE CHEMIN DU DUMP
# ============================================================================

log "=========================================="
log "RESTAURATION IMMICH — Best Practices"
log "=========================================="
log ""

# Chercher le dump dans plusieurs emplacements possibles
DUMP_PATH=""
if [ -f "$DUMP_FILE" ]; then
  DUMP_PATH="$DUMP_FILE"
elif [ -f "/Volumes/Expansion12/$DUMP_FILE" ]; then
  DUMP_PATH="/Volumes/Expansion12/$DUMP_FILE"
elif [ -f "/Volumes/NAS-LOGO-DATA/journaux/$DUMP_FILE" ]; then
  DUMP_PATH="/Volumes/NAS-LOGO-DATA/journaux/$DUMP_FILE"
else
  fail "Dump non trouvé: $DUMP_FILE (ni chemin complet, ni Expansion12, ni journaux)"
fi

ok "Dump trouvé: $DUMP_PATH"

# ============================================================================
# ÉTAPE 0.5: CONFIRMATION DU PATH
# ============================================================================

log ""
log "⚠️  CONFIRMATION REQUISE"
log "Chemin dump: $DUMP_PATH"
log ""
read -p "Continuer avec ce dump? (oui/non): " CONFIRM_PATH
if [ "$CONFIRM_PATH" != "oui" ]; then
  fail "Restauration annulée par l'utilisateur"
fi
ok "Path confirmé"

# ============================================================================
# ÉTAPE 0.6: ANALYSE DUMP (AUDIT)
# ============================================================================

log ""
log "ÉTAPE 0.6: Analyse du dump..."

# Créer répertoire audit temporaire
AUDIT_DIR="/tmp/immich-restore-audit-$$"
mkdir -p "$AUDIT_DIR"

# Lancer audit immich-dump-v3.sh
if [ -f "/Volumes/logousb/SSD/Projects/NAS-logo/bin/immich-audit-dump-v3.sh" ]; then
  bash /Volumes/logousb/SSD/Projects/NAS-logo/bin/immich-audit-dump-v3.sh "$DUMP_PATH" "$AUDIT_DIR" 2>&1 | tee -a "$RESTORE_LOG"

  # Lire résultats audit
  AUDIT_REPORT="$AUDIT_DIR/immich-audit-$(basename "$DUMP_PATH" .sql.gz).md"
  if [ -f "$AUDIT_REPORT" ]; then
    log ""
    log "📊 RÉSUMÉ DUMP:"
    log "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    head -50 "$AUDIT_REPORT" | tail -30 | tee -a "$RESTORE_LOG"
    log "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  fi
else
  warn "Script audit non trouvé (immich-audit-dump-v3.sh)"
fi

# ============================================================================
# ÉTAPE 1: CONFIRMATION AVANT RESTAURATION
# ============================================================================

log ""
log "⚠️  DERNIER AVERTISSEMENT"
log "Cette opération va:"
log "  1. Faire backup sécurité de la BD actuelle"
log "  2. SUPPRIMER la BD Immich existante"
log "  3. Restaurer le dump"
log "  4. Redémarrer les services"
log ""
read -p "Êtes-vous SÛR de vouloir continuer? (oui/je-comprends-le-risque): " CONFIRM_RESTORE
if [ "$CONFIRM_RESTORE" != "je-comprends-le-risque" ]; then
  fail "Restauration annulée par l'utilisateur"
fi
ok "Restauration confirmée — démarrage immédiat"

# ============================================================================
# ÉTAPE 1.5: VÉRIFICATIONS PRÉALABLES
# ============================================================================

log ""
log "ÉTAPE 1: Vérifications préalables..."

# Vérifier intégrité gzip
if ! gzip -t "$DUMP_PATH" 2>/dev/null; then
  fail "Dump corrompu (gzip -t échoué)"
fi
ok "Dump intègre (gzip OK)"

# Taille
DUMP_SIZE=$(du -h "$DUMP_PATH" | awk '{print $1}')
log "  Fichier: $(basename "$DUMP_PATH")"
log "  Taille: $DUMP_SIZE"

# Vérifier Docker + Colima
if ! docker ps > /dev/null 2>&1; then
  fail "Docker (Colima) non accessible"
fi
ok "Docker accessible"

# ============================================================================
# ÉTAPE 2: BACKUP SÉCURITÉ (snapshot ancienne BD)
# ============================================================================

log ""
log "ÉTAPE 2: Backup sécurité (snapshot avant restauration)..."

BACKUP_DIR="${JOURNAUX}/restore-backup-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUP_DIR"

log "  Dumping BD actuelle..."
if docker exec immich_postgres pg_dump -U immich -d immich --format=plain --no-acl --no-owner 2>/dev/null | gzip > "$BACKUP_DIR/immich-backup-before-restore.sql.gz"; then
  BACKUP_SIZE=$(du -h "$BACKUP_DIR/immich-backup-before-restore.sql.gz" | awk '{print $1}')
  ok "Backup sécurité créé ($BACKUP_SIZE) — si restauration échoue: $BACKUP_DIR/immich-backup-before-restore.sql.gz"
else
  warn "Backup sécurité échoué (BD peut être vide?)"
fi

# ============================================================================
# ÉTAPE 3: ARRÊT SERVICES
# ============================================================================

log ""
log "ÉTAPE 3: Arrêt des services..."

cd "$IMMICH_HOME"
if docker compose ps 2>/dev/null | grep -q "Up"; then
  log "  Arrêt Docker Compose..."
  docker compose down 2>&1 | grep -v "^$" || true
  sleep 3
  ok "Services arrêtés"
else
  ok "Services déjà arrêtés"
fi

# ============================================================================
# ÉTAPE 4: NETTOYER BD (option 1: DROP + CREATE)
# ============================================================================

log ""
log "ÉTAPE 4: Préparation PostgreSQL..."

# Démarrer PostgreSQL seul (pas immich-server, pas redis, etc.)
log "  Démarrage PostgreSQL..."
docker compose up -d immich_postgres 2>&1 | grep -v "^$" || true
sleep 5

# Attendre que PostgreSQL soit prêt
for i in {1..30}; do
  if docker exec immich_postgres pg_isready -U postgres > /dev/null 2>&1; then
    ok "PostgreSQL prêt"
    break
  fi
  [ $i -eq 30 ] && fail "PostgreSQL timeout"
  sleep 1
done

# DROP la BD Immich existante
log "  Suppression BD immich..."
docker exec immich_postgres psql -U postgres -d postgres -c "DROP DATABASE IF EXISTS immich;" 2>&1 | grep -v "^$" || true
sleep 1

# CREATE BD vide pour restauration
log "  Création BD vide..."
docker exec immich_postgres psql -U postgres -d postgres -c "CREATE DATABASE immich OWNER immich;" 2>&1 | grep -v "^$" || true
sleep 2

ok "PostgreSQL préparé (DB immich vide)"

# ============================================================================
# ÉTAPE 5: RESTAURATION DU DUMP
# ============================================================================

log ""
log "ÉTAPE 5: Restauration du dump..."

START=$(date +%s)
if gunzip -c "$DUMP_PATH" | docker exec -i immich_postgres psql -U immich -d immich > /dev/null 2>&1; then
  END=$(date +%s)
  ELAPSED=$((END - START))
  ok "Dump restauré ($((ELAPSED / 60))m$((ELAPSED % 60))s)"
else
  fail "Restauration échouée (psql erreur)"
fi

# ============================================================================
# ÉTAPE 6: VÉRIFICATIONS IMMÉDIATEMENT POST-RESTORE
# ============================================================================

log ""
log "ÉTAPE 6: Vérifications post-restauration..."

# Vérifier migrations table
MIGRATION_COUNT=$(sql "SELECT COUNT(*) FROM kysely_migrations;" | tr -d ' ')
if [ "$MIGRATION_COUNT" = "0" ] || [ "$MIGRATION_COUNT" = "ERROR" ]; then
  fail "Migrations table vide ou erreur (BD restore échoué?)"
fi
ok "Migrations table présente ($MIGRATION_COUNT migrations)"

# Vérifier assets
ASSET_COUNT=$(sql "SELECT COUNT(*) FROM asset;" | tr -d ' ')
if [ "$ASSET_COUNT" = "ERROR" ]; then
  fail "Impossible de lire asset count (BD corrompue?)"
fi

ASSET_FILE_COUNT=$(sql "SELECT COUNT(DISTINCT \"assetId\") FROM asset_file;" | tr -d ' ')
if [ "$ASSET_FILE_COUNT" = "ERROR" ]; then
  fail "Impossible de lire asset_file count"
fi

log "  Assets: $ASSET_COUNT"
log "  Asset files: $ASSET_FILE_COUNT"

# Calculer variance
if [ "$ASSET_COUNT" -gt 0 ]; then
  VARIANCE=$((100 * ($ASSET_COUNT - $ASSET_FILE_COUNT) / $ASSET_COUNT))
  if [ "$VARIANCE" -gt 10 ] || [ "$VARIANCE" -lt -10 ]; then
    warn "Variance haute entre asset et asset_file ($VARIANCE%) — vérifier intégrité"
  else
    ok "Asset/file counts cohérents"
  fi
fi

# Vérifier users (normalement vide après restore du dump)
USER_COUNT=$(sql "SELECT COUNT(*) FROM \"user\";" | tr -d ' ')
log "  Users: $USER_COUNT (à recréer via web UI)"

# ============================================================================
# ÉTAPE 7: REDÉMARRAGE SERVICES
# ============================================================================

log ""
log "ÉTAPE 7: Redémarrage de la stack Immich..."

cd "$IMMICH_HOME"
docker compose up -d 2>&1 | grep -v "^$" || true
sleep 15

# Vérifier que immich_server est UP
for i in {1..30}; do
  if curl -s http://localhost:2283/api/server/ping 2>/dev/null | grep -q "pong"; then
    ok "Immich-server opérationnel"
    break
  fi
  [ $i -eq 30 ] && warn "Immich-server timeout (vérifier manuellement)"
  sleep 1
done

# ============================================================================
# ÉTAPE 8: VALIDATION FINALE
# ============================================================================

log ""
log "ÉTAPE 8: Validation finale..."

# Assets count (peut avoir changé pendant redémarrage)
FINAL_ASSET_COUNT=$(sql "SELECT COUNT(*) FROM asset;" | tr -d ' ' || echo "ERROR")
if [ "$FINAL_ASSET_COUNT" != "ERROR" ]; then
  if [ "$FINAL_ASSET_COUNT" -eq "$ASSET_COUNT" ]; then
    ok "Asset count stable ($FINAL_ASSET_COUNT)"
  else
    warn "Asset count changé pendant startup ($ASSET_COUNT → $FINAL_ASSET_COUNT)"
  fi
fi

# Vérifier erreurs Immich
ERRORS=$(docker logs immich_server 2>&1 | grep -i "error\|failed\|fatal" | head -5 || echo "")
if [ -n "$ERRORS" ]; then
  warn "Erreurs détectées dans Immich:"
  echo "$ERRORS" | sed 's/^/  /' | tee -a "$RESTORE_LOG"
else
  ok "Aucune erreur critique dans Immich"
fi

# ============================================================================
# ÉTAPE 9: RAPPORT FINAL
# ============================================================================

log ""
log "=========================================="
log "✓ RESTAURATION COMPLÈTE"
log "=========================================="
log ""
log "Dump restauré         : $(basename "$DUMP_PATH")"
log "Taille               : $DUMP_SIZE"
log "Assets               : $FINAL_ASSET_COUNT"
log "Migrations           : $MIGRATION_COUNT"
log "Users (à recréer)    : $USER_COUNT"
log ""
log "📁 URL Immich        : http://localhost:2283"
log "🔑 Action requise    : Créer admin account via web UI"
log "📋 Log               : $RESTORE_LOG"
log "💾 Backup sécurité   : $BACKUP_DIR/immich-backup-before-restore.sql.gz"
log ""
log "⚠️  PROCHAINES ÉTAPES:"
log "1. Accéder à http://localhost:2283"
log "2. Créer nouveau compte admin (user table était vide)"
log "3. Attendre Meilisearch reindex (peut être lent: 100k+ assets = heures)"
log "4. Vérifier que les photos s'affichent correctement"
log "5. Vérifier face recognition (may need re-processing)"
log ""
log "=========================================="

ok "Restauration terminée — logs complets dans $RESTORE_LOG"
