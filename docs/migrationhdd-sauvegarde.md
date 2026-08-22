# Plan — Migration disques + intégration DS124 (Stratégie backup C)

## Contexte

Objectif : mettre en place une stratégie de backup 3-2-1 locale (Stratégie C, validée) avec 3 disques :
- **Maître** (données de production, toujours branché)
- **Réplique quotidienne** (toujours branché, snapshots Btrfs)
- **Archive rotation off-site** (débranché ~15j/mois, stocké ailleurs physiquement)

**Découverte critique en cours de planification** : l'état réel des disques ne correspond pas à l'hypothèse de départ.

```
NAS-LOGO-DATA (5,5 To total) : 3,8 To utilisés (70%) — contient les VRAIES données
                                 de production (Immich uploads, Paperless files,
                                 mail archives) lues/écrites en direct par les
                                 containers Docker via virtiofs
Expansion12   (11 To total)  : 9,1 To utilisés (84%) — rempli de vieux backups
                                 non nettoyés, dont AU MOINS 2 dossiers
                                 immich-backup-complete-20260703-* redondants
                                 (créés le même jour à 20 min d'écart)
DS124 (8 To)                  : neuf, jamais branché
```

Ni NAS-LOGO-DATA (trop petit, contient des données actives) ni Expansion12 (déjà
plein de vieilleries) ne peuvent directement jouer les rôles prévus. **Une
migration en plusieurs étapes est nécessaire avant que la stratégie C ne soit
opérationnelle.**

## Architecture cible confirmée (après migration)

| Rôle | Disque | Contenu |
|------|--------|---------|
| **Maître** (production) | Expansion12 (12 To) | Données actives Immich/Paperless/mail, toujours branché |
| **Réplique quotidienne** | DS124 (8 To) | Sync quotidien du maître, snapshots Btrfs |
| **Archive rotation off-site** | NAS-LOGO-DATA (6 To) | Vieux backups Expansion12 nettoyés, débranché ~15j/mois |

## Préparation disques — Reformatage + Déboulonnage

### Format final des disques

| Disque | Format | Raison |
|--------|--------|--------|
| **6 TB** (NAS-LOGO-DATA) | APFS | Archive off-site, léger versioning |
| **12 TB** (Expansion12) | **HFS+ Journalisé** | Maître production 24/7, stabilité maximale |
| **8 TB** (DS124 Synology) | BTRFS | Format natif NAS, snapshots quotidiens |

### Reformatage 12 TB → HFS+ Journalisé

**Avant Étape 0**, reformater Expansion12:

```bash
# 1. Déboulonner proprement (voir section ci-dessous)
diskutil unmountDisk /dev/disk5

# 2. Reformater
diskutil secureErase 0 HFS+ "Expansion12" /dev/disk5

# 3. Remounter
diskutil mount /dev/disk5s2
```

### Déboulonnage — Identifier et nettoyer les doublons

**Trouver les fichiers/répertoires dupliqués avant migration (sinon on copie la poubelle)**

#### Pour 12 TB (Expansion12) — Trouver les doublons:

```bash
# 1. Répertoires dupliqués (même nom, même niveau)
find /Volumes/Expansion12 -maxdepth 2 -type d -name "*immich*" -o -name "*backup*" | sort

# 2. Fichiers en double (même nom, même répertoire parent)
find /Volumes/Expansion12 -type f -name "*complete*" | head -20

# 3. Chercher les patterns de doublons (ex: même fichier copié plusieurs fois)
find /Volumes/Expansion12 -type d -name "*-20260703*" 
# Résultat attendu: plusieurs immich-backup-complete-20260703-*

# 4. Taille totale des doublons identifiés
du -sh /Volumes/Expansion12/immich-backup-complete-20260703-*/
du -sh /Volumes/Expansion12/Backup/ /Volumes/Expansion12/backups/

# 5. Hash pour vrai doublons (fichiers identiques, noms différents)
find /Volumes/Expansion12 -type f -size +100M -exec md5 {} \; | sort | uniq -d
```

#### Pour 6 TB (NAS-LOGO-DATA) — Chercher les doublons:

```bash
# Même approche
find /Volumes/NAS-LOGO-DATA -type d -name "*backup*" -o -name "*tmp*" | head -20

find /Volumes/NAS-LOGO-DATA -type f -newer /Volumes/NAS-LOGO-DATA/journaux/PLAN-EXPANSION12* | wc -l
# Fichiers modifiés après la dernière sauvegarde = à vérifier

# Fichiers orphelins (> 1 an)
find /Volumes/NAS-LOGO-DATA -type f -mtime +365 -size +1G
```

#### Stratégie de nettoyage:

1. **Avant Étape 0** (Expansion12):
   - Identifier les répertoires `immich-backup-complete-20260703-*` en doublon
   - Garder le plus complet/récent
   - Supprimer les autres (`rm -rf`)
   - Vérifier l'espace libéré: `du -sh /Volumes/Expansion12`

