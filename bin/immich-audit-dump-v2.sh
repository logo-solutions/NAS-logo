#!/bin/bash
#
# immich-audit-dump-v2.sh — Audit complet détaillé (toutes les tables)
# Usage: ./bin/immich-audit-dump-v2.sh <dump.sql> [output_dir]
#

set -euo pipefail

DUMP="${1:?Usage: $0 <dump.sql> [output_dir]}"
OUTPUT_DIR="${2:-.}"

if [[ ! -f "$DUMP" ]]; then
  echo "❌ Dump non trouvé: $DUMP"
  exit 1
fi

# Déterminer si gzip ou SQL brut
IS_GZIP=false
if file "$DUMP" | grep -q gzip; then
  IS_GZIP=true
fi

# Fonction pour lire le dump
read_dump() {
  if [[ $IS_GZIP == true ]]; then
    gunzip -c "$DUMP"
  else
    cat "$DUMP"
  fi
}

# Préparer le rapport
DUMP_NAME=$(basename "$DUMP")
TIMESTAMP=$(date -u +"%Y-%m-%d %H:%M:%S UTC")
REPORT="$OUTPUT_DIR/immich-audit-$(basename "$DUMP" .sql.gz).md"

echo "📊 Audit en cours: $DUMP_NAME"
echo "💾 Rapport: $REPORT"

# Vérifier intégrité gzip
GZIP_OK="❌"
if [[ $IS_GZIP == true ]]; then
  if gunzip -t "$DUMP" 2>/dev/null; then
    GZIP_OK="✅"
  fi
fi

# Extraire toutes les tables avec comptage
echo "📋 Inventaire des tables..."
TABLES_INVENTORY=$(read_dump | grep "^COPY public\." | sed 's/^COPY public."\([^"]*\)".*/\1/' | sort -u | while read table; do
  count=$(read_dump | sed -n "/^COPY public\.\"$table\" /,/^\\\\./p" | grep -v "^COPY\|^\\\\." | wc -l)
  echo "$table|$count"
done | sort -t'|' -k2 -rn)

# Compter total lignes
TOTAL_ROWS=$(echo "$TABLES_INVENTORY" | awk -F'|' '{sum+=$2} END {print sum}')
TABLE_COUNT=$(echo "$TABLES_INVENTORY" | grep -c '^' || echo 0)

# Générer rapport
cat > "$REPORT" << EOF
# 📊 AUDIT IMMICH COMPLET — $DUMP_NAME

**Généré:** $TIMESTAMP
**Fichier:** $DUMP_NAME
**Taille:** $(du -h "$DUMP" | cut -f1)
**Intégrité gzip:** $GZIP_OK

---

## 📋 RÉSUMÉ EXÉCUTIF

- **Total lignes:** $TOTAL_ROWS
- **Tables avec données:** $TABLE_COUNT
- **État:** $([ $TOTAL_ROWS -eq 0 ] && echo "🔴 VIDE" || echo "🟢 DONNÉES PRÉSENTES")

---

## 📊 INVENTAIRE DÉTAILLÉ PAR TABLE

| Table | Lignes |
|-------|--------|
EOF

# Ajouter toutes les tables
echo "$TABLES_INVENTORY" | while IFS='|' read -r table count; do
  echo "| \`$table\` | $count |" >> "$REPORT"
done

cat >> "$REPORT" << EOF

---

## 🔍 ANALYSE

EOF

if [ $TOTAL_ROWS -eq 0 ]; then
  cat >> "$REPORT" << EOF
### ⚠️ Dump VIDE

Ce dump ne contient aucune donnée:
- Aucun utilisateur
- Aucun asset/photo
- Aucun album
- Aucune métadonnée

**Verdict:** Non restaurable (schéma présent, données absentes)

EOF
else
  cat >> "$REPORT" << EOF
### ✅ Dump avec données

Ce dump contient $TOTAL_ROWS lignes réparties sur $TABLE_COUNT tables.

**Tables principales:**
EOF

  # Top 5 tables
  echo "$TABLES_INVENTORY" | head -5 | while IFS='|' read -r table count; do
    echo "- \`$table\`: $count lignes" >> "$REPORT"
  done
fi

cat >> "$REPORT" << EOF

---

**Audit généré le:** $TIMESTAMP
EOF

echo "✅ Rapport généré: $REPORT"
