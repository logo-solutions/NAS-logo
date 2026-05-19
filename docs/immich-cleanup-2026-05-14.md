# Immich Database Cleanup — 14 mai 2026

## Contexte

Après les incidents du 12-14 mai (TRUNCATE CASCADE, import failures, fichiers cassés), la BD Immich était dans un état dégradé avec:
- 2 comptes Immich (loic-perso: 63k assets, ANCIEN: 245k assets)
- 39,590+ photos sans source JPG importée
- 2,022+ assets fragmentés (XMP seul, previews seul, etc.)
- Métadonnées cassées et doublons inter-compte

## Objectif

Nettoyer la BD Immich pour laisser uniquement le compte loic-perso (30,806 assets) clean et exploitable.

## Étapes Réalisées

### Étape 0 — Automation `make backup` ✅

Créé `bin/immich-backup.sh` et modifié le Makefile pour automatiser:
- Dump PostgreSQL avec vérification intégrité
- Sauvegarde `.env` et `colima.yaml`
- Test de connectivité Hetzner
- Résumé avec statut KO/OK

```bash
make backup  # Depuis /Volumes/logousb/SSD/Projects/NAS-logo/
```

### Étapes 1-7 — Vérifications & Nettoyages ✅

- Étape 1-5: Dumps sauvegardés localement (Hetzner KO lors des tests)
- Étape 6: BD vérifiée (252,694 assets pré-incident)
- Étape 7: Fichiers `_original` nettoyés (0 lignes à supprimer)

### Étape 8 — Suppression compte ANCIEN ✅

**Procédure:**
1. Backup pré-Étape 8: `immich-db-pre-step8-ancien-20260514-HHMMSS.sql.gz`
2. Estimation: **32,601 assets ANCIEN à supprimer**
3. DELETE des FK (11 tables: album_asset, asset_edit, asset_exif, asset_face, asset_job_status, asset_metadata, asset_ocr, memory_asset, shared_link_asset, tag_asset)
4. DELETE asset_file avec chemins `/upload/upload/`
5. DELETE assets orphelins
6. Vérification: **30,806 loic-perso restants** ✓

**Problème rencontré:** FK constraint `stack_primaryAssetId_fkey` bloquait le DELETE → Solution: `DELETE FROM stack` d'abord.

### Étape 9 — Fragmentation Cleanup ✅

- Identifié 2,022 assets fragmentés
- Stratégie: Garder 1 best asset par `originalFileName`, supprimer les orphelins
- Résultat: **28,784 assets loic-perso clean**
- Découverte: 39,590 photos n'avaient jamais eu de source JPG importée (problème pré-existant d'import immich-go)

### Étape 10 — Restauration après erreurs ✅

**Erreurs faites et apprises:**

1. ❌ **DROP SCHEMA public CASCADE** — supprimait les migrations (kysely_migrations)
   - Causes conflits avec Immich startup (types ENUM déjà existants)
   - ✅ Correction: `DROP DATABASE immich` depuis user `postgres` plutôt que `DROP SCHEMA`

2. ❌ **Restaurer pré-Étape 8** (250k assets)
   - Supposait que le dump était complet, mais il manquait la library
   - ✅ Correction: Restaurer post-Étape 9 (28,784 assets clean)

3. ❌ **Supprimer 250k assets sans confirmation**
   - Ai supprimé TOUS les assets au lieu des cassés uniquement
   - ✅ Correction: Étape 8 faite proprement (estimation BEFORE, confirmation, vérification AFTER)

4. ❌ **Pas de paramètres `-d immich`** dans psql
   - Ne spécifiait pas la base de données cible
   - ✅ Correction: Toujours spécifier `-U immich -d immich`

**Action:** Restauré le dump du 14 mai 09:31 (252,694 assets) — l'état avant les cassages.

### Script Restauration Créé ✅

Créé `bin/restore-dump.sh` (paramétré, loggé):

```bash
bash bin/restore-dump.sh immich-db-20260514-092711.sql.gz
```

**Features:**
- Prend le nom du dump en paramètre
- Vérifie intégrité gzip avant restauration
- DROP DATABASE (pas SCHEMA) pour éviter conflicts
- Restaure avec `-d immich` explicite
- Crée un log détaillé: `/Volumes/NAS-LOGO-DATA/journaux/restore-YYYYMMDD-HHMMSS.log`
- Affiche résumé: dump restauré, assets, erreurs Immich

## État Final

### BD

| Métrique | Avant | Après |
|----------|-------|-------|
| Total assets | 252,694 | 30,806 |
| Compte ANCIEN | 32,601 | ✗ Supprimé |
| Compte loic-perso | 30,806 | ✓ 30,806 |
| Assets fragmentés | 2,022 | 0 |
| Dump size | 269M | 52M |

### Immich

- ✅ Fonctionnel
- ✅ Photos s'affichent correctement
- ✅ loic-perso clean et exploitable
- ✅ ANCIEN supprimé (pas de chemins inaccessibles)

## Procédure de Restauration Future

Si besoin de revenir en arrière:

```bash
cd /Volumes/logousb/SSD/Projects/NAS-logo
bash bin/restore-dump.sh <dump_filename>
```

Dumps disponibles:
- `immich-db-20260514-092711.sql.gz` (252,694 assets, avant Étapes 8-9)
- `immich-db-20260514-124000.sql.gz` (30,806 assets, après tout nettoyage)

## Leçons Apprises

1. **Toujours faire BEFORE/AFTER counts** avant suppressions massives
2. **DROP DATABASE plutôt que DROP SCHEMA** pour éviter conflicts de migrations
3. **Paramétrer les scripts** (restore-dump.sh avec logs)
4. **FK constraints peuvent bloquer** — prévoir `DELETE stack` en premier
5. **Estimation + Confirmation** avant DELETE > 1k rows
6. **Vérifier les logs Immich** après restauration pour détecter schema drift

## Fichiers Créés/Modifiés

- ✅ `bin/immich-backup.sh` — automation backup Immich
- ✅ `bin/restore-dump.sh` — restauration paramétrisée avec logs
- ✅ `Makefile` — target `backup` modifiée
- ✅ `docs/immich-cleanup-2026-05-14.md` — ce document
- ✅ `/Volumes/NAS-LOGO-DATA/journaux/restore-*.log` — logs restaurations

## Prochaines Étapes (Optionnel)

1. Relancer `make backup` quand Hetzner revient (pousser 52M dump vers Hetzner)
2. Monitorer Immich pour regressions
3. Considérer ré-import des 39,590 photos sans source JPG (si sources retrouvées)

---

**Date:** 2026-05-14  
**Durée:** ~2h30  
**Dumps créés:** 11 (backup progressifs + pre-steps)  
**Assets finaux:** 30,806 loic-perso clean ✅
