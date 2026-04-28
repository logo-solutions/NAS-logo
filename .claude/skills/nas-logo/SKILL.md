---
name: nas-logo
description: >
  Contexte complet du projet NAS-logo — provisioning Ansible d'un Mac Mini vierge en
  serveur familial complet : Immich, Paperless-ngx, Meilisearch, n8n, Whisper, monitoring,
  sauvegarde Hetzner, partage SMB, import Gmail. Utilise ce skill dès qu'on travaille sur
  ce projet : playbooks Ansible, rôles, variables, sécurité, déploiement. Déclenche aussi
  pour toute question sur l'architecture ou la configuration du NAS de logo.
---

# Projet NAS-logo — Contexte Claude

## Objectif

Provisioning complet et reproductible d'un **Mac Mini vierge (Apple Silicon)** pour en
faire un serveur familial accessible depuis n'importe où via VPN.

**Propriétaire :** logo (lgbertheaume@gmail.com)
**Repo Git :** https://github.com/logo-solutions/NAS-logo
**Dossier projet :** `/Volumes/logousb/SSD/Projects/NAS-logo`
**Tailscale IP fixe :** `100.113.214.55`

---

## Architecture

```
Mac Mini (hôte macOS Apple Silicon)
├── SSD données chaudes : /Volumes/logousb/SSD/NAS-LOGO-VOLUME
│   ├── immich/              → bibliothèque photos Immich        [→ migration prévue HDD]
│   ├── immich-db/           → base PostgreSQL                   [reste SSD]
│   ├── monitoring/          → données Prometheus + Grafana + ntfy [reste SSD]
│   ├── paperless/           → documents Paperless-ngx           [→ migration prévue HDD]
│   ├── meilisearch/         → index Meilisearch                 [reste SSD]
│   ├── n8n/                 → données n8n                       [reste SSD]
│   ├── whisper/             → modèles Whisper                   [reste SSD]
│   ├── files/               → fichiers partagés (SMB)           [→ migration prévue HDD]
│   ├── personnes/           → arbo par personne                 [→ migration prévue HDD]
│   └── backups/             → dump DB avant sync Hetzner        [reste SSD]
├── HDD données volumineuses : /Volumes/NAS-LOGO-DATA  (5,5 To APFS, ajouté 2026-04-26)
│   └── Documents/           → dossiers de l'utilisateur (symlinks depuis ~/Documents)
│       ├── abc/             → ~/Documents/abc (symlink, 37 Go)
│       └── SSD/             → ~/Documents/SSD (symlink, 9,1 Go)
├── ~/immich/                → docker-compose.yml Immich
├── ~/monitoring/            → docker-compose.monitoring.yml
├── ~/paperless/             → docker-compose.paperless.yml
├── ~/recherche/             → docker-compose.recherche.yml
├── ~/n8n/                   → docker-compose.n8n.yml
├── ~/whisper/               → docker-compose.whisper.yml
└── Colima (Docker runtime)
    ├── immich-server + machine-learning + postgres + redis
    ├── prometheus + grafana + cadvisor + alertmanager + node-exporter + ntfy
    ├── paperless-ngx + redis + postgres
    ├── meilisearch
    ├── n8n
    └── faster-whisper-server

Réseau
└── Tailscale  → VPN mesh, accès depuis n'importe où, aucun port exposé

Sauvegarde distante
└── Hetzner Storage Box (88.99.49.100) → rclone chiffré, rétention 7j quotidien
```

---

## Stack technique

| Composant        | Technologie                              | Port  |
|------------------|------------------------------------------|-------|
| Photos           | Immich (release)                         | 2283  |
| Documents        | Paperless-ngx + Tesseract OCR (FR)       | 8010  |
| Recherche        | Meilisearch v1.42.1 + indexeur Python    | 7700  |
| Automatisation   | n8n                                      | 5679  |
| Transcription    | faster-whisper-server (small, FR)        | 8020  |
| Monitoring       | Prometheus + Grafana + cAdvisor          | 9090 / 3000 / 8080 |
| Alertes          | ntfy (self-hosted) + Alertmanager        | 8090 / 9093 |
| Conteneurs       | Colima (pas Docker Desktop)              | —     |
| Réseau VPN       | Tailscale (tag:nas)                      | —     |
| Sauvegarde       | rclone → Hetzner SFTP chiffré            | —     |
| Partage fichiers | SMB macOS natif                          | 445   |
| Import email     | Gmail → Paperless/Immich (LaunchAgent)   | —     |
| Automatisation   | Ansible (rôles séparés)                  | —     |
| Secrets          | ansible-vault (AES256)                   | —     |
| UPS              | APC BX750MI, détecté via pmset           | —     |

