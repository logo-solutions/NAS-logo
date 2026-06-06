# Plan de Sauvegarde Rsync — NAS-logo (2026-05-25)

## Contexte
Sauvegarde séquentielle des données critiques du NAS vers /Volumes/Expansion12 (DD 12To) suite au blocage du port SFTP Hetzner (depuis 2026-05-19). 
Stratégie : 3 phases rsync en chaîne + backup de la BD Immich.

---

## 🎯 OBJECTIF CONFIRMÉ : ENVOI SUR DD 12To
**Tout le contenu de :**
- ✅ `/Volumes/NAS-LOGO-DATA/AFAIRE+tard/` → En cours (Phase 2)
- ✅ `/Volumes/NAS-LOGO-DATA/_done/` → À venir (Phase 3, lancera automatiquement)

**Destination finale :**
- ✅ `/Volumes/Expansion12/sauvetmpo25mai/` (DD 12To)

**Statut :**
- Phase 2 (AFAIRE+tard) : 🔄 EN COURS — À VÉRIFIER L'AVANCEMENT RÉEL
- Phase 3 (_done) : ⏳ ATTENDRA Phase 2 (lancera automatiquement)

---

## ✅ FAIT (Complété)

### Phase 1 — SauvAvril2026 → Expansion12
**Statut** : ✅ TERMINÉ  
**Durée** : ~20-30 min (lancé à ~3:32, terminé à ~3:52)  
**Source** : `/Volumes/NAS-LOGO-DATA/AFAIRE+tard/SauvAvril2026/` (54 GB)  
**Destination** : `/Volumes/Expansion12/sauvetmpo25mai/`  
**Commande** :
```bash
rsync -avh --progress \
  /Volumes/NAS-LOGO-DATA/AFAIRE+tard/SauvAvril2026/ \
  /Volumes/Expansion12/sauvetmpo25mai/
```
**Résultat** : 54 GB copiés avec succès, tous fichiers transférés

---

### Backup Immich-db (Sécurisé — Arrêt + Rsync + Redémarrage)
**Statut** : ✅ TERMINÉ  
**Durée** : ~2 min downtime (arrêt 30 sec + rsync 90 sec + redémarrage 40 sec)  
**Procédure** :
```bash
# 1. Arrêt Immich
cd ~/immich && docker compose down

# 2. Copie BD (immobile)
rsync -avh /Volumes/logousb/SSD/NAS-LOGO-VOLUME/immich-db/ \
  /Volumes/Expansion12/backups/NAS/immich-db/

# 3. Redémarrage
cd ~/immich && docker compose up -d
```
**Source** : `/Volumes/logousb/SSD/NAS-LOGO-VOLUME/immich-db/` (2.3 GB)  
**Destination** : `/Volumes/Expansion12/backups/NAS/immich-db/` (3.4 GB)  
**Résultat** : ✅ BD sauvegardée en sécurité, Immich relancé et healthy  
**Vérification** : API répond normalement (`{"res":"pong"}`), tous les conteneurs UP et healthy

---

## 🔄 EN COURS (Actuellement en exécution)

### Phase 2 — AFAIRE+tard (restant) → DD 12To
**Statut** : 🔄 EN COURS ✅ CONFIRMÉ  
**Lancé** : Début de session (après Phase 1)  
**Source** : `/Volumes/NAS-LOGO-DATA/AFAIRE+tard/` (excluant SauvAvril2026)  
**Destination** : `/Volumes/Expansion12/sauvetmpo25mai/AFAIRE+tard/` **← DD 12To**  
**Commande** :
```bash
rsync -avh --progress --exclude='SauvAvril2026' \
  /Volumes/NAS-LOGO-DATA/AFAIRE+tard/ \
  /Volumes/Expansion12/sauvetmpo25mai/AFAIRE+tard/
```
**Progression** : À vérifier en temps réel

**Contrôle** :
```bash
# Suivi en temps réel
tail -f /Volumes/NAS-LOGO-DATA/journaux/rsync-chain.out

# Vérifier la taille actuelle
du -sh /Volumes/Expansion12/sauvetmpo25mai/AFAIRE+tard/

# PID du processus principal
ps aux | grep "rsync.*AFAIRE" | grep -v grep
```

