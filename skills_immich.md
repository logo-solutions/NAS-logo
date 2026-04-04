# Domaines de responsabilité — Projet NAS-logo

> Mac Mini · SSD externe `/Volumes/logousb/SSD/NAS-LOGO-VOLUME` · Hetzner Storage Box · Docker · Ansible · Claude Code + MCP

---

## Skill 1 — Sécurité

> Protéger l'accès et les données contre toute intrusion

| Responsabilité                | Description                                                         | Rôle Ansible  |
| ----------------------------- | ------------------------------------------------------------------- | ------------- |
| VPN (Tailscale)               | Accès équipe uniquement via VPN — Immich jamais exposé sur internet | `securite`    |
| HTTPS + reverse proxy (Caddy) | Chiffrement TLS, certificat auto-renouvelé, port 443 uniquement     | `securite`    |
| Chiffrement du disque         | SSD chiffré (FileVault), données illisibles si vol physique         | manuel        |
| Logs et audit                 | Journalisation des accès, détection de tentatives suspectes         | `monitoring`  |
| Mises à jour de sécurité      | Patches macOS, Docker et Immich appliqués régulièrement             | `base`        |

---

## Skill 2 — Tests

> Vérifier que tout fonctionne, avant et après chaque changement

| Responsabilité          | Description                                                              | Commande          |
| ----------------------- | ------------------------------------------------------------------------ | ----------------- |
| Tests fonctionnels      | Upload, téléchargement, partage, accès par rôle                          | manuel            |
| Tests de restauration   | Simuler une perte de données et valider la restauration complète         | `make health`     |
| Tests de charge         | Accès simultanés, upload massif, temps de réponse                        | manuel            |
| Tests de non-régression | Vérifier qu'une mise à jour ne casse pas l'existant                      | `make test`       |
| Tests de disponibilité  | Redémarrage Mac Mini, reprise automatique de Docker                      | `make health`     |
| Dry-run Ansible         | Vérifier les changements avant application                               | `make dryrun`     |

---

## Skill 3 — Produit

> Installer, configurer et maintenir Immich pour l'équipe

| Responsabilité        | Description                                         | Rôle Ansible |
| --------------------- | --------------------------------------------------- | ------------ |
| Installation Immich   | Docker Compose, configuration initiale              | `immich`     |
| Config stockage       | SSD monté, chemin de stockage Immich                | `stockage`   |
| Mises à jour          | Versions (`v1.106.4`), rollback, zero-downtime      | `immich`     |
| Démarrage automatique | LaunchAgent plist, reprise au redémarrage Mac Mini  | `immich`     |
| Interface web         | Port 2283, domaine Tailscale via Caddy              | `securite`   |
| Sync mobile           | App iOS/Android, upload automatique                 | manuel       |

---

## Skill 4 — Gestion des accès

> Contrôler qui accède à quoi, et révoquer rapidement si nécessaire

| Responsabilité       | Description                                   | Rôle Ansible |
| -------------------- | --------------------------------------------- | ------------ |
| Utilisateurs         | Création, désactivation, quotas par compte    | `acces`      |
| Rôles et permissions | Admin, lecteur, éditeur                       | `acces`      |
| Double auth (2FA)    | TOTP obligatoire pour tous les membres        | `acces`      |
| Tokens et sessions   | Expiration, révocation, audit des connexions  | `acces`      |
| Partage albums       | Liens temporaires, accès limité dans le temps | manuel       |

---

## Skill 5 — Sauvegarde

> Ne jamais perdre une donnée, et pouvoir restaurer à tout moment

| Responsabilité         | Description                                       | Rôle Ansible  |
| ---------------------- | ------------------------------------------------- | ------------- |
| Sync Hetzner           | rclone chiffré, synchronisation planifiée         | `sauvegarde`  |
| Backup base de données | PostgreSQL dump automatique avec rotation         | `sauvegarde`  |
| Rétention              | 7j quotidien · 4 semaines hebdo · 12 mois mensuel| `sauvegarde`  |
| Vérification intégrité | Checksum automatique, alerte si échec             | `monitoring`  |
| Test de restauration   | Drill mensuel, validation complète des données    | manuel        |

---

## Skill 6 — Monitoring

> Savoir que tout fonctionne, avant que l'équipe le signale

| Responsabilité    | Description                                     | Rôle Ansible  |
| ----------------- | ----------------------------------------------- | ------------- |
| Espace disque     | Seuil d'alerte à 80%, surveillance SMART        | `monitoring`  |
| Uptime Immich     | Health check automatique, redémarrage si tombé  | `monitoring`  |
| Alertes           | Notifications ntfy.sh (`immich-alerts-*`)       | `monitoring`  |
| CPU et RAM        | Charge Mac Mini et conteneurs Docker            | `monitoring`  |
| Suivi sauvegardes | Rapport quotidien, logs rclone                  | `sauvegarde`  |

---

## Skill 7 — Déploiement

> Automatiser tout ce qui peut l'être, de façon reproductible

| Responsabilité        | Description                                               | Commande        |
| --------------------- | --------------------------------------------------------- | --------------- |
| Bootstrap             | Homebrew, Docker, SSH, dépendances                        | `make bootstrap`|
| Preflight             | Vérification SSD, Hetzner, macOS avant install            | `make preflight`|
| Dry-run               | Simulation avec diff des changements                      | `make dryrun`   |
| Installation          | Déploiement complet idempotent                            | `make install`  |
| Claude Code + MCP     | Connecteurs filesystem, docker, github, shell             | `make claude`   |
| Secrets Ansible Vault | Clés API et mots de passe chiffrés                        | `vault.yml`     |
| Tests et lint         | ansible-lint, Molecule sur rôles critiques                | `make lint/test`|

---

## Skill 8 — Stockage

> Gérer le disque physique de façon fiable et durable

| Responsabilité      | Description                                    | Rôle Ansible |
| ------------------- | ---------------------------------------------- | ------------ |
| Partitionnement SSD | Format, montage `/Volumes/logousb/SSD/NAS-LOGO-VOLUME` | `stockage` |
| Quotas utilisateurs | Limites de stockage par compte Immich          | `acces`      |
| Santé disque SMART  | Température, secteurs défectueux, durée de vie | `monitoring` |

---

## Récapitulatif

| #   | Skill             | Catégorie | Rôle Ansible              | Responsabilités |
| --- | ----------------- | --------- | ------------------------- | --------------- |
| 1   | Sécurité          | Core      | `securite`                | 5               |
| 2   | Tests             | Core      | `qualite` + make          | 6               |
| 3   | Produit           | Core      | `immich`                  | 6               |
| 4   | Gestion des accès | Core      | `acces`                   | 5               |
| 5   | Sauvegarde        | Infra     | `sauvegarde`              | 5               |
| 6   | Monitoring        | Infra     | `monitoring`              | 5               |
| 7   | Déploiement       | Infra     | Makefile + playbooks      | 7               |
| 8   | Stockage          | Infra     | `stockage`                | 3               |

---

_Projet NAS-logo · Mac Mini · Hetzner · Docker · Ansible · Claude Code + MCP_
_Mis à jour : 2026-04-04_
