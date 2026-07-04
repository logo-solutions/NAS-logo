#!/bin/bash
# Script d'inventaire complet avec du, find, et md5
# Usage: ./inventaire-nas.sh "/Volumes/[HDD-OLD]" "[destination]"
# destination = "expansion12" ou "nas-data-logo"

SOURCE_PATH="${1:?Erreur: fournir le chemin source /Volumes/[HDD-OLD]}"
DEST_TYPE="${2:-expansion12}"  # expansion12 ou nas-data-logo

# Déterminer les paths de destination
if [ "$DEST_TYPE" = "nas-data-logo" ]; then
  DEST_PATH="/Volumes/NAS-LOGO-DATA/NAS-LOGO-VOLUME"
  DEST_NAME="NAS-LOGO-DATA"
else
  DEST_PATH="/Volumes/Expansion12"
  DEST_NAME="Expansion12"
fi

# Extraire le nom du disque source
SOURCE_NAME=$(basename "$SOURCE_PATH")
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK_DIR="${SCRIPT_DIR}/${SOURCE_NAME}"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)

# Créer répertoire de travail
mkdir -p "$WORK_DIR"

# Fichiers de journaux
DU_LOG="${WORK_DIR}/du-${SOURCE_NAME}-${TIMESTAMP}.txt"
FIND_LOG="${WORK_DIR}/find-${SOURCE_NAME}-${TIMESTAMP}.txt"
MD5_LOG="${WORK_DIR}/md5-${SOURCE_NAME}-${TIMESTAMP}.txt"
RAPPORT="${WORK_DIR}/rapport-${SOURCE_NAME}-${TIMESTAMP}.txt"

echo "🔄 Inventaire en cours: $SOURCE_NAME"
echo "📂 Répertoire de travail: $WORK_DIR"
echo ""

# ============================================================================
# PHASE 1: DU (RAPIDE)
# ============================================================================
echo "📊 Phase 1/3: Calcul des tailles (du)..."

