#!/bin/bash

set -euo pipefail

# Script de nettoyage orphelins Immich — 6 étapes avec ceinture et bretelle
# Utilisation: ./cleanup-immich-orphans.sh [--dry-run] [--step N]

IMMICH_DATA="/Volumes/NAS-LOGO-DATA/NAS-LOGO-VOLUME/personnes/loic-perso/immich"
BACKUP_DIR="/Volumes/NAS-LOGO-DATA/journaux"
QUARANTINE_DIR="$BACKUP_DIR/immich-orphelins-$(date +%Y%m%d-%H%M%S)"
LOG_FILE="$BACKUP_DIR/immich-cleanup-$(date +%Y%m%d-%H%M%S).log"
CSV_ASSETS="/tmp/immich_assets_bd.csv"
CSV_FS="/tmp/immich_files_fs.csv"
MISSING_ASSETS="/tmp/immich_missing_on_fs.txt"
ORPHAN_FILES="/tmp/immich_orphan_files.txt"

DRY_RUN=false
START_STEP=0

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --dry-run) DRY_RUN=true; shift ;;
    --step) START_STEP=$2; shift 2 ;;
    *) echo "Usage: $0 [--dry-run] [--step N]"; exit 1 ;;
  esac
done

log() {
  local msg="$1"
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $msg" | tee -a "$LOG_FILE"
}

pause_and_confirm() {
  local prompt="$1"
  if [ "$DRY_RUN" = true ]; then
    log "DRY-RUN: $prompt (pas de confirmation)"
    return 0
  fi
  echo
  echo "⚠️  $prompt"
  echo "Continuer? (y/N)"
  read -r confirm
  if [ "$confirm" != "y" ]; then
    log "❌ Annulé par l'utilisateur"
    exit 1
  fi
}

# ============================================================================
# ÉTAPE 0 — Pré-flight
# ============================================================================
if [ "$START_STEP" -le 0 ]; then
  log "════════════════════════════════════════════════════════════"
  log "ÉTAPE 0 — Pré-flight check"
  log "════════════════════════════════════════════════════════════"

  # Vérifier Immich API
  if ! curl -s -m 2 http://localhost:2283/api/server/ping 2>/dev/null | grep -q "pong"; then
    log "❌ Immich API ne répond pas"
    exit 1
  fi
  log "✓ Immich API online"

  # Vérifier espace disque HDD
  available=$(df "$IMMICH_DATA" | tail -1 | awk '{print $4}')
  available_gb=$((available / 1024 / 1024))
  log "  HDD space available: ${available_gb} GB"
  if [ $available_gb -lt 500 ]; then
    log "❌ Espace insuffisant (besoin >= 500 GB)"
    exit 1
  fi
  log "✓ Espace disque OK"

  log "✓ Étape 0 complète"
  echo
fi

# ============================================================================
# ÉTAPE 1 — DUMP BD
# ============================================================================
if [ "$START_STEP" -le 1 ]; then
  log "════════════════════════════════════════════════════════════"
  log "ÉTAPE 1 — DUMP BD (ceinture)"
  log "════════════════════════════════════════════════════════════"

  DUMP_FILE="$BACKUP_DIR/immich-backup-pre-cleanup-$(date +%Y%m%d-%H%M%S).sql.gz"

  pause_and_confirm "Dump la BD Immich (500 Mo, ~30 sec) → $DUMP_FILE?"

  log "  Dump en cours..."
  if [ "$DRY_RUN" = false ]; then
    docker exec immich_postgres pg_dumpall --clean --if-exists -U immich 2>/dev/null | gzip > "$DUMP_FILE"
    log "  Vérification intégrité gzip..."
    if ! gzip -t "$DUMP_FILE" 2>/dev/null; then
      log "❌ Dump corrompu — annulation"
      rm -f "$DUMP_FILE"
      exit 1
    fi
    log "✓ Dump OK: $(du -h "$DUMP_FILE" | cut -f1)"
  else
    log "[DRY-RUN] Dump skipped"
  fi

  log "✓ Étape 1 complète"
  echo
fi

# ============================================================================
# ÉTAPE 2 — ANALYSE
# ============================================================================
if [ "$START_STEP" -le 2 ]; then
  log "════════════════════════════════════════════════════════════"
  log "ÉTAPE 2 — ANALYSE (read-only)"
  log "════════════════════════════════════════════════════════════"

  log "  2a. Export assets BD..."
  docker exec immich_postgres psql -U immich -d immich -c \
    "COPY (SELECT id, \"originalPath\", \"originalFileName\" FROM asset WHERE NOT \"isOffline\") \
     TO STDOUT CSV HEADER" > "$CSV_ASSETS"
  log "    $(wc -l < "$CSV_ASSETS") assets en BD"

  log "  2b. Scan FS Immich..."
  find "$IMMICH_DATA/upload" -type f > "$CSV_FS" 2>/dev/null
  log "    $(wc -l < "$CSV_FS") fichiers en FS"

  log "  2c. Croiser BD vs FS..."
  # Assets en BD dont le fichier n'existe pas
  > "$MISSING_ASSETS"
  while IFS=',' read -r id originalPath filename; do
    [ "$id" = "id" ] && continue # skip header
    # Remplacer /usr/src/app/upload par le chemin local
    local_path="/Volumes/NAS-LOGO-DATA/NAS-LOGO-VOLUME/personnes/loic-perso/immich${originalPath#/usr/src/app/upload}"
    if [ ! -f "$local_path" ]; then
      echo "$id|$originalPath|$filename" >> "$MISSING_ASSETS"
    fi
  done < "$CSV_ASSETS"

  # Fichiers en FS sans BD
  > "$ORPHAN_FILES"
  while read -r fs_file; do
    if ! grep -q "$(basename "$fs_file")" "$CSV_ASSETS" 2>/dev/null; then
      echo "$fs_file" >> "$ORPHAN_FILES"
    fi
  done < "$CSV_FS"

  missing_count=$(wc -l < "$MISSING_ASSETS")
  orphan_count=$(wc -l < "$ORPHAN_FILES")

  log "  📊 RÉSULTATS ANALYSE:"
  log "    Assets BD sans fichier FS: $missing_count"
  log "    Fichiers FS sans entrée BD: $orphan_count"

  log "✓ Étape 2 complète"
  echo
