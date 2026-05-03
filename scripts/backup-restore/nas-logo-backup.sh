#!/bin/bash
# backup.sh — dump DB + sync rclone vers Hetzner chiffré
# Généré par Ansible (NAS-logo)
set -euo pipefail

NTFY_URL="http://localhost:8090/nas-logo"
LOG_DIR="/Volumes/logousb/SSD/NAS-LOGO-VOLUME/../Projects/NAS-logo/scripts/backup-restore/logs"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/backup-$(date +%Y%m%d).log"
RCLONE="/opt/homebrew/bin/rclone"
START_TIME=$(date +%s)

notify() {
  local title="$1" msg="$2" priority="${3:-default}"
  curl -s -H "Title: $title" -H "Priority: $priority" -d "$msg" "$NTFY_URL" || true
}

duration_human() {
  local seconds=$1
  local hours=$((seconds / 3600))
  local minutes=$(((seconds % 3600) / 60))
  printf "%dh%02dm" "$hours" "$minutes"
}

# Mode maintenance : créer /tmp/nas-logo-maintenance pour suspendre les sauvegardes
if [ -f /tmp/nas-logo-maintenance ]; then
  echo "==> Mode maintenance actif — sauvegarde ignorée ($(date))" | tee "$LOG_FILE" >&2
  exit 0
fi

echo "==> Sauvegarde NAS-logo démarrée ($(date))" | tee "$LOG_FILE" >&2

# 1. Dump PostgreSQL
echo "==> Dump base de données..." | tee -a "$LOG_FILE" >&2
if ! /usr/local/bin/nas-logo-dump-db.sh 2>&1 | tee -a "$LOG_FILE"; then
  notify "NAS-logo Dump DB échoué" "Le dump PostgreSQL a échoué — sauvegarde annulée. Voir $LOG_FILE." "urgent"
  exit 1
fi

# 2. Vérification espace disque
echo "==> Vérification espace disque..." | tee -a "$LOG_FILE" >&2
FREE_GB=$(df -g "/Volumes/logousb/SSD/NAS-LOGO-VOLUME" | awk 'NR==2{print $4}')
if [ "$FREE_GB" -lt 5 ]; then
  notify "NAS-logo Espace critique" "Seulement ${FREE_GB}Go libres sur SSD — sync Hetzner ignorée." "urgent"
  exit 1
fi
echo "==> Espace OK : ${FREE_GB}Go libres" | tee -a "$LOG_FILE" >&2

# 3. Sync SSD vers Hetzner chiffré (DB, backups, index, services)
# Exclusions : thumbs, encoded-video (reconstruits), meilisearch, monitoring (rebuilt)
echo "==> Sync SSD vers Hetzner..." | tee -a "$LOG_FILE" >&2
$RCLONE sync "/Volumes/logousb/SSD/NAS-LOGO-VOLUME" hetzner-crypt:current/ssd \
  --backup-dir "hetzner-crypt:versions/$(date +%Y%m%d)/ssd" \
  --exclude "immich/thumbs/**" \
  --exclude "immich/encoded-video/**" \
  --exclude "meilisearch/**" \
  --exclude "monitoring/**" \
  --exclude ".DS_Store" \
  --exclude "*.DS_Store" \
  --log-level INFO \
  --log-file "$LOG_FILE" \
  --min-age 5m

# 4. Sync HDD vers Hetzner chiffré (fichiers Immich, Paperless, documents)
# Exclusions : thumbs, encoded-video (reconstruits sur SSD), fichiers système
echo "==> Sync HDD vers Hetzner..." | tee -a "$LOG_FILE" >&2
$RCLONE sync "/Volumes/logousb/SSD/NAS-LOGO-VOLUME" hetzner-crypt:current/hdd \
  --backup-dir "hetzner-crypt:versions/$(date +%Y%m%d)/hdd" \
  --exclude "immich/thumbs/**" \
  --exclude "immich/encoded-video/**" \
  --exclude "immich/backups/**" \
  --exclude "paperless/db/**" \
  --exclude "paperless/redis/**" \
  --exclude ".DS_Store" \
  --exclude "*.DS_Store" \
  --log-level INFO \
  --log-file "$LOG_FILE" \
  --min-age 5m

# 5. Rétention : purger les anciennes versions (garder min N versions)
echo "==> Application de la rétention (min 7 versions)..." | tee -a "$LOG_FILE" >&2
for bucket in ssd hdd; do
  echo "==> Purge versions $bucket > 7 jours..." | tee -a "$LOG_FILE" >&2
  $RCLONE lsd hetzner-crypt:versions 2>/dev/null | awk '{print $NF}' | sort -r | \
    tail -n +$(( 7 + 1 )) | while read dir; do
      if $RCLONE lsd "hetzner-crypt:versions/$dir/$bucket" 2>/dev/null | grep -q .; then
        echo "==> Purge version : $dir/$bucket" | tee -a "$LOG_FILE" >&2
        $RCLONE purge "hetzner-crypt:versions/$dir/$bucket" --log-file "$LOG_FILE" || true
      fi
    done
done

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))
DURATION_STR=$(duration_human "$DURATION")

echo "==> Sauvegarde terminée en $DURATION_STR ($(date))" | tee -a "$LOG_FILE" >&2
notify "NAS-logo Sauvegarde OK" "Terminée en $DURATION_STR. Voir $LOG_FILE." "low"
