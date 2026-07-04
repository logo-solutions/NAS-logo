#!/usr/bin/env bash
# colima-backup-daily.sh — Sauvegarde quotidienne de la config Colima
#
# Sauvegarde: config YAML + archive complète .colima/
# Destination: /Volumes/Expansion12/Backup/colima-YYYYMMDD-HHMMSS.tar.gz
# Logs: /Volumes/NAS-LOGO-DATA/journaux/
#
# Usage: bash bin/colima-backup-daily.sh
# LaunchAgent: com.nas-logo.colima-backup à 02:00 chaque jour

set -euo pipefail

# ============================================================================
# CONFIGURATION
# ============================================================================

COLIMA_HOME="${HOME}/.colima"
JOURNAUX="/Volumes/NAS-LOGO-DATA/journaux"
BACKUP_ROOT="/Volumes/Expansion12/Backup"
BACKUP_DATE=$(date +%Y%m%d-%H%M%S)
BACKUP_LOCATION="${BACKUP_ROOT}/colima-${BACKUP_DATE}.tar.gz"

LOG_FILE="${JOURNAUX}/colima-backup-daily-${BACKUP_DATE}.log"
RETENTION_DAYS=7

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
# TRACES DIAGNOSTIC (LaunchAgent debugging)
# ============================================================================

{
  echo "=== COLIMA BACKUP DIAGNOSTIC ==="
  echo "Timestamp: $(date)"
  echo "User: $(whoami)"
  echo "PID: $$"
  echo ""
  echo "1. État Colima:"
  if command -v colima &> /dev/null; then
    colima status 2>&1 || echo "  (Colima pas lancé)"
  else
    echo "  colima: NOT FOUND"
  fi
  echo ""
  echo "2. Répertoires:"
  echo "  COLIMA_HOME: $COLIMA_HOME"
  echo "  BACKUP_ROOT: $BACKUP_ROOT"
  echo "  LOG_FILE: $LOG_FILE"
  echo ""
} | tee "$LOG_FILE"

# ============================================================================
# VÉRIFICATIONS PRÉ-BACKUP
# ============================================================================

log "=== PRÉ-BACKUP CHECKS ==="

# 1. Vérifier existence .colima/
if [ ! -d "$COLIMA_HOME" ]; then
  error "COLIMA_HOME not found: $COLIMA_HOME"
fi
log "✓ COLIMA_HOME existe: $COLIMA_HOME"

# 2. Vérifier existence BACKUP_ROOT
if [ ! -d "$BACKUP_ROOT" ]; then
  log "⚠ BACKUP_ROOT n'existe pas, création: $BACKUP_ROOT"
  mkdir -p "$BACKUP_ROOT" || error "Cannot create BACKUP_ROOT"
fi
log "✓ BACKUP_ROOT existe: $BACKUP_ROOT"

# 3. Vérifier espace disque
AVAILABLE=$(df "$BACKUP_ROOT" | awk 'NR==2 {print $4}')
REQUIRED_KB=$((3500 * 1024))  # 3.5 GB minimum
if [ "$AVAILABLE" -lt "$REQUIRED_KB" ]; then
  error "Not enough space on $BACKUP_ROOT (available: ${AVAILABLE}KB, needed: ${REQUIRED_KB}KB)"
fi
log "✓ Espace disponible: ${AVAILABLE}KB (> ${REQUIRED_KB}KB)"

# 4. Vérifier JOURNAUX existe
if [ ! -d "$JOURNAUX" ]; then
  log "⚠ JOURNAUX n'existe pas, création: $JOURNAUX"
  mkdir -p "$JOURNAUX" || error "Cannot create JOURNAUX"
fi
log "✓ JOURNAUX existe: $JOURNAUX"

# ============================================================================
# SAUVEGARDE
# ============================================================================

log ""
log "=== SAUVEGARDE COLIMA ==="

START_TIME=$(date +%s)

# Archive complète .colima/
log "Archivage .colima/ → $BACKUP_LOCATION"
tar -czf "$BACKUP_LOCATION" \
  -C "$HOME" .colima/ \
  2>&1 | grep -v "^tar:.*Removing leading\|^tar:.*Could not pack\|socket" | tee -a "$LOG_FILE" || true

if [ ! -f "$BACKUP_LOCATION" ]; then
  error "Backup file not created: $BACKUP_LOCATION"
fi

BACKUP_SIZE=$(ls -lh "$BACKUP_LOCATION" | awk '{print $5}')
log "✓ Archive créée: $BACKUP_LOCATION ($BACKUP_SIZE)"

END_TIME=$(date +%s)
ELAPSED=$((END_TIME - START_TIME))
log "Temps total: ${ELAPSED}s"

# ============================================================================
# ROTATION (garder RETENTION_DAYS jours)
# ============================================================================

log ""
log "=== ROTATION (garde les ${RETENTION_DAYS} derniers jours) ==="

CUTOFF_DATE=$(date -d "-${RETENTION_DAYS} days" +%Y%m%d 2>/dev/null || date -v-${RETENTION_DAYS}d +%Y%m%d)
OLD_BACKUPS=$(find "$BACKUP_ROOT" -name "colima-*.tar.gz" -type f | while read f; do
  BACKUP_DATEONLY=$(basename "$f" | sed 's/colima-\([0-9]\{8\}\).*/\1/')
  if [ "$BACKUP_DATEONLY" -lt "$CUTOFF_DATE" ]; then
    echo "$f"
  fi
done)

if [ -z "$OLD_BACKUPS" ]; then
  log "Aucun backup à supprimer (< ${RETENTION_DAYS} jours)"
else
  echo "$OLD_BACKUPS" | while read old_backup; do
    OLD_SIZE=$(ls -lh "$old_backup" | awk '{print $5}')
    log "Suppression: $(basename "$old_backup") ($OLD_SIZE)"
    rm -f "$old_backup" || log "⚠ Erreur suppression: $old_backup"
  done
fi

# ============================================================================
# RÉSUMÉ
# ============================================================================

log ""
log "=== RÉSUMÉ ==="
log "✓ Backup complété avec succès"
log "  Fichier: $(basename "$BACKUP_LOCATION")"
log "  Taille: $BACKUP_SIZE"
log "  Durée: ${ELAPSED}s"

# Compter backups existants
TOTAL_BACKUPS=$(find "$BACKUP_ROOT" -name "colima-*.tar.gz" -type f | wc -l)
log "  Backups stockés: $TOTAL_BACKUPS"

TOTAL_SIZE=$(du -sh "$BACKUP_ROOT" | awk '{print $1}')
log "  Espace total utilisé: $TOTAL_SIZE"

log ""
log "=== FIN ==="

exit 0
