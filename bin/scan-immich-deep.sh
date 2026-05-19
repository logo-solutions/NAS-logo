#!/bin/bash

IMMICH_DATA="/Volumes/NAS-LOGO-DATA/NAS-LOGO-VOLUME/personnes/loic-perso/immich"
REPORT="/Volumes/NAS-LOGO-DATA/journaux/immich-deep-scan-$(date +%Y%m%d-%H%M%S).txt"
TEMP_ERRORS="/tmp/immich_scan_errors.txt"

{
  echo "╔════════════════════════════════════════════════════════════╗"
  echo "║ SCAN PROFOND Immich — FFmpeg + Validation media            ║"
  echo "╚════════════════════════════════════════════════════════════╝"
  echo "Démarrage: $(date '+%Y-%m-%d %H:%M:%S')"
  echo "Répertoire: $IMMICH_DATA"
  echo

  # Vérifier dépendances
  echo "🔧 Vérification dépendances..."
  deps=("ffprobe" "ffmpeg" "identify")
  for cmd in "${deps[@]}"; do
    if command -v "$cmd" &>/dev/null; then
      echo "  ✓ $cmd trouvé"
    else
      echo "  ❌ $cmd MANQUANT — install: brew install ffmpeg imagemagick"
    fi
  done
  echo

  rm -f "$TEMP_ERRORS"

  # ============================================================================
  # SCAN VIDÉOS
  # ============================================================================
  echo "🎬 SCAN VIDÉOS (FFprobe)"
  echo "────────────────────────"
  video_count=0
  video_errors=0
  video_corrupt_list=()

  find "$IMMICH_DATA" -type f \( -iname "*.mp4" -o -iname "*.mov" -o -iname "*.mkv" -o -iname "*.avi" -o -iname "*.m4v" \) | while read video; do
    ((video_count++))
    filename=$(basename "$video")
    filesize=$(stat -f%z "$video" 2>/dev/null)

    # FFprobe scan
    ffprobe_out=$(ffprobe -v error -select_streams v:0 -show_entries stream=codec_type,width,height,duration -of default=noprint_wrappers=1 "$video" 2>&1)
    if [ -z "$ffprobe_out" ] || echo "$ffprobe_out" | grep -q "Unknown format"; then
      echo "  ❌ CORRUPT: $filename ($(numfmt --to=iec $filesize 2>/dev/null || echo "$filesize bytes"))"
      echo "     Erreur: $ffprobe_out" | head -1
      echo "$video" >> "$TEMP_ERRORS"
      ((video_errors++))
    else
      duration=$(echo "$ffprobe_out" | grep "duration=" | cut -d= -f2 | cut -d. -f1)
      resolution=$(echo "$ffprobe_out" | grep -E "width=|height=" | tr '\n' ' ')
      echo "  ✓ OK: $filename (${duration}s, $resolution)"
    fi
  done

  echo "Vidéos scannées: $video_count | Erreurs: $video_errors"
  echo

  # ============================================================================
  # SCAN IMAGES
  # ============================================================================
  echo "🖼️ SCAN IMAGES (ImageMagick + FFprobe)"
  echo "──────────────────────────────────────"
  image_count=0
  image_errors=0

  find "$IMMICH_DATA" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" -o -iname "*.gif" -o -iname "*.heic" -o -iname "*.raw" \) | while read image; do
    ((image_count++))
    filename=$(basename "$image")
    filesize=$(stat -f%z "$image" 2>/dev/null)

    # Check via ImageMagick identify
    if command -v identify &>/dev/null; then
      id_out=$(identify -verbose "$image" 2>&1)
      if echo "$id_out" | grep -q "Geometry"; then
        geometry=$(echo "$id_out" | grep "Geometry:" | head -1 | awk '{print $2}')
        echo "  ✓ OK: $filename ($geometry, $(numfmt --to=iec $filesize 2>/dev/null || echo "$filesize bytes"))"
      else
        echo "  ❌ CORRUPT: $filename — ImageMagick ne peut pas lire"
        echo "$image" >> "$TEMP_ERRORS"
        ((image_errors++))
      fi
    else
      # Fallback: check file header
      magic=$(xxd -l 16 "$image" 2>/dev/null | head -1)
      if echo "$magic" | grep -qi "ffd8\|89png\|47494"; then
        echo "  ✓ OK: $filename (header valide)"
      else
        echo "  ❌ CORRUPT: $filename — en-tête invalide"
        echo "$image" >> "$TEMP_ERRORS"
        ((image_errors++))
      fi
    fi
  done

  echo "Images scannées: $image_count | Erreurs: $image_errors"
  echo

  # ============================================================================
  # SCAN AUDIO
  # ============================================================================
  echo "🎵 SCAN AUDIO (FFprobe)"
  echo "──────────────────────"
  audio_count=0
  audio_errors=0

  find "$IMMICH_DATA" -type f \( -iname "*.mp3" -o -iname "*.m4a" -o -iname "*.aac" -o -iname "*.flac" -o -iname "*.wav" \) | while read audio; do
    ((audio_count++))
    filename=$(basename "$audio")

    ffprobe_out=$(ffprobe -v error -select_streams a:0 -show_entries stream=codec_type,duration -of default=noprint_wrappers=1 "$audio" 2>&1)
    if [ -z "$ffprobe_out" ] || echo "$ffprobe_out" | grep -q "Unknown format"; then
      echo "  ❌ CORRUPT: $filename"
      echo "$audio" >> "$TEMP_ERRORS"
      ((audio_errors++))
    else
      echo "  ✓ OK: $filename"
    fi
  done

  echo "Audio scannés: $audio_count | Erreurs: $audio_errors"
  echo

  # ============================================================================
  # STATISTIQUES
  # ============================================================================
  echo "╔════════════════════════════════════════════════════════════╗"
  echo "║ RÉSUMÉ DU SCAN                                             ║"
  echo "╚════════════════════════════════════════════════════════════╝"

  total_scanned=$((video_count + image_count + audio_count))
  total_errors=$((video_errors + image_errors + audio_errors))
  error_rate=$(echo "scale=2; ($total_errors * 100) / $total_scanned" | bc 2>/dev/null || echo "N/A")

  echo "Fichiers scannés: $total_scanned"
  echo "  - Vidéos: $video_count ($video_errors erreurs)"
  echo "  - Images: $image_count ($image_errors erreurs)"
  echo "  - Audio: $audio_count ($audio_errors erreurs)"
  echo
  echo "Fichiers corrompus: $total_errors ($error_rate%)"
  echo

  if [ -f "$TEMP_ERRORS" ]; then
    echo "Fichiers à corriger (voir détails ci-dessous):"
    wc -l < "$TEMP_ERRORS"
    echo
    echo "📋 DÉTAILS FICHIERS CORROMPUS:"
    echo "────────────────────────────"
    cat "$TEMP_ERRORS" | nl
    echo
  fi

  echo "⏱️  Fin: $(date '+%Y-%m-%d %H:%M:%S')"
  echo "📄 Rapport: $REPORT"

  rm -f "$TEMP_ERRORS"

} | tee "$REPORT"

echo
echo "✓ Scan profond terminé"
echo "Rapport complet: $REPORT"
