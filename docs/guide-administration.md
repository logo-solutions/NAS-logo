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
├── SSD externe → /Volumes/logousb/SSD/NAS-LOGO-VOLUME/
│   ├── immich/              — photos uploadées
│   ├── immich-db/           — données PostgreSQL
│   ├── backups/             — dumps DB locaux
│   ├── imports/             — zone de dépôt (Takeout, scans...)
│   ├── monitoring/          — données Prometheus + Grafana
│   ├── paperless/           — documents GED
│   └── meilisearch/         — index de recherche
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
| Service      | URL                              | Credentials          |
|--------------|----------------------------------|----------------------|
| Immich       | http://100.113.214.55:2283       | compte Immich        |
| Paperless    | http://100.113.214.55:8010       | admin / 1.Ctoutpaper |
| Grafana      | http://100.113.214.55:3000       | admin / 1.Ctoutgraf  |
| Prometheus   | http://100.113.214.55:9090       | (sans auth)          |
| ntfy         | http://100.113.214.55:8090       | (sans auth)          |
| Meilisearch  | http://100.113.214.55:7700       | (sans auth)          |

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
- **Dump DB :** `/usr/local/bin/nas-logo-dump-db.sh`
- **Destination :** Hetzner Storage Box `u575742.your-storagebox.de` via rclone (SFTP chiffré)
- **Remote path :** `immich-backup` (sans slash initial)
- **Logs :** `/tmp/nas-logo-backup.log` et `/tmp/nas-logo-backup.err`

### Lancer une sauvegarde manuelle
```bash
ssh logo@100.113.214.55 '/usr/local/bin/nas-logo-backup.sh'
# ou depuis ton Mac :
make backup
```

### Vérifier le dernier backup
```bash
# Voir les logs
cat /tmp/nas-logo-backup.log | tail -30

# Lister les fichiers sur Hetzner
rclone ls hetzner-crypt:immich-backup --max-depth 1
```

### Structure des backups sur Hetzner
```
immich-backup/
├── immich-db-YYYYMMDD-HHMMSS.sql.gz   — dump PostgreSQL
└── immich/                            — fichiers photos (rclone sync)
```

### Problème connu : dump DB échoue
Le dump PostgreSQL échoue avec `Operation not permitted` car le SSD a des restrictions d'écriture.

**Fix temporaire :** dumper vers `/tmp` puis copier :
```bash
DOCKER_HOST=unix://$HOME/.colima/default/docker.sock \
  docker exec immich_postgres pg_dumpall -U immich | gzip > /tmp/immich-db-$(date +%Y%m%d).sql.gz

cp /tmp/immich-db-*.sql.gz /Volumes/logousb/SSD/NAS-LOGO-VOLUME/backups/
```

**Fix permanent :** à implémenter dans Ansible — changer le chemin de dump vers `/tmp`.

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
6. Restaurer les photos depuis Hetzner :
   ```bash
   rclone sync hetzner-crypt:immich-backup/immich /Volumes/logousb/SSD/NAS-LOGO-VOLUME/immich
   ```
7. Restaurer la base de données :
   ```bash
   gunzip -c /Volumes/logousb/SSD/NAS-LOGO-VOLUME/backups/immich-db-LATEST.sql.gz | \
     docker exec -i immich_postgres psql -U immich
   ```

> **RTO/RPO non validés** — un test de restore complet reste à faire.
