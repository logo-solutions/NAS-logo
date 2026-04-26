#!/usr/bin/env bash
# Consolidation nocturne de mémoire — appelé par launchd ou schedule
# Usage: ./scripts/consolidate-memory.sh [--dry-run]

set -euo pipefail

PROJ_DIR="/Volumes/logousb/SSD/Projects/NAS-logo"
LOG_DIR="$HOME/.claude/projects/-Volumes-logousb-SSD-Projects-NAS-logo"
MEMORY_DIR="$PROJ_DIR/memory"
MARKER="/tmp/.consolidate_memory_marker"
DRY_RUN="${1:-}"
NOW=$(date "+%Y-%m-%d %H:%M")
CUTOFF_EPOCH=$(date -v-24H +%s 2>/dev/null || date -d "24 hours ago" +%s)

log() { echo "[consolidate-memory] $*"; }

# --- Collect recent JSONL files ---
log "Recherche des logs des 24 dernières heures dans $LOG_DIR"

if [[ ! -d "$LOG_DIR" ]]; then
  log "ERREUR: répertoire de logs introuvable: $LOG_DIR"
  exit 1
fi

# Build list of JSONL files newer than marker (or all if no marker)
if [[ -f "$MARKER" ]]; then
  RECENT_FILES=$(find "$LOG_DIR" -name "*.jsonl" -newer "$MARKER" 2>/dev/null | sort)
else
  # First run: take files from last 24h by mtime
  RECENT_FILES=$(find "$LOG_DIR" -name "*.jsonl" -mmin -1440 2>/dev/null | sort)
fi

SESSION_COUNT=$(echo "$RECENT_FILES" | grep -c ".jsonl" 2>/dev/null || echo 0)
log "Sessions trouvées: $SESSION_COUNT"

if [[ "$SESSION_COUNT" -eq 0 ]]; then
  log "Aucune session récente — consolidation à blanc."
  touch "$MARKER"
  exit 0
fi

# --- Extract signal from logs ---
DECISIONS=""
FILES_MODIFIED=""
CORRECTIONS=""
CONFIRMATIONS=""

while IFS= read -r jsonl_file; do
  [[ -z "$jsonl_file" ]] && continue

  # Extract assistant text containing decision markers
  DECISIONS+=$(grep -o '"text":"[^"]*"' "$jsonl_file" 2>/dev/null \
    | grep -i "je vais\|on va\|j'utilise\|je choisis\|donc\|finalement\|la solution\|j'opte" \
    | sed 's/"text":"//;s/"$//' \
    | head -5 || true)

  # Extract file paths from Write/Edit tool calls
  FILES_MODIFIED+=$(grep -o '"file_path":"[^"]*"' "$jsonl_file" 2>/dev/null \
    | sed 's/"file_path":"//;s/"$//' \
    | sort -u || true)

  # Extract user corrections
  CORRECTIONS+=$(grep -o '"text":"[^"]*"' "$jsonl_file" 2>/dev/null \
    | grep -i '"non\b\|pas ça\|arrête\|ne fais pas\|plutôt\|stop' \
    | sed 's/"text":"//;s/"$//' \
    | head -3 || true)

  # Extract user confirmations
  CONFIRMATIONS+=$(grep -o '"text":"[^"]*"' "$jsonl_file" 2>/dev/null \
    | grep -i 'exactement\|parfait\|oui exactement\|c'\''est ça\|continue comme' \
    | sed 's/"text":"//;s/"$//' \
    | head -3 || true)

done <<< "$RECENT_FILES"

DECISION_COUNT=$(echo "$DECISIONS" | grep -c "." 2>/dev/null || echo 0)
FILE_COUNT=$(echo "$FILES_MODIFIED" | sort -u | grep -c "." 2>/dev/null || echo 0)

log "Décisions extraites: $DECISION_COUNT"
log "Fichiers référencés: $FILE_COUNT"

if [[ "$DRY_RUN" == "--dry-run" ]]; then
  log "Mode dry-run — aucun fichier modifié."
  log "--- Décisions ---"
  echo "$DECISIONS" | head -10
  log "--- Fichiers ---"
  echo "$FILES_MODIFIED" | sort -u | head -10
  exit 0
fi

# --- Update recent-memory.md (overwrite, 48h window) ---
log "Mise à jour de recent-memory.md"

SESSION_LIST=""
while IFS= read -r f; do
  [[ -z "$f" ]] && continue
  MTIME=$(stat -f "%Sm" -t "%Y-%m-%d %H:%M" "$f" 2>/dev/null || stat -c "%y" "$f" 2>/dev/null | cut -c1-16)
  SESSION_LIST+="- $MTIME — session $(basename "$f" .jsonl | cut -c1-8)\n"
done <<< "$RECENT_FILES"

DECISIONS_FMT=$(echo "$DECISIONS" | sed '/^$/d' | head -10 | sed 's/^/- /')
FILES_FMT=$(echo "$FILES_MODIFIED" | sort -u | sed '/^$/d' | head -20 | sed 's|^|- `|;s|$|`|')

cat > "$MEMORY_DIR/recent-memory.md" << HEREDOC
---
window: 48h
updated: $NOW
---

# Mémoire Récente (fenêtre glissante 48h)

## Sessions récentes
$(echo -e "$SESSION_LIST")

## Décisions prises
${DECISIONS_FMT:-<!-- aucune décision extraite -->}

## Fichiers modifiés
${FILES_FMT:-<!-- aucun fichier référencé -->}

## Problèmes ouverts
<!-- À compléter manuellement ou par analyse approfondie -->
HEREDOC

# --- Update long-term-memory.md (append only for new confirmed patterns) ---
if [[ -n "$CONFIRMATIONS" ]]; then
  log "Ajout de patterns confirmés dans long-term-memory.md"
  echo "" >> "$MEMORY_DIR/long-term-memory.md"
  echo "<!-- Consolidation $NOW -->" >> "$MEMORY_DIR/long-term-memory.md"
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    # Only append if not already present (dedup by content)
    if ! grep -qF "$line" "$MEMORY_DIR/long-term-memory.md" 2>/dev/null; then
      echo "- $line — confirmé $NOW" >> "$MEMORY_DIR/long-term-memory.md"
    fi
  done <<< "$CONFIRMATIONS"
fi

# --- Update project-memory.md timestamp ---
log "Mise à jour du timestamp project-memory.md"
sed -i '' "s/^updated: .*/updated: $NOW/" "$MEMORY_DIR/project-memory.md" 2>/dev/null \
  || sed -i "s/^updated: .*/updated: $NOW/" "$MEMORY_DIR/project-memory.md"

# --- Mark completion ---
touch "$MARKER"

log "Consolidation terminée — $NOW"
log "  Sessions analysées : $SESSION_COUNT"
log "  Décisions extraites : $DECISION_COUNT"
log "  Fichiers modifiés référencés : $FILE_COUNT"
log "  Nouvelles confirmations long-terme : $(echo "$CONFIRMATIONS" | grep -c "." 2>/dev/null || echo 0)"
