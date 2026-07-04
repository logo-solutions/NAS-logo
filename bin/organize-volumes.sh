#!/bin/bash
# Script de nettoyage et réorganisation des volumes
# Génère des listings avec tailles pour faciliter le tri

set -euo pipefail

JOURNAL_DIR="/Volumes/NAS-LOGO-DATA/journaux"
TIMESTAMP=$(date +"%Y%m%d-%H%M%S")
OUTPUT_DIR="${JOURNAL_DIR}/organize-${TIMESTAMP}"

mkdir -p "$OUTPUT_DIR"

echo "📋 Génération des listings..."
echo "Sortie: $OUTPUT_DIR"

# 1. Lister NAS-LOGO-DATA avec tailles
echo "🔍 Scanning /Volumes/NAS-LOGO-DATA..."
find /Volumes/NAS-LOGO-DATA \
  -type f \
  ! -path '*/\.*' \
  -exec ls -lhS {} \; | awk '{print $9, "(" $5 ")"}' \
  > "$OUTPUT_DIR/nas-logo-data-files.txt" 2>&1 || true

# 2. Lister les répertoires principaux avec du -sh
echo "🔍 Calculating /Volumes/NAS-LOGO-DATA directory sizes..."
du -sh /Volumes/NAS-LOGO-DATA/* 2>/dev/null | sort -rh \
  > "$OUTPUT_DIR/nas-logo-data-dirs.txt" || true

# 3. Lister Expansion12 avec tailles
echo "🔍 Scanning /Volumes/Expansion12..."
find /Volumes/Expansion12 \
  -type f \
  ! -path '*/\.*' \
  -exec ls -lhS {} \; | awk '{print $9, "(" $5 ")"}' \
  > "$OUTPUT_DIR/expansion12-files.txt" 2>&1 || true

# 4. Lister répertoires Expansion12
echo "🔍 Calculating /Volumes/Expansion12 directory sizes..."
du -sh /Volumes/Expansion12/* 2>/dev/null | sort -rh \
  > "$OUTPUT_DIR/expansion12-dirs.txt" || true

# 5. Générer un rapport de nettoyage potentiel
cat > "$OUTPUT_DIR/CLEANUP-CANDIDATES.md" << 'EOF'
# Candidates au nettoyage

## À vérifier

- Fichiers système (.DS_Store, ._*, .Spotlight-V100)
- Fichiers temporaires anciens (> 30 jours)
- Duplicatas (voir czkawka)
- Dossiers vides

## Structure proposée après nettoyage

### /Volumes/NAS-LOGO-DATA/
- `NAS-LOGO-VOLUME/` — données principales (personnes/, immich-db/, etc.)
- `journaux/` — logs et rapports
- `backups/` — archive historique (optionnel)

### /Volumes/Expansion12/
- `backups/NAS/` — backups actuels de production
- `SOURCES/` — sources d'import (iCloud, etc.)
- Archive ancienne (à clarifier)

## Commandes de cleanup

```bash
# Trouver fichiers système macOS
find /Volumes/Expansion12 -name '.DS_Store' -delete
find /Volumes/Expansion12 -name '._*' -delete
find /Volumes/Expansion12 -name '.Spotlight-V100' -delete

# Lister doublons (avant suppression!)
czkawka dup -d /Volumes/Expansion12 -m hash
```
EOF

# 6. Résumé
cat > "$OUTPUT_DIR/SUMMARY.txt" << 'EOF'
=== ORGANISATION VOLUMES ===

Fichiers générés :
- nas-logo-data-dirs.txt    : répertoires /Volumes/NAS-LOGO-DATA avec tailles
- nas-logo-data-files.txt   : fichiers /Volumes/NAS-LOGO-DATA listés
- expansion12-dirs.txt      : répertoires /Volumes/Expansion12 avec tailles
- expansion12-files.txt     : fichiers /Volumes/Expansion12 listés
- CLEANUP-CANDIDATES.md     : recommandations

Prochain pas :
1. Examiner les listings (tri par taille DESC)
2. Identifier duplicatas avec czkawka (avant de supprimer!)
3. Archiver/supprimer fichiers système obsolètes
4. Réorganiser dossiers selon structure proposée
EOF

# Afficher résumé
cat "$OUTPUT_DIR/SUMMARY.txt"
echo ""
echo "✅ Listings générés dans: $OUTPUT_DIR"
echo ""
echo "=== Tailles principales /Volumes/NAS-LOGO-DATA ==="
cat "$OUTPUT_DIR/nas-logo-data-dirs.txt" | head -15
echo ""
echo "=== Tailles principales /Volumes/Expansion12 ==="
cat "$OUTPUT_DIR/expansion12-dirs.txt" | head -15
