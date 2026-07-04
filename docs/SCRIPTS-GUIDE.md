# 📋 GUIDE COMPLET DES SCRIPTS NAS-LOGO

**Version:** 2026-06-07  
**Total scripts:** 46  
**But:** Référence unique pour éviter la confusion et les doublons

---

## 🔴 IMMICH — BACKUP (5 scripts)

### 1. `immich-backup.sh` ⚠️ GÉNÉRIQUE (ne pas utiliser)
**Chemin:** `/Volumes/logousu/SSD/Projects/NAS-logo/bin/immich-backup.sh`  
**Fonction:** Wrapper générique (DÉPRECIÉ)  
**Status:** ❌ À IGNORER — utiliser les scripts spécialisés ci-dessous

### 2. `immich-backup-db-only.sh` ✅ RECOMMANDÉ
**Chemin:** `/Volumes/logousb/SSD/Projects/NAS-logo/bin/immich-backup-db-only.sh`  
**Fonction:** Dump PostgreSQL uniquement (rapide, quotidien)  
**Usage:**
```bash
bash bin/immich-backup-db-only.sh
```
**Sauvegardes (Expansion12/Backup):**
- Destination: `/Volumes/Expansion12/Backup/immich-backup-db-YYYYMMDD-HHMMSS/`
- Format: `immich-db-YYYYMMDD-HHMMSS.sql.gz`
- Taille: ~113M (compressé)
- Exemplaires: juin 2026 (2026-06-06, 2026-06-07, etc.)

**Journaux (NAS-LOGO-DATA/journaux):**
- Pattern: `/Volumes/NAS-LOGO-DATA/journaux/immich-backup-db-only-YYYYMMDD-HHMMSS.log`
- Historique: juin 2026 (derniers backups)

**Quand l'utiliser:** Chaque jour (LaunchDaemon 03:00) — rapide, léger

---

### 3. `immich-backup-physical.sh`
**Chemin:** `/Volumes/logousb/SSD/Projects/NAS-logo/bin/immich-backup-physical.sh`  
**Fonction:** Copie physique assets + DB (complet, lourd)  
**Usage:**
```bash
bash bin/immich-backup-physical.sh
```
**Sauvegardes (Expansion12/Backup):**
- Destination: `/Volumes/Expansion12/Backup/immich-backup-physical-YYYYMMDD-HHMMSS/`
- Structure: `upload/` (photos), `immich-db*.sql.gz` (base de données)
- Taille: ~800M-2GB
- Exemplaires: juin 2026 (2026-06-06, etc.)

**Journaux (NAS-LOGO-DATA/journaux):**
- Pattern: `/Volumes/NAS-LOGO-DATA/journaux/immich-backup-physical-YYYYMMDD-HHMMSS.log`
- Historique: juin 2026

**Quand l'utiliser:** Hebdomadaire (dimanche matin) — sauvegarde complète

---

### 4. `immich-backup-complete.sh` 
**Chemin:** `/Volumes/logousb/SSD/Projects/NAS-logo/bin/immich-backup-complete.sh`  
**Fonction:** Archive complète (DB + assets + metadata)  
**Status:** ⚠️ À tester — version expérimentale

---

### 5. `immich-backup-professional.sh`
**Chemin:** `/Volumes/logousb/SSD/Projects/NAS-logo/bin/immich-backup-professional.sh`  
**Fonction:** Backup professionnel avec audit + checksums  
**Usage:**
```bash
bash bin/immich-backup-professional.sh
```
**Sauvegardes (Expansion12/Backup):**
- Destination: `/Volumes/Expansion12/Backup/immich-backup-professional-YYYYMMDD-HHMMSS/`
- Contenu: `dump.sql.gz`, `README.md`, `audit.txt`, checksums

**Journaux (NAS-LOGO-DATA/journaux):**
- Pattern: `/Volumes/NAS-LOGO-DATA/journaux/immich-backup-professional-*.log`

---

## 🟢 IMMICH — RESTORE (2 scripts)

### 6. `restore-db-only.sh`
**Chemin:** `/Volumes/logousb/SSD/Projects/NAS-logo/bin/restore-db-only.sh`  
**Fonction:** Restaurer BD depuis dump  
**Usage:**
```bash
bash bin/restore-db-only.sh /path/to/dump.sql.gz
```
**Quand l'utiliser:** Après incident BD (crash, corruption)

---

### 7. `restore-dump.sh`
**Chemin:** `/Volumes/logousb/SSD/Projects/NAS-logo/bin/restore-dump.sh`  
**Fonction:** Restaurer dump complet (DB + assets)  
**Usage:**
```bash
bash bin/restore-dump.sh /path/to/backup-dir/
```

---

