# Import Immich loic-perso — Guide complet

**Date création** : 2026-05-07
**Instance** : loic-perso (fresh start après incident 2026-05-06)
**Architecture** : HDD `/Volumes/NAS-LOGO-DATA/NAS-LOGO-VOLUME/`

---

## Architecture stockage

| Élément | Chemin |
|---------|--------|
| **SOURCE** (Takeouts) | `/Volumes/NAS-LOGO-DATA/NAS-LOGO-VOLUME/immich/upload/` |
| **CIBLE** (Assets stockés) | `/Volumes/NAS-LOGO-DATA/NAS-LOGO-VOLUME/personnes/loic-perso/immich/upload/` |
| **Vignettes** | `/Volumes/NAS-LOGO-DATA/NAS-LOGO-VOLUME/personnes/loic-perso/immich/thumbs/` |
| **Fichiers à importer** | 874 photos/vidéos (83,8k fichiers) |
| **Immich server** | `http://localhost:2283` |
| **User Immich** | loicgourmelon@gmail.com / "Loic Perso" (admin) |

**Note** : Structure standard Immich — les assets vont dans `upload/`, les vignettes dans `thumbs/`, etc.

---

## Config Ansible

**Fichier** : `inventory/group_vars/all/vars.yml` ligne 17

```yaml
immich_data_dir: "{{ hdd_mount_point }}/NAS-LOGO-VOLUME/personnes/loic-perso/immich"
```

**Résultat** : Immich stocke les photos dans `personnes/loic-perso/immich/library/`

---

## API Key

**Actuelle (2026-05-07)** : `dg46m83TgQBP4r8pxPloTnagaNUl2wWcgmNlB7Wk`

**Localisation vault** : `inventory/group_vars/all/vault.yml`
```yaml
vault_immich_api_key: "dg46m83TgQBP4r8pxPloTnagaNUl2wWcgmNlB7Wk"
```

**Pour obtenir une nouvelle API key** :
1. Accès Immich : http://100.113.214.55:2283 (ou localhost:2283 en local)
2. Paramètres → Compte → Clés d'API
3. Créer une nouvelle clé
4. Mettre à jour vault + commit

---

## Commandes immich-go

### Option 1 : Mode CLI sans UI (RECOMMANDÉ)

```bash
immich-go upload from-folder \
  --server http://localhost:2283 \
  --api-key dg46m83TgQBP4r8pxPloTnagaNUl2wWcgmNlB7Wk \
  --no-ui \
  /Volumes/NAS-LOGO-DATA/NAS-LOGO-VOLUME/immich/upload/
```

**Pourquoi** : Évite le panic tcell dans l'UI graphique

### Option 2 : Dry-run (test sans import)

```bash
immich-go upload from-folder \
  --server http://localhost:2283 \
  --api-key dg46m83TgQBP4r8pxPloTnagaNUl2wWcgmNlB7Wk \
  --dry-run \
  --no-ui \
  /Volumes/NAS-LOGO-DATA/NAS-LOGO-VOLUME/immich/upload/
```

**Affiche** : Ce qui serait importé sans le faire réellement

### Option 3 : Mode interactif avec UI (risqué)

```bash
immich-go upload from-folder \
  --server http://localhost:2283 \
  --api-key dg46m83TgQBP4r8pxPloTnagaNUl2wWcgmNlB7Wk \
  /Volumes/NAS-LOGO-DATA/NAS-LOGO-VOLUME/immich/upload/
```

**Attention** : Peut causer panic "close of nil channel" (tcell bug)

---

## Flags importants

| Flag | Défaut | Remarque |
|------|--------|----------|
| `--no-ui` | false | Désactiver l'UI graphique (évite panic tcell) |
| `--dry-run` | false | Test sans importer |
| `--recursive` | true | Scanner les sous-dossiers |
| `--concurrent-tasks` | 8 | Nombre de fichiers en parallèle |
| `--pause-immich-jobs` | true | Pause les jobs Immich pendant l'import |
| `--overwrite` | false | Ne pas re-importer les doublons |
| `--on-errors` | stop | Arrêter si erreur (`skip` pour continuer) |

---

## Étapes import (en local)

### 1. Vérifier la connexion Immich

```bash
curl -s http://localhost:2283/api/server/ping
```

**Réponse attendue** : `{"res":"pong"}`

### 2. Vérifier la source

```bash
find /Volumes/NAS-LOGO-DATA/NAS-LOGO-VOLUME/immich/upload -type f | wc -l
```

**Attendu** : ~52,5k fichiers

### 3. Lancer l'import (--dry-run d'abord)

```bash
# Test seulement
immich-go upload from-folder \
  --server http://localhost:2283 \
  --api-key dg46m83TgQBP4r8pxPloTnagaNUl2wWcgmNlB7Wk \
  --dry-run \
  --no-ui \
  /Volumes/NAS-LOGO-DATA/NAS-LOGO-VOLUME/immich/upload/

# Import réel
immich-go upload from-folder \
  --server http://localhost:2283 \
  --api-key dg46m83TgQBP4r8pxPloTnagaNUl2wWcgmNlB7Wk \
  --no-ui \
  /Volumes/NAS-LOGO-DATA/NAS-LOGO-VOLUME/immich/upload/
```

### 4. Vérifier l'import