fi

# ============================================================================
# ÉTAPE 3 — DRY-RUN
# ============================================================================
if [ "$START_STEP" -le 3 ]; then
  log "════════════════════════════════════════════════════════════"
  log "ÉTAPE 3 — DRY-RUN (bretelle)"
  log "════════════════════════════════════════════════════════════"

  log "  Exemples assets BD sans fichier (10 premiers):"
  head -10 "$MISSING_ASSETS" | while IFS='|' read -r id path filename; do
    log "    ❌ $filename ($path)"
  done

  log "  Exemples fichiers FS sans BD (10 premiers):"
  head -10 "$ORPHAN_FILES" | while read -r file; do
    log "    🔁 $(basename "$file")"
  done

  pause_and_confirm "Procéder au nettoyage BD (marquer isOffline) et FS (déplacer en quarantaine)?"

  log "✓ Étape 3 complète"
  echo
fi

# ============================================================================
# ÉTAPE 4 — NETTOYAGE BD
# ============================================================================
if [ "$START_STEP" -le 4 ]; then
  log "════════════════════════════════════════════════════════════"
  log "ÉTAPE 4 — NETTOYAGE BD (UPDATE isOffline)"
  log "════════════════════════════════════════════════════════════"

  missing_ids=$(awk -F'|' '{print "'"'"'" $1 "'"'"'"}' "$MISSING_ASSETS" | paste -sd, -)

  if [ -z "$missing_ids" ]; then
    log "  Aucun asset à marquer offline"
  else
    if [ "$DRY_RUN" = false ]; then
      log "  UPDATE assets SET isOffline = true..."
      docker exec immich_postgres psql -U immich -d immich -c \
        "UPDATE asset SET \"isOffline\" = true WHERE id IN ($missing_ids);" > /dev/null
      log "✓ $(echo "$missing_ids" | tr ',' '\n' | wc -l) assets marqués offline"
    else
      log "[DRY-RUN] UPDATE skipped"
    fi
  fi

  log "✓ Étape 4 complète"
  echo
fi

# ============================================================================
# ÉTAPE 5 — NETTOYAGE FS
# ============================================================================
if [ "$START_STEP" -le 5 ]; then
  log "════════════════════════════════════════════════════════════"
  log "ÉTAPE 5 — NETTOYAGE FS (déplacer en quarantaine)"
  log "════════════════════════════════════════════════════════════"

  orphan_count=$(wc -l < "$ORPHAN_FILES")

  if [ "$orphan_count" -eq 0 ]; then
    log "  Aucun fichier orphelin"
  else
    if [ "$DRY_RUN" = false ]; then
      mkdir -p "$QUARANTINE_DIR"
      log "  Déplacement en quarantaine: $QUARANTINE_DIR"
      while read -r file; do
        [ -z "$file" ] && continue
        mv "$file" "$QUARANTINE_DIR/" 2>/dev/null || true
      done < "$ORPHAN_FILES"
      log "✓ $orphan_count fichiers en quarantaine"
      log "  Taille quarantaine: $(du -sh "$QUARANTINE_DIR" | cut -f1)"
    else
      log "[DRY-RUN] Move skipped"
    fi
  fi

  log "✓ Étape 5 complète"
  echo
fi

# ============================================================================
# ÉTAPE 6 — VÉRIFICATION FINALE
# ============================================================================
if [ "$START_STEP" -le 6 ]; then
  log "════════════════════════════════════════════════════════════"
  log "ÉTAPE 6 — VÉRIFICATION FINALE"
  log "════════════════════════════════════════════════════════════"

  log "  Recount assets actifs en BD..."
  active_count=$(docker exec immich_postgres psql -U immich -d immich -t -c \
    "SELECT COUNT(*) FROM asset WHERE NOT \"isOffline\" AND \"deletedAt\" IS NULL;")
  log "    Assets actifs: $active_count"

  log "  Vérif Immich API..."
  if curl -s -m 2 http://localhost:2283/api/server/ping | grep -q "pong"; then
    log "    ✓ API online"
  else
    log "    ❌ API offline — investigation requise"
  fi

  log "  📊 RÉSUMÉ FINAL:"
  log "    Assets marqués offline: $missing_count"
  log "    Fichiers en quarantaine: $orphan_count"
  log "    Assets restants actifs: $active_count"

  log "✓ Étape 6 complète"
  echo
fi

# ============================================================================
# CLEANUP
# ============================================================================
rm -f "$CSV_ASSETS" "$CSV_FS" "$MISSING_ASSETS" "$ORPHAN_FILES"

log "════════════════════════════════════════════════════════════"
log "✓ NETTOYAGE COMPLET"
log "════════════════════════════════════════════════════════════"
log "Log: $LOG_FILE"
if [ "$DRY_RUN" = false ] && [ "$orphan_count" -gt 0 ]; then
  log "Quarantaine: $QUARANTINE_DIR"
fi
log "Rollback: restore du dump si problème"