## 🟡 IMMICH — IMPORT (3 scripts)

### 8. `immich-import.sh` ✅ RECOMMANDÉ
**Chemin:** `/Volumes/logousb/SSD/Projects/NAS-logo/bin/immich-import.sh`  
**Fonction:** Import générique via immich-go  
**Usage:**
```bash
bash bin/immich-import.sh /path/to/source/
bash bin/immich-import.sh /path/to/source/ --google
bash bin/immich-import.sh /path/to/source/ --no-hetzner
```
**Arguments:**
- `--google` : Mode Google Photos (`from-google-photos`)
- `--no-hetzner` : Sauter backup Hetzner

**Résultat:** Import + backup DB auto + restart Immich

---

### 9. `immich-import-icloud-skipHash.sh` ❌ NE FONCTIONNE PAS
**Chemin:** `/Volumes/logousb/SSD/Projects/NAS-logo/bin/immich-import-icloud-skipHash.sh`  
**Fonction:** Import iCloud avec skip-hash (BUG)  
**Status:** ❌ BROKEN — `--skip-hash` flag n'existe pas dans immich-go

**Solution:** Utiliser immich-go directement:
```bash
immich-go upload from-folder --server http://localhost:2283 --api-key $KEY \
  --overwrite --no-ui --on-errors=continue /path/to/source/
```

---

### 10. `immich-import-test-subset.sh`
**Chemin:** `/Volumes/logousb/SSD/Projects/NAS-logo/bin/immich-import-test-subset.sh`  
**Fonction:** Import test (10 fichiers seulement)  
**Usage:** Tester avant import complet

---

## 🔵 IMMICH — AUDIT/SANTÉ (4 scripts)

### 11. `immich-audit-dump.sh`
**Chemin:** `/Volumes/logousb/SSD/Projects/NAS-logo/bin/immich-audit-dump.sh`  
**Fonction:** Analyser structure DB (comptage tables, volumétrie)  
**Usage:**
```bash
bash bin/immich-audit-dump.sh /path/to/dump.sql.gz /output/dir/
```
**Résultat:** Rapport complet (61 tables, counts, volumes)

---

### 12. `immich-audit-dump-v2.sh` / `immich-audit-dump-v3.sh`
**Chemin:** `/Volumes/logousb/SSD/Projects/NAS-logo/bin/immich-audit-dump-v*.sh`  
**Fonction:** Versions antérieures (archive)  
**Status:** ⚠️ Garder pour historique

---

### 13. `immich-health-check.sh`
**Chemin:** `/Volumes/logousb/SSD/Projects/NAS-logo/bin/immich-health-check.sh`  
**Fonction:** Vérifier santé instance (DB, containers, API)  
**Usage:**
```bash
bash bin/immich-health-check.sh
```
**Résultat:** Status: ✓ OK ou ✗ ERREURS

---

### 14. `immich-compare-dumps.sh`
**Chemin:** `/Volumes/logousb/SSD/Projects/NAS-logo/bin/immich-compare-dumps.sh`  
**Fonction:** Comparer deux dumps (delta, anomalies)  
**Usage:**
```bash
bash bin/immich-compare-dumps.sh dump1.sql.gz dump2.sql.gz
```

---

## 🟣 IMMICH — SCAN/CLEANUP (4 scripts)

### 15. `scan-immich-deep.sh`
**Chemin:** `/Volumes/logousb/SSD/Projects/NAS-logo/bin/scan-immich-deep.sh`  
**Fonction:** Audit profond assets (orphelins, corruptions)  
**Quand:** Avant nettoyage majeur

---

### 16. `scan-immich-photos.sh`
**Chemin:** `/Volumes/logousb/SSD/Projects/NAS-logo/bin/scan-immich-photos.sh`  
**Fonction:** Compter photos/vidéos par utilisateur  
**Quand:** Rapport usage

---

### 17. `cleanup-immich-orphans.sh`
**Chemin:** `/Volumes/logousb/SSD/Projects/NAS-logo/bin/cleanup-immich-orphans.sh`  
**Fonction:** Supprimer assets orphelins (BD sans fichier)  
**Quand:** Maintenance

---

### 18. `immich-icloud-reconcile.sh`
**Chemin:** `/Volumes/logousb/SSD/Projects/NAS-logo/bin/immich-icloud-reconcile.sh`  
**Fonction:** Réconcilier iCloud export vs BD  
**Quand:** Après import iCloud incomplet

---

## 🟠 IMMICH — SHUTDOWN (1 script)

### 19. `graceful-shutdown.sh`
**Chemin:** `/Volumes/logousb/SSD/Projects/NAS-logo/bin/graceful-shutdown.sh`  
**Fonction:** Arrêt propre Immich (pause jobs, backup, stop containers)  
**Usage:**
```bash
bash bin/graceful-shutdown.sh
```
**Quand:** Avant maintenance, reboot, ou migration

