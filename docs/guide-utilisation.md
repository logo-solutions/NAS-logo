
# Guide d'utilisation — NAS-logo

> Immich · Paperless · Accès Tailscale  
> Pour les utilisateurs quotidiens du NAS familial

---

## Sommaire

1. [Connexion au NAS](#connexion-au-nas)
2. [Immich — Photos](#immich--photos)
3. [Paperless — Documents](#paperless--documents)
4. [Importer des photos](#importer-des-photos)
5. [Importer des documents](#importer-des-documents)
6. [Import en masse dans Paperless](#import-en-masse-dans-paperless)
7. [Import en masse dans Immich](#import-en-masse-dans-immich)
8. [Créer un nouvel accès utilisateur](#créer-un-nouvel-accès-utilisateur)
9. [Créer les comptes Immich et Paperless (admin)](#créer-les-comptes-immich-et-paperless-admin)
10. [Réinitialiser le mot de passe](#réinitialiser-le-mot-de-passe)
11. [Sauvegarder les bases de données](#sauvegarder-les-bases-de-données)
12. [Sauvegardes — ce que tu dois savoir](#sauvegardes--ce-que-tu-dois-savoir)
13. [Vérifier la sauvegarde sur Hetzner](#vérifier-la-sauvegarde-sur-hetzner)

---

## Connexion au NAS

Le NAS est **uniquement accessible via Tailscale** — pas depuis internet en direct.

### Prérequis
- Avoir Tailscale installé sur ton appareil (iPhone, Mac, PC)
- Être connecté au réseau Tailscale de la famille

### Adresse du serveur
```
100.113.214.55
```

---

## Immich — Photos

### Accéder à Immich

| Appareil | URL / App |
|----------|-----------|
| iPhone / Android | App **Immich** → serveur `http://100.113.214.55:2283` |
| Navigateur | http://100.113.214.55:2283 |

### Fonctionnalités principales

#### Parcourir les photos
- **Chronologie** : toutes les photos triées par date
- **Albums** : collections organisées (Famille, Vacances, etc.)
- **Carte** : photos géolocalisées sur une carte

#### Recherche
La recherche Immich est intelligente — tu peux chercher en langage naturel :
- `"plage"` → trouve toutes les photos de plage
- `"chien 2024"` → chiens en 2024
- `"anniversaire alban"` → anniversaires d'Alban

#### Albums partagés
| Album | Accès |
|-------|-------|
| Famille | loic + alban + ilan |
| Alban | loic + alban |
| Ilan | loic + ilan |

#### Télécharger des photos
- Sur une photo : bouton `...` → **Télécharger**
- Sur un album : `...` → **Télécharger l'album** (ZIP)

#### Partager une photo
- Sur une photo : bouton de partage → **Créer un lien de partage**
- Le lien est accessible même sans compte Immich (durée configurable)

### Sauvegarde automatique depuis iPhone
Dans l'app Immich → **Paramètres** → **Sauvegarde** :
- Activer la sauvegarde automatique
- Choisir les albums à sauvegarder
- La sauvegarde se déclenche en Wi-Fi (ou mobile selon config)

---

## Paperless — Documents

### Accéder à Paperless
- **URL :** http://100.113.214.55:8010
- **Login :** admin / *(demander le mot de passe à Loïc)*

### Fonctionnalités principales

#### Recherche de documents
La barre de recherche en haut de page. Paperless indexe le contenu complet des PDF (OCR).
- Cherche par mots dans le document, pas seulement dans le nom du fichier
- Exemples : `"impôts 2023"`, `"assurance voiture"`, `"EDF facture"`

#### Parcourir par tags
Les documents sont automatiquement tagués selon leur dossier d'origine.  
Menu **Tags** → sélectionner un tag pour filtrer.

#### Télécharger un document
Sur un document → bouton **Télécharger** (icône flèche bas).

#### Partager / Envoyer un document
Sur un document → `...` → **Partager** → copier le lien (valide 24h par défaut).

### Organisation des documents
```
Dossiers disponibles dans /consume :
├── administratif/
├── immo/
├── pro/
└── formation/
```

Les fichiers déposés dans ces dossiers sont automatiquement importés et tagués.

---

## Importer des photos

### Option 1 — App Immich (recommandé)
Sauvegarde automatique depuis l'app mobile.

### Option 2 — Import manuel depuis le SSD
Déposer les fichiers dans :
```
/Volumes/logousb/SSD/NAS-LOGO-VOLUME/imports/
```
Puis déclencher l'import depuis l'interface Immich :  
**Administration** → **Bibliothèques externes** → **Analyser**.

### Option 3 — Import Google Takeout
Pour importer un export Google Photos :

1. Télécharger l'export Takeout depuis [takeout.google.com](https://takeout.google.com)
2. Décompresser dans `/Volumes/logousb/SSD/NAS-LOGO-VOLUME/imports/Takeout/`
3. Lancer le script d'import :
   ```bash
   ssh logo@100.113.214.55 'nohup ~/nas-logo-import-takeout.sh &'
   ```
4. Suivre la progression :
   ```bash
   ssh logo@100.113.214.55 'tail -f /tmp/nas-logo-import-takeout.log'
   ```

L'import préserve les dates EXIF et crée automatiquement les albums.

---

## Importer des documents

### Option 1 — Via l'interface Paperless
**Paperless** → bouton **+** (en haut à droite) → **Importer un document** → glisser-déposer le PDF.

### Option 2 — Dossier de consommation
Déposer le fichier directement dans :
```
/Volumes/logousb/SSD/NAS-LOGO-VOLUME/paperless/consume/
```
Paperless le détecte automatiquement, lance l'OCR et l'indexe.

### Option 3 — Email (automatique)
Les pièces jointes Gmail (PDF, docs) sont automatiquement importées dans Paperless chaque nuit.  
Pour déclencher manuellement : `ssh logo@100.113.214.55 'nas-logo-gmail-fetch.py'`

---

## Import en masse dans Paperless

### Méthode 1 — Dossier de consommation (recommandé)

Le dossier `/consume` est surveillé en continu. Tous les fichiers qui y sont placés sont traités automatiquement.

1. Préparer les fichiers PDF/image à importer
2. Placer les fichiers dans :
   ```
   /Volumes/logousb/SSD/NAS-LOGO-VOLUME/paperless/consume/
   ```
3. Paperless détecte automatiquement les fichiers et lance :
   - L'OCR (reconnaissance de texte)
   - L'indexation (recherche par mots)
   - Le tagging automatique (basé sur le dossier d'origine)

### Méthode 2 — Interface Web avec drag-and-drop

1. Aller sur http://100.113.214.55:8010
2. Cliquer sur le bouton **+** (haut à droite)
3. Sélectionner **Importer un document**
4. Glisser-déposer les fichiers ou parcourir

### Méthode 3 — Depuis Gmail (automatique)

Les pièces jointes PDF/documents de Gmail sont importées automatiquement chaque nuit.

Pour forcer l'import immédiat :
```bash
ssh logo@100.113.214.55 'nas-logo-gmail-fetch.py'
```

### Organisation des dossiers

Créer des sous-dossiers dans `/consume` pour que Paperless les utilise comme tags :
```
/consume/
├── administratif/     → Les docs reçoivent le tag "administratif"
├── immo/
├── pro/
└── formation/
```

---

## Import en masse dans Immich

### Méthode 1 — Dossier d'import externe (recommandé)

Placer les photos dans le dossier d'import, puis les faire analyser par Immich.

1. Préparer les fichiers image (JPG, PNG, RAW, etc.)
2. Placer les fichiers dans :
   ```
   /Volumes/logousb/SSD/NAS-LOGO-VOLUME/imports/
   ```
3. Aller dans **Immich** → **Paramètres** (engrenage en bas à gauche)
4. Aller dans l'onglet **Administrateur** → **Bibliothèques externes**
5. Cliquer sur **Analyser** pour scanner le dossier
6. Attendre l'import (la progression s'affiche à l'écran)

**Avantages :**
- Import très rapide (les fichiers ne sont pas copiés, juste scannés)
- Les dates EXIF sont préservées
- Supporte tous les formats de photo

### Méthode 2 — Google Takeout (import complet de Google Photos)

Pour importer un export complet de Google Photos :

1. Télécharger l'export depuis [takeout.google.com](https://takeout.google.com)
   - Sélectionner **Google Photos**
   - Format ZIP (télécharger par parties si > 2 GB)

2. Décompresser sur le SSD :
   ```bash
   cd /Volumes/logousb/SSD/NAS-LOGO-VOLUME/imports/
   # Décompresser tous les fichiers ZIP Takeout ici
   unzip -q "Takeout*.zip"
   ```

3. Lancer le script d'import automatique :
   ```bash
   ssh logo@100.113.214.55 'nohup ~/nas-logo-import-takeout.sh > /tmp/nas-logo-import-takeout.log 2>&1 &'
   ```

4. Suivre la progression en direct :
   ```bash
   ssh logo@100.113.214.55 'tail -f /tmp/nas-logo-import-takeout.log'
   ```

**Le script :**
- Préserve les dates originales des photos
- Crée les albums automatiquement (à partir des dossiers Takeout)
- Ajoute les métadonnées (géolocalisation, description)
- Déduplique les doublons automatiquement

### Méthode 3 — Interface Web avec drag-and-drop

Pour quelques fichiers :

1. Accéder à http://100.113.214.55:2283
2. Cliquer sur le bouton **+** (haut à droite)
3. Sélectionner **Uploader des photos**
4. Glisser-déposer les fichiers ou parcourir

**Limite :** conseillé pour < 100 fichiers (sinon c'est lent)

### Méthode 4 — App mobile Immich (sauvegarde continue)

L'app Immich sur iPhone/Android peut sauvegarder automatiquement les photos du téléphone.

1. Installer l'app Immich depuis l'App Store ou Google Play
2. Ajouter le serveur : `http://100.113.214.55:2283`
3. Rentrer identifiant/mot de passe
4. Aller dans **Paramètres** → **Sauvegarde**
5. Activer **Sauvegarde automatique**
6. Choisir les albums à sauvegarder (Photos, Captures, etc.)
7. Les photos se téléversent automatiquement en Wi-Fi

### Conseils pour l'import en masse

| Situation | Méthode | Temps estimé |
|-----------|---------|--------------|
| Photos depuis une clé USB | Dossier d'import externe | 5-30 min |
| Export complet Google Photos | Google Takeout | 30 min - 2h |
| Quelques photos ponctuelles | Interface Web | 5-10 min |
| Sauvegarder le téléphone | App mobile | Continu |

### Problèmes courants lors de l'import

**Les photos ne s'importent pas :**
- Vérifier le format (JPG, PNG, RAW supportés)
- Vérifier les permissions du dossier `/imports/`
- Relancer "Analyser" manuellement

**Les dates sont mauvaises :**
- Immich utilise la date EXIF de la photo
- Si absent, utilise la date du fichier (modifié)
- Vérifier les métadonnées : `exiftool photo.jpg`

**Impossible d'importer depuis le navigateur :**
- Vérifier la connexion à 100.113.214.55
- Vérifier que le port 2283 est accessible via Tailscale
- Réessayer depuis une autre application (navigateur, app mobile)

---

## Créer un nouvel accès utilisateur

### Créer un nouvel utilisateur dans Immich

1. Accéder à http://100.113.214.55:2283
2. Cliquer sur **Paramètres** (engrenage en bas à gauche)
3. Aller dans l'onglet **Administrateur** → **Utilisateurs**
4. Cliquer sur le bouton **+** (créer un nouvel utilisateur)
5. Remplir le formulaire :
   - **Email** : adresse email unique (ex: `loic-immo@nas.local`)
   - **Prénom** : nom d'affichage (ex: `Loïc Immo`)
   - **Mot de passe** : générer un mot de passe sécurisé
6. Cliquer **Créer utilisateur**

### Ajouter des albums au nouvel utilisateur dans Immich

**Partager des albums existants :**

1. Aller dans l'album que tu veux partager
2. Cliquer sur **...** (menu) → **Modifier les paramètres d'accès**
3. Cliquer sur **+ Ajouter un utilisateur**
4. Sélectionner l'utilisateur (ex: `Loïc Immo`)
5. Choisir le niveau d'accès :
   - **Visualisation** : voir l'album uniquement
   - **Édition** : voir + modifier les photos/descriptions
6. Cliquer **Ajouter**

**Créer un album pour ce nouvel utilisateur :**

1. En tant qu'admin, créer un nouvel album vide
2. Partager cet album avec le nouvel utilisateur (voir ci-dessus)
3. Le nouvel utilisateur peut y ajouter ses propres photos

### Importer des photos avec un nouvel accès dans Immich

Une fois créé, le nouvel utilisateur peut :

1. **Depuis l'app mobile :**
   - Installer Immich (App Store ou Google Play)
   - Ajouter serveur : `http://100.113.214.55:2283`
   - Rentrer email et mot de passe du nouvel accès
   - Activer la sauvegarde automatique

2. **Depuis l'interface Web :**
   - Accéder à http://100.113.214.55:2283
   - Se connecter avec le nouvel accès
   - Cliquer **+** → **Uploader des photos**
   - Glisser-déposer les fichiers

3. **Depuis le dossier d'import externe :**
   - L'admin place les fichiers dans `/imports/`
   - Lance "Analyser" → les photos apparaissent dans l'album partagé avec le nouvel utilisateur

### Créer un nouvel utilisateur dans Paperless

1. Accéder à http://100.113.214.55:8010
2. **En tant qu'admin** (admin/mot-de-passe) → **Paramètres** (engrenage) → **Utilisateurs**
3. Cliquer sur **+ Ajouter un utilisateur**
4. Remplir le formulaire :
   - **Nom d'utilisateur** : unique (ex: `loic-immo`)
   - **Email** : (ex: `loic-immo@nas.local`)
   - **Mot de passe** : générer un mot de passe sécurisé
   - **Permissions** : cocher "Peut ajouter des documents" si tu veux qu'il importe
5. Cliquer **Enregistrer**

### Importer des documents avec un nouvel accès dans Paperless

Une fois créé, le nouvel utilisateur peut :

1. **Depuis l'interface Web :**
   - Accéder à http://100.113.214.55:8010
   - Se connecter avec le nouvel accès
   - Cliquer **+** → **Importer un document**
   - Glisser-déposer les fichiers PDF

2. **Depuis le dossier de consommation :**
   - L'admin place les fichiers dans `/paperless/consume/` (ou sous-dossier)
   - Paperless les indexe automatiquement
   - Les documents appartiennent à l'utilisateur propriétaire du dossier

3. **Via Gmail (si configuré) :**
   - Les pièces jointes Gmail sont importées automatiquement
   - Elles apparaissent dans le compte admin (à rediviser si besoin)

### Gérer les permissions des documents dans Paperless

Paperless ne permet pas de partager des documents individuellement. Les solutions :

**Option 1 — Tags publics :**
- Créer un tag public (ex: `Immobilier`)
- L'utilisateur filtre par tags pour voir ses documents

**Option 2 — Utilisateurs séparés :**
- Chaque utilisateur a ses propres documents
- Pas de partage possible

**Option 3 — Dossiers de consommation séparés :**
- Créer des dossiers avec des permissions spécifiques
- L'admin place les docs → Paperless les attribue à l'utilisateur

### Résumé — Créer un accès complet (ex: `loic-immo`)

| Service | Action |
|---------|--------|
| **Immich** | Paramètres → Administrateur → Utilisateurs → **+ Ajouter** |
| **Immich Albums** | Partager les albums existants avec le nouvel utilisateur |
| **Paperless** | Paramètres → Utilisateurs → **+ Ajouter** |
| **Permissions** | Cocher "Peut ajouter des documents" pour Paperless |
| **Accès** | Email/User + Mot de passe (à communiquer en sécurisé) |

---

## Créer les comptes Immich et Paperless (admin)

Cette section s'adresse à **Loïc** (administrateur du NAS) pour créer automatiquement tous les comptes famille via Ansible.

### Comptes disponibles

| Utilisateur | Immich Email | Paperless Username | Usage |
|-------------|--------------|-------------------|-------|
| **Loïc** | loic-perso@nas.local | loic-perso | Photos/docs personnels Loïc |
| | loic-immo@nas.local | loic-immo | Documents immobilier |
| | loic-pro@nas.local | loic-pro | Documents professionnels |
| **Alban** | alban@nas.local | alban | Accès famille + perso |
| **Ilan** | ilan@nas.local | ilan | Accès famille + perso |
| **Mahaut** | mahaut@nas.local | mahaut | Accès famille + perso |
| **Alice** | alice-perso@nas.local | alice-perso | Photos/docs personnels Alice |
| | alice-prof@nas.local | alice-prof | Documents professionnels Alice |

### Déploiement automatique avec Ansible

#### Étape 1 : Ajouter les mots de passe au vault

1. Ouvrir le vault chiffré :
   ```bash
   ansible-vault edit /Volumes/logousb/SSD/Projects/NAS-logo/inventory/group_vars/all/vault.yml --vault-password-file ~/.nas-logo-vault-pass
   ```

2. Ajouter les mots de passe à la fin du fichier (copier depuis `/Volumes/logousb/SSD/Projects/NAS-logo/docs/VAULT-PASSWORDS.md`) :

   **Immich passwords :**
   ```yaml
   vault_immich_loic_perso_password: ikgKokgVuxIVLiRp7GE91g
   vault_immich_loic_immo_password: WzyqwhZZAl60h8ZiG-j2xw
   vault_immich_loic_pro_password: aMTBaWVrkvebpqbNjPSiHQ
   vault_immich_alban_password: qRBm5SKChIMiRfqRzG-DQw
   vault_immich_ilan_password: S-Tm4HNGL5VQ3oV4N_jJrQ
   vault_immich_mahaut_password: 6g5EYOSAd1pVnJgqdFqWzQ
   vault_immich_alice_perso_password: 82tuPCniBYBS6grMgyQo3w
   vault_immich_alice_prof_password: 5A2mZbc8Sg_nFg8dxtZ8iQ
   ```

   **Paperless passwords :**
   ```yaml
   vault_paperless_loic_perso_password: pCY2l6nEyO4O1UdOyJIwEw
   vault_paperless_loic_immo_password: MDckhI5VJNpIwxzozTKCEg
   vault_paperless_loic_pro_password: aRZnp_t_PPcE3HnfGBJj_w
   vault_paperless_alban_password: cjKN55ds0OL8xHCO38aczA
   vault_paperless_ilan_password: I9DLfjWhMZM3aVY38doWrA
   vault_paperless_mahaut_password: rqKQP9PfbQ8A9fZGxBTpCQ
   vault_paperless_alice_perso_password: cvTzufAVfjVA2zK_FVPERg
   vault_paperless_alice_prof_password: D-Lqcdr3LP1Mkuf8fclj1A
   ```

3. Sauvegarder et fermer (`:wq` en vim)

#### Étape 2 : Déployer les comptes

Exécuter le playbook Ansible pour créer tous les comptes :

```bash
cd /Volumes/logousb/SSD/Projects/NAS-logo

# Créer les comptes Immich et Paperless
ansible-playbook site.yml --vault-password-file ~/.nas-logo-vault-pass --tags immich,paperless
```

**Durée estimée :** 2-3 minutes

**Résultat :**
- ✅ 8 comptes Immich créés
- ✅ 8 comptes Paperless créés
- ✅ 8 dossiers de consommation mappés `/consume/loic-perso/`, `/consume/loic-immo/`, etc.
- ✅ Album "Famille" créé et partagé entre tous les utilisateurs

#### Étape 3 : Vérifier la création des comptes

**Pour Immich :**
```bash
# Se connecter au serveur
ssh logo@100.113.214.55

# Vérifier les utilisateurs Immich via l'API
curl -H "x-api-key: $(cat ~/.nas-logo-immich-api-key)" \
  http://localhost:2283/api/admin/users | jq '.[] | {email: .email, name: .name}'
```

**Pour Paperless :**
```bash
# Vérifier les utilisateurs Paperless
curl -H "Authorization: Token $(cat ~/.nas-logo-paperless-api-token)" \
  http://localhost:8010/api/users/ | jq '.[] | {username: .username, is_staff: .is_staff}'
```

#### Étape 4 : Tester les accès

1. **Depuis le navigateur :**
   - Immich : http://100.113.214.55:2283 → Login avec `loic-perso@nas.local` / mot de passe
   - Paperless : http://100.113.214.55:8010 → Login avec `loic-perso` / mot de passe

2. **Depuis l'app mobile Immich :**
   - Ajouter serveur : `http://100.113.214.55:2283`
   - Email : `alban@nas.local`
   - Mot de passe : *(celui du vault)*
   - Activer la sauvegarde automatique

3. **Tester l'isolation Paperless :**
   - Placer un PDF dans `/Volumes/logousb/SSD/NAS-LOGO-VOLUME/paperless/consume/loic-perso/`
   - Attendre 5 secondes → le document apparaît uniquement dans le compte `loic-perso`
   - Placer un PDF dans `/consume/famille/` → visible par tous

### Supprimer ou recréer un compte (si nécessaire)

Pour recréer tous les comptes (déjà créés seront ignorés) :
```bash
ansible-playbook site.yml --vault-password-file ~/.nas-logo-vault-pass --tags immich,paperless
```

Pour supprimer manuellement un compte Immich :
```bash
ssh logo@100.113.214.55

# Lister les users
docker exec immich-server npm run cli:admin:list-users

# Supprimer par email
docker exec immich-server npm run cli:admin:delete-user -- --email alban@nas.local
```

Pour supprimer un compte Paperless :
```bash
ssh logo@100.113.214.55

# Via l'interface web ou l'API
curl -X DELETE \
  -H "Authorization: Token $(cat ~/.nas-logo-paperless-api-token)" \
  http://localhost:8010/api/users/USER_ID/
```

---

## Réinitialiser le mot de passe

### Immich

1. Accéder à l'interface : http://100.113.214.55:2283
2. Cliquer sur le menu **Paramètres** (en bas à gauche)
3. Aller dans **Compte** → **Changer le mot de passe**
4. Entrer l'ancien mot de passe, puis le nouveau (2x)
5. Cliquer **Enregistrer**

### Paperless

1. Accéder à l'interface : http://100.113.214.55:8010
2. Cliquer sur le profil utilisateur (en haut à droite) → **Changer le mot de passe**
3. Entrer l'ancien mot de passe, puis le nouveau (2x)
4. Cliquer **Enregistrer**

### Accès en SSH (administrateur)

Si tu oublies ton mot de passe :
```bash
ssh logo@100.113.214.55
# Une fois connecté au NAS :

# Pour Immich
docker exec immich-server npm run cli:admin-password -- --password NEW_PASSWORD

# Pour Paperless
docker exec paperless python manage.py changepassword admin
```

---

## Sauvegarder les bases de données

### Sauvegarde manuelle de Immich

```bash
ssh logo@100.113.214.55

# Créer une sauvegarde
docker exec immich-server npm run cli:db:backup -- --backup-dir=/backups/immich

# Vérifier les sauvegardes existantes
ls -lh /backups/immich/
```

### Sauvegarde manuelle de Paperless

```bash
ssh logo@100.113.214.55

# Créer une sauvegarde de la base de données
docker exec paperless python manage.py dbbackup --output-filename=paperless_backup.sql

# Créer une sauvegarde des fichiers (documents)
docker exec paperless python manage.py filedump --output-dir=/backups/paperless/

# Vérifier
ls -lh /backups/paperless/
```

### Sauvegarde automatique (programmée)

Les sauvegardes tournent automatiquement chaque nuit via un script cron.

Les sauvegardes sont stockées localement dans `/backups/` puis envoyées vers Hetzner.

---

## Sauvegardes — ce que tu dois savoir

### Ce qui est sauvegardé
- **Photos Immich** : tous les fichiers image stockés dans Immich
- **Base de données Immich** : métadonnées, albums, partages, favoris, géolocalisation
- **Documents Paperless** : tous les PDF et images importés
- **Base de données Paperless** : index de recherche (OCR), tags, correspondants, historique
- **Configuration des services** : paramètres de tous les services (Mail, Whisper, etc.)

### Quand
- **Automatique** : chaque nuit à 03h00 (exécution d'un script cron)
- **Manuel** : possible à tout moment en SSH

### Où
- **Stockage local** : `/backups/` sur le NAS (disque dédié)
- **Stockage distant** : Hetzner Storage Box (Allemagne) — chiffré AES256
- **Redondance** : les backups sont aussi synchronisés vers 2 disques externes USB

### Architecture de sauvegarde

```
NAS → /backups/ (stockage local) → Hetzner (chiffré) + DD USB externes
```

### En cas de perte de données

**Petit problème (fichier supprimé) :**
Contacter Loïc pour restaurer depuis Hetzner (quelques fichiers).

**Problème grave (disque mort) :**
- Restauration automatique possible depuis Hetzner ou les DD USB externes
- Contacter Loïc pour les étapes de récupération complète

**Important :** Les sauvegardes sont chiffrées. Seul Loïc a les clés de déchiffrement.

---

## Vérifier la sauvegarde sur Hetzner

### Prérequis
- Avoir accès SSH au NAS (login: logo)
- Connaître le mot de passe Hetzner Storage Box

### Vérifier l'état de la dernière sauvegarde

```bash
ssh logo@100.113.214.55

# Voir le journal de sauvegarde
tail -50 /var/log/nas-logo-backup.log

# Voir la date de la dernière sauvegarde réussie
grep "Backup completed" /var/log/nas-logo-backup.log | tail -1

# Voir l'espace utilisé sur Hetzner
du -sh /mnt/hetzner-backup/
```

### Vérifier les fichiers sauvegardés sur Hetzner

```bash
ssh logo@100.113.214.55

# Lister les répertoires de sauvegarde
ls -lh /mnt/hetzner-backup/

# Vérifier les photos Immich
ls -lh /mnt/hetzner-backup/immich/

# Vérifier les documents Paperless
ls -lh /mnt/hetzner-backup/paperless/

# Vérifier les configurations
ls -lh /mnt/hetzner-backup/config/
```

### Taille des sauvegardes

```bash
ssh logo@100.113.214.55

# Voir le détail de chaque sauvegarde
du -sh /mnt/hetzner-backup/*

# Espace total utilisé
du -sh /mnt/hetzner-backup/
```

### Restaurer une sauvegarde (administrateur)

**Attention :** cette opération est réservée à Loïc.

Pour restaurer un fichier spécifique depuis Hetzner :

```bash
ssh logo@100.113.214.55

# Trouver le fichier à restaurer
find /mnt/hetzner-backup/ -name "*.sql" -o -name "*.pdf"

# Copier depuis la sauvegarde Hetzner vers le NAS
cp /mnt/hetzner-backup/immich/database.sql /backups/restore/
```

### Planification des sauvegardes

| Jour | Heure | Service | Durée estimée |
|------|-------|---------|---------------|
| Lun-Dim | 03h00 | Toutes les bases | ~30 min |
| Jeu | 21h00 | Photos Immich (complet) | ~1h |
| Sam | 21h00 | Documents Paperless (complet) | ~45 min |

---

## Raccourcis utiles

| Action | Raccourci Immich |
|--------|-----------------|
| Sélectionner plusieurs photos | Clic long sur une photo |
| Ajouter à un album | Sélectionner → icône album |
| Marquer comme favori | Cœur sur la photo |
| Voir les infos EXIF | `i` sur la photo |
| Plein écran | `f` |




## vault
  ansible-vault edit /Volumes/logousb/SSD/Projects/NAS-logo/inventory/group_vars/all/vault.yml --vault-password-file ~/.nas-logo-vault-pass