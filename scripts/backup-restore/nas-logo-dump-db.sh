#!/bin/bash
# dump_db.sh — dump PostgreSQL Immich + Paperless + n8n via docker exec
# Généré par Ansible (NAS-logo)
set -euo pipefail

BACKUP_DIR="/Volumes/logousb/SSD/NAS-LOGO-VOLUME/backups"
LOG_DIR="/Volumes/logousb/SSD/NAS-LOGO-VOLUME/../Projects/NAS-logo/scripts/backup-restore/logs"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/dump-$(date +%Y%m%d-%H%M%S).log"
DOCKER_HOST="unix:///Users/logo/.colima/default/docker.sock"
export DOCKER_HOST

check_dump() {
  local dump_file="$1" service="$2"
  # Vérification intégrité gzip
  if ! gzip -t "$dump_file" 2>/dev/null; then
    echo "ERREUR : dump $service corrompu : $dump_file" | tee -a "$LOG_FILE" >&2
    exit 1
  fi
  # Vérification taille (> 1 Ko minimum)
  local size
  size=$(stat -f%z "$dump_file" 2>/dev/null || echo 0)
  if [ "$size" -lt 1024 ]; then
    echo "ERREUR : dump $service trop petit (vide?) : $dump_file ($size bytes)" | tee -a "$LOG_FILE" >&2
    exit 1
  fi
  local size_h
  size_h=$(du -sh "$dump_file" | cut -f1)
  echo "==> ✓ OK : $service dump OK ($size_h)" | tee -a "$LOG_FILE" >&2
}

# ── Immich ──────────────────────────────────────────────────────────────────
IMMICH_DUMP="$BACKUP_DIR/immich-db-$(date +%Y%m%d-%H%M%S).sql.gz"
echo "==> Dump PostgreSQL Immich..." | tee -a "$LOG_FILE" >&2
/opt/homebrew/bin/docker exec immich_postgres pg_dumpall \
  --clean \
  --if-exists \
  --username=immich \
  | gzip > "$IMMICH_DUMP"
check_dump "$IMMICH_DUMP" "Immich"

# ── Paperless ────────────────────────────────────────────────────────────────
PAPERLESS_DUMP="$BACKUP_DIR/paperless-db-$(date +%Y%m%d-%H%M%S).sql.gz"
echo "==> Dump PostgreSQL Paperless..." | tee -a "$LOG_FILE" >&2
/opt/homebrew/bin/docker exec paperless_db pg_dump \
  --clean \
  --if-exists \
  --username=paperless \
  paperless \
  | gzip > "$PAPERLESS_DUMP"
check_dump "$PAPERLESS_DUMP" "Paperless"

# ── n8n ──────────────────────────────────────────────────────────────────────
N8N_DUMP="$BACKUP_DIR/n8n-db-$(date +%Y%m%d-%H%M%S).sql.gz"
echo "==> Dump PostgreSQL n8n..." | tee -a "$LOG_FILE" >&2
/opt/homebrew/bin/docker exec n8n_db pg_dump \
  --clean \
  --if-exists \
  --username=n8n \
  n8n \
  | gzip > "$N8N_DUMP"
check_dump "$N8N_DUMP" "n8n"

# ── Nettoyage local (7 jours) ────────────────────────────
find "$BACKUP_DIR" -name "immich-db-*.sql.gz" -mtime +7 -delete
find "$BACKUP_DIR" -name "paperless-db-*.sql.gz" -mtime +7 -delete
find "$BACKUP_DIR" -name "n8n-db-*.sql.gz" -mtime +7 -delete
echo "==> Nettoyage dumps locaux > 7j terminé" | tee -a "$LOG_FILE" >&2