**IMPORTANT — Docker :** Colima uniquement. Pas Docker Desktop. Socket :
`unix:///Users/{{ ansible_user_id }}/.colima/default/docker.sock`
Tous les ports Docker doivent être bindés sur `0.0.0.0:X:X` (Colima n'expose pas `127.0.0.1`).

---

## Structure du projet

```
NAS-logo/
├── Makefile                    → commandes principales
├── site.yml                    → playbook principal (make install)
├── bootstrap.yml               → étape 1 : Homebrew + outils
├── preflight.yml               → étape 2 : vérifie SSD, réseau, Hetzner
├── healthcheck.yml             → health check complet (make health)
├── claude.yml                  → étape optionnelle : Claude Code + MCP
├── inventory/
│   ├── hosts                   → cible : 100.113.214.55 ansible_user=logo
│   └── group_vars/all/
│       ├── vars.yml            → variables globales (pas de secrets)
│       └── vault.yml           → secrets chiffrés (ansible-vault)
├── roles/
│   ├── base/                   → Homebrew, packages, collections Ansible
│   ├── stockage/               → vérification SSD, arborescence
│   ├── acces/                  → SSH hardening, clés autorisées
│   ├── securite/               → Tailscale, firewall macOS
│   ├── docker/                 → Colima
│   ├── immich/                 → Docker Compose Immich
│   ├── personnes/              → arbo SSD par personne
│   ├── monitoring/             → Prometheus + Grafana + cAdvisor + ntfy + Alertmanager
│   ├── sauvegarde/             → rclone, dump PostgreSQL, LaunchAgent cron
│   ├── paperless/              → Paperless-ngx + Tesseract
│   ├── recherche/              → Meilisearch + indexeur + UI HTML
│   ├── smb/                    → partage SMB famille
│   ├── gmail/                  → import Gmail → Paperless/Immich (LaunchAgent)
│   ├── n8n/                    → workflows n8n
│   └── whisper/                → faster-whisper-server
├── scripts/
│   ├── setup-ups.sh                → configuration UPS APC
│   ├── consolidate-memory.sh       → consolidation mémoire nocturne (LaunchAgent 02h00)
│   ├── consolidate-memory.plist    → LaunchAgent macOS
│   └── install-memory-schedule.sh  → installe/désinstalle le LaunchAgent
├── memory/                     → couche mémoire persistante (MAJ nightly par LaunchAgent)
│   ├── recent-memory.md        → contexte glissant 48h (écrasé à chaque run)
│   ├── long-term-memory.md     → préférences confirmées (append only)
│   └── project-memory.md       → état actif du projet (merge-update)
├── skills/                     → skills agent-skills
│   └── consolidateMemory/      → skill de consolidation mémoire
├── agents/                     → personas IA
├── references/                 → checklists sécurité, perf, tests
└── .claude/skills/nas-logo/    → ce fichier
```

---

## Makefile — commandes

| Commande              | Description                                        |
|-----------------------|----------------------------------------------------|
| `make bootstrap`      | Homebrew, Ansible, dépendances (une fois)          |
| `make preflight`      | Vérifications pré-déploiement                      |
| `make dryrun`         | Dry-run complet avec diff                          |
| `make install`        | Installation complète                              |
| `make health`         | Health check à tout moment                         |
| `make lint`           | ansible-lint sur tous les playbooks                |
| `make backup`         | Sauvegarde manuelle immédiate                      |
| `make restore`        | Restaurer depuis Hetzner (VERSION=YYYYMMDD)        |
| `make restore-list`   | Lister les versions disponibles                    |
| `make gmail-run`      | Import Gmail immédiat                              |
| `make maintenance-on` | Suspendre les sauvegardes                          |
| `make claude`         | Claude Code + MCP (optionnel)                      |

Vault + become passwords : `~/.nas-logo-vault-pass` + `~/.nas-logo-become-pass`

---

## Variables clés (vars.yml)

| Variable               | Valeur                                              |
|------------------------|-----------------------------------------------------|
| `mac_user`             | `{{ ansible_user_id }}`                             |
| `ssd_mount_point`      | `/Volumes/logousb/SSD/NAS-LOGO-VOLUME`              |
| `hdd_mount_point`      | `/Volumes/NAS-LOGO-DATA` (HDD 5,5 To APFS, ajouté 2026-04-26) |
| `nas_ip`               | `100.113.214.55`                                    |
| `immich_port`          | `2283`                                              |
| `paperless_port`       | `8010`                                              |
| `grafana_port`         | `3000`                                              |
| `prometheus_port`      | `9090`                                              |
| `meilisearch_port`     | `7700`                                              |
| `n8n_port`             | `5679`                                              |
| `whisper_port`         | `8020`                                              |
| `ntfy_port`            | `8090`                                              |
| `alert_disk_threshold` | `80` (%)                                            |
| `backup_daily_keep`    | `7`                                                 |
| `hetzner_host`         | `88.99.49.100`                                      |
| `docker_bin`           | `/opt/homebrew/bin/docker`                          |
| `docker_host`          | `unix:///Users/{{ ansible_user_id }}/.colima/...`   |
| `whisper_model`        | `small`                                             |
| `whisper_language`     | `fr`                                                |

Personnes : `alice`, `loic-administratif`, `loic-formation`, `loic-pro`, `loic-immo`,
`alo`, `alban`, `mahaut`, `ilan`, `famille-gourmelon`, `famille-vasseur`

Comptes SMB : `alban`, `ilan`, `alice`
Comptes Immich : `alban`, `ilan`
Comptes Paperless : `alban`, `ilan`

Variables sensibles dans `vault.yml` :
- `vault_hetzner_user`, `vault_hetzner_password`
- `vault_tailscale_authkey`
- `vault_grafana_admin_password`
- `vault_immich_api_key`, `vault_immich_alban_password`, `vault_immich_ilan_password`
- `vault_paperless_db_password`, `vault_paperless_api_token`
- `vault_paperless_alban_password`, `vault_paperless_ilan_password`
- `vault_meilisearch_master_key`
- `vault_smb_alban_password`, `vault_smb_ilan_password`, `vault_smb_alice_password`
- `vault_gmail_user`
- `vault_alice_ssh_public_key`

`immich_db_password` est généré via `lookup('ansible.builtin.password', ...)` — pas dans vault.

---

## Conventions

- **Idempotence** : chaque tâche peut tourner N fois sans effet de bord.
- **Secrets** : jamais en clair — toujours `vault_*` dans `vault.yml`.
- **Modules FQCN** : `ansible.builtin.*`, `community.general.*`, `community.docker.*`.
- **`changed_when` / `failed_when`** explicites sur tous les `shell`/`command`.
- **`when: not ansible_check_mode`** sur les tâches docker_compose_v2.
- **Docker** : tout passe par Docker Compose (jamais `docker run` nu).
- **Ports** : toujours `0.0.0.0:X:X` dans les compose (Colima n'expose pas 127.0.0.1).
- **Git** : travailler sur `main`, committer après chaque étape validée.
- **Sauvegarde** : dump PostgreSQL avant rclone, chiffrement rclone crypt côté client.
- **Maintenance** : `make maintenance-on` avant toute intervention sur les données.

---

## Health check (`make health`)

Vérifie dans l'ordre :
1. SSD monté + usage < 80%
2. Colima running + conteneurs sans erreur
3. HTTP : Immich (2283), Paperless (8010), Grafana (3000), Prometheus (9090),
   cAdvisor (8080), node-exporter (9100), Alertmanager (9093), ntfy (8090),
   n8n (5679), Whisper (8020)
4. SMB share actif + port 445
5. Tailscale connecté + IP == `100.113.214.55`
6. Accès via IP Tailscale (simulation externe)
7. Hetzner SFTP joignable (port 22)
8. Fraîcheur backup < 25h
9. UPS APC BX750MI détecté (`pmset -g batt`) + batterie > 50%

---

## Instructions de session

**À chaque démarrage de session sur ce projet**, lire impérativement :
- `/Users/logo/.claude/projects/-Volumes-logousb-SSD-Projects-NAS-logo/memory/project_roadmap.md` — roadmap priorisée, reprendre là où on s'est arrêtés
