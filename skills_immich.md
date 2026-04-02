# Skills — Projet stockage sécurisé Immich

> Mac Mini 4To · SSD externe · Hetzner Storage Box · Docker · Ansible · Claude Code + MCP

---

## Skill 1 — Sécurité

> Protéger l'accès et les données contre toute intrusion

| Responsabilité                | Description                                                         |
| ----------------------------- | ------------------------------------------------------------------- |
| VPN (Tailscale)               | Accès équipe uniquement via VPN — Immich jamais exposé sur internet |
| HTTPS + reverse proxy (Caddy) | Chiffrement TLS, certificat auto-renouvelé, port 443 uniquement     |
| Chiffrement du disque         | SSD chiffré (FileVault ou LUKS), données illisibles si vol physique |
| Logs et audit                 | Journalisation des accès, détection de tentatives suspectes         |
| Mises à jour de sécurité      | Patches macOS, Docker et Immich appliqués régulièrement             |

---

## Skill 2 — Tests

> Vérifier que tout fonctionne, avant et après chaque changement

| Responsabilité          | Description                                                              |
| ----------------------- | ------------------------------------------------------------------------ |
| Tests fonctionnels      | Upload, téléchargement, partage, accès par rôle                          |
| Tests de restauration   | Simuler une perte de données et valider la restauration complète         |
| Tests de charge         | Accès simultanés, upload massif, temps de réponse                        |
| Tests de non-régression | Vérifier qu'une mise à jour ne casse pas l'existant                      |
| Tests de disponibilité  | Redémarrage Mac Mini, reprise automatique de Docker                      |
| Test de déchiffrement   | Monter le disque chiffré, déchiffrer et vérifier l'intégrité des données |

---

## Skill 3 — Produit

> Installer, configurer et maintenir Immich pour l'équipe

| Responsabilité        | Description                                    |
| --------------------- | ---------------------------------------------- |
| Installation Immich   | Docker Compose, configuration initiale         |
| Config stockage       | SSD monté, chemin de stockage Immich           |
| Mises à jour          | Versions, rollback, zero-downtime              |
| Démarrage automatique | Reprise automatique au redémarrage du Mac Mini |
| Interface web         | URL, langue, thème pour l'équipe               |
| Sync mobile           | App iOS/Android, upload automatique            |

---

## Skill 4 — Gestion des accès

> Contrôler qui accède à quoi, et révoquer rapidement si nécessaire

| Responsabilité       | Description                                   |
| -------------------- | --------------------------------------------- |
| Utilisateurs         | Création, désactivation, quotas par compte    |
| Rôles et permissions | Admin, lecteur, éditeur                       |
| Double auth (2FA)    | TOTP obligatoire pour tous les membres        |
| Tokens et sessions   | Expiration, révocation, audit des connexions  |
| Partage albums       | Liens temporaires, accès limité dans le temps |

---

## Skill 5 — Sauvegarde

> Ne jamais perdre une donnée, et pouvoir restaurer à tout moment

| Responsabilité         | Description                                       |
| ---------------------- | ------------------------------------------------- |
| Sync Hetzner           | rclone chiffré, synchronisation planifiée         |
| Backup base de données | PostgreSQL dump automatique avec rotation         |
| Rétention              | 7j quotidien · 4 semaines hebdo · 12 mois mensuel |
| Vérification intégrité | Checksum automatique, alerte si échec             |
| Test de restauration   | Drill mensuel, validation complète des données    |

---

## Skill 6 — Monitoring

> Savoir que tout fonctionne, avant que l'équipe le signale

| Responsabilité    | Description                                    |
| ----------------- | ---------------------------------------------- |
| Espace disque     | Seuil d'alerte à 80%, surveillance SMART       |
| Uptime Immich     | Health check automatique, redémarrage si tombé |
| Alertes           | Notifications email, Slack ou ntfy.sh          |
| CPU et RAM        | Charge Mac Mini et conteneurs Docker           |
| Suivi sauvegardes | Rapport quotidien, logs rclone                 |

---

## Skill 7 — Déploiement

> Automatiser tout ce qui peut l'être, de façon reproductible

| Responsabilité        | Description                                               |
| --------------------- | --------------------------------------------------------- |
| Playbooks Ansible     | Rôles, inventaire, variables d'environnement              |
| Secrets Ansible Vault | Clés API et mots de passe chiffrés                        |
| Déploiement continu   | Zero-downtime, rollback automatique                       |
| Provisioning          | Installation Homebrew, Docker et dépendances from scratch |
| Tests et lint         | ansible-lint, dry-run, versionnement Git                  |

---

## Skill 8 — Stockage

> Gérer le disque physique de façon fiable et durable

| Responsabilité      | Description                                    |
| ------------------- | ---------------------------------------------- |
| Partitionnement SSD | Format, montage automatique au démarrage       |
| Quotas utilisateurs | Limites de stockage par compte Immich          |
| Santé disque SMART  | Température, secteurs défectueux, durée de vie |

---

## Récapitulatif

| #   | Skill             | Catégorie | Responsabilités |
| --- | ----------------- | --------- | --------------- |
| 1   | Sécurité          | Core      | 5               |
| 2   | Tests             | Core      | 6               |
| 3   | Produit           | Core      | 6               |
| 4   | Gestion des accès | Core      | 5               |
| 5   | Sauvegarde        | Infra     | 5               |
| 6   | Monitoring        | Infra     | 5               |
| 7   | Déploiement       | Infra     | 5               |
| 8   | Stockage          | Infra     | 3               |

---

_Généré dans le cadre du projet Immich · Mac Mini · Hetzner · Claude Code + MCP_