---

## 🟤 COLIMA (1 script)

### 20. `colima-backup-daily.sh`
**Chemin:** `/Volumes/logousb/SSD/Projects/NAS-logo/bin/colima-backup-daily.sh`  
**Fonction:** Sauvegarder config Colima + ~/.colima/  
**Usage:**
```bash
bash bin/colima-backup-daily.sh
```
**Sauvegardes (Expansion12/Backup):**
- Destination: `/Volumes/Expansion12/Backup/colima-YYYYMMDD-HHMMSS.tar.gz`
- Contenu: ~/.colima/ directory, docker config
- Retention: 7 jours (anciens supprimés)
- Exemplaires: juin 2026

**Journaux (NAS-LOGO-DATA/journaux):**
- Pattern: `/Volumes/NAS-LOGO-DATA/journaux/colima-backup-YYYYMMDD-HHMMSS.log`
- Historique: juin 2026

**LaunchAgent:** com.nas-logo.colima-backup à 02:00

---

## 🏠 NAS — BACKUP/RESTORE (6 scripts)

### 21-25. `nas-logo-backup*.sh` / `nas-logo-restore*.sh`
**Chemin:** `/Volumes/logousb/SSD/Projects/NAS-logo/scripts/backup-restore/`  
**Scripts:**
- `nas-logo-backup.sh` — Backup personnes/ + immich-db/
- `nas-logo-backup-cible.sh` — Backup vers cible externe
- `nas-logo-dump-db.sh` — Dump BD simple
- `nas-logo-restore.sh` — Restaurer depuis backup
- `nas-logo-restore-test.sh` — Test restauration (dry-run)

**Quand:** Sauvegarde quotidienne du NAS

---

## 🧹 NAS — CLEANUP/INVENTORY (3 scripts)

### 26. `inventaire-nas.sh`
**Chemin:** `/Volumes/logousb/SSD/Projects/NAS-logo/scripts/cleanHDDs/inventaire-nas.sh`  
**Fonction:** Lister tous HDD, volumes, espaces libres  
**Usage:**
```bash
bash scripts/cleanHDDs/inventaire-nas.sh
```

---

### 27. `rapport-doublons-rang2.sh`
**Chemin:** `/Volumes/logousb/SSD/Projects/NAS-logo/scripts/cleanHDDs/rapport-doublons-rang2.sh`  
**Fonction:** Analyser doublons entre HDDs  
**Usage:**
```bash
bash scripts/cleanHDDs/rapport-doublons-rang2.sh
```

---

### 28. `cleanup-nas-data.sh`
**Chemin:** `/Volumes/logousb/SSD/Projects/NAS-logo/scripts/cleanup-nas-data.sh`  
**Fonction:** Nettoyer/archiver données obsolètes  
**⚠️ DANGER:** Destructif!

---

## 🚀 BOOTSTRAP/SETUP (2 scripts)

### 29. `bootstrap.sh`
**Chemin:** `/Volumes/logousb/SSD/Projects/NAS-logo/bootstrap.sh`  
**Fonction:** Setup initial (Homebrew, Ansible, dépendances)  
**Usage:**
```bash
bash bootstrap.sh
```
**Quand:** Première installation

---

### 30. `setup-ups.sh`
**Chemin:** `/Volumes/logousb/SSD/Projects/NAS-logo/scripts/setup-ups.sh`  
**Fonction:** Configurer onduleur UPS  
**Quand:** Setup matériel

---

## 🔧 HOOKS/INTERNAL (3 scripts)

### 31. `session-start.sh`
**Chemin:** `/Volumes/logousb/SSD/Projects/NAS-logo/hooks/session-start.sh`  
**Fonction:** Hook session (interne)  
**Status:** 🔒 Ne pas toucher

---

### 32-33. `simplify-ignore*.sh`
**Chemin:** `/Volumes/logousb/SSD/Projects/NAS-logo/hooks/simplify-ignore*.sh`  
**Fonction:** Gérer gitignore automatiquement  
**Status:** 🔒 Automatisé

---

## 📋 RÉSUMÉ PAR CAS D'USAGE

### **Backup quotidien**
```bash
# DB seulement (léger, rapide)
bash bin/immich-backup-db-only.sh

# LaunchDaemon auto: 03:00 chaque jour
```

### **Backup hebdomadaire**
```bash
# Assets complets (lent, lourd)
bash bin/immich-backup-physical.sh

# LaunchDaemon auto: dimanche 04:00
```