---

## ⏳ AVENIR (À venir — Lancera automatiquement après Phase 2)

### Phase 3 — _done/ → DD 12To
**Statut** : ⏳ EN ATTENTE (lancera automatiquement après Phase 2) ✅ CONFIRMÉ  
**Source** : `/Volumes/NAS-LOGO-DATA/_done/`  
**Destination** : `/Volumes/Expansion12/sauvetmpo25mai/_done/` **← DD 12To**  
**Commande** :
```bash
rsync -avh --progress \
  /Volumes/NAS-LOGO-DATA/_done/ \
  /Volumes/Expansion12/sauvetmpo25mai/_done/
```
**Notes** : Lancée automatiquement par le script `/tmp/rsync-chain.sh` une fois Phase 2 terminée. ✅ CONFIRMÉ - _done sera copié sur le 12To après AFAIRE+tard.

---

## 📊 Données Critiques (À sauvegarder indépendamment)

### A. /Volumes/NAS-LOGO-DATA/NAS-LOGO-VOLUME/personnes/ — CRITIQUE
**Statut** : ⏳ PLANIFIÉ  
**Raison** : Contient les assets Immich + documents Paperless (UPLOAD_LOCATION + external library)  
**Taille réelle** : **2.2 TB**  
**Contenu** :
```
personnes/
  ├── loic-perso/
  │   ├── immich/       ← Assets Immich (CRITIQUE)
  │   ├── paperless/    ← Documents (CRITIQUE)
  │   └── files/
  ├── alban/
  ├── mahaut/
  └── ilan/
```
**Commande recommandée** :
```bash
rsync -avh --progress \
  /Volumes/NAS-LOGO-DATA/NAS-LOGO-VOLUME/personnes/ \
  /Volumes/Expansion12/backups/NAS/personnes/
```

### B. /Volumes/logousb/SSD/NAS-LOGO-VOLUME/immich-db/ — CRITIQUE
**Statut** : ⏳ PLANIFIÉ  
**Raison** : Base de données PostgreSQL Immich (non reconstruisible)  
**Taille estimée** : 5-10 GB  
**Commande recommandée** :
```bash
rsync -avh --progress \
  /Volumes/logousb/SSD/NAS-LOGO-VOLUME/immich-db/ \
  /Volumes/Expansion12/backups/NAS/immich-db/
```

### C. /Volumes/NAS-LOGO-DATA/NAS-LOGO-VOLUME/immich/ — OPTIONNEL (ancien)
**Statut** : ⏳ À DÉCIDER  
**Raison** : Ancien dossier Immich (non utilisé par le service actuel)  
**Contenu** : backups/, encoded-video/, library/, profile/, thumbs/  
**Taille estimée** : ~50-100 GB  
**Décision** : Nécessaire pour archivage complet, mais non-critique pour la restauration du service  
**Commande recommandée (avec --delete)** :
```bash
# ÉTAPE 1 : DRY-RUN (voir ce qui serait supprimé)
rsync -avh --delete --dry-run --progress \
  /Volumes/NAS-LOGO-DATA/NAS-LOGO-VOLUME/immich/ \
  /Volumes/Expansion12/backup-bientotpurge/immich/

# ÉTAPE 2 : Exécution (après validation du dry-run)
rsync -avh --delete --progress \
  /Volumes/NAS-LOGO-DATA/NAS-LOGO-VOLUME/immich/ \
  /Volumes/Expansion12/backup-bientotpurge/immich/
```
**⚠️ Risques** :
- `--delete` supprime fichiers en destination non présents en source (sans confirmation)
- Inversion d'arguments catastrophique (risque de vider la source)
- Expansion12 doit être montée (sinon crée /Volumes/Expansion12 en local)
- Aucun backup de la destination après suppression

---

## 🔧 Modifications Prévues

