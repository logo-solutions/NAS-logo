#!/bin/bash
# Script de nettoyage NAS-LOGO-DATA
# Supprime AFAIRE+tard et _done après vérification de sauvegarde

set -euo pipefail

echo "=========================================="
echo "🧹 NETTOYAGE NAS-LOGO-DATA"
echo "=========================================="
echo ""

# Colore pour lisibilité
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 1. VÉRIFICATION DE SAUVEGARDE
echo -e "${YELLOW}📋 ÉTAPE 1 : VÉRIFICATION DES SAUVEGARDES${NC}"
echo ""

echo "✓ Vérification AFAIRE+tard sur Expansion12..."
if [ -d /Volumes/Expansion12/sauvetmpo25mai/AFAIRE+tard ]; then
    SIZE=$(du -sh /Volumes/Expansion12/sauvetmpo25mai/AFAIRE+tard 2>/dev/null | cut -f1)
    echo -e "  ${GREEN}✅ Trouvé (${SIZE})${NC}"
else
    echo -e "  ${RED}❌ MANQUANT — ARRÊT${NC}"
    exit 1
fi

echo ""
echo "✓ Vérification _done sur Expansion12..."
if [ -d /Volumes/Expansion12/sauvetmpo25mai/_done ]; then
    SIZE=$(du -sh /Volumes/Expansion12/sauvetmpo25mai/_done 2>/dev/null | cut -f1)
    echo -e "  ${GREEN}✅ Trouvé (${SIZE})${NC}"
else
    echo -e "  ${RED}❌ MANQUANT — ARRÊT${NC}"
    exit 1
fi

echo ""
echo "=========================================="
echo -e "${YELLOW}📊 ÉTAPE 2 : TAILLE À LIBÉRER${NC}"
echo ""

AFAIRE_SIZE=$(du -sh /Volumes/NAS-LOGO-DATA/AFAIRE+tard 2>/dev/null | cut -f1)
DONE_SIZE=$(du -sh /Volumes/NAS-LOGO-DATA/_done 2>/dev/null | cut -f1)

echo "À supprimer :"
echo "  - /Volumes/NAS-LOGO-DATA/AFAIRE+tard  → ${AFAIRE_SIZE}"
echo "  - /Volumes/NAS-LOGO-DATA/_done        → ${DONE_SIZE}"
echo ""
echo "Total à libérer : ~1,45 To"

echo ""
echo "=========================================="
echo -e "${RED}⚠️  ATTENTION${NC}"
echo "=========================================="
echo ""
echo "Cette opération va supprimer DÉFINITIVEMENT :"
echo "  - AFAIRE+tard/ (310 Go + 44 Go + 1,3 Go + 0 Go)"
echo "  - _done/ (798 Go + contenu)"
echo ""
echo -e "${YELLOW}Assure-toi que :${NC}"
echo "  ✓ Les données sont bien sauvegardées sur Expansion12"
echo "  ✓ Tu as attendu la fin du rsync Phase 3"
echo "  ✓ Aucun processus rsync n'est en cours"
echo ""

# 2. DEMANDE CONFIRMATION
read -p "Tape 'OUI' en majuscules pour confirmer la suppression : " CONFIRM

if [ "$CONFIRM" != "OUI" ]; then
    echo -e "${YELLOW}Suppression annulée${NC}"
    exit 0
fi

echo ""
echo "=========================================="
echo -e "${YELLOW}🗑️  ÉTAPE 3 : SUPPRESSION${NC}"
echo "=========================================="
echo ""

# Suppression AFAIRE+tard
echo "Suppression AFAIRE+tard..."
rm -rf /Volumes/NAS-LOGO-DATA/AFAIRE+tard
if [ $? -eq 0 ]; then
    echo -e "  ${GREEN}✅ AFAIRE+tard supprimé${NC}"
else
    echo -e "  ${RED}❌ Erreur lors de la suppression de AFAIRE+tard${NC}"
    exit 1
fi

echo ""

# Suppression _done
echo "Suppression _done..."
rm -rf /Volumes/NAS-LOGO-DATA/_done
if [ $? -eq 0 ]; then
    echo -e "  ${GREEN}✅ _done supprimé${NC}"
else
    echo -e "  ${RED}❌ Erreur lors de la suppression de _done${NC}"
    exit 1
fi

echo ""
echo "=========================================="
echo -e "${YELLOW}📊 ÉTAPE 4 : VÉRIFICATION FINALE${NC}"
echo "=========================================="
echo ""

# Espace disponible après suppression
df -h /Volumes/NAS-LOGO-DATA | tail -1

echo ""
echo -e "${GREEN}✅ NETTOYAGE TERMINÉ${NC}"
echo ""
echo "Espace libéré : ~1,45 To"
echo "Disponible sur NAS-LOGO-DATA : $(df /Volumes/NAS-LOGO-DATA | tail -1 | awk '{printf "%.2f To", $4/1024/1024}')"

