# Guide d'administration — NAS-logo

> Mac Mini Apple Silicon · Immich · Paperless · Monitoring · Hetzner Backup  
> Mis à jour : avril 2026

---

## Sommaire

1. [Architecture](#architecture)
2. [Accès au serveur](#accès-au-serveur)
3. [Services](#services)
4. [Commandes Ansible](#commandes-ansible)
5. [Docker & Colima](#docker--colima)
6. [Sauvegardes](#sauvegardes)
7. [Monitoring & Alertes](#monitoring--alertes)
8. [Problèmes connus](#problèmes-connus)
9. [Disaster recovery](#disaster-recovery)

---

## Architecture

```
Mac Mini (Apple Silicon)
├── Colima (runtime Docker)
│   ├── immich_server        :2283  — serveur photos
│   ├── immich_machine_learning     — reconnaissance IA
│   ├── immich_postgres             — base de données Immich
│   ├── immich_redis                — cache
│   ├── paperless            :8010  — GED documents
│   ├── paperless_redis             — cache Paperless
│   ├── grafana              :3000  — dashboards monitoring
│   ├── prometheus           :9090  — métriques
│   ├── cadvisor             :8080  — métriques Docker
│   ├── node_exporter        :9100  — métriques système
│   ├── alertmanager                — gestion alertes
│   ├── ntfy                 :8090  — push notifications
│   ├── meilisearch          :7700  — moteur de recherche
│   └── search-ui            :7701  — UI Meilisearch
│
├── SSD données chaudes → /Volumes/logousb/SSD/NAS-LOGO-VOLUME/
│   ├── immich/              — photos uploadées
│   ├── immich-db/           — données PostgreSQL
│   ├── backups/             — dumps DB locaux
│   ├── monitoring/          — données Prometheus + Grafana
│   ├── paperless/           — documents GED
│   ├── meilisearch/         — index de recherche
│   ├── n8n/                 — données n8n
│   └── whisper/             — modèles Whisper
│
├── HDD données volumineuses → /Volumes/NAS-LOGO-DATA/  (5,5 To APFS, ajouté 2026-04-26)
│   └── Documents/
│       ├── abc/             ← ~/Documents/abc (symlink, 37 Go)
│       └── SSD/             ← ~/Documents/SSD (symlink, 9,1 Go)
│   (migrations futures : immich, paperless, files, personnes)
│
└── Tailscale VPN
    └── IP : 100.113.214.55
```

---

## Accès au serveur

### SSH
```bash
ssh logo@100.113.214.55
```

### Variables d'environnement Docker (à ajouter dans le shell)
```bash
export DOCKER_HOST=unix://$HOME/.colima/default/docker.sock
export PATH="/opt/homebrew/bin:$PATH"
```

### URLs (via Tailscale uniquement)
| Service      | URL                              | Credentials          | Accès réseau |
|--------------|----------------------------------|----------------------|--------------|
| Immich       | http://100.113.214.55:2283       | compte Immich        | Tailscale    |
| Paperless    | http://100.113.214.55:8010       | admin / voir vault   | Tailscale    |
| Grafana      | http://100.113.214.55:3000       | admin / voir vault   | Tailscale    |
| ntfy         | http://100.113.214.55:8090       | (sans auth)          | Tailscale    |
| Meilisearch  | http://100.113.214.55:7700       | master key           | Tailscale    |
| Prometheus   | http://localhost:9090            | (sans auth)          | **localhost uniquement** — SSH tunnel si besoin |
| cAdvisor     | http://localhost:8080            | (sans auth)          | **localhost uniquement** |
| Alertmanager | http://localhost:9093            | (sans auth)          | **localhost uniquement** |

> **SSH tunnel** pour accéder à Prometheus/Grafana depuis son Mac :
> ```bash
> ssh -L 9090:localhost:9090 logo@100.113.214.55
> ```

---

## Services

### Vérifier l'état de tous les conteneurs
```bash
export DOCKER_HOST=unix://$HOME/.colima/default/docker.sock
docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'
```

### Démarrer / Arrêter un service
```bash
# Immich
cd ~/immich && docker compose up -d
cd ~/immich && docker compose down

# Monitoring
cd ~/monitoring && docker compose up -d
cd ~/monitoring && docker compose down

# Paperless
cd ~/paperless && docker compose up -d
cd ~/paperless && docker compose down
```

### Voir les logs d'un conteneur
```bash
docker logs immich_server --tail 50 -f
docker logs paperless --tail 50 -f
docker logs alertmanager --tail 50 -f
```

### Mettre à jour Immich
```bash
cd ~/immich
docker compose pull
docker compose up -d
```

> **Attention :** vérifier les release notes avant de mettre à jour Immich — certaines versions nécessitent une migration DB manuelle.

---

## Commandes Ansible

Le provisioning est géré depuis **ton Mac** (pas le Mac Mini) :

```bash
cd ~/logo-projects/NAS-logo

# Vérifier les prérequis
make preflight

# Dry-run (voir les changements sans les appliquer)
make dryrun

# Déploiement complet
make install

# Santé du système
make health

# Sauvegarde manuelle
make backup

# Lint des playbooks
make lint
```

### Vault Ansible
Les secrets sont dans `inventory/group_vars/vault.yml` (chiffré AES256).

```bash
# Éditer les secrets
ansible-vault edit inventory/group_vars/vault.yml

# Voir un secret
ansible-vault view inventory/group_vars/vault.yml
```

---

## Docker & Colima

### Démarrer Colima (si Docker ne répond pas)
```bash
colima start
# ou avec plus de ressources :
colima start --cpu 4 --memory 8
```

### Vérifier Colima
```bash
colima status
colima list
```

### Nettoyer Docker (images/volumes inutilisés)
```bash
export DOCKER_HOST=unix://$HOME/.colima/default/docker.sock
docker system prune -a --volumes
```

---

## Sauvegardes

### Fonctionnement
- **Cron quotidien :** 03h00 tous les jours via LaunchAgent
- **Script :** `/usr/local/bin/nas-logo-backup.sh`
- **Dump DB :** `/usr/local/bin/nas-logo-dump-db.sh` (Immich + Paperless)
- **Destination :** Hetzner Storage Box `u575742.your-storagebox.de` via rclone (SFTP chiffré)
- **Logs :** `~/Library/Logs/nas-logo/backup.log`

### Ce qui est sauvegardé
| Donnée | Méthode |
|--------|---------|
| Photos Immich | rclone sync → Hetzner |
| DB Immich (PostgreSQL) | `pg_dumpall` → `immich-db-YYYYMMDD.sql.gz` |
| Documents Paperless | rclone sync → Hetzner |
| DB Paperless (PostgreSQL) | `pg_dump` → `paperless-db-YYYYMMDD.sql.gz` |

### Lancer une sauvegarde manuelle
```bash
nas-logo-backup.sh
# ou :
make backup
```

### Vérifier le dernier backup
```bash
tail -30 ~/Library/Logs/nas-logo/backup.log
nas-logo-restore.sh --list
```

### Structure des backups sur Hetzner
```
hetzner-crypt:current/
├── backups/
│   ├── immich-db-YYYYMMDD-HHMMSS.sql.gz    — dump PostgreSQL Immich
│   └── paperless-db-YYYYMMDD-HHMMSS.sql.gz — dump PostgreSQL Paperless
├── immich/                                  — photos/vidéos
└── paperless/                               — documents PDF + media

hetzner-crypt:versions/YYYYMMDD/             — snapshots quotidiens (7 jours)
```

### Restauration depuis Hetzner

```bash
# Lister les versions disponibles
nas-logo-restore.sh --list

# Simuler la restauration (dry-run)
nas-logo-restore.sh --dry-run

# Restaurer la dernière version
nas-logo-restore.sh

# Restaurer une version spécifique
nas-logo-restore.sh --version 20260419
```

Le script `nas-logo-restore.sh` :
1. Arrête Immich et Paperless
2. Synchronise les fichiers depuis Hetzner (rclone)
3. **Immich** : supprime `immich-db/`, réinitialise PostgreSQL, restaure le dump SQL
4. **Paperless** : démarre `paperless_db`, restaure le dump SQL
5. Redémarre Immich et Paperless

**Important — après restore Immich :** si erreur 500, vérifier qu'aucune instance Docker Desktop n'est active sur le port 2283 :
```bash
DOCKER_HOST=unix://$HOME/.docker/run/docker.sock docker ps | grep 2283
# Si une instance tourne → l'arrêter :
DOCKER_HOST=unix://$HOME/.docker/run/docker.sock docker compose -f ~/immich/docker-compose.yml down
# Puis relancer via Colima :
docker compose -f ~/immich/docker-compose.yml down && docker compose -f ~/immich/docker-compose.yml up -d
```

---

## Monitoring & Alertes

### Dashboards Grafana
- **URL :** http://100.113.214.55:3000
- **Login :** admin / 1.Ctoutgraf
- Dashboards disponibles : cAdvisor (Docker), Node Exporter (système), Immich

### Alertes ntfy
- **Topic :** `nas-logo`
- **URL :** http://100.113.214.55:8090/nas-logo
- Abonnement mobile : app ntfy → serveur `http://100.113.214.55:8090` → topic `nas-logo`

### Règles d'alerte actives
- Disque SSD > 80% → alerte urgente
- Conteneur down > 5 min → alerte
- Backup échoué → alerte urgente

### Prometheus
```bash
# Voir les métriques brutes
curl http://100.113.214.55:9090/metrics

# Vérifier les targets
curl http://100.113.214.55:9090/api/v1/targets | jq '.data.activeTargets[] | {job: .labels.job, health: .health}'
```

---

## Problèmes connus

### Immich `unhealthy`
Immich peut rester en état `unhealthy` après un import massif (machine learning en train de tourner). Vérifier :
```bash
docker logs immich_server --tail 20
docker logs immich_machine_learning --tail 20
```
Si bloqué, redémarrer le service machine learning :
```bash
docker restart immich_machine_learning
```

### Alertmanager en `Restarting`
Alertmanager redémarre en boucle. Vérifier la config :
```bash
docker logs alertmanager --tail 30
cat /Volumes/logousb/SSD/NAS-LOGO-VOLUME/monitoring/alertmanager/alertmanager.yml
```

### SMB / Partage réseau
`smbd` n'a pas accès au SSD externe à cause des restrictions TCC macOS.  
**Fix :** Réglages Système → Confidentialité & Sécurité → Accès complet au disque → ajouter `/usr/sbin/smbd`.  
Nécessite un accès physique (impossible via SSH / SIP activé).

---

## Disaster recovery

### Si le Mac Mini meurt

1. Récupérer un nouveau Mac Mini (Apple Silicon)
2. Configurer SSH + Tailscale manuellement
3. Monter le SSD externe
4. Cloner le repo :
   ```bash
   git clone <repo> ~/logo-projects/NAS-logo
   ```
5. Re-provisionner :
   ```bash
   make bootstrap
   make install
   ```
6. Restaurer depuis Hetzner :
   ```bash
   nas-logo-restore.sh --list       # voir les versions
   nas-logo-restore.sh --dry-run    # vérifier avant d'exécuter
   nas-logo-restore.sh              # restaurer
   ```
7. Si Immich affiche une erreur 500 après restore → voir section **Restauration depuis Hetzner** ci-dessus (conflit Docker Desktop).

> **RTO/RPO validés le 2026-04-19** — test de restore complet effectué avec succès (backup 20260413 et 20260419).
