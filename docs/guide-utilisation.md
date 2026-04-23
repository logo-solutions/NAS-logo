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
6. [Sauvegardes — ce que tu dois savoir](#sauvegardes--ce-que-tu-dois-savoir)

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

## Sauvegardes — ce que tu dois savoir

### Ce qui est sauvegardé
- Toutes les photos Immich
- La base de données Immich (métadonnées, albums, partages)
- Tous les documents Paperless
- La base de données Paperless (index, tags, correspondants)

### Quand
- **Automatique** : chaque nuit à 03h00
- **Manuel** : possible à tout moment

### Où
- Hetzner Storage Box (Allemagne) — chiffré de bout en bout

### En cas de perte de données
Contacter Loïc — la restauration depuis Hetzner est possible mais manuelle.

---

## Raccourcis utiles

| Action | Raccourci Immich |
|--------|-----------------|
| Sélectionner plusieurs photos | Clic long sur une photo |
| Ajouter à un album | Sélectionner → icône album |
| Marquer comme favori | Cœur sur la photo |
| Voir les infos EXIF | `i` sur la photo |
| Plein écran | `f` |
