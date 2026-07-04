# Guide de Sauvegarde NAS-logo

## Vue d'ensemble

Le système de sauvegarde NAS-logo repose sur 3 piliers :

1. **Dump PostgreSQL quotidien** : Immich, Paperless, n8n
2. **Sync rclone vers Hetzner** : Tous les fichiers SSD (chiffré AES256)
3. **Rétention intelligente** : Garde minimum 7 versions, auto-purge anciennes

### Architecture

```
Sources
├── SSD (/Volumes/logousb/SSD/NAS-LOGO-VOLUME)
│   ├── immich-db/              (PostgreSQL — sauvegardé quotidien)
│   ├── backups/                (dumps locaux, conservés 7 jours)
│   ├── n8n/, meilisearch/, monitoring/, ...
│   └── (thumbs, encoded-video reconstruits)
└── HDD (/Volumes/NAS-LOGO-DATA/NAS-LOGO-VOLUME)
    ├── immich/library/         (photos importées ~400 Gi)
    ├── immich/upload/          (uploads mobiles/web)
    ├── personnes/*/files/      (documents personnels, uploads Immich)
    ├── paperless/              (documents avec transcriptions)
    └── files/                  (fichiers généraux)

        ↓ (1) DB dumps quotidiens → SSD
        ↓ (2) rclone sync SSD
        ↓ (3) rclone sync HDD
        ↓ (4) rétention 7 versions min

Hetzner Storage Box (chiffré rclone)
├── current/
│   ├── ssd/                    (BDD, backups, index)
│   └── hdd/                    (fichiers: immich, paperless, personnes, files)
└── versions/YYYYMMDD/
    ├── ssd/
    └── hdd/
```

---

## Sauvegardes Automatiques

### Quand ?
**Quotidiennement à 2h30 du matin** via LaunchAgent macOS.

### Quoi ?
1. Dumps PostgreSQL complets (Immich, Paperless, n8n) → **SSD**
2. Tous les fichiers **SSD** sauf :
   - `immich/thumbs/**` (reconstruits automatiquement)
   - `immich/encoded-video/**` (reconstruits)
   - `meilisearch/**` (index, recalculable)
   - `monitoring/**` (métriques, recalculables)
   - `.DS_Store` (fichiers système)
3. Tous les fichiers **HDD** sauf :
   - `immich/thumbs/**`, `immich/encoded-video/**` (reconstruits sur SSD)
   - `immich/backups/**` (dumps locaux, non essentiels)
   - `paperless/db/**`, `paperless/redis/**` (BDD sur SSD)
   - `.DS_Store` (fichiers système)

### Logs automatiques
```bash
$HOME/Library/Logs/nas-logo/
├── backup-20260503.log        # Backup quotidien
├── dump-20260503-143015.log   # Dumps DB
└── restore.log                 # Restaurations (si exécutées)
```

### Maintenance — Pause temporaire
```bash
# Pour suspendre les sauvegardes (ex: migration, maintenance)
touch /tmp/nas-logo-maintenance

# Les sauvegardes seront ignorées jusqu'à suppression du fichier
rm /tmp/nas-logo-maintenance
```

---

## Sauvegarde Ciblée (avant opération sensible)

### Cas d'usage
- Avant mise à jour majeure d'un service
- Avant changement de configuration critique
- Avant opération de maintenance

### Commande
```bash
# Sauvegarder UN service (local seulement)
nas-logo-backup-cible.sh --service n8n --no-transfer

# Sauvegarder UN service (+ upload Hetzner)
nas-logo-backup-cible.sh --service immich

# Sauvegarder TOUS les services
nas-logo-backup-cible.sh --service all
```

### Services disponibles
- `immich` : Base Immich (métadonnées photos, comptes, albums)
- `paperless` : Base Paperless (documents, utilisateurs, étiquettes)
- `n8n` : Base n8n (workflows, credentials, logs)
- `all` : Les trois