### Makefile — Nouveau target `make backup`
**Statut** : 📋 À IMPLÉMENTER  
**Objectif** : Centraliser sauvegarde locale personnnes/ + immich-db vers /Volumes/Expansion12/backups/NAS  
**Commandes à ajouter** :
```makefile
.PHONY: backup
backup:
	@echo "▶ Sauvegarde locale vers /Volumes/Expansion12/backups/NAS..."
	mkdir -p /Volumes/Expansion12/backups/NAS/{personnes,immich-db}
	rsync -avh --progress \
		/Volumes/NAS-LOGO-DATA/NAS-LOGO-VOLUME/personnes/ \
		/Volumes/Expansion12/backups/NAS/personnes/
	rsync -avh --progress \
		/Volumes/logousb/SSD/NAS-LOGO-VOLUME/immich-db/ \
		/Volumes/Expansion12/backups/NAS/immich-db/
	@echo "✅ Sauvegarde terminée"
```

---

## 🚨 Problèmes Bloquants

### Hetzner SFTP port 23 — REFUSÉ
**Découvert** : 2026-05-19  
**Statut** : 🔴 NON RÉSOLU  
**Impact** : Sauvegarde distante complètement bloquée  
**Mitigation** : Sauvegarde locale vers Expansion12 en cours (plan actuel)  
**Action requise** : Contacter Hetzner support pour débloquer port 23 (ou trouver alternative)  

### Immich conteneurs ne relancent pas au boot
**Découvert** : Avant 2026-05-21  
**Statut** : 🟡 WORKAROUND APPLIQUÉ  
**Symptôme** : Après reboot NAS, conteneurs Immich exited  
**Mitigation** : Relance manuelle avec `docker compose up -d` depuis ~/immich/  
**Action requise** : Créer LaunchAgent `com.nas-logo.immich` pour relance automatique (P2)

---

## 📈 Résumé du Progrès

| Phase | Source | Destination | Statut | Taille |
|-------|--------|------------|--------|--------|
| 1 | SauvAvril2026 | /Volumes/Expansion12/sauvetmpo25mai/ | ✅ Terminé | 54 GB |
| 2 | AFAIRE+tard | /Volumes/Expansion12/sauvetmpo25mai/AFAIRE+tard/ | 🔄 EN COURS | À vérifier |
| 3 | _done/ | /Volumes/Expansion12/sauvetmpo25mai/_done/ | ⏳ Attente | À vérifier |
| Backup | immich-db/ | /Volumes/Expansion12/backups/NAS/immich-db/ | ✅ Terminé | 3.4 GB |
| A | personnes/ | /Volumes/Expansion12/backups/NAS/personnes/ | 📋 Script prêt | 2.2 TB |
| C | immich/ (ancien) | /Volumes/Expansion12/backup-bientotpurge/immich/ | 📋 Script prêt | ~50-100 GB |

---

---

## 📁 COMMANDES RSYNC — UNE LIGNE PAR SOUS-RÉPERTOIRE (Exact : ce qui a été lancé / va être lancé)

### PHASE 1 — SauvAvril2026 (✅ TERMINÉE)
```
✅ rsync -avh --progress /Volumes/NAS-LOGO-DATA/AFAIRE+tard/SauvAvril2026/ /Volumes/Expansion12/sauvetmpo25mai/
```

---

### PHASE 2 — AFAIRE+tard (🔄 EN COURS)
```
🔄 rsync -avh --progress /Volumes/NAS-LOGO-DATA/AFAIRE+tard/photos-toshiba-copy/ /Volumes/Expansion12/sauvetmpo25mai/AFAIRE+tard/photos-toshiba-copy/
🔄 rsync -avh --progress /Volumes/NAS-LOGO-DATA/AFAIRE+tard/SAUV\ DD/ /Volumes/Expansion12/sauvetmpo25mai/AFAIRE+tard/SAUV\ DD/
🔄 rsync -avh --progress /Volumes/NAS-LOGO-DATA/AFAIRE+tard/Sauv\ Icloud/ /Volumes/Expansion12/sauvetmpo25mai/AFAIRE+tard/Sauv\ Icloud/
🔄 rsync -avh --progress /Volumes/NAS-LOGO-DATA/AFAIRE+tard/videos\ Perso\ Familles\ Voyage/ /Volumes/Expansion12/sauvetmpo25mai/AFAIRE+tard/videos\ Perso\ Familles\ Voyage/
```

