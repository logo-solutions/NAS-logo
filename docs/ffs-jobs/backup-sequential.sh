#!/bin/bash
# Script de sauvegarde séquentielle avec pause entre chaque job
# Exclut les fichiers système macOS (._*, .DS_Store, etc.)

set -u

# Exclusions macOS
EXCLUDES=(
  --exclude='._*'
  --exclude='.DS_Store'
  --exclude='.TemporaryItems'
  --exclude='.Spotlight-V100'
  --exclude='.fseventsd'
  --exclude='.DocumentRevisions-V100'
  --exclude='.Trashes'
)

# Log file
LOG="/Volumes/NAS-LOGO-DATA/journaux/backup-seq-$(date +%Y%m%d-%H%M%S).log"
mkdir -p "$(dirname "$LOG")"

# Liste des 23 jobs (source|destination)
JOBS=(
  # Phase 3 — _done/ (17 jobs, du plus petit au plus grand)
  "1|/Volumes/NAS-LOGO-DATA/_done/gmail-archive.mbox|/Volumes/Expansion12/sauvetmpo25mai/_done/"
  "2|/Volumes/NAS-LOGO-DATA/_done/google-takeout-sample/|/Volumes/Expansion12/sauvetmpo25mai/_done/google-takeout-sample/"
  "3|/Volumes/NAS-LOGO-DATA/_done/import16mai/|/Volumes/Expansion12/sauvetmpo25mai/_done/import16mai/"
  "4|/Volumes/NAS-LOGO-DATA/_done/jpeg_corruptions.txt|/Volumes/Expansion12/sauvetmpo25mai/_done/"
  "5|/Volumes/NAS-LOGO-DATA/_done/NewAppPhoto29Avril/|/Volumes/Expansion12/sauvetmpo25mai/_done/NewAppPhoto29Avril/"
  "6|/Volumes/NAS-LOGO-DATA/_done/PhotoAvant2015/|/Volumes/Expansion12/sauvetmpo25mai/_done/PhotoAvant2015/"
  "7|/Volumes/NAS-LOGO-DATA/_done/scan_import.sh|/Volumes/Expansion12/sauvetmpo25mai/_done/"
  "8|/Volumes/NAS-LOGO-DATA/_done/scan-report/|/Volumes/Expansion12/sauvetmpo25mai/_done/scan-report/"
  "9|/Volumes/NAS-LOGO-DATA/_done/ssd-immich-upload-old/|/Volumes/Expansion12/sauvetmpo25mai/_done/ssd-immich-upload-old/"
  "10|/Volumes/NAS-LOGO-DATA/_done/ssd-imports-2015-2018/|/Volumes/Expansion12/sauvetmpo25mai/_done/ssd-imports-2015-2018/"
  "11|/Volumes/NAS-LOGO-DATA/_done/takeout-drive/|/Volumes/Expansion12/sauvetmpo25mai/_done/takeout-drive/"
  "12|/Volumes/NAS-LOGO-DATA/_done/toshiba-1-photoslibrary/|/Volumes/Expansion12/sauvetmpo25mai/_done/toshiba-1-photoslibrary/"
  "13|/Volumes/NAS-LOGO-DATA/_done/toshiba-a-classer2/|/Volumes/Expansion12/sauvetmpo25mai/_done/toshiba-a-classer2/"
  "14|/Volumes/NAS-LOGO-DATA/_done/toshiba-photos-videos-famille/|/Volumes/Expansion12/sauvetmpo25mai/_done/toshiba-photos-videos-famille/"
  "15|/Volumes/NAS-LOGO-DATA/_done/toshiba-sauvegarde-20150319/|/Volumes/Expansion12/sauvetmpo25mai/_done/toshiba-sauvegarde-20150319/"
  "16|/Volumes/NAS-LOGO-DATA/_done/wd-pix-macos-photoslibrary/|/Volumes/Expansion12/sauvetmpo25mai/_done/wd-pix-macos-photoslibrary/"
  "17|/Volumes/NAS-LOGO-DATA/_done/wd-videos-famille-lot1/|/Volumes/Expansion12/sauvetmpo25mai/_done/wd-videos-famille-lot1/"

  # Phase 2 — AFAIRE+tard (sans SAUV DD)
  "18|/Volumes/NAS-LOGO-DATA/AFAIRE+tard/SauvAvril2026/|/Volumes/Expansion12/sauvetmpo25mai/SAUVAVRIL2026/"
  "19|/Volumes/NAS-LOGO-DATA/AFAIRE+tard/Sauv Icloud/|/Volumes/Expansion12/sauvetmpo25mai/AFAIRE+tard/Sauv Icloud/"
  "20|/Volumes/NAS-LOGO-DATA/AFAIRE+tard/videos Perso Familles Voyage/|/Volumes/Expansion12/sauvetmpo25mai/AFAIRE+tard/videos Perso Familles Voyage/"
  "21|/Volumes/NAS-LOGO-DATA/AFAIRE+tard/photos-toshiba-copy/|/Volumes/Expansion12/sauvetmpo25mai/AFAIRE+tard/photos-toshiba-copy/"

  # Optionnelle — personnes/
  "22|/Volumes/NAS-LOGO-DATA/NAS-LOGO-VOLUME/personnes/|/Volumes/Expansion12/backups/NAS/personnes/"

  # Dernier — takeout-extracted/ (gros)
  "23|/Volumes/NAS-LOGO-DATA/_done/takeout-extracted/|/Volumes/Expansion12/sauvetmpo25mai/_done/takeout-extracted/"
)

# Boucle sur chaque job
for job in "${JOBS[@]}"; do
  IFS='|' read -r num source dest <<< "$job"

  echo ""
  echo "════════════════════════════════════════════════════════════════"
  echo "  JOB $num/23"
  echo "  Source : $source"
  echo "  Cible  : $dest"
  echo "════════════════════════════════════════════════════════════════"
  echo ""
  read -p "▶ Lancer ce job ? [Entrée=oui, s=skip, q=quitter] " choice

  case "$choice" in
    q|Q) echo "Arrêt demandé. Bye."; exit 0 ;;
    s|S) echo "Job $num skippé."; continue ;;
  esac

  # Créer le répertoire destination si besoin
  mkdir -p "$(dirname "$dest")"

  # Lancer rsync
  echo "→ Lancement rsync..."
  rsync -avh --progress "${EXCLUDES[@]}" "$source" "$dest" 2>&1 | tee -a "$LOG"

  if [ ${PIPESTATUS[0]} -eq 0 ]; then
    echo "✅ Job $num terminé avec succès"
  else
    echo "❌ Job $num — ERREUR"
  fi

  echo ""
  read -p "▶ Vérifier puis appuyer Entrée pour continuer (q=quitter) " next
  [ "$next" = "q" ] || [ "$next" = "Q" ] && exit 0
done

echo ""
echo "🎉 Tous les jobs sont terminés !"
echo "Log complet : $LOG"
