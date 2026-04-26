---
name: consolidateMemory
description: Reads the last 24h of Claude Code session logs, extracts key decisions, updates the three memory files (recent, long-term, project). Use when running nightly consolidation or when memory feels stale after a heavy session.
---

# Consolidate Memory

## Overview

Read the raw Claude Code JSONL session logs from the last 24 hours, extract signal (decisions, file changes, corrections, confirmed patterns, project state changes), and write structured summaries into the three memory files. This keeps context alive across sessions without bloating the main memory index.

## When to Use

- Nightly scheduled run (automated)
- After any session longer than 30 minutes
- When the user says "mets à jour la mémoire" or "consolide la mémoire"
- Before starting a new session on a complex topic

**When NOT to use:** During an active session — memory is live context. Consolidate at the end.

## Process

### Step 1 — Collect logs from the last 24h

```bash
PROJ="-Volumes-logousb-SSD-Projects-NAS-logo"
LOG_DIR="$HOME/.claude/projects/$PROJ"
CUTOFF=$(date -v-24H +%s 2>/dev/null || date -d "24 hours ago" +%s)

# Find JSONL files modified in last 24h
find "$LOG_DIR" -name "*.jsonl" -newer /tmp/.consolidate_marker | sort
touch /tmp/.consolidate_marker
```

Read each file line by line. Each line is a JSON object. Relevant fields:
- `role`: `"assistant"` or `"user"`  
- `content`: array of content blocks  
- `type`: `"tool_use"`, `"tool_result"`, `"text"`  
- Tool names to watch: `Write`, `Edit`, `Bash`, `Read`

### Step 2 — Extract signal

For each session file, extract:

**Decisions** — Assistant text that contains:
- Action verbs: "je vais", "on va", "j'utilise", "je choisis", "on garde"
- Conclusions after a back-and-forth: "donc", "finalement", "la solution"
- Architecture choices: anything touching `roles/`, `docker-compose`, Ansible vars

**File changes** — All `Write` and `Edit` tool calls → extract `file_path`

**Corrections** — User messages containing: "non", "pas ça", "arrête", "ne fais pas", "plutôt"

**Confirmations** — User messages containing: "oui", "exactement", "parfait", "continue", "c'est ça"

**Project state changes** — Any Bash output mentioning service names (Immich, Paperless, n8n, Meilisearch, Whisper) with status keywords (running, stopped, error, failed, up)

### Step 3 — Update `memory/recent-memory.md`

Overwrite the file (48h sliding window — no accumulation). Format:

```markdown
---
window: 48h
updated: YYYY-MM-DD HH:MM
---

# Mémoire Récente (fenêtre glissante 48h)

## Sessions récentes
- YYYY-MM-DD HH:MM — <one-line summary of the session topic>

## Décisions prises
- <decision> — (session: <date>)

## Fichiers modifiés
- `<path>` — <why it was touched>

## Problèmes ouverts
- <problem> — <context>
```

Keep entries to the last 48h only. Drop anything older.

### Step 4 — Update `memory/long-term-memory.md`

**Append only** — never remove existing entries. Add new entries only if:
- A pattern appears in 2+ session files, OR
- A correction was issued (user said "non"/"pas ça"), OR
- A confirmation was strong ("exactement", "parfait")

Format new entries as:
```markdown
- **<topic>:** <rule> — confirmed <date>
```

### Step 5 — Update `memory/project-memory.md`

Merge-update the state table. Rules:
- If a service status was observed in logs → update that row
- If a task was described as "terminé" or "done" → mark it as complete and move to an "Historique" section
- If a new "à faire" was mentioned → add to "Prochaines étapes"
- If an architectural decision was made → add to "Décisions d'architecture actives"

### Step 6 — Write a consolidation summary

After updating all three files, output a brief report:

```
Consolidation terminée — <date>
  Sessions analysées : N
  Décisions extraites : N
  Fichiers modifiés référencés : N
  Nouvelles entrées long-terme : N
  État projet : mis à jour / inchangé
```

## Common Rationalizations

**"Les logs sont trop longs à lire entièrement"** — Ne lis pas tout. Cherche uniquement les patterns du Step 2. Un `grep` ciblé suffit.

**"Je ne suis pas sûr que c'est une décision importante"** — En cas de doute, inclus-la dans recent-memory mais pas dans long-term. Le seuil pour long-term est 2 sessions ou confirmation explicite.

**"Le projet-memory est déjà à jour"** — Vérifie quand même. Une session peut avoir changé l'état sans que tu l'aies noté.

## Red Flags

- `recent-memory.md` contient des entrées de plus de 48h → nettoie
- `long-term-memory.md` a plus de 50 entrées → revois les doublons et fusionne
- `project-memory.md` mentionne des services sans date → ajoute une date de dernière vérification
- Aucun fichier JSONL trouvé dans les 24h → signale que la consolidation est à blanc

## Verification

After updating:
1. Confirm the `updated:` frontmatter timestamp is current
2. Confirm `recent-memory.md` has no entries older than 48h
3. Confirm `long-term-memory.md` has no duplicate rules
4. Confirm `project-memory.md` service table has at least one row with a non-`?` status if any service was discussed
