---
window: 48h
updated: 2026-04-26 08:30
---

# Mémoire Récente (fenêtre glissante 48h)

Ce fichier est écrasé à chaque consolidation. Il contient uniquement les événements des 48 dernières heures.

## Sessions récentes

- 2026-04-26 — Migration stockage : achat NAS-LOGO-DATA, rsync ~/Documents/, symlinks abc/ et SSD/ créés
- 2026-04-26 — Création couche mémoire persistante (memory/, consolidateMemory skill, LaunchAgent 02h00)
- 2026-04-26 — Mise à jour skill nas-logo, memory, project-memory, guide-administration

## Décisions prises

- **Architecture disques :** données volumineuses → NAS-LOGO-DATA (HDD 5,5 To) / données chaudes (DB, index, monitoring) → NAS-LOGO-VOLUME (SSD)
- **Symlinks sous-dossiers seulement** : ne pas symlinkter ~/Documents en entier (apps sandboxées Mac App Store) — symlinkter uniquement les gros sous-dossiers
- **abc/ (37 Go) et SSD/ (9,1 Go) migrés** : symlinks ~/Documents/abc → NAS-LOGO-DATA/Documents/abc, idem SSD/
- **FileVault NAS-LOGO-DATA** : à activer quand voulu via `diskutil apfs encryptVolume NAS-LOGO-DATA -user disk`
- **vars.yml** : variable `hdd_mount_point` à ajouter, migrations de services à planifier séparément

## Fichiers modifiés

- `memory/` — couche mémoire créée (recent, long-term, project)
- `skills/consolidateMemory/SKILL.md` — skill de consolidation créé
- `scripts/consolidate-memory.sh` + `.plist` + `install-memory-schedule.sh` — LaunchAgent 02h00
- `.claude/skills/nas-logo/SKILL.md` — architecture HDD ajoutée, scripts et memory documentés
- `memory/project-memory.md` — état projet mis à jour
- `docs/guide-administration.md` — section stockage mise à jour

## Problèmes ouverts

- **LaunchAgent non encore installé** — lancer `./scripts/install-memory-schedule.sh` pour activer la consolidation nocturne
- **vars.yml** — `hdd_mount_point` à ajouter, migrations services (immich_data_dir, paperless_data_dir, files_dir, personnes_dir) à planifier
- **Pictures et Downloads** — à migrer vers NAS-LOGO-DATA selon même méthode symlink