### Exemple : avant upgrade Immich
```bash
# 1. Sauvegarder Immich localement
nas-logo-backup-cible.sh --service immich --no-transfer

# 2. Vérifier le dump
ls -lh /Volumes/logousb/SSD/NAS-LOGO-VOLUME/backups/immich-db-backup-cible-*.sql.gz | tail -1

# 3. Procéder à l'upgrade
docker compose -f ~/immich/docker-compose.yml pull
docker compose -f ~/immich/docker-compose.yml up -d

# 4. Si problème : restaurer depuis le dump créé
# (voir section "Restauration d'urgence")
```

### Logs
```bash
/Volumes/logousb/SSD/Projects/NAS-logo/scripts/backup-restore/logs/backup-cible-*.log
```

---

## Test de Restauration (non-destructif)

### Cas d'usage
- Vérifier régulièrement que les dumps sont restaurables
- Valider intégrité des backups
- Avant d'effectuer une restauration réelle

### Commande
```bash
# Tester restauration d'un service (conteneur temporaire)
nas-logo-restore-test.sh --service n8n

# Tester tous les services
nas-logo-restore-test.sh --service all

# Tester avec un dump spécifique
nas-logo-restore-test.sh --service immich --dump /backups/immich-db-20260503-123456.sql.gz
```

### Ce que le test fait
1. Lance un conteneur PostgreSQL temporaire (port 15432)
2. Restaure le dump du service
3. Valide la structure DB :
   - Immich : >20 tables, compte les assets
   - Paperless : >10 tables, compte les documents
   - n8n : >15 tables, compte les workflows
4. Supprime le conteneur temporaire

### Interprétation
```
✓ TOUS LES TESTS PASS → Dumps intègres, restauration possible
✗ TEST ÉCHOUÉ → Dump corrompu ou incomplet, investigation requise
```

### Logs
```bash
/Volumes/logousb/SSD/Projects/NAS-logo/scripts/backup-restore/logs/restore-test-*.log
```

### Maintenance recommandée
```bash
# Tester tous les services mensuellement
nas-logo-restore-test.sh --service all

# Monitorer les logs
tail -f /Volumes/logousb/SSD/Projects/NAS-logo/scripts/backup-restore/logs/restore-test-*.log
```

---

## Restauration

### Scénario 1 : Restauration complète (perte totale SSD)

```bash
# ⚠️  ATTENTION : Cette opération écrase tout sur SSD

# 1. Vérifier quelle version restaurer
nas-logo-restore.sh --list

# 2. (Optionnel) Simuler sans écrire
nas-logo-restore.sh --dry-run

# 3. Restaurer depuis la dernière sauvegarde
nas-logo-restore.sh

# 4. Ou restaurer depuis une version spécifique
nas-logo-restore.sh --version 20260501

# 5. Vérifier les logs
tail -f ~/Library/Logs/nas-logo/restore.log
```

**Le script restaure automatiquement :**
- Tous les fichiers SSD depuis Hetzner
- Base PostgreSQL Immich
- Base PostgreSQL Paperless
- Base PostgreSQL n8n
- Redémarre les conteneurs dans le bon ordre

---

### Scénario 2 : Restauration d'urgence (service cassé)

Si UN service seulement a un problème, restaurer uniquement sa DB :

```bash
# 1. Arrêter le service
docker stop immich_server immich_machine_learning immich_postgres

# 2. Supprimer les données corrompues
rm -rf /Volumes/logousb/SSD/NAS-LOGO-VOLUME/immich-db

# 3. Lancer PostgreSQL seul
docker compose -f ~/immich/docker-compose.yml up -d database

# 4. Attendre que PostgreSQL soit prêt (5-10s)
sleep 10

# 5. Restaurer le dump
gunzip -c /Volumes/logousb/SSD/NAS-LOGO-VOLUME/backups/immich-db-20260503-123456.sql.gz | \
  docker exec -i immich_postgres psql --username=immich --dbname=immich

# 6. Redémarrer Immich complet
docker compose -f ~/immich/docker-compose.yml up -d

# 7. Vérifier les logs
docker logs immich_server | tail -50
```

---

### Scénario 3 : Récupération partielle (1 photo, 1 document)

La restauration complète est trop coûteuse. Récupérer juste quelques fichiers :

