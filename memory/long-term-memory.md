---
updated: never
---

# Mémoire Long Terme — Préférences Confirmées

Ce fichier s'enrichit progressivement. Une entrée n'est ajoutée que si elle apparaît dans au moins deux sessions différentes ou si elle a été explicitement confirmée par l'utilisateur.

## Préférences techniques

- **Conteneurs :** Colima uniquement (jamais Docker Desktop — conflits de ports et credsStore)
- **Ports :** toujours binder sur `0.0.0.0`, jamais `127.0.0.1`
- **Langue :** réponses en français

## Patterns de travail validés

- **Symlinks sous-dossiers uniquement pour ~/Documents** : ne jamais symlinkter ~/Documents en entier — les apps sandboxées Mac App Store peuvent perdre l'accès. Symlinkter seulement les gros sous-dossiers depuis ~/Documents/. Confirmé 2026-04-26.
- **Vérifier les tailles avec `--apparent-size`** : `du -sh` varie selon la granularité des blocs (SSD vs HDD). Toujours confirmer avec le nombre de fichiers (`find | wc -l`) pour valider une copie.

## Anti-patterns à éviter

<!-- Comportements que l'utilisateur a corrigés au moins une fois -->

## Conventions du projet NAS-logo

- Stack : Ansible + Docker Compose sur Mac Mini
- Rôles Ansible dans `roles/`, playbooks à la racine
- Variables sensibles dans `group_vars/all/vault.yml` (chiffrées Ansible Vault)