---

### PHASE 3 — _done (⏳ À VENIR — Auto-lancera après Phase 2)
```
⏳ rsync -avh --progress /Volumes/NAS-LOGO-DATA/_done/gmail-archive.mbox /Volumes/Expansion12/sauvetmpo25mai/_done/
⏳ rsync -avh --progress /Volumes/NAS-LOGO-DATA/_done/google-takeout-sample/ /Volumes/Expansion12/sauvetmpo25mai/_done/google-takeout-sample/
⏳ rsync -avh --progress /Volumes/NAS-LOGO-DATA/_done/import16mai/ /Volumes/Expansion12/sauvetmpo25mai/_done/import16mai/
⏳ rsync -avh --progress /Volumes/NAS-LOGO-DATA/_done/jpeg_corruptions.txt /Volumes/Expansion12/sauvetmpo25mai/_done/
⏳ rsync -avh --progress /Volumes/NAS-LOGO-DATA/_done/NewAppPhoto29Avril/ /Volumes/Expansion12/sauvetmpo25mai/_done/NewAppPhoto29Avril/
⏳ rsync -avh --progress /Volumes/NAS-LOGO-DATA/_done/PhotoAvant2015/ /Volumes/Expansion12/sauvetmpo25mai/_done/PhotoAvant2015/
⏳ rsync -avh --progress /Volumes/NAS-LOGO-DATA/_done/scan_import.sh /Volumes/Expansion12/sauvetmpo25mai/_done/
⏳ rsync -avh --progress /Volumes/NAS-LOGO-DATA/_done/scan-report/ /Volumes/Expansion12/sauvetmpo25mai/_done/scan-report/
⏳ rsync -avh --progress /Volumes/NAS-LOGO-DATA/_done/ssd-immich-upload-old/ /Volumes/Expansion12/sauvetmpo25mai/_done/ssd-immich-upload-old/
⏳ rsync -avh --progress /Volumes/NAS-LOGO-DATA/_done/ssd-imports-2015-2018/ /Volumes/Expansion12/sauvetmpo25mai/_done/ssd-imports-2015-2018/
⏳ rsync -avh --progress /Volumes/NAS-LOGO-DATA/_done/takeout-drive/ /Volumes/Expansion12/sauvetmpo25mai/_done/takeout-drive/
⏳ rsync -avh --progress /Volumes/NAS-LOGO-DATA/_done/takeout-extracted/ /Volumes/Expansion12/sauvetmpo25mai/_done/takeout-extracted/
⏳ rsync -avh --progress /Volumes/NAS-LOGO-DATA/_done/toshiba-1-photoslibrary/ /Volumes/Expansion12/sauvetmpo25mai/_done/toshiba-1-photoslibrary/
⏳ rsync -avh --progress /Volumes/NAS-LOGO-DATA/_done/toshiba-a-classer2/ /Volumes/Expansion12/sauvetmpo25mai/_done/toshiba-a-classer2/
⏳ rsync -avh --progress /Volumes/NAS-LOGO-DATA/_done/toshiba-photos-videos-famille/ /Volumes/Expansion12/sauvetmpo25mai/_done/toshiba-photos-videos-famille/
⏳ rsync -avh --progress /Volumes/NAS-LOGO-DATA/_done/toshiba-sauvegarde-20150319/ /Volumes/Expansion12/sauvetmpo25mai/_done/toshiba-sauvegarde-20150319/
⏳ rsync -avh --progress /Volumes/NAS-LOGO-DATA/_done/wd-pix-macos-photoslibrary/ /Volumes/Expansion12/sauvetmpo25mai/_done/wd-pix-macos-photoslibrary/
⏳ rsync -avh --progress /Volumes/NAS-LOGO-DATA/_done/wd-videos-famille-lot1/ /Volumes/Expansion12/sauvetmpo25mai/_done/wd-videos-famille-lot1/
```

---