```bash
# 1. Lister les backups Hetzner
nas-logo-restore.sh --list

# 2. Monter la version voulue localement (rclone mount)
mkdir -p /tmp/nas-restore
rclone mount hetzner-crypt:versions/20260501/ssd /tmp/nas-restore &

# 3. Copier les fichiers voulus
cp /tmp/nas-restore/immich/library/photos/monPhoto.jpg /Volumes/logousb/SSD/...

# 4. Démonter
fusermount -u /tmp/nas-restore 2>/dev/null || diskutil eject /tmp/nas-restore
```

---

## Stockage des Backups

### Local (SSD)
```
/Volumes/logousb/SSD/NAS-LOGO-VOLUME/backups/

Rétention : 7 jours
Fichiers :
  - immich-db-*.sql.gz         (dumps quotidiens)
  - paperless-db-*.sql.gz      (dumps quotidiens)
  - n8n-db-*.sql.gz            (dumps quotidiens)
  - *-backup-cible-*.sql.gz    (sauvegardes ciblées manuelles)
```

**Nettoyage automatique** : Les dumps > 7 jours sont supprimés au prochain dump quotidien.

### Hetzner Storage Box (88.99.49.100)
```
Authentification : SSH + rclone (chiffré AES256)
Organisme : Hetzner GmbH (DE)
Rétention : Minimum 7 versions datées pour SSD ET HDD

Structure :
  current/
    ├── ssd/                   (dernière sauvegarde SSD)
    │   ├── immich-db/
    │   ├── n8n/
    │   ├── backups/
    │   └── ...
    └── hdd/                   (dernière sauvegarde HDD)
        ├── immich/
        ├── paperless/
        ├── personnes/
        └── files/

  versions/YYYYMMDD/
    ├── ssd/                   (archives SSD 7 jours minimum)
    └── hdd/                   (archives HDD 7 jours minimum)
```

**Nettoyage automatique** : Après 7 versions, les anciennes versions de SSD ET HDD sont purgées.

---

## Monitoring et Alertes

### Notifications ntfy (push + desktop)

Le système envoie des notifications quand :

| Événement | Priorité | Action |
|-----------|----------|--------|
| ✅ Backup OK | basse | Informationnel |
| ⚠️  Espace critique (< 5 Gb) | haute | Vérifier SSD |
| ❌ Dump échoué | urgente | Investiguer immédiatement |
| ❌ Restauration échouée | urgente | Investiguer immédiatement |
| ✓ Restore-test OK | basse | Dump valide |
| ✗ Restore-test échoué | haute | Dump corrompu |

### Vérification manuelle

```bash
# Voir les logs quotidiens
ls -lt ~/Library/Logs/nas-logo/ | head -10

# Taille actuelle des backups locaux
du -sh /Volumes/logousb/SSD/NAS-LOGO-VOLUME/backups/

# Espace libre SSD
df -h /Volumes/logousb/SSD/

# Vérifier la rétention Hetzner
rclone lsd hetzner-crypt:versions | sort -r | head -10
```

---

## Dépannage

### "Dump PostgreSQL trop petit (vide?)"
```
Cause : Conteneur Docker arrêté ou base vide
Solution :
  1. Vérifier que le conteneur est UP : docker ps | grep postgres
  2. Vérifier la connectivité : docker exec immich_postgres pg_isready
  3. Relancer le dump manuellement : /usr/local/bin/nas-logo-dump-db.sh
```

### "Espace critique — sync Hetzner ignorée"
```
Cause : SSD < 5 Gb libres
Solution :
  1. Vérifier l'espace : df -h /Volumes/logousb/SSD/
  2. Identifier ce qui prend la place : du -sh /Volumes/logousb/SSD/*/ | sort -h
  3. Nettoyer :
     - Vider imports/ si import fini : rm -rf /Volumes/logousb/SSD/NAS-LOGO-VOLUME/imports/
     - Vider immich/upload/ : rm -rf /Volumes/logousb/SSD/NAS-LOGO-VOLUME/immich/upload/
     - Purger les anciens dumps : find /Volumes/logousb/SSD/NAS-LOGO-VOLUME/backups -name "*.sql.gz" -mtime +3 -delete
```

