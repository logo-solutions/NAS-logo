#!/bin/bash
# backup.sh — dump DB + sync rclone vers Hetzner + local MacOS-vide (dumps only)
# Généré par Ansible (NAS-logo)
set -euo pipefail

NTFY_URL="http://localhost:8090/nas-logo"
LOG_DIR="/Volumes/NAS-LOGO-DATA/NAS-LOGO-VOLUME/backups/../Projects/NAS-logo/scripts/backup-restore/logs"
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

# Déterminer le tier de sauvegarde (daily, weekly, ou monthly) selon le calendrier
TODAY=$(date +%Y%m%d)
DOW=$(date +%u)       # 1=lundi … 7=dimanche
DOM=$(date +%d)       # 01-31

if [ "$DOM" = "01" ]; then
  BACKUP_TIER="monthly"
  BACKUP_KEY=$(date +%Y%m)   # ex: 202605
elif [ "$DOW" = "7" ]; then
  BACKUP_TIER="weekly"
  BACKUP_KEY="$TODAY"
else
  BACKUP_TIER="daily"
  BACKUP_KEY="$TODAY"
fi

echo "==> Tier sauvegarde : $BACKUP_TIER/$BACKUP_KEY" | tee -a "$LOG_FILE" >&2

# 3. Sync SSD vers Hetzner chiffré (DB, backups, index, services)
# Exclusions : thumbs, encoded-video (reconstruits), meilisearch, monitoring (rebuilt)
echo "==> Sync SSD vers Hetzner..." | tee -a "$LOG_FILE" >&2
$RCLONE sync "/Volumes/logousb/SSD/NAS-LOGO-VOLUME" hetzner-crypt:current/ssd \
  --backup-dir "hetzner-crypt:${BACKUP_TIER}/${BACKUP_KEY}/ssd" \
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
# Exclusions : thumbs, encoded-video (reconstruits sur SSD), sources brutes déjà importées, fichiers système
echo "==> Sync HDD vers Hetzner..." | tee -a "$LOG_FILE" >&2
$RCLONE sync "/Volumes/NAS-LOGO-DATA" hetzner-crypt:current/hdd \
  --backup-dir "hetzner-crypt:${BACKUP_TIER}/${BACKUP_KEY}/hdd" \
  --exclude "immich/thumbs/**" \
  --exclude "immich/encoded-video/**" \
  --exclude "immich/backups/**" \
  --exclude "paperless/db/**" \
  --exclude "paperless/redis/**" \
  --exclude "_done/**" \
  --exclude "AFAIRE+tard/**" \
  --exclude "MAIL/**" \
  --exclude "files/**" \
  --exclude ".DS_Store" \
  --exclude "*.DS_Store" \
  --log-level INFO \
  --log-file "$LOG_FILE" \
  --min-age 5m

# 4b. Copie locale miroir → MacOS-vide/sauvegardeNAS (dumps Immich uniquement)
LOCAL_BACKUP="/Volumes/MacOS-vide/sauvegardeNAS"
if [ -d "$(dirname "$LOCAL_BACKUP")" ] && mount | grep -q "MacOS-vide"; then
  echo "==> Copie locale SSD → $LOCAL_BACKUP/current/ssd..." | tee -a "$LOG_FILE" >&2
  $RCLONE sync "/Volumes/logousb/SSD/NAS-LOGO-VOLUME" "$LOCAL_BACKUP/current/ssd" \
    --exclude "immich/thumbs/**" \
    --exclude "immich/encoded-video/**" \
    --exclude "meilisearch/**" \
    --exclude "monitoring/**" \
    --exclude ".DS_Store" \
    --exclude "*.DS_Store" \
    --log-level INFO \
    --log-file "$LOG_FILE" \
    --min-age 5m

  echo "==> Copie locale dumps Immich → $LOCAL_BACKUP/current/immich-dumps..." | tee -a "$LOG_FILE" >&2
  $RCLONE sync "/Volumes/NAS-LOGO-DATA/NAS-LOGO-VOLUME/backups" "$LOCAL_BACKUP/current/immich-dumps" \
    --log-level INFO \
    --log-file "$LOG_FILE"
else
  echo "==> WARN: MacOS-vide non monté — copie locale ignorée" | tee -a "$LOG_FILE" >&2
fi

# 5. Rétention : purger les anciennes versions par tier (daily, weekly, monthly)
echo "==> Application de la rétention (daily: 7, weekly: 4, monthly: 3)..." | tee -a "$LOG_FILE" >&2

for TIER in daily weekly monthly; do
  case "$TIER" in
    daily)   KEEP=7 ;;
    weekly)  KEEP=4 ;;
    monthly) KEEP=3 ;;
  esac

  echo "==> Purge versions $TIER (garder $KEEP)..." | tee -a "$LOG_FILE" >&2
  VERSIONS=$($RCLONE lsf "hetzner-crypt:${TIER}/" --dirs-only 2>/dev/null | sort -r)
  COUNT=0

  for V in $VERSIONS; do
    COUNT=$((COUNT+1))
    if [ $COUNT -gt $KEEP ]; then
      echo "==> Purge ${TIER}/$V" | tee -a "$LOG_FILE" >&2
      $RCLONE purge "hetzner-crypt:${TIER}/${V%/}" --log-file "$LOG_FILE" || true
    fi
  done
done

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))
DURATION_STR=$(duration_human "$DURATION")

echo "==> Sauvegarde terminée en $DURATION_STR ($(date))" | tee -a "$LOG_FILE" >&2
notify "NAS-logo Sauvegarde OK" "Terminée en $DURATION_STR. Voir $LOG_FILE." "low"