2. **Avant Étape 1** (NAS-LOGO-DATA):
   - Lancer audit: `bash bin/audit-hdd.sh /Volumes/NAS-LOGO-DATA`
   - Identifier fichiers `*tmp*`, `*cache*`, `*old*`
   - Décider: garder ou supprimer avant copie vers DS124

3. **Lors Étape 2-3** (copie):
   - N'inclure que les données validées
   - Exclure patterns: `.DS_Store`, `.TemporaryItems`, `Thumbs.db`, `*.tmp`

#### Exemples de commandes find avec exclusions:

```bash
# Copie SANS les fichiers temporaires
rsync -avh --exclude=".DS_Store" --exclude="*.tmp" --exclude="*cache*" \
  /Volumes/Expansion12/ /Volumes/NAS-LOGO-DATA/

# Copie SANS les répertoires doublons
rsync -avh --exclude="immich-backup-complete-20260703-201-*" \
  /Volumes/Expansion12/ /Volumes/NAS-LOGO-DATA/

# Copie avec liste de fichiers valides seulement
find /Volumes/Expansion12 -type f ! -name ".*" ! -path "*backup*" ! -path "*tmp*" \
  -print0 | rsync -av --files-from=- --from0 /Volumes/Expansion12/ /Volumes/NAS-LOGO-DATA/
```

---

## Outil — Audit HDD (préalable à la migration)

Nouveau script `bin/audit-hdd.sh` (réutilisable, argument = point de montage) :

- **Usage** : `bash bin/audit-hdd.sh /Volumes/Expansion12`
- **Profondeur** : exactement 3 niveaux fixes (`path1/sous-path1/sous-sous-path1`),
  via `du -h --max-depth=3` (ou équivalent macOS : `find ... -maxdepth 3` +
  `du -sh` par entrée).
- **Format de sortie** : arborescence indentée façon `tree`, taille affichée à
  côté de chaque dossier (ex. `├── Backup/ (22G)`).
- **Nom du fichier** : `hdd<nomdumontage>` (ex. `hddExpansion12`,
  `hddNAS-LOGO-DATA`) — le nom du point de montage est extrait automatiquement
  de l'argument (`basename`).
- **Emplacement de sortie** : `/Volumes/NAS-LOGO-DATA/journaux/` (convention
  déjà en place dans le projet pour tous les logs/rapports, cf. `CLAUDE.md`
  section "Logging & Artifacts").
- **Attention** : `du` sur ces disques (11 To / 5,5 To) peut être lent — lancer
  en arrière-plan avec un timeout raisonnable plutôt qu'en bloquant, et éviter
  de relancer plusieurs scans simultanés sur le même disque (déjà rencontré
  pendant la planification : scans `du` tués car trop longs).

**À exécuter avant l'Étape 0** (Expansion12, pour cibler précisément quoi
nettoyer) **et avant l'Étape 1** (NAS-LOGO-DATA, pour vérification du contenu
qui sera copié vers DS124).

## Trajectoire de migration (one-time, ordonnée)

Chaque étape de suppression est un **checkpoint manuel avec confirmation
explicite** — pas de suppression automatique sans vérification préalable de
l'intégrité de la copie (conforme aux règles de sécurité du projet : jamais de
destructif sans confirmation).

**PRÉ-ÉTAPE — Reformater 12 TB en HFS+ Journalisé**
1. Déboulonner Expansion12: `diskutil unmountDisk /dev/disk5`
2. Reformater: `diskutil secureErase 0 HFS+ "Expansion12" /dev/disk5`
3. Remounter: `diskutil mount /dev/disk5s2`
4. Vérifier: `diskutil info /Volumes/Expansion12 | grep "File System"`

**Étape 0 — Nettoyer Expansion12 (avant tout transfert)**
1. Lancer `bash bin/audit-hdd.sh /Volumes/Expansion12` → génère
   `hddExpansion12` dans `/Volumes/NAS-LOGO-DATA/journaux/`, avec le détail des
   8 dossiers racine (`Backup/`, `backups/`, `sauvegarde-live-logo-projects/`,
   `SOURCES/`, `Seagate/`, et les 3 `immich-backup-complete-20260703-*`) sur 3
   niveaux de profondeur.
2. Identifier et supprimer les doublons évidents à partir de ce rapport (garder
   uniquement le run `immich-backup-complete-20260703-*` le plus
   récent/complet parmi les 3).
3. Objectif : faire tenir le contenu restant sous ~5 To (marge de sécurité sous
   les 5,5 To de capacité de NAS-LOGO-DATA qui servira de tampon à l'étape 4).

**Étape 1 — Copier NAS-LOGO-DATA (prod actuelle) → DS124 (staging temporaire)**
0. Lancer `bash bin/audit-hdd.sh /Volumes/NAS-LOGO-DATA` → génère
   `hddNAS-LOGO-DATA` dans `/Volumes/NAS-LOGO-DATA/journaux/`, pour référence
   avant transfert (vérification post-copie par comparaison).
- `rsync -avh --progress /Volumes/NAS-LOGO-DATA/ <mount DS124>/staging/`
- Vérifier l'intégrité (comparaison taille/nombre de fichiers, checksums sur un
  échantillon) avant de continuer.