### OPTIONNEL (À DÉCIDER)
```
📋 rsync -avh --progress /Volumes/NAS-LOGO-DATA/NAS-LOGO-VOLUME/personnes/ /Volumes/Expansion12/backups/NAS/personnes/
📋 rsync -avh --progress /Volumes/logousb/SSD/NAS-LOGO-VOLUME/immich-db/ /Volumes/Expansion12/backups/NAS/immich-db/
🚨 rsync -avh --delete --dry-run --progress /Volumes/NAS-LOGO-DATA/NAS-LOGO-VOLUME/immich/ /Volumes/Expansion12/backup-bientotpurge/immich/
🚨 rsync -avh --delete --progress /Volumes/NAS-LOGO-DATA/NAS-LOGO-VOLUME/immich/ /Volumes/Expansion12/backup-bientotpurge/immich/
```

---

## 📍 CHEMINS SOURCE → CIBLE (Référence rapide)

### Phase 2 (EN COURS)
| Élément | Source | Cible |
|--------|--------|-------|
| **AFAIRE+tard** | `/Volumes/NAS-LOGO-DATA/AFAIRE+tard/` | `/Volumes/Expansion12/sauvetmpo25mai/AFAIRE+tard/` |

### Phase 3 (À VENIR)
| Élément | Source | Cible |
|--------|--------|-------|
| **_done** | `/Volumes/NAS-LOGO-DATA/_done/` | `/Volumes/Expansion12/sauvetmpo25mai/_done/` |

