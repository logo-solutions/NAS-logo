---
name: nas-logo
description: >
  Contexte complet du projet NAS-logo — provisioning Ansible d'un Mac Mini vierge avec
  Immich, Docker, Tailscale, rclone, Prometheus et Grafana. Utilise ce skill dès qu'on
  travaille sur ce projet : playbooks Ansible, rôles, variables, sauvegarde Hetzner,
  monitoring, sécurité. Déclenche aussi pour toute question sur l'architecture,
  le déploiement ou la configuration du NAS de logo.
---

# Projet NAS-logo — Contexte Claude

## Objectif

Provisioning complet et reproductible d'un **Mac Mini vierge** pour en faire un serveur
de photos personnel basé sur **Immich**, automatisé via **Ansible** et déployé avec
**Docker Compose**.

**Propriétaire :** logo (lgbertheaume@gmail.com)
**Repo Git :** https://github.com/logo-solutions/NAS-logo
**Dossier projet :** `/Users/logo/logo-projects/NAS-logo`

---

## Architecture

```
Mac Mini (hôte macOS Apple Silicon)
├── SSD externe : /Volumes/logousb/SSD/NAS-LOGO-VOLUME
│   ├── immich/              → bibliothèque photos Immich
│   ├── immich-db/           → base PostgreSQL
│   ├── monitoring/          → données Prometheus + Grafana
│   └── backups/             → dump DB avant sync Hetzner
├── ~/immich/                → docker-compose.yml + .env
└── Docker Desktop
    ├── immich-server
    ├── immich-microservices
    ├── immich-machine-learning
    ├── postgres
    ├── redis
    ├── prometheus
    ├── grafana
    └── cadvisor

Réseau
└── Tailscale               → VPN mesh, accès depuis n'importe où
                               pas de port exposé sur internet

Sauvegarde distante
└── Hetzner Storage Box     → rclone chiffré (crypt)
                               rétention : 7j quotidien / 4s hebdo / 12m mensuel
```

---

## Stack technique

| Composant       | Technologie                        |
|-----------------|------------------------------------|
| Photos          | Immich (dernière version stable)   |
| Conteneurs      | Docker Desktop for Mac             |
| Réseau          | Tailscale (VPN mesh, pas de Caddy) |
| Monitoring      | Prometheus + Grafana + cAdvisor    |
| Alertes         | ntfy (push mobile)                 |
| Sauvegarde      | rclone → Hetzner Storage Box       |
| Automatisation  | Ansible (rôles séparés)            |
| Secrets         | ansible-vault                      |

---

## Structure du projet

```
NAS-logo/
├── Makefile                    → commandes principales
├── site.yml                    → playbook principal (make install)
├── bootstrap.yml               → étape 1 : Homebrew + outils
├── preflight.yml               → étape 2 : vérifie SSD, réseau, Hetzner
├── healthcheck.yml             → health check (make health)
├── claude.yml                  → étape optionnelle : Claude Code + MCP
├── inventory/
│   ├── hosts                   → cible : localhost (macmini)
│   └── group_vars/
│       ├── all.yml             → variables globales
│       └── vault.yml           → secrets chiffrés (ansible-vault)
├── roles/
│   ├── base/                   → Homebrew, dépendances système
│   ├── stockage/               → montage SSD, arborescence
│   ├── docker/                 → Docker Desktop
│   ├── immich/                 → Docker Compose Immich
│   ├── monitoring/             → Prometheus + Grafana + cAdvisor + ntfy
│   ├── sauvegarde/             → rclone, dump PostgreSQL, cron
│   ├── securite/               → Tailscale, FileVault, firewall
│   └── acces/                  → utilisateurs, SSH, 2FA
├── skills/                     → skills agent-skills (référence)
├── agents/                     → personas IA (code-reviewer, etc.)
├── references/                 → checklists sécurité, perf, tests
└── .claude/
    └── skills/nas-logo/        → ce fichier (contexte projet)
```

---

## Makefile — ordre de déploiement

| Commande          | Étape | Description                              |
|-------------------|-------|------------------------------------------|
| `make bootstrap`  | 1     | Homebrew, Ansible, dépendances           |
| `make preflight`  | 2a    | Vérifie SSD, Hetzner, Tailscale          |
| `make dryrun`     | 2b    | Dry-run complet avec diff                |
| `make install`    | 3     | Installation complète                    |
| `make claude`     | 4     | Claude Code + MCP (optionnel)            |
| `make health`     | —     | Health check à tout moment               |
| `make lint`       | —     | ansible-lint sur tous les playbooks      |
| `make backup`     | —     | Sauvegarde manuelle immédiate            |

---

## Variables clés (all.yml)

| Variable               | Valeur                                    |
|------------------------|-------------------------------------------|
| `mac_user`             | `{{ ansible_user_id }}`                   |
| `ssd_mount_point`      | `/Volumes/logousb/SSD/NAS-LOGO-VOLUME`    |
| `immich_version`       | `release` (dernière stable)               |
| `immich_install_dir`   | `~/immich`                                |
| `immich_data_dir`      | `{{ ssd_mount_point }}/immich`            |
| `immich_db_dir`        | `{{ ssd_mount_point }}/immich-db`         |
| `immich_port`          | `2283`                                    |
| `monitoring_data_dir`  | `{{ ssd_mount_point }}/monitoring`        |
| `grafana_port`         | `3000`                                    |
| `prometheus_port`      | `9090`                                    |
| `alert_disk_threshold` | `80` (%)                                  |
| `backup_daily_keep`    | `7`                                       |
| `backup_weekly_keep`   | `4`                                       |
| `backup_monthly_keep`  | `12`                                      |
| `hetzner_host`         | `{{ vault_hetzner_host }}`                |
| `hetzner_user`         | `{{ vault_hetzner_user }}`                |
| `hetzner_remote_path`  | `/immich-backup`                          |

Variables sensibles dans `vault.yml` (ansible-vault) :
- `vault_hetzner_host`, `vault_hetzner_user`, `vault_hetzner_password`
- `vault_tailscale_authkey`
- `vault_ntfy_topic`
- `vault_immich_db_password`
- `vault_grafana_admin_password`

---

## Conventions

- **Idempotence** : chaque tâche Ansible peut tourner N fois sans effet de bord.
- **Secrets** : jamais en clair dans les fichiers versionnés — toujours dans `vault.yml`.
- **Ordre** : bootstrap → preflight → dryrun → install → (claude optionnel).
- **Git** : travailler sur `main`, committer après chaque étape validée.
- **Docker** : pas de `docker run` nu — tout passe par Docker Compose.
- **Monitoring** : Prometheus scrape cAdvisor + node-exporter, Grafana visualise,
  ntfy envoie les alertes mobiles.
- **Sauvegarde** : dump PostgreSQL avant rclone, chiffrement côté client (rclone crypt).

---

## État du déploiement

- [ ] Étape 1 — bootstrap (Homebrew, Ansible, outils)
- [ ] Étape 2 — preflight + dryrun
- [ ] Étape 3 — installation complète (Immich + monitoring + sauvegarde)
- [ ] Hetzner credentials à configurer dans vault.yml
- [ ] Tailscale authkey à configurer dans vault.yml
- [ ] ntfy topic à configurer dans vault.yml
