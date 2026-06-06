# 🔧 Intégration immich-audit-dump.sh dans Makefile

## Vue d'ensemble

Le script `bin/immich-audit-dump.sh` génère automatiquement un rapport d'audit détaillé d'un dump PostgreSQL Immich.

**Utilisé par:** `make backup` (après `pg_dump`)  
**Localisation:** `/Volumes/logousb/SSD/Projects/NAS-logo/bin/immich-audit-dump.sh`

---

## Usage

```bash
./bin/immich-audit-dump.sh <dump-file> [output-directory]
```

### Paramètres

| Param | Requis | Description |
|-------|--------|-------------|
| `dump-file` | ✅ | Fichier SQL ou SQL.gz (dump PostgreSQL) |
| `output-directory` | ❌ | Dossier de sortie (défaut: current directory) |

### Exemples

```bash
# Sur un dump gzip
./bin/immich-audit-dump.sh immich-db-20260603.sql.gz /Volumes/NAS-LOGO-DATA/journaux/

# Sur un dump SQL brut
./bin/immich-audit-dump.sh immich-dump-20260602-231201.sql /Volumes/NAS-LOGO-DATA/journaux/

# Sur le dump du jour (automatique dans make backup)
./bin/immich-audit-dump.sh "immich-db-$(date +%Y%m%d-%H%M%S).sql.gz" "/Volumes/NAS-LOGO-DATA/journaux/"
```

---

## Intégration Makefile

### Ajouter au script `immich-backup-professional.sh`

```bash
# Après le dump PostgreSQL (ligne ~ÉTAPE 2/6)

DUMP_FILE="/Volumes/Expansion12/immich-backup-20260603-121658/immich-db-20260603-121658.sql.gz"
AUDIT_OUTPUT="/Volumes/NAS-LOGO-DATA/journaux/"

# Générer audit automatique
if [[ -f "$DUMP_FILE" ]]; then
  echo "[INFO] Génération audit du dump..."
  ./bin/immich-audit-dump.sh "$DUMP_FILE" "$AUDIT_OUTPUT" || echo "[WARN] Audit échoué (non-bloquant)"
fi
```

### Ou créer une cible Make

```makefile
.PHONY: audit-immich

# Audit du dump Immich le plus récent
audit-immich:
	@LATEST=$$(ls -t /Volumes/NAS-LOGO-DATA/journaux/immich-*.sql* 2>/dev/null | head -1); \
	if [[ -z "$$LATEST" ]]; then \
	  echo "❌ Aucun dump Immich trouvé"; \
	  exit 1; \
	fi; \
	echo "📊 Audit: $$LATEST"; \
	./bin/immich-audit-dump.sh "$$LATEST" /Volumes/NAS-LOGO-DATA/journaux/
```

Usage:
```bash
make audit-immich
```

---

## Output

Le script génère un fichier Markdown:

```
/Volumes/NAS-LOGO-DATA/journaux/immich-audit-immich-db-20260603-121658.md
```

**Contenu du rapport:**

```markdown
# 📊 AUDIT IMMICH — immich-db-20260603-121658.sql.gz

## 👤 UTILISATEURS
| Métrique | Valeur |
|----------|--------|
| Total | 1 |
| Email | loicgourmelon@gmail.com |
| ...

## 📸 ASSETS
| Métrique | Valeur |
|----------|--------|
| Total photos/vidéos | 152433 |
| ...
```

---

## Caractéristiques

✅ **Gère gzip et SQL brut** — Détecte automatiquement le format  
✅ **Extraction utilisateur** — Email, rôle, quota utilisé  
✅ **Comptage complet** — 15+ tables analysées  
✅ **Extensions PostgreSQL** — Liste les extensions détectées  
✅ **Rapide** — Gzip: ~2-3s, SQL brut: ~5-10s (1.8 GB)  
✅ **Rapport lisible** — Markdown bien formaté avec tableaux

---

## Limitations Connues

⚠️ **SQL brut très lent** — Le fichier 1.8 GB prend 5-10s à analyser  
✅ **Gzip recommandé** — Compression 2.7x plus rapide (784 MB)

**Recommandation:** Toujours dumper en gzip:
```bash
pg_dump ... | gzip > dump-YYYYMMDD.sql.gz  # Rapide et léger
```

---

## Exemple Complet dans make backup

```bash
#!/bin/bash
# Après pg_dump en ÉTAPE 2:

BACKUP_DIR="/Volumes/Expansion12/immich-backup-$(date +%Y%m%d-%H%M%S)"
DUMP="$BACKUP_DIR/immich-db-$(date +%Y%m%d-%H%M%S).sql.gz"

mkdir -p "$BACKUP_DIR"

# Dump
pg_dump -U immich -h 127.0.0.1 immich | gzip > "$DUMP"

# Audit automatique
./bin/immich-audit-dump.sh "$DUMP" "/Volumes/NAS-LOGO-DATA/journaux/" || true

echo "✅ Backup: $BACKUP_DIR"
echo "📊 Audit: /Volumes/NAS-LOGO-DATA/journaux/immich-audit-*.md"
```

---

## Voir Aussi

- `bin/immich-backup-professional.sh` — Script backup complet
- `/Volumes/NAS-LOGO-DATA/journaux/immich-audit-*.md` — Rapports générés
- CLAUDE.md — Directives complètes Immich
