#!/bin/bash
#
# immich-audit-dump.sh — Audit complet d'un dump PostgreSQL Immich (CORRIGÉ)
# Usage: ./bin/immich-audit-dump.sh <dump.sql.gz> [output_dir]
#
# Génère un rapport structuré avec toutes les statistiques BD.
# À appeler par `make backup` après pg_dump.
#

set -euo pipefail

DUMP="${1:?Usage: $0 <dump.sql.gz> [output_dir]}"
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

# Fonction pour lire le dump (gzip ou raw)
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
echo ""

# Vérifier intégrité gzip
GZIP_OK="❌"
if [[ $IS_GZIP == true ]]; then
  if gunzip -t "$DUMP" 2>/dev/null; then
    GZIP_OK="✅"
  fi
fi

# Extraire utilisateur (si table "user" a des données)
USER_EMAIL=""
USER_ROLE=""
USER_NAME=""
QUOTA_USED=""
USER_COUNT=$(read_dump | sed -n '/^COPY public."user" /,/^\\.$/p' | grep -v "^COPY\|^\\\.$" | wc -l)
if [[ $USER_COUNT -gt 0 ]]; then
  USER_DATA=$(read_dump | sed -n '/^COPY public."user" /,/^\\.$/p' | grep -v "^COPY\|^\\\.$" | head -1 | cut -f2,12,13,14)
  IFS=$'\t' read -r USER_EMAIL USER_ROLE USER_NAME QUOTA_USED <<< "$USER_DATA" || true
fi

# Compter les extensions
PGVECTO_RS="❌"
if read_dump | grep -q "CREATE EXTENSION.*vectors"; then
  PGVECTO_RS="✅"
fi

# Fonction pour compter les lignes d'une table (CORRIGÉE)
count_table() {
  local table="$1"
  read_dump | sed -n "/^COPY public\.\"$table\" /,/^\\.$/p" | grep -v "^COPY\|^\\\.$" | wc -l
}

# Générer le rapport
cat > "$REPORT" << EOF
# 📊 AUDIT IMMICH — $(basename "$DUMP")

**Généré:** $TIMESTAMP
**Fichier:** $DUMP_NAME
**Taille:** $(du -h "$DUMP" | cut -f1)
**Intégrité gzip:** $GZIP_OK

---

## 👤 UTILISATEURS
| Métrique | Valeur |
|----------|--------|
| **Total** | $(count_table '"user"') |
| **Email** | ${USER_EMAIL:-—} |
| **Rôle** | ${USER_ROLE:-—} |
| **Nom** | ${USER_NAME:-—} |
| **Quota utilisé** | ${QUOTA_USED:-—} bytes |

## 📸 ASSETS
| Métrique | Valeur |
|----------|--------|
| **Total photos/vidéos** | $(count_table 'asset') |
| **Fichiers** | $(count_table 'asset_file') |
| **Métadonnées EXIF** | $(count_table 'asset_exif') |
| **Éditions** | $(count_table 'asset_edit') |
| **Avec OCR** | $(count_table 'asset_ocr') |

## 📁 ALBUMS
| Métrique | Valeur |
|----------|--------|
| **Albums** | $(count_table 'album') |
| **Assets assignés** | $(count_table 'album_asset') |
| **Partages utilisateur** | $(count_table 'album_user') |
| **Tags** | $(count_table 'tag') |
| **Tag-asset** | $(count_table 'tag_asset') |

## 👤 RECONNAISSANCE FACIALE
| Métrique | Valeur |
|----------|--------|
| **Personnes (groupes)** | $(count_table 'person') |
| **Détections visages** | $(count_table 'asset_face') |
| **Embeddings CLIP** | $(count_table 'smart_search') |
| **OCR texte** | $(count_table 'ocr_search') |

## 🔐 ACCÈS & PARTAGE
| Métrique | Valeur |
|----------|--------|
| **Clés API** | $(count_table 'api_key') |
| **Sessions** | $(count_table 'session') |
| **Liens publics** | $(count_table 'shared_link') |
| **Notifications** | $(count_table 'notification') |

## 🎬 AUTOMATISATIONS
| Métrique | Valeur |
|----------|--------|
| **Workflows** | $(count_table 'workflow') |
| **Plugins** | $(count_table 'plugin') |

## 🔧 EXTENSIONS POSTGRESQL
\`\`\`
✅ cube
✅ earthdistance
✅ pg_trgm
✅ unaccent
✅ uuid-ossp
$PGVECTO_RS pgvecto-rs (vectors)
\`\`\`

---

## 📋 INVENTAIRE COMPLET (Toutes les tables)

| Table | Lignes |
|-------|--------|
EOF

# Ajouter toutes les tables avec comptage
read_dump | grep "^COPY public\." | sed 's/^COPY public\."\([^"]*\)".*/\1/' | sort -u | while read table; do
  count=$(count_table "$table")
  if [[ $count -gt 0 ]] || [[ "$table" != "activity" ]]; then  # Afficher même si 0
    printf "| \`%s\` | %s |\n" "$table" "$count" >> "$REPORT"
  fi
done

TOTAL_ROWS=$(read_dump | awk '/^COPY public\./{flag=1; next} /^\\./{flag=0} flag' | wc -l)
TABLE_COUNT=$(read_dump | grep "^COPY public\." | wc -l)

cat >> "$REPORT" << EOF

---

## 📊 STATISTIQUES GLOBALES

| Métrique | Valeur |
|----------|--------|
| **Total lignes** | $TOTAL_ROWS |
| **Tables définies** | $TABLE_COUNT |
| **Verdict** | $([ $TOTAL_ROWS -gt 0 ] && echo "🟢 DONNÉES PRÉSENTES" || echo "🔴 VIDE") |

---

**Audit généré le:** $TIMESTAMP
EOF

echo "✅ Rapport généré: $REPORT"
