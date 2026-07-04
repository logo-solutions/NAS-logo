#!/usr/bin/env bash
# rapport-doublons-rang2.sh — Doublons de répertoires simples avec awk

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
JOURNAUX="/Volumes/NAS-LOGO-DATA/journaux"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
RAPPORT="$JOURNAUX/doublons-hdd-$TIMESTAMP.md"
TEMP_INDEX="/tmp/doublons-$TIMESTAMP.txt"

mkdir -p "$JOURNAUX"
> "$TEMP_INDEX"

echo "=== Extraction des répertoires ===" >&2

# Traiter Expansion12
if [ -f "$SCRIPT_DIR/find-Expansion12-20260531-103509.txt" ]; then
  echo "  Expansion12..." >&2
  cut -d'|' -f3 "$SCRIPT_DIR/find-Expansion12-20260531-103509.txt" | \
    awk -F'/' 'NF >= 4 {
      rang1 = $4
      rang2 = $5
      if (rang1 != "") print "Expansion12|" rang1 "|1"
      if (rang2 != "") print "Expansion12|" rang2 "|2"
    }' >> "$TEMP_INDEX"
fi

# Traiter Elements
if [ -f "$SCRIPT_DIR/Elements/find-Elements-20260601-124446.txt" ]; then
  echo "  Elements..." >&2
  cut -d'|' -f3 "$SCRIPT_DIR/Elements/find-Elements-20260601-124446.txt" | \
    awk -F'/' 'NF >= 4 {
      rang1 = $4
      rang2 = $5
      if (rang1 != "") print "Elements|" rang1 "|1"
      if (rang2 != "") print "Elements|" rang2 "|2"
    }' >> "$TEMP_INDEX"
fi

# Traiter SAUV-MAIIL
if [ -f "$SCRIPT_DIR/SAUV-MAIIL/find-SAUV-MAIIL-20260601-205304.txt" ]; then
  echo "  SAUV-MAIIL..." >&2
  cut -d'|' -f3 "$SCRIPT_DIR/SAUV-MAIIL/find-SAUV-MAIIL-20260601-205304.txt" | \
    awk -F'/' 'NF >= 4 {
      rang1 = $4
      rang2 = $5
      if (rang1 != "") print "SAUV-MAIIL|" rang1 "|1"
      if (rang2 != "") print "SAUV-MAIIL|" rang2 "|2"
    }' >> "$TEMP_INDEX"
fi

# Traiter SauvAvril2026
if [ -f "$SCRIPT_DIR/SauvAvril2026/find-SauvAvril2026-20260601-215020.txt" ]; then
  echo "  SauvAvril2026..." >&2
  cut -d'|' -f3 "$SCRIPT_DIR/SauvAvril2026/find-SauvAvril2026-20260601-215020.txt" | \
    awk -F'/' 'NF >= 4 {
      rang1 = $4
      rang2 = $5
      if (rang1 != "") print "SauvAvril2026|" rang1 "|1"
      if (rang2 != "") print "SauvAvril2026|" rang2 "|2"
    }' >> "$TEMP_INDEX"
fi

# Traiter Toshiba
if [ -f "$SCRIPT_DIR/Toshiba/find-Toshiba-20260531-103509.txt" ]; then
  echo "  Toshiba..." >&2
  cut -d'|' -f3 "$SCRIPT_DIR/Toshiba/find-Toshiba-20260531-103509.txt" | \
    awk -F'/' 'NF >= 4 {
      rang1 = $4
      rang2 = $5
      if (rang1 != "") print "Toshiba|" rang1 "|1"
      if (rang2 != "") print "Toshiba|" rang2 "|2"
    }' >> "$TEMP_INDEX"
fi

echo "Génération du rapport..." >&2

# Générer le rapport
{
  echo "# Doublons de répertoires entre HDDs (rang 1-2)"
  echo ""
  echo "Généré le $(date '+%Y-%m-%d %H:%M:%S')"
  echo ""

  if [ -s "$TEMP_INDEX" ]; then
    # Trier et éliminer les doublons
    sort -u "$TEMP_INDEX" | awk -F'|' '
      {
        name = $2
        hdd = $1
        depth = $3
        entries[name] = entries[name] hdd "(" depth ")|"
        count[name]++
      }
      END {
        for (name in count) {
          if (count[name] >= 2) {
            print "## Doublon: `" name "`"
            print ""
            n = split(entries[name], items, "|")
            for (i = 1; i < n; i++) {
              print "- " items[i]
            }
            print ""
          }
        }
      }
    '

    echo "---"
    total=$(sort -u "$TEMP_INDEX" | wc -l)
    doublons=$(sort -u "$TEMP_INDEX" | awk -F'|' '{count[$2]++} END {n=0; for (name in count) if (count[name] >= 2) n++; print n}')
    echo ""
    echo "**Résumé**: $doublons doublons trouvés sur $total répertoires"
  else
    echo "**Résumé**: Aucun répertoire trouvé"
  fi

} | tee "$RAPPORT"

rm -f "$TEMP_INDEX"
echo "✓ Rapport: $RAPPORT" >&2