### **Colima sauvegarde**
```bash
bash bin/colima-backup-daily.sh

# LaunchDaemon auto: 02:00 chaque jour
```

### **Import photos**
```bash
# Import générique (loic-perso, Google Photos, etc.)
bash bin/immich-import.sh /path/to/photos/

# IMMICH-GO DIRECT (plus sûr pour iCloud):
immich-go upload from-folder \
  --server http://localhost:2283 \
  --api-key $KEY \
  --no-ui \
  --on-errors=continue \
  /path/to/icloud-export/
```

### **Santé système**
```bash
bash bin/immich-health-check.sh
bash scripts/cleanHDDs/inventaire-nas.sh
```

### **Restauration d'urgence**
```bash
bash bin/restore-db-only.sh /path/to/dump.sql.gz
```

---

## ⚠️ SCRIPTS À ÉVITER

| Script | Raison | Alternative |
|--------|--------|-------------|
| `immich-backup.sh` | Générique, obsolète | Utiliser `immich-backup-db-only.sh` |
| `immich-import-icloud-skipHash.sh` | Flag inexistant | Utiliser `immich-go` direct |
| `cleanup-nas-data.sh` | Destructif sans backup | À utiliser avec extrême prudence |
| `immich-audit-dump-v2.sh` | Ancienne version | Utiliser `immich-audit-dump.sh` |

---

## 📞 QUAND UTILISER QUOI

**Besoin:** Sauvegarder BD quotidiennement  
→ `immich-backup-db-only.sh` (auto via LaunchDaemon)

**Besoin:** Importer photos iCloud  
→ `immich-go upload from-folder` (direct, pas de script cassé)

**Besoin:** Nettoyer assets orphelins  
→ `cleanup-immich-orphans.sh`

**Besoin:** Vérifier santé  
→ `immich-health-check.sh`

**Besoin:** Restaurer urgence  
→ `restore-db-only.sh` + `restore-dump.sh`

---

## 📦 RÉFÉRENCE — SAUVEGARDES PAR DESTINATION

### `/Volumes/Expansion12/Backup/` (Disque externe USB — PRINCIPAL)

| Répertoire | Type | Mois | Taille | Script |
|-----------|------|------|--------|--------|
| `immich-backup-db-*` | Dumps DB quotidiens | **juin 2026** | ~113M chacun | immich-backup-db-only.sh |
| `immich-backup-physical-*` | Assets complets | **juin 2026** | ~800M-2GB chacun | immich-backup-physical.sh |
| `immich-backup-professional-*` | Dump + audit + checksums | **juin 2026** | ~150M | immich-backup-professional.sh |
| `colima-*.tar.gz` | Config Colima archivée | **juin 2026** | ~50-100M | colima-backup-daily.sh |

**Nettoyage:** Garder les 7 derniers pour Colima; les autres selon politique de rétention

---

## 📝 RÉFÉRENCE — JOURNAUX CENTRALISÉS

### `/Volumes/NAS-LOGO-DATA/journaux/` (Disque NAS — HISTORIQUE)

| Pattern de logs | Source script | Mois | Taille |
|-----------------|---------------|------|--------|
| `immich-backup-db-only-*.log` | immich-backup-db-only.sh | **juin 2026** | ~100-500K |
| `immich-backup-physical-*.log` | immich-backup-physical.sh | **juin 2026** | ~500K-2M |
| `immich-backup-professional-*.log` | immich-backup-professional.sh | **juin 2026** | ~200K |
| `colima-backup-*.log` | colima-backup-daily.sh | **juin 2026** | ~50K |
| `immich-go-*.log` | immich-import.sh | **juin 2026** | ~1-100M |
| `rsync-*.log` | Manual rsync ops | **mai-juin 2026** | ~10-500M |
| `doublons-hdd-*.md` | rapport-doublons-rang2.sh | **juin 2026** | ~50K |
| `immich-health-check-*.log` | immich-health-check.sh | **juin 2026** | ~10-50K |

**Archivage:** Tous les logs > 90 jours peuvent être gzipés/archivés

---

## 🗓️ CALENDRIER DE MAINTENANCE

**Quotidien (03:00):** DB backup → `/Volumes/Expansion12/Backup/immich-backup-db-*`

**Quotidien (02:00):** Colima backup → `/Volumes/Expansion12/Backup/colima-*.tar.gz`

**Hebdomadaire (dimanche 04:00):** Assets backup → `/Volumes/Expansion12/Backup/immich-backup-physical-*`

Tous les logs → `/Volumes/NAS-LOGO-DATA/journaux/`

---

**Dernière mise à jour:** 2026-06-07 10:27  
**Auteur:** Claude Code  
**Ref issue:** #NAS-LOGO-SCRIPTS-001
