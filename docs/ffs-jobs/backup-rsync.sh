#!/bin/bash
# Sauvegarde séquentielle rsync — sans delete, avec reprise, pause après chaque job
# Log dans /Volumes/NAS-LOGO-DATA/journaux/

set -u

LOG_DIR="/Volumes/NAS-LOGO-DATA/journaux"
LOG="$LOG_DIR/backup-rsync-$(date +%Y%m%d-%H%M%S).log"
mkdir -p "$LOG_DIR"

log() {
  echo "$1" | tee -a "$LOG"
}

# 20 jobs (numéro|source|destination)
JOBS=(
  "01|/Volumes/NAS-LOGO-DATA/_done/google-takeout-sample/|/Volumes/Expansion12/sauvetmpo25mai/_done/google-takeout-sample/"
  "02|/Volumes/NAS-LOGO-DATA/_done/import16mai/|/Volumes/Expansion12/sauvetmpo25mai/_done/import16mai/"
  "03|/Volumes/NAS-LOGO-DATA/_done/NewAppPhoto29Avril/|/Volumes/Expansion12/sauvetmpo25mai/_done/NewAppPhoto29Avril/"
  "04|/Volumes/NAS-LOGO-DATA/_done/PhotoAvant2015/|/Volumes/Expansion12/sauvetmpo25mai/_done/PhotoAvant2015/"
  "05|/Volumes/NAS-LOGO-DATA/_done/scan-report/|/Volumes/Expansion12/sauvetmpo25mai/_done/scan-report/"
  "06|/Volumes/NAS-LOGO-DATA/_done/ssd-immich-upload-old/|/Volumes/Expansion12/sauvetmpo25mai/_done/ssd-immich-upload-old/"
  "07|/Volumes/NAS-LOGO-DATA/_done/ssd-imports-2015-2018/|/Volumes/Expansion12/sauvetmpo25mai/_done/ssd-imports-2015-2018/"
  "08|/Volumes/NAS-LOGO-DATA/_done/takeout-drive/|/Volumes/Expansion12/sauvetmpo25mai/_done/takeout-drive/"
  "09|/Volumes/NAS-LOGO-DATA/_done/toshiba-1-photoslibrary/|/Volumes/Expansion12/sauvetmpo25mai/_done/toshiba-1-photoslibrary/"
  "10|/Volumes/NAS-LOGO-DATA/_done/toshiba-a-classer2/|/Volumes/Expansion12/sauvetmpo25mai/_done/toshiba-a-classer2/"
  "11|/Volumes/NAS-LOGO-DATA/_done/toshiba-photos-videos-famille/|/Volumes/Expansion12/sauvetmpo25mai/_done/toshiba-photos-videos-famille/"
  "12|/Volumes/NAS-LOGO-DATA/_done/toshiba-sauvegarde-20150319/|/Volumes/Expansion12/sauvetmpo25mai/_done/toshiba-sauvegarde-20150319/"
  "13|/Volumes/NAS-LOGO-DATA/_done/wd-pix-macos-photoslibrary/|/Volumes/Expansion12/sauvetmpo25mai/_done/wd-pix-macos-photoslibrary/"
  "14|/Volumes/NAS-LOGO-DATA/_done/wd-videos-famille-lot1/|/Volumes/Expansion12/sauvetmpo25mai/_done/wd-videos-famille-lot1/"
  "15|/Volumes/NAS-LOGO-DATA/AFAIRE+tard/SauvAvril2026/|/Volumes/Expansion12/sauvetmpo25mai/SAUVAVRIL2026/"
  "16|/Volumes/NAS-LOGO-DATA/AFAIRE+tard/Sauv Icloud/|/Volumes/Expansion12/sauvetmpo25mai/AFAIRE+tard/Sauv Icloud/"
  "17|/Volumes/NAS-LOGO-DATA/AFAIRE+tard/videos Perso Familles Voyage/|/Volumes/Expansion12/sauvetmpo25mai/AFAIRE+tard/videos Perso Familles Voyage/"
  "18|/Volumes/NAS-LOGO-DATA/AFAIRE+tard/photos-toshiba-copy/|/Volumes/Expansion12/sauvetmpo25mai/AFAIRE+tard/photos-toshiba-copy/"
  "19|/Volumes/NAS-LOGO-DATA/NAS-LOGO-VOLUME/personnes/|/Volumes/Expansion12/backups/NAS/personnes/"
  "20|/Volumes/NAS-LOGO-DATA/_done/takeout-extracted/|/Volumes/Expansion12/sauvetmpo25mai/_done/takeout-extracted/"
)

total=${#JOBS[@]}

log "════════════════════════════════════════════════════════════════"
log "  DÉBUT SAUVEGARDE RSYNC — $(date '+%Y-%m-%d %H:%M:%S')"
log "  Log : $LOG"
log "  Jobs : $total"
log "  Mode : sans --delete (aucune suppression)"
log "════════════════════════════════════════════════════════════════"

for job in "${JOBS[@]}"; do
  IFS='|' read -r num source dest <<< "$job"

  log ""
  log "════════════════════════════════════════════════════════════════"
  log "  JOB $num/$total"
  log "  Source : $source"
  log "  Cible  : $dest"
  log "  Heure  : $(date '+%H:%M:%S')"
  log "════════════════════════════════════════════════════════════════"
  echo ""
  read -p "▶ Lancer ce job ? [Entrée=oui, s=skip, q=quitter] " choice

  case "$choice" in
    q|Q) log "⏹ Arrêt demandé à JOB $num"; exit 0 ;;
    s|S) log "⏭ Job $num skippé"; continue ;;
  esac

  # Créer répertoire destination si besoin
  mkdir -p "$(dirname "$dest")"

  log "→ Lancement rsync à $(date '+%H:%M:%S')"
  start=$(date +%s)

  # rsync SANS --delete (pas de suppression en destination)
  # -avh = archive, verbose, human-readable
  # --progress = progression fichier par fichier
  # --partial = garde les fichiers partiellement transférés (reprise)
  rsync -avh --progress --partial "$source" "$dest" 2>&1 | tee -a "$LOG"
  exit_code=${PIPESTATUS[0]}

  end=$(date +%s)
  duration=$((end - start))
  duration_str=$(printf '%dh%02dm%02ds' $((duration/3600)) $((duration%3600/60)) $((duration%60)))

  if [ "$exit_code" -eq 0 ]; then
    log "✅ Job $num terminé en $duration_str — $(date '+%H:%M:%S')"
  else
    log "❌ Job $num — ERREUR (code $exit_code) après $duration_str"
  fi

  # Visibilité après le job : tailles source vs destination
  log ""
  log "── Vérification tailles ──"
  src_size=$(du -sh "$source" 2>/dev/null | awk '{print $1}')
  dst_size=$(du -sh "$dest" 2>/dev/null | awk '{print $1}')
  log "  Source      : $src_size"
  log "  Destination : $dst_size"

  echo ""
  read -p "▶ Appuyer Entrée pour continuer (q=quitter) " next
  if [ "$next" = "q" ] || [ "$next" = "Q" ]; then
    log "⏹ Arrêt demandé après JOB $num"
    exit 0
  fi
done

log ""
log "════════════════════════════════════════════════════════════════"
log "  🎉 TOUS LES JOBS TERMINÉS — $(date '+%Y-%m-%d %H:%M:%S')"
log "  Log complet : $LOG"
log "════════════════════════════════════════════════════════════════"