### Données Critiques (À sauvegarder)
| Élément | Source | Cible |
|--------|--------|-------|
| **personnes/** | `/Volumes/NAS-LOGO-DATA/NAS-LOGO-VOLUME/personnes/` | `/Volumes/Expansion12/backups/NAS/personnes/` |
| **immich-db/** | `/Volumes/logousb/SSD/NAS-LOGO-VOLUME/immich-db/` | `/Volumes/Expansion12/backups/NAS/immich-db/` |
| **immich/ (ancien)** | `/Volumes/NAS-LOGO-DATA/NAS-LOGO-VOLUME/immich/` | `/Volumes/Expansion12/backup-bientotpurge/immich/` |

---

## 🔍 Commandes de Suivi

```bash
# Progression de Phase 2 (AFAIRE+tard)
tail -f /Volumes/NAS-LOGO-DATA/journaux/rsync-chain.out

# Vérifier les tailles actuelles
du -sh /Volumes/Expansion12/sauvetmpo25mai/*

# Processus rsync actifs
ps aux | grep rsync | grep -v grep

# Espace disque Expansion12
df -h /Volumes/Expansion12/

# Log complet du script de chaînage
cat /Volumes/NAS-LOGO-DATA/journaux/rsync-YYYYMMDD-HHMMSS.log
```

---

## ✅ Prochaines Étapes (Ordre de Priorité)

1. **✅ Backup immich-db** → TERMINÉ (2026-05-25 18:27, 3.4 GB)
2. **Attendre fin Phase 2** → Phase 3 se lancera automatiquement
3. **Lancer script complet** → `/tmp/rsync-complete-script.sh` (Optionnelles + Phase 3)
4. **Mettre à jour Makefile** → Ajouter `make backup` (personnes/ + immich-db/safe)
5. **Résoudre Hetzner** → Contacter support port 23 SFTP
6. **Implémenter LaunchAgent Immich** → Pour relance automatique au boot

---

---

## 🔢 COMMANDES NUMÉROTÉES 1–27 (Ordre d'exécution)

**Script de lancement** : `/tmp/rsync-complete-script.sh`  
**Arrête en attente Phase 2 → Lance Optionnelles (6-9) → Lance Phase 3 (10-27)**

### PHASE 1 (✅ TERMINÉE — pour référence)
```
 1. ✅ rsync -avh --progress /Volumes/NAS-LOGO-DATA/AFAIRE+tard/SauvAvril2026/ /Volumes/Expansion12/sauvetmpo25mai/
```

### PHASE 2 (🔄 EN COURS — non lancées par script, déjà en exécution directe)
```
 (2-5. Exécutées directement — pas par le script, incluses pour complétude)
 2. 🔄 rsync -avh --progress /Volumes/NAS-LOGO-DATA/AFAIRE+tard/photos-toshiba-copy/ /Volumes/Expansion12/sauvetmpo25mai/AFAIRE+tard/photos-toshiba-copy/
 3. 🔄 rsync -avh --progress /Volumes/NAS-LOGO-DATA/AFAIRE+tard/SAUV\ DD/ /Volumes/Expansion12/sauvetmpo25mai/AFAIRE+tard/SAUV\ DD/
 4. 🔄 rsync -avh --progress /Volumes/NAS-LOGO-DATA/AFAIRE+tard/Sauv\ Icloud/ /Volumes/Expansion12/sauvetmpo25mai/AFAIRE+tard/Sauv\ Icloud/
 5. 🔄 rsync -avh --progress /Volumes/NAS-LOGO-DATA/AFAIRE+tard/videos\ Perso\ Familles\ Voyage/ /Volumes/Expansion12/sauvetmpo25mai/AFAIRE+tard/videos\ Perso\ Familles\ Voyage/
```

### OPTIONNELLES (📋 Lancées par `/tmp/rsync-complete-script.sh` AVANT Phase 3)
```
 6. 📋 rsync -avh --progress /Volumes/NAS-LOGO-DATA/NAS-LOGO-VOLUME/personnes/ /Volumes/Expansion12/backups/NAS/personnes/
    ⚠️ CRITICAL: personnes/ (2.2 TB) — Immich assets + Paperless docs — ligne 6
    
 7. 📋 rsync -avh --progress /Volumes/logousb/SSD/NAS-LOGO-VOLUME/immich-db/ /Volumes/Expansion12/backups/NAS/immich-db/
    Note: Déjà sauvegardée en sécurité (2026-05-25), redondance pour intégrité
    
 8. 🚨 rsync -avh --delete --dry-run --progress /Volumes/NAS-LOGO-DATA/NAS-LOGO-VOLUME/immich/ /Volumes/Expansion12/backup-bientotpurge/immich/
    Note: DRY-RUN UNIQUEMENT — affiche ce qui serait supprimé, ne supprime rien
    
 9. 🚨 rsync -avh --delete --progress /Volumes/NAS-LOGO-DATA/NAS-LOGO-VOLUME/immich/ /Volumes/Expansion12/backup-bientotpurge/immich/
    ⚠️ RISQUE: --delete supprime destination ≠ source (sans confirmation)
```

### PHASE 3 (⏳ Lancées par `/tmp/rsync-complete-script.sh` APRÈS Optionnelles)
```
10. ⏳ rsync -avh --progress /Volumes/NAS-LOGO-DATA/_done/gmail-archive.mbox /Volumes/Expansion12/sauvetmpo25mai/_done/
11. ⏳ rsync -avh --progress /Volumes/NAS-LOGO-DATA/_done/google-takeout-sample/ /Volumes/Expansion12/sauvetmpo25mai/_done/google-takeout-sample/
12. ⏳ rsync -avh --progress /Volumes/NAS-LOGO-DATA/_done/import16mai/ /Volumes/Expansion12/sauvetmpo25mai/_done/import16mai/
13. ⏳ rsync -avh --progress /Volumes/NAS-LOGO-DATA/_done/jpeg_corruptions.txt /Volumes/Expansion12/sauvetmpo25mai/_done/
14. ⏳ rsync -avh --progress /Volumes/NAS-LOGO-DATA/_done/NewAppPhoto29Avril/ /Volumes/Expansion12/sauvetmpo25mai/_done/NewAppPhoto29Avril/
15. ⏳ rsync -avh --progress /Volumes/NAS-LOGO-DATA/_done/PhotoAvant2015/ /Volumes/Expansion12/sauvetmpo25mai/_done/PhotoAvant2015/
16. ⏳ rsync -avh --progress /Volumes/NAS-LOGO-DATA/_done/scan_import.sh /Volumes/Expansion12/sauvetmpo25mai/_done/
17. ⏳ rsync -avh --progress /Volumes/NAS-LOGO-DATA/_done/scan-report/ /Volumes/Expansion12/sauvetmpo25mai/_done/scan-report/
18. ⏳ rsync -avh --progress /Volumes/NAS-LOGO-DATA/_done/ssd-immich-upload-old/ /Volumes/Expansion12/sauvetmpo25mai/_done/ssd-immich-upload-old/
19. ⏳ rsync -avh --progress /Volumes/NAS-LOGO-DATA/_done/ssd-imports-2015-2018/ /Volumes/Expansion12/sauvetmpo25mai/_done/ssd-imports-2015-2018/
20. ⏳ rsync -avh --progress /Volumes/NAS-LOGO-DATA/_done/takeout-drive/ /Volumes/Expansion12/sauvetmpo25mai/_done/takeout-drive/
21. ⏳ rsync -avh --progress /Volumes/NAS-LOGO-DATA/_done/takeout-extracted/ /Volumes/Expansion12/sauvetmpo25mai/_done/takeout-extracted/
22. ⏳ rsync -avh --progress /Volumes/NAS-LOGO-DATA/_done/toshiba-1-photoslibrary/ /Volumes/Expansion12/sauvetmpo25mai/_done/toshiba-1-photoslibrary/
23. ⏳ rsync -avh --progress /Volumes/NAS-LOGO-DATA/_done/toshiba-a-classer2/ /Volumes/Expansion12/sauvetmpo25mai/_done/toshiba-a-classer2/
24. ⏳ rsync -avh --progress /Volumes/NAS-LOGO-DATA/_done/toshiba-photos-videos-famille/ /Volumes/Expansion12/sauvetmpo25mai/_done/toshiba-photos-videos-famille/
25. ⏳ rsync -avh --progress /Volumes/NAS-LOGO-DATA/_done/toshiba-sauvegarde-20150319/ /Volumes/Expansion12/sauvetmpo25mai/_done/toshiba-sauvegarde-20150319/
26. ⏳ rsync -avh --progress /Volumes/NAS-LOGO-DATA/_done/wd-pix-macos-photoslibrary/ /Volumes/Expansion12/sauvetmpo25mai/_done/wd-pix-macos-photoslibrary/
27. ⏳ rsync -avh --progress /Volumes/NAS-LOGO-DATA/_done/wd-videos-famille-lot1/ /Volumes/Expansion12/sauvetmpo25mai/_done/wd-videos-famille-lot1/
```

---

**Dernière mise à jour** : 2026-05-31 (Phase 2 ✅ TERMINÉE, Phase 3 ✅ TERMINÉE — Sauvegarde complète ~1,45 To sur Expansion12)

---

## 🎉 MISE À JOUR 2026-05-31 — TOUTES LES PHASES TERMINÉES

### Phase 2 — AFAIRE+tard ✅ TERMINÉE
- **Durée** : Plusieurs heures
- **Résultat** : 
  - photos-toshiba-copy : 310 Go ✅
  - Sauv Icloud : 44 Go ✅
  - videos Perso Familles Voyage : 1,3 Go ✅
  - SAUV DD : 0 Go (vide) ✅

### Phase 3 — _done ✅ TERMINÉE
- **Début** : 2026-05-30 23:28:35 CEST
- **Fin** : 2026-05-31 05:40:06 CEST
- **Durée** : 6 heures 12 minutes
- **Données transférées** : 798 Go / 1,042 To (total)
- **Fichiers** : 483 589 fichiers
- **Vitesse moyenne** : 37,8 MB/s
- **Statut** : ✅ SUCCÈS

### Résumé Final
| Phase | Contenu | Taille | Statut |
|-------|---------|--------|--------|
| 1 | SauvAvril2026 | 294 Go | ✅ |
| 2a | photos-toshiba-copy | 310 Go | ✅ |
| 2b | Sauv Icloud | 44 Go | ✅ |
| 2c | videos Perso Familles Voyage | 1,3 Go | ✅ |
| 2d | SAUV DD | 0 Go | ✅ |
| 3 | _done | 798 Go | ✅ |
| **TOTAL** | **~1,45 To** | | **✅** |

### Prochaines Étapes
1. **Reboot** (problème corbeille)
2. **Cleanup** : Exécuter `/Volumes/logousb/SSD/Projects/NAS-logo/scripts/cleanup-nas-data.sh`
3. **Vérification** : Vérifier espace libre sur NAS-LOGO-DATA