```bash
# Compter les fichiers importés
find /Volumes/NAS-LOGO-DATA/NAS-LOGO-VOLUME/personnes/loic-perso/immich/library -type f | wc -l

# Vérifier la taille
du -sh /Volumes/NAS-LOGO-DATA/NAS-LOGO-VOLUME/personnes/loic-perso/immich/library

# Comparer source vs cible
echo "SOURCE:" && find /Volumes/NAS-LOGO-DATA/NAS-LOGO-VOLUME/immich/upload -type f | wc -l
echo "CIBLE:" && find /Volumes/NAS-LOGO-DATA/NAS-LOGO-VOLUME/personnes/loic-perso/immich/library -type f | wc -l
```

---

## Logs

**Log immich-go** : `~/Library/Caches/immich-go/immich-go_YYYY-MM-DD_HH-MM-SS.log`

**Vérifier les erreurs** :
```bash
tail -200 ~/Library/Caches/immich-go/immich-go_2026-05-07_*.log | grep -i "error\|failed\|panic"
```

---

## Session import (2026-05-07)

### Tentative 1 : Dry-run + Upload partiel (06:45–06:56)
- ✅ 355 fichiers uploadés avec succès
- ⚠️ 10 erreurs serveur
- 🔴 507 assets "pending" (coupure SSH)

### Tentative 2 : Config mount library/ (incomplet)
- 🔴 Immich crée `/upload/`, `/thumbs/` EN DEDANS de `/library/`
- Revenu à mount parent (structure standard)

### Tentative 3 : Import final (07:16–07:20)
- Process lancé à 07:16 avec concurrent-tasks=8
- ✅ 183 uploadés en 30 min (trop lent)
- Relancé à 07:20 avec concurrent-tasks=32 mais bug immich-go (blocage après flags)

### RÉSULTAT FINAL (2026-05-07)
- ✅ **823 assets importés** (94% du total)
- Stockés dans : `/Volumes/NAS-LOGO-DATA/NAS-LOGO-VOLUME/personnes/loic-perso/immich/upload/`
- Vignettes : 730 générées dans `thumbs/`
- Vidéos transcodées : 613 MB dans `encoded-video/`
- ⚠️ 51 assets manquants (5%) — immich-go a un bug (blocage après flags)

**Import réussi malgré les obstacles** — structure Immich standard respectée

---

## Problèmes rencontrés (2026-05-07)

### 1. Panic tcell avec UI graphique
**Symptôme** : `panic: close of nil channel` dans tscreen.go
**Solution** : Utiliser `--no-ui`

### 2. Immich-go bloqué après flags
**Symptôme** : Processus "st allé à 06:45:09 et rien après les flags
**Cause** : À investiguer (peut-être timeout réseau ou API)
**Solution** : Tuer le processus (`pkill -9 immich-go`) et relancer

### 3. Peu de fichiers importés
**Symptôme** : Seulement quelques fichiers copiés (6 fichiers, 24 Ko)
**Cause** : Panic ou blocage prématuré
**Solution** : Relancer avec `--no-ui` et monitoring actif

---

## Monitoring (en arrière-plan)

### Lancer l'import en background
```bash
immich-go upload from-folder \
  --server http://localhost:2283 \
  --api-key dg46m83TgQBP4r8pxPloTnagaNUl2wWcgmNlB7Wk \
  --no-ui \
  /Volumes/NAS-LOGO-DATA/NAS-LOGO-VOLUME/immich/upload/ 2>&1 | tee /tmp/immich-go-import.log &
```

### Monitorer la progression (autre terminal)
```bash
# Vérifier tous les N secondes
watch -n 10 'find /Volumes/NAS-LOGO-DATA/NAS-LOGO-VOLUME/personnes/loic-perso/immich/library -type f | wc -l'

# Ou
tail -f /tmp/immich-go-import.log | grep -E "uploaded|asset|error"
```

### Arrêter l'import
```bash
pkill -9 immich-go
```

---

## Checklist pré-import

- [ ] Immich loic-perso est running et répond à `/api/server/ping`
- [ ] API key `dg46m83TgQBP4r8pxPloTnagaNUl2wWcgmNlB7Wk` est valide
- [ ] SOURCE : `/Volumes/NAS-LOGO-DATA/NAS-LOGO-VOLUME/immich/upload/` existe et a 52,5k fichiers
- [ ] CIBLE : `/Volumes/NAS-LOGO-DATA/NAS-LOGO-VOLUME/personnes/loic-perso/immich/` existe (créé par Ansible)
- [ ] Immich jobs sont pausées (`--pause-immich-jobs=true` par défaut)
- [ ] Disque HDD a assez d'espace libre

---

## Après l'import

1. **Vérifier les comptes** : Immich UI → Paramètres → Voir les utilisateurs
2. **Relancer Immich** : S'assurer que les jobs sont relancés
   ```bash
   curl -X POST http://localhost:2283/api/admin/jobs/resume \
     -H "x-api-key: dg46m83TgQBP4r8pxPloTnagaNUl2wWcgmNlB7Wk"
   ```
3. **Créer les comptes supplémentaires** : alban, ilan, etc. (instances séparées à faire)
4. **Sauvegarder la BD** : 
   ```bash
   make backup
   ```

---

## Références

- **Ansible config** : `inventory/group_vars/all/vars.yml` ligne 17
- **Vault API key** : `inventory/group_vars/all/vault.yml`
- **Rôle Immich** : `roles/immich/`
- **Incident précédent** : docs/incident-immich-20260506.md