**Étape 2 — Vider NAS-LOGO-DATA (une fois la copie vérifiée)**
- Confirmation explicite requise avant suppression.
- Arrêter proprement les containers qui écrivent dessus (Immich, Paperless)
  avant la bascule pour éviter toute écriture perdue pendant la copie finale.

**Étape 3 — Copier le contenu nettoyé d'Expansion12 → NAS-LOGO-DATA (tampon)**
- `rsync -avh --progress /Volumes/Expansion12/ /Volumes/NAS-LOGO-DATA/`
- Vérifier l'intégrité, puis vider Expansion12 (confirmation explicite requise).

**Étape 4 — Copier les données de prod depuis DS124 (staging) → Expansion12 (maître final)**
- `rsync -avh --progress <mount DS124>/staging/ /Volumes/Expansion12/`
- Vérifier l'intégrité.

**Étape 5 — Reconfigurer les chemins Ansible**
- `inventory/group_vars/all/vars.yml` : `hdd_mount_point` passe de
  `/Volumes/NAS-LOGO-DATA` à `/Volumes/Expansion12` (ou renommage/remount pour
  garder le nom logique stable — à trancher à l'exécution).
- Redéployer les rôles qui dépendent de `hdd_mount_point`/`hdd_nas_volume`
  (`immich`, `personnes`, `smb`, `mail`) : `ansible-playbook site.yml --tags
  immich,personnes,smb,mail`.
- Vérifier `make health` après bascule (Immich/Paperless doivent répondre
  normalement sur le nouveau volume).

**Étape 6 — Vider le staging DS124**
- Une fois Expansion12 confirmé opérationnel comme maître, supprimer
  `<mount DS124>/staging/` (confirmation explicite) pour libérer DS124 pour son
  rôle final de réplique quotidienne.

## Configuration Ansible pérenne (rôle `sauvegarde`)

Une fois la migration terminée, intégrer les flux réguliers dans le rôle
`roles/sauvegarde/` existant (pattern déjà en place : `backup.sh.j2` a une
étape 4b qui sync vers un disque local monté — on l'étend plutôt que la
dupliquer) :

1. **Secrets** (`inventory/group_vars/vault.yml`) : `vault_ds124_user`,
   `vault_ds124_password` (compte SMB dédié créé sur le DS124).

2. **Variables** (`inventory/group_vars/all/vars.yml`) :
   ```yaml
   ds124_host: "<IP LAN statique du DS124>"
   ds124_share: "nas-logo-backup"
   ds124_mount_point: "/Volumes/DS124-Backup"
   rotation_mount_point: "/Volumes/NAS-LOGO-DATA"  # archive off-site, ex-nom conservé
   ```

3. **Montage SMB persistant du DS124** (`roles/sauvegarde/tasks/main.yml`) :
   nouveau template `mount-ds124.sh.j2` + LaunchAgent
   `com.nas-logo.mount-ds124.plist.j2`, sur le modèle du LaunchDaemon Tailscale
   déjà en place (`roles/securite/`).

4. **Étendre `backup.sh.j2`** : ajouter une étape de sync quotidien
   Expansion12 → DS124 (réplique), réutilisant `$RCLONE`, `$LOG_FILE`,
   `notify()` déjà définis en tête du script — même pattern que l'étape 4b
   existante (copie locale non chiffrée, sans rotation).

5. **Rotation mensuelle NAS-LOGO-DATA** : documenter la procédure manuelle
   (débrancher/rebrancher le 1er du mois) + ajouter un check dans
   `healthcheck.yml` qui alerte si le disque de rotation attendu n'est pas
   monté (sur le modèle des checks Hetzner existants), sans bloquer le reste
   du healthcheck.

6. **Healthcheck** (`healthcheck.yml`) : vérifier montage DS124 + port SMB 445,
   sur le modèle des checks Hetzner déjà présents.

## Points d'attention

- **Aucune étape destructive (suppression sur NAS-LOGO-DATA, Expansion12, ou
  staging DS124) ne doit être exécutée sans vérification d'intégrité préalable
  et confirmation explicite au moment de l'exécution** — ce plan liste l'ordre
  et la logique, pas un script à lancer en aveugle.
- Arrêter les containers Docker (Immich, Paperless) pendant les étapes 2-4 pour
  éviter des écritures perdues pendant la bascule de `hdd_mount_point`.
- Le volume exact des dossiers Expansion12 (Étape 0) n'a pas pu être mesuré en
  totalité pendant la planification (scan `du` trop long sur ce disque de
  11 To) — à mesurer précisément avant de décider quoi supprimer.

## Vérification finale

- Après étape 5 : `make health` doit montrer Immich/Paperless opérationnels
  sur `/Volumes/Expansion12`.
- Après étape 6 : confirmer `mount | grep ds124` et que le sync quotidien
  écrit bien dans `{{ ds124_mount_point }}`.
- `make dryrun` avant tout déploiement Ansible réel.
- Tester un cycle de rotation complet (débrancher NAS-LOGO-DATA, vérifier
  l'alerte healthcheck, rebrancher, vérifier que l'alerte disparaît).
