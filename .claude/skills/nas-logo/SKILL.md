---
name: nas-logo
description: >
  Contexte complet du projet NAS-logo — infrastructure Immich sur Mac Mini avec SSD externe,
  Docker, Ansible et Hetzner. Utilise ce skill dès qu'on travaille sur ce projet : playbooks
  Ansible, rôles, variables, Makefile, MCP Claude Code, sauvegarde, monitoring, sécurité.
  Déclenche aussi pour toute question sur l'architecture, le déploiement ou la configuration
  du NAS de logo.
---

# Projet NAS-logo — Contexte Claude

## Vue d'ensemble

Serveur de photos personnel basé sur **Immich**, hébergé sur un **Mac Mini** avec un SSD
externe USB. L'ensemble est automatisé via **Ansible** et déployé avec **Docker Compose**.

**Propriétaire :** logo (lgbertheaume@gmail.com)
**Repo Git :** https://github.com/logo-solutions/NAS-logo
**Dossier projet :** `/Volumes/logousb/SSD/Projects/NAS-logo`

---

## Architecture

```
Mac Mini (hôte)
├── SSD externe : /Volumes/logousb/SSD/NAS-LOGO-VOLUME
│   ├── immich/          → données photos Immich
│   ├── immich-db/       → base PostgreSQL
│   └── backups/         → sauvegardes locales avant sync Hetzner
├── ~/immich/            → config Docker Compose + logs
└── Docker              → conteneurs Immich, PostgreSQL, Redis

Réseau
├── Tailscale           → VPN, accès équipe uniquement
└── Caddy               → reverse proxy HTTPS, domaine Tailscale

Sauvegarde distante
└── Hetzner Storage Box → rclone chiffré, rétention 7j/4s/12m
```

---

## Structure du projet

```
NAS-logo/
├── Makefile                    → commandes principales (voir ci-dessous)
├── site.yml                    → playbook principal (make install)
├── bootstrap.yml               → étape 1 : prépare l'environnement
├── preflight.yml               → étape 2a : vérifie les prérequis
├── claude.yml                  → étape 4 : Claude Code + MCP
├── healthcheck.yml             → health check (make health)
├── inventory/
│   ├── hosts                   → cible : localhost (macmini)
│   └── group_vars/
│       ├── all.yml             → variables globales (voir ci-dessous)
│       └── vault.yml          → secrets chiffrés (ansible-vault)
└── roles/
    ├── base/                   → Homebrew, dépendances système
    ├── qualite/                → ansible-lint, Molecule
    ├── securite/               → Tailscale, Caddy, firewall
    ├── stockage/               → montage SSD, création dossiers
    ├── docker/                 → installation Docker Desktop
    ├── immich/                 → Docker Compose Immich
    ├── acces/                  → utilisateurs, rôles, 2FA
    ├── sauvegarde/             → rclone, cron, dump PostgreSQL
    └── monitoring/             → healthcheck.sh, alertes ntfy
```

---

## Makefile — ordre de déploiement

| Commande        | Étape | Description                              |
|-----------------|-------|------------------------------------------|
| `make bootstrap`| 1     | Prépare l'env (lint, Molecule, Docker)   |
| `make preflight`| 2a    | Vérifie SSD, Hetzner, macOS             |
| `make dryrun`   | 2b    | Dry-run complet avec diff                |
| `make install`  | 3     | Installation complète                    |
| `make claude`   | 4     | Claude Code + MCP (optionnel)            |
| `make health`   | —     | Health check (utilisable à tout moment)  |
| `make lint`     | —     | ansible-lint sur tous les playbooks      |
| `make test`     | —     | Molecule sur immich, sauvegarde, monitor |

---

## Variables clés (all.yml)

| Variable             | Valeur actuelle                          |
|----------------------|------------------------------------------|
| `ssd_mount_point`    | `/Volumes/logousb/SSD/NAS-LOGO-VOLUME`  |
| `immich_version`     | `v1.106.4`                               |
| `immich_install_dir` | `~/immich`                               |
| `immich_data_dir`    | `{{ ssd_mount_point }}/immich`           |
| `immich_db_dir`      | `{{ ssd_mount_point }}/immich-db`        |
| `immich_port`        | `2283`                                   |
| `alert_disk_threshold`| `80` (%)                               |
| `backup_daily_keep`  | `7`                                      |
| `backup_weekly_keep` | `4`                                      |
| `backup_monthly_keep`| `12`                                     |

Variables sensibles dans `vault.yml` (ansible-vault) :
- `vault_github_token`
- `vault_tailscale_authkey`
- Credentials Hetzner, ntfy token, etc.

---

## MCP Claude Code

Connecteurs configurés dans `claude.yml` et `~/.claude.json` :

| Connecteur   | Commande                                                       | État        |
|--------------|----------------------------------------------------------------|-------------|
| `filesystem` | `npx @modelcontextprotocol/server-filesystem <ssd> ~/immich`  | ✗ (SSD off) |
| `docker`     | `docker run mcp/docker`                                        | ✗ (Docker)  |
| `github`     | `docker run ghcr.io/github/github-mcp-server`                  | ✗ (Docker)  |
| `shell`      | `npx @wonderwhy-er/desktop-commander`                          | ✓ Connected |

Les connecteurs docker/github/filesystem passent au vert quand Docker Desktop est lancé
et le SSD monté.

---

## Conventions de travail

- **Idempotence** : chaque tâche Ansible doit pouvoir tourner N fois sans effet de bord.
  Utiliser `failed_when` pour ignorer les erreurs bénignes (ex: "already exists").
- **Secrets** : jamais en clair dans les fichiers versionnés. Toujours dans `vault.yml`.
- **Ordre** : respecter bootstrap → preflight → dryrun → install → claude.
- **Git** : travailler sur `main`, committer après chaque étape validée.
- **Fichiers** : j'ai un accès direct au dossier projet. Les modifications que je fais
  sont immédiatement visibles sur le Mac — pas besoin de `git pull`.

---

## État actuel du déploiement

- [x] Étape 4 : Claude Code installé (v2.1.92), MCP configurés
- [ ] Étape 1 : bootstrap à valider
- [ ] Étape 2 : preflight + dryrun à lancer
- [ ] Étape 3 : installation complète (Immich pas encore déployé)
- [ ] Hetzner credentials à configurer dans all.yml
- [ ] ntfy topic et caddy_domain à configurer

---

## Référence documentaire

Le fichier `skills_immich.md` à la racine du projet liste les 8 domaines de responsabilité
(Sécurité, Tests, Produit, Accès, Sauvegarde, Monitoring, Déploiement, Stockage).
