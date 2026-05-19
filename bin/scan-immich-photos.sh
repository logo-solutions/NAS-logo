#!/bin/bash

IMMICH_DATA="/Volumes/NAS-LOGO-DATA/NAS-LOGO-VOLUME/personnes/loic-perso/immich"
LOG_FILE="/Volumes/NAS-LOGO-DATA/journaux/immich-scan-$(date +%Y%m%d-%H%M%S).log"
REPORT_FILE="/Volumes/NAS-LOGO-DATA/journaux/immich-scan-report-$(date +%Y%m%d-%H%M%S).txt"

{
  echo "=== Scan Cohérence Photos Immich ==="
  echo "Date: $(date)"
  echo "Répertoire: $IMMICH_DATA"
  echo

  # Stats fichiers
  echo "📊 Stats fichiers:"
  total=$(find "$IMMICH_DATA" -type f | wc -l)
  images=$(find "$IMMICH_DATA" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" \) | wc -l)
  videos=$(find "$IMMICH_DATA" -type f \( -iname "*.mp4" -o -iname "*.mov" -o -iname "*.mkv" -o -iname "*.avi" \) | wc -l)
  other=$((total - images - videos))
  size=$(du -sh "$IMMICH_DATA" | cut -f1)

  echo "  Total fichiers: $total"
  echo "  Images: $images"
  echo "  Vidéos: $videos"
  echo "  Autres: $other"
  echo "  Taille totale: $size"
  echo

  # Vérifier fichiers orphelins (en FS mais pas en BD)
  echo "🔍 Vérification fichiers orphelins..."
  orphans=0
  find "$IMMICH_DATA" -type f -name "*" | while read file; do
    filename=$(basename "$file")
    # Vérifier si fichier existe en BD (simple check par nom)
    if ! docker exec immich_postgres psql -U postgres -d immich -t -c \
         "SELECT 1 FROM assets WHERE original_file_name = '$filename' LIMIT 1;" 2>/dev/null | grep -q "1"; then
      echo "  ⚠️  Orphelin: $file"
      ((orphans++))
    fi
  done
  echo "  Fichiers orphelins trouvés: $orphans"
  echo

  # Vérifier fichiers corrompus (taille 0, en-têtes invalides)
  echo "🔧 Vérification fichiers corrompus..."
  corrupted=0

  # Fichiers vides
  empty=$(find "$IMMICH_DATA" -type f -size 0 | wc -l)
  if [ $empty -gt 0 ]; then
    echo "  ⚠️  Fichiers vides: $empty"
    find "$IMMICH_DATA" -type f -size 0 | head -5 | sed 's/^/    /'
    corrupted=$((corrupted + empty))
  fi

  # Fichiers avec en-têtes invalides (simple check JPEG)
  invalid_jpg=$(find "$IMMICH_DATA" -type f -iname "*.jpg" -o -iname "*.jpeg" | while read f; do
    if ! file "$f" 2>/dev/null | grep -q "JPEG\|image"; then
      echo "$f"
    fi
  done | wc -l)

  if [ $invalid_jpg -gt 0 ]; then
    echo "  ⚠️  JPEG invalides: $invalid_jpg"
    corrupted=$((corrupted + invalid_jpg))
  fi

  echo "  Total fichiers corrompus: $corrupted"
  echo

  # Vérifier doublons (même contenu)
  echo "🔄 Scan doublons (par hash SHA256)..."
  echo "  (long — peut prendre 5-10 min)"

  dupes=0
  declare -A hashes

  find "$IMMICH_DATA" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.mp4" \) | while read file; do
    hash=$(sha256sum "$file" 2>/dev/null | cut -d' ' -f1)
    if [ -z "$hash" ]; then
      continue
    fi

    # Vérifier si hash déjà vu
    if grep -q "^$hash" /tmp/immich_hashes.txt 2>/dev/null; then
      echo "  🔁 Doublon détecté:"
      grep "^$hash" /tmp/immich_hashes.txt | head -1
      echo "     vs $file"
      ((dupes++))
    else
      echo "$hash|$file" >> /tmp/immich_hashes.txt
    fi
  done

  echo "  Doublons trouvés: $dupes"
  rm -f /tmp/immich_hashes.txt
  echo

  # Intégrité BD vs FS
  echo "🗂️ Vérification BD vs Filesystem..."
  db_count=$(docker exec immich_postgres psql -U postgres -d immich -t -c \
    "SELECT COUNT(*) FROM assets;" 2>/dev/null | tr -d ' ')
  fs_count=$images

  echo "  Photos en BD: $db_count"
  echo "  Photos en FS: $fs_count"

  if [ $db_count -ne $fs_count ]; then
    echo "  ⚠️  MISMATCH: BD a $db_count, FS a $fs_count"
  else
    echo "  ✓ Cohérence OK"
  fi
  echo

  # Résumé
  echo "=== Résumé ==="
  echo "Fichiers totaux: $total"
  echo "Fichiers corrompus: $corrupted"
  echo "Doublons potentiels: $dupes"
  echo "Statut BD/FS: $([ $db_count -eq $fs_count ] && echo '✓ OK' || echo '❌ MISMATCH')"
  echo
  echo "Log complet: $LOG_FILE"

} | tee "$REPORT_FILE" "$LOG_FILE"

echo "✓ Scan terminé — rapport: $REPORT_FILE"
