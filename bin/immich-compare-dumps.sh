#!/bin/bash
#
# immich-compare-dumps.sh — Comparer deux dumps Immich PostgreSQL
# Usage: ./bin/immich-compare-dumps.sh <dump1.sql.gz> <dump2.sql> [output_dir]
#
# Compare la structure et les données entre deux backups pour identifier les différences.
#

set -euo pipefail

DUMP1="${1:?Usage: $0 <dump1.sql.gz> <dump2.sql> [output_dir]}"
DUMP2="${2:?Usage: $0 <dump1.sql.gz> <dump2.sql> [output_dir]}"
OUTPUT_DIR="${3:-.}"

if [[ ! -f "$DUMP1" ]]; then
  echo "❌ Dump 1 non trouvé: $DUMP1"
  exit 1
fi

if [[ ! -f "$DUMP2" ]]; then
  echo "❌ Dump 2 non trouvé: $DUMP2"
  exit 1
fi

# Déterminer si gzip ou SQL brut
IS_GZIP1=false
if file "$DUMP1" | grep -q gzip; then
  IS_GZIP1=true
fi

# Fonction pour lire le dump
read_dump1() {
  if [[ $IS_GZIP1 == true ]]; then
    gunzip -c "$DUMP1"
  else
    cat "$DUMP1"
  fi
}

read_dump2() {
  cat "$DUMP2"
}

# Préparer le rapport
DUMP1_NAME=$(basename "$DUMP1")
DUMP2_NAME=$(basename "$DUMP2")
TIMESTAMP=$(date -u +"%Y-%m-%d %H:%M:%S UTC")
REPORT="$OUTPUT_DIR/immich-compare-$(basename "$DUMP1" .sql.gz)-vs-$(basename "$DUMP2" .sql).md"

echo "📊 Comparaison en cours: $DUMP1_NAME vs $DUMP2_NAME"
echo "💾 Rapport: $REPORT"
echo ""

# Tables clés à comparer
TABLES=(
  "asset"
  "asset_file"
  "asset_exif"
  "asset_face"
  "smart_search"
  "user"
  "album"
  "album_asset"
  "person"
  "tag"
  "api_key"
  "session"
  "library"
  "memory"
  "notification"
)

# Générer le rapport
cat > "$REPORT" << EOF
# 📊 COMPARAISON DUMPS IMMICH

**Généré:** $TIMESTAMP

**Dump 1:** $DUMP1_NAME ($(du -h "$DUMP1" | cut -f1))
**Dump 2:** $DUMP2_NAME ($(du -h "$DUMP2" | cut -f1))

---

## 📋 COMPARAISON LIGNES PAR TABLE

| Table | Dump 1 | Dump 2 | Différence |
|-------|--------|--------|-----------|
EOF

# Compter et comparer
for table in "${TABLES[@]}"; do
  count1=$(read_dump1 | sed -n "/^COPY public\.$table /,/^\\\\./p" | grep -v "^COPY\|^\\\\." | wc -l)
  count2=$(read_dump2 | sed -n "/^COPY public\.$table /,/^\\\\./p" | grep -v "^COPY\|^\\\\." | wc -l)
  diff=$((count1 - count2))

  status="✅"
  if [ $diff -ne 0 ]; then
    status="❌"
  fi

  printf "| **%s** | %d | %d | %+d %s |\n" "$table" "$count1" "$count2" "$diff" "$status" >> "$REPORT"
done

cat >> "$REPORT" << 'EOF'

---

## 🎯 INTERPRÉTATION

- **Dump 1 > Dump 2:** Données perdues entre les deux
- **Dump 1 < Dump 2:** Nouvelles données dans Dump 2
- **Dump 1 = Dump 2:** Structure identique

### Notes Importantes

- Les **photos elles-mêmes** ne sont pas stockées en PostgreSQL
- Les tables *asset*, *asset_file*, etc. contiennent des **RÉFÉRENCES** et **MÉTADONNÉES**
- Les vrais fichiers image sont sur le disque dur (taille: variables)

---

**Rapport généré le:** $TIMESTAMP
EOF

echo "✅ Rapport généré: $REPORT"
wc -l "$REPORT"
