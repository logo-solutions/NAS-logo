#!/bin/bash
# audit-hdd.sh — Audit arborescence d'un HDD avec profondeur 3 niveaux
# Usage: bash bin/audit-hdd.sh /Volumes/Expansion12
# Sortie: /Volumes/NAS-LOGO-DATA/journaux/hdd<nomdumontage> (arborescence indentée)

set -euo pipefail

if [ $# -eq 0 ]; then
  echo "Usage: bash bin/audit-hdd.sh /Volumes/MOUNTPOINT"
  echo "Génère un fichier hdd<nomdumontage> dans /Volumes/NAS-LOGO-DATA/journaux/"
  exit 1
fi

MOUNT_PATH="$1"
MOUNT_NAME=$(basename "$MOUNT_PATH")
OUTPUT_DIR="/Volumes/NAS-LOGO-DATA/journaux"
OUTPUT_FILE="$OUTPUT_DIR/hdd${MOUNT_NAME}"

if [ ! -d "$MOUNT_PATH" ]; then
  echo "Erreur: $MOUNT_PATH n'existe pas ou n'est pas un répertoire."
  exit 1
fi

mkdir -p "$OUTPUT_DIR"

echo "Audit de $MOUNT_PATH en cours..."
echo "Résultat sera écrit dans: $OUTPUT_FILE"
echo ""

{
  echo "═══════════════════════════════════════════════════════════════"
  echo "Audit HDD: $MOUNT_PATH"
  echo "Date: $(date)"
  echo "═══════════════════════════════════════════════════════════════"
  echo ""

  # Utiliser du -h --max-depth pour ne pas avoir besoin de sous-shells
  echo "📦 Racine"
  du -h --max-depth 3 "$MOUNT_PATH" 2>/dev/null | tail -n +2 | sort -k2 | awk -v mp="$MOUNT_PATH" '
    BEGIN { FS="\t" }
    {
      path=$2
      size=$1
      depth = gsub(/\//, "/", path) - gsub(/\//, "/", mp)
      name = substr(path, length(mp)+2)
      if (depth == 1) printf "├── %s (%s)\n", name, size
      else if (depth == 2) printf "│   ├── %s (%s)\n", name, size
      else if (depth == 3) printf "│   │   ├── %s (%s)\n", name, size
    }
  '

  echo ""
  echo "═══════════════════════════════════════════════════════════════"
  echo "Total du disque: $(du -sh "$MOUNT_PATH" 2>/dev/null | cut -f1)"
  echo "Espace disponible: $(df -h "$MOUNT_PATH" | tail -1 | awk '{print $4}')"
  echo "Pourcentage utilisé: $(df -h "$MOUNT_PATH" | tail -1 | awk '{print $5}')"
  echo "═══════════════════════════════════════════════════════════════"
} | tee "$OUTPUT_FILE"

echo ""
echo "✅ Audit terminé. Fichier: $OUTPUT_FILE"
