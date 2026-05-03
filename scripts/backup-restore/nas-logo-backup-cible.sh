#!/bin/bash
# backup-cible.sh — backup manuel très ciblé d'un service spécifique (avant opération sensible)
# Généré par Ansible (NAS-logo)
# Usage: nas-logo-backup-cible.sh --service immich|paperless|n8n|all [--no-transfer]
set -euo pipefail

BACKUP_DIR="/Volumes/logousb/SSD/NAS-LOGO-VOLUME/backups"
LOG_DIR="/Volumes/logousb/SSD/NAS-LOGO-VOLUME/../Projects/NAS-logo/scripts/backup-restore/logs"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/backup-cible-$(date +%Y%m%d-%H%M%S).log"
RCLONE="/opt/homebrew/bin/rclone"
DOCKER_HOST="unix:///Users/logo/.colima/default/docker.sock"
export DOCKER_HOST

NTFY_URL="http://localhost:8090/nas-logo"
SERVICE=""
NO_TRANSFER=false

cleanup() {
  rm -f "$BACKUP_DIR"/backup-cible-temp-*.sql.gz 2>/dev/null || true
}
trap cleanup EXIT

notify() {
  local title="$1" msg="$2" priority="${3:-default}"
  curl -s -H "Title: $title" -H "Priority: $priority" -d "$msg" "$NTFY_URL" || true
}

check_dump() {
  local dump_file="$1" service="$2"
  if ! gzip -t "$dump_file" 2>/dev/null; then
    echo "ERREUR : dump $service corrompu" | tee -a "$LOG_FILE" >&2
    exit 1
  fi
  local size
  size=$(stat -f%z "$dump_file" 2>/dev/null || echo 0)
  if [ "$size" -lt 1024 ]; then
    echo "ERREUR : dump $service trop petit (vide?)" | tee -a "$LOG_FILE" >&2
    exit 1
  fi
}

usage() {
  cat >&2 <<EOF
Usage: $(basename "$0") --service SERVICE [--no-transfer]

SERVICE : immich | paperless | n8n | all
--no-transfer : dump local seulement, ne pas envoyer vers Hetzner
EOF
  exit 1
}

[[ $# -eq 0 ]] && usage

while [[ $# -gt 0 ]]; do
  case "$1" in
    --service) SERVICE="$2"; shift 2 ;;
    --no-transfer) NO_TRANSFER=true; shift ;;
    -h|--help) usage ;;
    *) echo "Option inconnue: $1" >&2; usage ;;
  esac
done

[[ -z "$SERVICE" ]] && { echo "ERREUR: --service requis" >&2; usage; }

echo "==> Backup ciblé démarrée : $SERVICE ($(date))" | tee "$LOG_FILE" >&2
[[ "$NO_TRANSFER" == "true" ]] && echo "==> Mode DRY : pas de transfer Hetzner" | tee -a "$LOG_FILE" >&2

# Dump immich
if [[ "$SERVICE" == "immich" ]] || [[ "$SERVICE" == "all" ]]; then
  IMMICH_DUMP="$BACKUP_DIR/immich-db-backup-cible-$(date +%Y%m%d-%H%M%S).sql.gz"
  echo "==> Dump Immich..." | tee -a "$LOG_FILE" >&2
  /opt/homebrew/bin/docker exec immich_postgres pg_dumpall \
    --clean --if-exists --username=immich \
    | gzip > "$IMMICH_DUMP"
  check_dump "$IMMICH_DUMP" "Immich"
  SIZE=$(du -sh "$IMMICH_DUMP" | cut -f1)
  echo "==> ✓ Immich : $SIZE" | tee -a "$LOG_FILE" >&2

  if [[ "$NO_TRANSFER" == "false" ]]; then
    echo "==> Transfer Immich vers Hetzner manual/..." | tee -a "$LOG_FILE" >&2
    $RCLONE copy "$IMMICH_DUMP" "hetzner-crypt:manual/$(date +%Y%m%d-%H%M%S)/immich/" \
      --log-file "$LOG_FILE"
  fi
fi

# Dump paperless
if [[ "$SERVICE" == "paperless" ]] || [[ "$SERVICE" == "all" ]]; then
  PAPERLESS_DUMP="$BACKUP_DIR/paperless-db-backup-cible-$(date +%Y%m%d-%H%M%S).sql.gz"
  echo "==> Dump Paperless..." | tee -a "$LOG_FILE" >&2
  /opt/homebrew/bin/docker exec paperless_db pg_dump \
    --clean --if-exists --username=paperless paperless \
    | gzip > "$PAPERLESS_DUMP"
  check_dump "$PAPERLESS_DUMP" "Paperless"
  SIZE=$(du -sh "$PAPERLESS_DUMP" | cut -f1)
  echo "==> ✓ Paperless : $SIZE" | tee -a "$LOG_FILE" >&2

  if [[ "$NO_TRANSFER" == "false" ]]; then
    echo "==> Transfer Paperless vers Hetzner manual/..." | tee -a "$LOG_FILE" >&2
    $RCLONE copy "$PAPERLESS_DUMP" "hetzner-crypt:manual/$(date +%Y%m%d-%H%M%S)/paperless/" \
      --log-file "$LOG_FILE"
  fi
fi

# Dump n8n
if [[ "$SERVICE" == "n8n" ]] || [[ "$SERVICE" == "all" ]]; then
  N8N_DUMP="$BACKUP_DIR/n8n-db-backup-cible-$(date +%Y%m%d-%H%M%S).sql.gz"
  echo "==> Dump n8n..." | tee -a "$LOG_FILE" >&2
  /opt/homebrew/bin/docker exec n8n_db pg_dump \
    --clean --if-exists --username=n8n n8n \
    | gzip > "$N8N_DUMP"
  check_dump "$N8N_DUMP" "n8n"
  SIZE=$(du -sh "$N8N_DUMP" | cut -f1)
  echo "==> ✓ n8n : $SIZE" | tee -a "$LOG_FILE" >&2

  if [[ "$NO_TRANSFER" == "false" ]]; then
    echo "==> Transfer n8n vers Hetzner manual/..." | tee -a "$LOG_FILE" >&2
    $RCLONE copy "$N8N_DUMP" "hetzner-crypt:manual/$(date +%Y%m%d-%H%M%S)/n8n/" \
      --log-file "$LOG_FILE"
  fi
fi

echo "==> Backup cible terminée ($(date))" | tee -a "$LOG_FILE" >&2
notify "NAS-logo Backup cible OK" "Service=$SERVICE, No-transfer=$NO_TRANSFER. Voir $LOG_FILE." "default"