{
  echo "=== DU: TAILLES PAR REPERTOIRE ==="
  echo "Date: $(date '+%Y-%m-%d %H:%M:%S')"
  echo "Source: $SOURCE_PATH"
  echo ""
  du -sh "$SOURCE_PATH"/* 2>/dev/null | sort -hr
} > "$DU_LOG"

echo "✅ Tailles sauvegardées: $DU_LOG"

# ============================================================================
# PHASE 2: FIND (DÉTAIL COMPLET)
# ============================================================================
echo "🔎 Phase 2/3: Énumération des fichiers (find)..."

{
  echo "=== FIND: INVENTAIRE COMPLET ==="
  echo "Date: $(date '+%Y-%m-%d %H:%M:%S')"
  echo "Source: $SOURCE_PATH"
  echo "Format: taille | date-modification | chemin"
  echo ""
  find "$SOURCE_PATH" -type f -printf '%s | %TY-%Tm-%Td %TH:%TM:%TS | %p\n' 2>/dev/null | sort
} > "$FIND_LOG"

echo "✅ Énumération sauvegardée: $FIND_LOG"

# ============================================================================
# PHASE 3: MD5 (DETECTION DOUBLONS)
# ============================================================================
echo "🔐 Phase 3/3: Calcul des checksums (md5)..."

{
  echo "=== MD5: CHECKSUMS POUR DEDUPLICATION ==="
  echo "Date: $(date '+%Y-%m-%d %H:%M:%S')"
  echo "Source: $SOURCE_PATH"
  echo "Format: md5 | taille | chemin"
  echo ""
  find "$SOURCE_PATH" -type f -exec md5 -r {} \; 2>/dev/null | \
  awk '{
    # Extraire taille du fichier
    cmd = "stat -f %z \"" $NF "\""
    cmd | getline size
    close(cmd)
    printf "%s | %8d | %s\n", $1, size, $NF
  }' | sort
} > "$MD5_LOG"

echo "✅ Checksums sauvegardés: $MD5_LOG"

# ============================================================================
# RAPPORT PRINCIPAL
# ============================================================================
echo "📋 Génération du rapport..."

{
  echo "╔════════════════════════════════════════════════════════════════════╗"
  echo "║                   RAPPORT D'INVENTAIRE NAS                         ║"
  echo "╚════════════════════════════════════════════════════════════════════╝"
  echo ""
  echo "Date du rapport: $(date '+%Y-%m-%d %H:%M:%S')"
  echo ""

  # ============================================================================
  # SECTION 1: INFOS DISQUES
  # ============================================================================
  echo "╔════════════════════════════════════════════════════════════════════╗"
  echo "║ 1. INFORMATIONS DISQUES                                            ║"
  echo "╚════════════════════════════════════════════════════════════════════╝"
  echo ""

  echo "📦 DISQUE SOURCE (HDD-OLD)"
  echo "   Nom:     $SOURCE_NAME"
  echo "   Path:    $SOURCE_PATH"
  if [ -d "$SOURCE_PATH" ]; then
    SOURCE_SIZE=$(du -sh "$SOURCE_PATH" 2>/dev/null | cut -f1)
    SOURCE_FREE=$(df -h "$SOURCE_PATH" 2>/dev/null | tail -1 | awk '{print $4}')
    SOURCE_FILES=$(find "$SOURCE_PATH" -type f 2>/dev/null | wc -l)
    echo "   Taille:  $SOURCE_SIZE"
    echo "   Fichiers: $SOURCE_FILES"
    echo "   Libre:   $SOURCE_FREE"
    echo "   ✅ MONTE"
  else
    echo "   ❌ NON MONTE"
  fi
  echo ""

  echo "📦 DISQUE DESTINATION"
  echo "   Nom:     $DEST_NAME"
  echo "   Path:    $DEST_PATH"
  if [ -d "$DEST_PATH" ]; then
    DEST_SIZE=$(du -sh "$DEST_PATH" 2>/dev/null | cut -f1)
    DEST_FREE=$(df -h "$DEST_PATH" 2>/dev/null | tail -1 | awk '{print $4}')
    DEST_FILES=$(find "$DEST_PATH" -type f 2>/dev/null | wc -l)
    echo "   Taille:  $DEST_SIZE"
    echo "   Fichiers: $DEST_FILES"
    echo "   Libre:   $DEST_FREE"
    echo "   ✅ MONTE"
  else
    echo "   ❌ NON MONTE"
  fi
  echo ""

  # ============================================================================
  # SECTION 2: DU PAR REPERTOIRE (TOP 10)
  # ============================================================================
  echo "╔════════════════════════════════════════════════════════════════════╗"
  echo "║ 2. TOP 10 PLUS GROS REPERTOIRES (SOURCE)                           ║"
  echo "╚════════════════════════════════════════════════════════════════════╝"
  echo ""

  if [ -d "$SOURCE_PATH" ]; then
    du -sh "$SOURCE_PATH"/* 2>/dev/null | sort -hr | head -10 | \
    awk '{printf "   %-40s %8s\n", $2, $1}'
  else
    echo "   ❌ Disque source non accessible"
  fi
  echo ""

  # ============================================================================
  # SECTION 3: DOUBLONS DETECTS (MD5)
  # ============================================================================
  echo "╔════════════════════════════════════════════════════════════════════╗"
  echo "║ 3. DOUBLONS DETECTES (md5 identiques)                              ║"
  echo "╚════════════════════════════════════════════════════════════════════╝"
  echo ""

  if [ -f "$MD5_LOG" ]; then
    DUPLICATES=$(awk -F'|' '{print $1}' "$MD5_LOG" | sort | uniq -d | wc -l)
    echo "   Checksums dupliqués: $DUPLICATES"
    echo ""

    if [ "$DUPLICATES" -gt 0 ]; then
      echo "   Exemples de doublons:"
      awk -F'|' '{print $1}' "$MD5_LOG" | sort | uniq -d | while read hash; do
        echo "   Hash: $hash"
        grep "^$hash" "$MD5_LOG" | head -3 | awk -F'|' '{printf "      - %8d bytes: %s\n", $2, $3}'
        echo ""
      done | head -20
    fi
  else
    echo "   ⏳ Calcul des checksums en cours..."
  fi
  echo ""

  # ============================================================================
  # SECTION 4: FICHIERS MANQUANTS SUR DESTINATION
  # ============================================================================
  echo "╔════════════════════════════════════════════════════════════════════╗"
  echo "║ 4. FICHIERS À COPIER (rsync --dry-run)                            ║"
  echo "╚════════════════════════════════════════════════════════════════════╝"
  echo ""

  if [ -d "$SOURCE_PATH" ] && [ -d "$DEST_PATH" ]; then
    MISSING_COUNT=$(rsync --dry-run -avh "$SOURCE_PATH/" "$DEST_PATH/" 2>/dev/null | grep "^<" | wc -l)
    MISSING_SIZE=$(rsync --dry-run -avh "$SOURCE_PATH/" "$DEST_PATH/" 2>/dev/null | grep "^<" | awk '{s+=$5} END {printf "%.1f GB", s/1024/1024/1024}')

    echo "   📥 Fichiers À COPIER: $MISSING_COUNT"
    echo "   📏 Taille à transférer: ~$MISSING_SIZE"
    echo ""

    if [ "$MISSING_COUNT" -gt 0 ]; then
      echo "   Premiers 20 fichiers à copier:"
      rsync --dry-run -avh "$SOURCE_PATH/" "$DEST_PATH/" 2>/dev/null | grep "^<" | head -20 | \
      awk '{printf "      - %s\n", $2}'
      [ "$MISSING_COUNT" -gt 20 ] && echo "      ... et $((MISSING_COUNT - 20)) autres"
    fi
  else
    echo "   ❌ Impossible de comparer (disques non accessibles)"
  fi
  echo ""

  # ============================================================================
  # SECTION 5: FICHIERS DE JOURNAUX
  # ============================================================================
  echo "╔════════════════════════════════════════════════════════════════════╗"
  echo "║ 5. FICHIERS DE JOURNAUX GENERES                                   ║"
  echo "╚════════════════════════════════════════════════════════════════════╝"
  echo ""
  echo "   📂 Répertoire: $WORK_DIR"
  echo ""
  echo "   📄 du-${SOURCE_NAME}-${TIMESTAMP}.txt"
  echo "      → Tailles par répertoire"
  echo ""
  echo "   📄 find-${SOURCE_NAME}-${TIMESTAMP}.txt"
  echo "      → Énumération complète (taille | date | chemin)"
  echo ""
  echo "   📄 md5-${SOURCE_NAME}-${TIMESTAMP}.txt"
  echo "      → Checksums pour déduplication"
  echo ""
  echo "   📄 rapport-${SOURCE_NAME}-${TIMESTAMP}.txt"
  echo "      → Ce rapport (résumé exécutif)"
  echo ""

  # ============================================================================
  # SECTION 6: COMMANDES UTILES
  # ============================================================================
  echo "╔════════════════════════════════════════════════════════════════════╗"
  echo "║ 6. COMMANDES UTILES                                                ║"
  echo "╚════════════════════════════════════════════════════════════════════╝"
  echo ""
  echo "   # Afficher les doublons trouvés"
  echo "   awk -F'|' '{print \$1}' $MD5_LOG | sort | uniq -d"
  echo ""
  echo "   # Copier les fichiers manquants"
  echo "   rsync -avh --progress $SOURCE_PATH/ $DEST_PATH/"
  echo ""
  echo "   # Vérifier intégrité après copie"
  echo "   rsync --dry-run -avh $SOURCE_PATH/ $DEST_PATH/"
  echo ""

} | tee "$RAPPORT"

# ============================================================================
# RESUME FINAL
# ============================================================================
echo ""
echo "╔════════════════════════════════════════════════════════════════════╗"
echo "║ ✅ INVENTAIRE COMPLETE                                            ║"
echo "╚════════════════════════════════════════════════════════════════════╝"
echo ""
echo "📂 Tous les fichiers sauvegardés dans:"
echo "   $WORK_DIR"
echo ""
echo "📋 Accès rapides:"
echo "   cat $RAPPORT"
echo "   tail -20 $DU_LOG"
echo "   grep -E '^[a-f0-9]+' $MD5_LOG | cut -d'|' -f1 | sort | uniq -c | sort -rn | head -20"
echo ""
