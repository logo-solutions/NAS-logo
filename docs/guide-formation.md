# Guide de formation — NAS-logo

> Pour Alban et Ilan · Prise en main du NAS familial  
> Aucune connaissance technique requise

---

## C'est quoi le NAS familial ?

Le **NAS** (Network Attached Storage), c'est un petit ordinateur (Mac Mini) qui tourne chez nous et qui stocke :

- **Toutes les photos de famille** — organisées, consultables, searchables
- **Les documents importants** — factures, contrats, papiers admin

Il est accessible depuis n'importe où dans le monde, via une connexion sécurisée (VPN Tailscale).

---

## Étape 1 — Installer Tailscale

Tailscale est l'application qui te connecte au réseau privé familial.

### Sur iPhone
1. Télécharger **Tailscale** sur l'App Store
2. Se connecter avec le compte Google ou Email fourni par Loïc
3. Activer le VPN quand demandé
4. Tu es connecté quand l'icône Tailscale est verte

### Sur Mac
1. Télécharger **Tailscale** sur [tailscale.com](https://tailscale.com)
2. Se connecter avec le compte fourni
3. Cliquer sur l'icône dans la barre de menu → **Connect**

### Sur PC (Windows)
1. Télécharger Tailscale sur [tailscale.com/download](https://tailscale.com/download)
2. Installer et se connecter
3. Activer dans la barre des tâches

**Une fois connecté, le serveur est accessible à l'adresse `100.113.214.55`.**

---

## Étape 2 — Installer l'app Immich

Immich, c'est l'application pour regarder et gérer les photos.

### Sur iPhone
1. Télécharger **Immich** sur l'App Store
2. Ouvrir l'app → **Connexion**
3. Entrer l'URL du serveur : `http://100.113.214.55:2283`
4. Se connecter avec les identifiants fournis par Loïc

### Sur navigateur (Mac/PC)
Ouvrir : **http://100.113.214.55:2283**

---

## Étape 3 — Découvrir Immich

### L'écran principal

```
┌─────────────────────────────┐
│  🏠 Accueil    Photos récentes│
│  📅 Chronologie              │
│  🔍 Recherche                │
│  📁 Albums                   │
│  👤 Mon compte               │
└─────────────────────────────┘
```

### Regarder les photos
- **Chronologie** → toutes les photos triées par date
- **Albums** → collections organisées

### Rechercher une photo
Tape ce que tu cherches dans la barre de recherche :
- `"vacances Bretagne"` → photos de vacances en Bretagne
- `"anniversaire 2023"` → anniversaires de 2023
- `"neige"` → toutes les photos avec de la neige

La recherche est **intelligente** — elle reconnaît le contenu des photos, pas seulement les noms de fichiers.

### Albums partagés
Tu as accès à ces albums :

| Album | Contenu |
|-------|---------|
| **Famille** | Photos partagées par toute la famille |
| **Alban** *(ou Ilan)* | Tes photos personnelles partagées avec Loïc |

### Télécharger une photo
1. Ouvrir la photo
2. Appuyer sur `...` (3 points) en haut à droite
3. Choisir **Télécharger**

---

## Étape 4 — Activer la sauvegarde automatique

Pour que tes nouvelles photos iPhone soient automatiquement sauvegardées sur le NAS :

1. Dans l'app Immich → **Mon compte** (icône en bas à droite)
2. → **Paramètres** → **Sauvegarde automatique**
3. Activer le bouton
4. Recommandé : activer **"Wi-Fi uniquement"** pour économiser les données mobiles

**Une fois activé**, toutes tes nouvelles photos seront automatiquement envoyées sur le NAS la nuit.

---

## Étape 5 — Ajouter une photo à un album

1. Ouvrir une photo
2. Appuyer sur `...` → **Ajouter à un album**
3. Sélectionner l'album (ex : *Famille*)

Ou pour plusieurs photos :
1. Appuyer **longuement** sur une photo → mode sélection
2. Sélectionner d'autres photos
3. Appuyer sur l'icône album en haut → choisir l'album

---

## Questions fréquentes

**Est-ce que mes photos sont privées ?**  
Oui. Le serveur n'est accessible que via Tailscale — personne d'autre ne peut y accéder depuis internet.

**Est-ce que mes photos sont sauvegardées ?**  
Oui, chaque nuit automatiquement sur un serveur en Allemagne (chiffré).

**Et si je perds mon téléphone ?**  
Tes photos sont sur le NAS — elles ne sont pas perdues.

**L'app consomme beaucoup de batterie ?**  
Non. La sauvegarde se fait en arrière-plan, uniquement en Wi-Fi si tu le configures ainsi.

**Je ne vois pas les photos des autres ?**  
Les albums sont partagés séparément. Si tu ne vois pas un album, demande à Loïc de te l'ajouter.

**Tailscale me demande de me reconnecter ?**  
Ouvre l'app Tailscale, reconnecte-toi. Ça arrive rarement.

---

## En cas de problème

| Problème | Solution |
|----------|----------|
| L'app Immich ne se connecte pas | Vérifier que Tailscale est actif (icône verte) |
| Les photos ne se sauvegardent pas | Ouvrir Immich → Paramètres → Sauvegarde → forcer une synchro |
| Une photo a disparu | Demander à Loïc — elle est probablement dans la corbeille Immich |
| Le serveur ne répond pas | Contacter Loïc |

---

## Résumé en 1 minute

```
1. Tailscale actif (icône verte)
2. Ouvrir Immich → http://100.113.214.55:2283
3. Parcourir photos / Albums / Recherche
4. Activer la sauvegarde automatique dans les paramètres
```

C'est tout. Pour le reste, demande à Loïc.
