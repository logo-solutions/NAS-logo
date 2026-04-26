---
updated: 2026-04-26 08:30
---

# Mémoire Projet — État Actif

Ce fichier reflète l'état courant du projet NAS-logo. Il est mis à jour à chaque consolidation nocturne.

## État des services (dernière vérification connue)

| Service        | État    | Notes                              |
|----------------|---------|------------------------------------|
| Immich         | ?       |                                    |
| Paperless-ngx  | ?       |                                    |
| n8n            | ?       | bind mount SSD + export quotidien  |
| Meilisearch    | ?       |                                    |
| Whisper        | ?       |                                    |
| Monitoring     | ?       |                                    |
| UPS BX750MI    | ?       | healthcheck Colima configuré       |

## Travaux en cours

- **Consolidation mémoire nocturne** — LaunchAgent créé mais pas encore installé
  - Installer : `./scripts/install-memory-schedule.sh`
  - Tester : `launchctl start com.logo.consolidate-nas-memory`

## Prochaines étapes connues

- Ajouter `hdd_mount_point: /Volumes/NAS-LOGO-DATA` dans `vars.yml`
- Migrer les services vers NAS-LOGO-DATA (à planifier) : immich_data_dir, paperless_data_dir, files_dir, personnes_dir
- Activer FileVault sur NAS-LOGO-DATA : `diskutil apfs encryptVolume NAS-LOGO-DATA -user disk`
- Migrer Pictures, Downloads via symlinks sous-dossiers (même méthode que abc/ et SSD/)
- Supprimer `~/Documents.bak` si aucun problème après quelques jours (actuellement il n'y a pas de .bak — on a fait la migration différemment via symlinks sous-dossiers)

## Décisions d'architecture actives

- **Deux disques distincts :**
  - `NAS-LOGO-DATA` (`/Volumes/NAS-LOGO-DATA`, HDD 5,5 To APFS, ajouté 2026-04-26) — données volumineuses froides
  - `NAS-LOGO-VOLUME` (`/Volumes/logousb/SSD/NAS-LOGO-VOLUME`, SSD) — données chaudes : DB, monitoring, index, n8n
- **Symlinks sous-dossiers uniquement** : ~/Documents lui-même reste local (compatibilité apps sandboxées). Seuls abc/ et SSD/ pointent vers NAS-LOGO-DATA.
- **iCloud Drive** : ~/Documents réel non synchronisé iCloud — pas de conflit

## Incidents récents

<!-- Bugs résolus ou en cours, avec leur contexte -->
