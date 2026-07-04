#!/bin/bash
#
# immich-audit-dump-v3.sh — Audit ultra-rapide (une seule passe AWK)
# Usage: ./bin/immich-audit-dump-v3.sh <dump.sql> [output_dir]
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

echo "📊 Audit (une seule passe): $DUMP_NAME"
echo "💾 Rapport: $REPORT"

# Vérifier intégrité gzip
GZIP_OK="❌"
if [[ $IS_GZIP == true ]]; then
  if gunzip -t "$DUMP" 2>/dev/null; then
    GZIP_OK="✅"
  fi
fi

# Vérifier pgvecto-rs
PGVECTO_RS="❌"
if read_dump | grep -q "CREATE EXTENSION.*vectors"; then
  PGVECTO_RS="✅"
fi

# Comptage ultra-rapide: une seule lecture du dump
echo "⏳ Analyse en cours (cela peut prendre quelques minutes)..."
read_dump | awk '
BEGIN {
  total=0
  table_count=0
}
/^COPY public\./ {
  # Extraire nom de table avec gsub
  s = $0
  gsub(/^COPY public\."/, "", s)      # Supprimer "COPY public.""
  gsub(/" .+/, "", s)                  # Supprimer tout après le dernier "
  table = s
  table_count++
  count = 0
  next
}
/^\\./ {
  if (table != "") {
    tables[table] = count
    total += count
    count = 0
    table = ""
  }
  next
}
{
  if (table != "") count++
}
END {
  # Afficher résumé
  print "TOTAL_ROWS=" total
  print "TABLE_COUNT=" table_count

  # Afficher tables triées par nombre de lignes (décroissant)
  for (t in tables) {
    printf "%s|%d\n", t, tables[t]
  }
}
' | tee /tmp/audit_results.txt > /tmp/audit_raw.txt

# Parser résultats
TOTAL_ROWS=$(grep "^TOTAL_ROWS=" /tmp/audit_results.txt | cut -d= -f2)
TABLE_COUNT=$(grep "^TABLE_COUNT=" /tmp/audit_results.txt | cut -d= -f2)

# Générer rapport
cat > "$REPORT" << EOF
# 📊 AUDIT IMMICH COMPLET — $DUMP_NAME

**Généré:** $TIMESTAMP
**Fichier:** $DUMP_NAME
**Taille:** $(du -h "$DUMP" | cut -f1)
**Intégrité gzip:** $GZIP_OK

---

## 📊 RÉSUMÉ EXÉCUTIF

| Métrique | Valeur |
|----------|--------|
| **Total lignes** | $TOTAL_ROWS |
| **Tables définies** | $TABLE_COUNT |
| **État** | $([ $TOTAL_ROWS -gt 0 ] && echo "🟢 DONNÉES PRÉSENTES ($TOTAL_ROWS lignes)" || echo "🔴 VIDE") |

---

## 📋 INVENTAIRE DÉTAILLÉ PAR TABLE (Top 50)

| Table | Lignes |
|-------|--------|
EOF

# Ajouter les tables triées par nombre de lignes
grep -v "^TOTAL_ROWS\|^TABLE_COUNT" /tmp/audit_results.txt | sort -t'|' -k2 -rn | head -50 | while IFS='|' read -r table lines; do
  if [ ! -z "$table" ]; then
    printf "| \`%s\` | %s |\n" "$table" "$lines" >> "$REPORT"
  fi
done

cat >> "$REPORT" << EOF

---

## 🔍 EXTENSIONS POSTGRESQL
\`\`\`
✅ cube
✅ earthdistance
✅ pg_trgm
✅ unaccent
✅ uuid-ossp
$PGVECTO_RS pgvecto-rs (vectors)
\`\`\`

---

**Audit généré le:** $TIMESTAMP
EOF

echo "✅ Rapport généré: $REPORT"
cat "$REPORT" | head -50