### "Dump corrompu : gzip -t échoué"
```
Cause : Dump incomplet (processus interrompu, disque plein)
Solution :
  1. Vérifier l'intégrité : gzip -t /chemin/dump.sql.gz
  2. Supprimer le dump corrompu : rm /chemin/dump.sql.gz
  3. Relancer le dump : /usr/local/bin/nas-logo-dump-db.sh
```

### "Restauration : conteneur PostgreSQL timeout"
```
Cause : PostgreSQL ne répond pas assez vite au démarrage
Solution :
  1. Augmenter le timeout : éditer restore.sh (ligne 121)
  2. Vérifier les ressources macOS : Activity Monitor
  3. Redémarrer Colima : colima restart
```

### "rclone : 'permission denied' sur Hetzner"
```
Cause : Clés rclone invalides ou expirées
Solution :
  1. Vérifier la config : cat ~/.config/rclone/rclone.conf
  2. Tester la connexion : rclone ls hetzner-crypt:current
  3. Si échouée : mise à jour via Ansible
     cd /Volumes/logousb/SSD/Projects/NAS-logo
     ansible-playbook -i inventory/hosts site.yml --tags sauvegarde
```

---

## Aide-mémoire

### Commandes les plus utiles

```bash
# Sauvegarde immédiate (après changement critique)
nas-logo-backup-cible.sh --service immich

# Vérifier que les dumps sont restaurables
nas-logo-restore-test.sh --service all

# Voir les sauvegardes disponibles
nas-logo-restore.sh --list

# Lire les logs de sauvegarde
tail -f ~/Library/Logs/nas-logo/backup-*.log

# Voir l'espace disque
df -h | grep -E "SSD|NAS-LOGO"
du -sh /Volumes/logousb/SSD/NAS-LOGO-VOLUME/*
```

### Variables Ansible (pour customisation)

| Variable | Par défaut | Signification |
|----------|-----------|---|
| `backup_local_keep` | 7 | Jours de rétention locale |
| `backup_daily_keep` | 7 | Minimum versions Hetzner |
| `backup_dir` | SSD/backups | Dossier dumps locaux |
| `ssd_mount_point` | `/Volumes/logousb/SSD/NAS-LOGO-VOLUME` | Chemin données SSD |
| `hdd_nas_volume` | SSD (fallback) | Chemin données HDD |

---

## FAQ

**Q: Combien de place prend une sauvegarde complète ?**
R: ~50 Gi sur SSD (DB + index meilisearch). Hetzner : stockage illimité (forfait) mais laisser marges.

**Q: Combien de temps dure le backup quotidien ?**
R: 10-15 minutes (dumps DB + sync rclone). Optimisé pour 2h30 du matin quand système peu utilisé.

**Q: Et si je veux restaurer une photo spécifique sans tout recréer ?**
R: Voir section "Restauration d'urgence (service cassé)" — monter Hetzner en rclone mount et copier.

**Q: Les photos HDD et fichiers Immich sont-elles sauvegardés ?**
R: Oui ! HDD complet est sauvegardé vers Hetzner quotidiennement (sauf thumbnails/encoded-video reconstruits). Cela inclut :
   - `immich/library/` (~400 Gi photos importées)
   - `immich/upload/` (uploads mobiles/web)
   - `personnes/*/files/` (documents personnels)
   - `paperless/` (documents OCRisés)
   - `files/` (fichiers généraux)

**Q: Qui a accès aux backups Hetzner ?**
R: Seulement via credentials rclone (chiffrement AES256). Pas d'accès SSH direct.

**Q: Quand est le meilleur moment pour faire une sauvegarde ciblée ?**
R: Avant : upgrade service | changement config critique | migration données. Attendre ~5 min après arrêt du service.

---

## Support

Pour problèmes de sauvegarde :
1. Vérifier les logs : `~/Library/Logs/nas-logo/`
2. Tester manuellement : `/usr/local/bin/nas-logo-backup-cible.sh`
3. Consulter le dépannage ci-dessus
4. Vérifier l'état du système : `make health`

**Dernière mise à jour** : 2026-05-03
