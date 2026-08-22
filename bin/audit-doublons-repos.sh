#!/bin/bash
# audit-doublons-repos.sh — Identifier répertoires dupliqués entre deux disques
# Usage: bash bin/audit-doublons-repos.sh /Volumes/Expansion12 /Volumes/NAS-LOGO-DATA

set -e

DISK1="${1:?Fournir premier disque: ex /Volumes/Expansion12}"
DISK2="${2:?Fournir deuxième disque: ex /Volumes/NAS-LOGO-DATA}"
OUTPUT_DIR="/Volumes/NAS-LOGO-DATA/journaux"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
REPORT="$OUTPUT_DIR/audit-doublons-repos-$TIMESTAMP.md"

mkdir -p "$OUTPUT_DIR"

echo "# Audit Doublons Répertoires — $TIMESTAMP" > "$REPORT"
echo "" >> "$REPORT"
echo "Comparaison: \`$DISK1\` vs \`$DISK2\`" >> "$REPORT"
echo "" >> "$REPORT"

# 1. Créer signatures des répertoires (Disk1)
echo "## Étape 1: Scanner $DISK1..."
DISK1_SIGS="/tmp/disk1-sigs-$TIMESTAMP.txt"
find "$DISK1" -maxdepth 3 -type d ! -path "*/\.*" | while read DIR; do
    FILE_COUNT=$(find "$DIR" -maxdepth 1 -type f 2>/dev/null | wc -l)
    TOTAL_SIZE=$(du -sh "$DIR" 2>/dev/null | awk '{print $1}')
    DIR_NAME=$(basename "$DIR")
    echo "$DIR_NAME|$FILE_COUNT|$TOTAL_SIZE|$DIR" >> "$DISK1_SIGS"
done

# 2. Créer signatures des répertoires (Disk2)
echo "## Étape 2: Scanner $DISK2..."
DISK2_SIGS="/tmp/disk2-sigs-$TIMESTAMP.txt"
find "$DISK2" -maxdepth 3 -type d ! -path "*/\.*" | while read DIR; do
    FILE_COUNT=$(find "$DIR" -maxdepth 1 -type f 2>/dev/null | wc -l)
    TOTAL_SIZE=$(du -sh "$DIR" 2>/dev/null | awk '{print $1}')
    DIR_NAME=$(basename "$DIR")
    echo "$DIR_NAME|$FILE_COUNT|$TOTAL_SIZE|$DIR" >> "$DISK2_SIGS"
done

# 3. Chercher répertoires avec même nombre de fichiers + même taille
echo "## Étape 3: Identifier doublons potentiels..."
echo "" >> "$REPORT"
echo "### Répertoires dupliqués (même nom, même taille)" >> "$REPORT"
echo "" >> "$REPORT"

DOUBLONS=0
while IFS='|' read -r NAME1 COUNT1 SIZE1 PATH1; do
    while IFS='|' read -r NAME2 COUNT2 SIZE2 PATH2; do
        # Si même nom ET même taille
        if [[ "$NAME1" == "$NAME2" ]] && [[ "$SIZE1" == "$SIZE2" ]] && [[ "$COUNT1" -eq "$COUNT2" ]]; then
            echo "**Doublon détecté:**" >> "$REPORT"
            echo "- Disk1: \`$PATH1\` ($COUNT1 fichiers, $SIZE1)" >> "$REPORT"
            echo "- Disk2: \`$PATH2\` ($COUNT2 fichiers, $SIZE2)" >> "$REPORT"
            echo "" >> "$REPORT"
            ((DOUBLONS++))
        fi
    done < "$DISK2_SIGS"
done < "$DISK1_SIGS"

echo "**Total doublons trouvés: $DOUBLONS**" >> "$REPORT"

# 4. Vérifier avec hash complet (pour être sûr)
echo "" >> "$REPORT"
echo "### Vérification fine (hash des fichiers)..." >> "$REPORT"
echo "" >> "$REPORT"

echo "Vérification fine en cours (peut prendre du temps)..." >&2
CONFIRMED=0
while IFS='|' read -r NAME1 COUNT1 SIZE1 PATH1; do
    while IFS='|' read -r NAME2 COUNT2 SIZE2 PATH2; do
        if [[ "$NAME1" == "$NAME2" ]] && [[ "$SIZE1" == "$SIZE2" ]]; then
            # Créer hash de tous les fichiers dans le répertoire
            HASH1=$(find "$PATH1" -type f ! -path "*/\.*" -exec md5 {} \; 2>/dev/null | sort | md5 | awk '{print $1}')
            HASH2=$(find "$PATH2" -type f ! -path "*/\.*" -exec md5 {} \; 2>/dev/null | sort | md5 | awk '{print $1}')

            if [[ "$HASH1" == "$HASH2" ]]; then
                echo "✅ **DOUBLON CONFIRMÉ:** \`$NAME1\`" >> "$REPORT"
                echo "   - Disk1: \`$PATH1\`" >> "$REPORT"
                echo "   - Disk2: \`$PATH2\`" >> "$REPORT"
                echo "   - Hash: $HASH1" >> "$REPORT"
                echo "" >> "$REPORT"
                ((CONFIRMED++))
            fi
        fi
    done < "$DISK2_SIGS"
done < "$DISK1_SIGS"

echo "**Doublons confirmés: $CONFIRMED**" >> "$REPORT"

# 5. Recommandations
echo "" >> "$REPORT"
echo "## Stratégie de fusion (mettre à plat)" >> "$REPORT"
echo "" >> "$REPORT"
echo "1. Pour chaque doublon confirmé:" >> "$REPORT"
echo "   - Garder la copie la PLUS RÉCENTE (vérifier \`stat\`)" >> "$REPORT"
echo "   - Supprimer l'autre copie" >> "$REPORT"
echo "" >> "$REPORT"
echo "2. Créer une arborescence canonique unique:" >> "$REPORT"
echo "   - \`/Volumes/Expansion12-MERGED/personnes/Guido/photos/\`" >> "$REPORT"
echo "   - \`/Volumes/Expansion12-MERGED/personnes/Guido/documents/\`" >> "$REPORT"
echo "" >> "$REPORT"
echo "3. Copier (rsync avec --delete-after) vers la destination final" >> "$REPORT"
echo "" >> "$REPORT"

echo "Rapport généré: $REPORT"
cat "$REPORT"

# Cleanup
rm -f "$DISK1_SIGS" "$DISK2_SIGS"
