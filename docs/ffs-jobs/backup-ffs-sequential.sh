#!/bin/bash
# Lance séquentiellement les 20 .ffs_batch FreeFileSync avec pause entre chaque
# Log centralisé dans /Volumes/NAS-LOGO-DATA/journaux/

set -u

FFS="/Applications/FreeFileSync.app/Contents/MacOS/FreeFileSync"
JOBS_DIR="/Volumes/logousb/SSD/Projects/NAS-logo/Docs/ffs-jobs"
LOG_DIR="/Volumes/NAS-LOGO-DATA/journaux"
LOG="$LOG_DIR/ffs-backup-$(date +%Y%m%d-%H%M%S).log"

mkdir -p "$LOG_DIR"

# Fonction de log : écrit à la fois à l'écran et dans le fichier
log() {
  echo "$1" | tee -a "$LOG"
}

# Liste des .ffs_batch (dans l'ordre)
BATCHES=(
  "$JOBS_DIR/01-google-takeout-sample.ffs_batch"
  "$JOBS_DIR/02-import16mai.ffs_batch"
  "$JOBS_DIR/03-NewAppPhoto29Avril.ffs_batch"
  "$JOBS_DIR/04-PhotoAvant2015.ffs_batch"
  "$JOBS_DIR/05-scan-report.ffs_batch"
  "$JOBS_DIR/06-ssd-immich-upload-old.ffs_batch"
  "$JOBS_DIR/07-ssd-imports-2015-2018.ffs_batch"
  "$JOBS_DIR/08-takeout-drive.ffs_batch"
  "$JOBS_DIR/09-toshiba-1-photoslibrary.ffs_batch"
  "$JOBS_DIR/10-toshiba-a-classer2.ffs_batch"
  "$JOBS_DIR/11-toshiba-photos-videos-famille.ffs_batch"
  "$JOBS_DIR/12-toshiba-sauvegarde-20150319.ffs_batch"
  "$JOBS_DIR/13-wd-pix-macos-photoslibrary.ffs_batch"
  "$JOBS_DIR/14-wd-videos-famille-lot1.ffs_batch"
  "$JOBS_DIR/15-SauvAvril2026.ffs_batch"
  "$JOBS_DIR/16-Sauv-Icloud.ffs_batch"
  "$JOBS_DIR/17-videos-Perso-Familles-Voyage.ffs_batch"
  "$JOBS_DIR/18-photos-toshiba-copy.ffs_batch"
  "$JOBS_DIR/19-personnes.ffs_batch"
  "$JOBS_DIR/20-takeout-extracted.ffs_batch"
)

log "════════════════════════════════════════════════════════════════"
log "  DÉBUT — $(date '+%Y-%m-%d %H:%M:%S')"
log "  Log : $LOG"
log "════════════════════════════════════════════════════════════════"

num=1
total=${#BATCHES[@]}

for batch in "${BATCHES[@]}"; do
  job_name=$(basename "$batch" .ffs_batch)

  log ""
  log "════════════════════════════════════════════════════════════════"
  log "  JOB $num/$total — $job_name"
  log "  Fichier : $batch"
  log "  Heure   : $(date '+%H:%M:%S')"
  log "════════════════════════════════════════════════════════════════"
  echo ""
  read -p "▶ Lancer ce job ? [Entrée=oui, s=skip, q=quitter] " choice

  case "$choice" in
    q|Q) log "⏹ Arrêt demandé à JOB $num"; exit 0 ;;
    s|S) log "⏭ Job $num skippé"; ((num++)); continue ;;
  esac

  log "→ Lancement FreeFileSync à $(date '+%H:%M:%S')"
  start=$(date +%s)

  "$FFS" "$batch" 2>&1 | tee -a "$LOG"
  exit_code=${PIPESTATUS[0]}

  end=$(date +%s)
  duration=$((end - start))

  if [ "$exit_code" -eq 0 ]; then
    log "✅ Job $num terminé en ${duration}s — $(date '+%H:%M:%S')"
  else
    log "❌ Job $num — ERREUR (code $exit_code) après ${duration}s"
  fi

  echo ""
  read -p "▶ Vérifier puis appuyer Entrée pour continuer (q=quitter) " next
  if [ "$next" = "q" ] || [ "$next" = "Q" ]; then
    log "⏹ Arrêt demandé après JOB $num"
    exit 0
  fi

  ((num++))
done

log ""
log "════════════════════════════════════════════════════════════════"
log "  🎉 TOUS LES JOBS TERMINÉS — $(date '+%Y-%m-%d %H:%M:%S')"
log "  Log complet : $LOG"
log "════════════════════════════════════════════════════════════════"
