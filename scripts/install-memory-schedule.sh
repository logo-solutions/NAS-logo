#!/usr/bin/env bash
# Installe le LaunchAgent de consolidation mémoire nocturne
# Usage: ./scripts/install-memory-schedule.sh [uninstall]

set -euo pipefail

LABEL="com.logo.consolidate-nas-memory"
PLIST_SRC="/Volumes/logousb/SSD/Projects/NAS-logo/scripts/consolidate-memory.plist"
PLIST_DST="$HOME/Library/LaunchAgents/$LABEL.plist"

if [[ "${1:-}" == "uninstall" ]]; then
  launchctl unload "$PLIST_DST" 2>/dev/null || true
  rm -f "$PLIST_DST"
  echo "LaunchAgent désinstallé."
  exit 0
fi

# Vérifications préalables
if [[ ! -f "$PLIST_SRC" ]]; then
  echo "ERREUR: plist introuvable: $PLIST_SRC"
  exit 1
fi

if [[ ! -x "/Volumes/logousb/SSD/Projects/NAS-logo/scripts/consolidate-memory.sh" ]]; then
  echo "ERREUR: script non exécutable. Lance: chmod +x scripts/consolidate-memory.sh"
  exit 1
fi

# Copie et chargement
cp "$PLIST_SRC" "$PLIST_DST"
launchctl unload "$PLIST_DST" 2>/dev/null || true
launchctl load "$PLIST_DST"

echo "LaunchAgent installé — tourne chaque nuit à 02:00"
echo "Logs: /tmp/consolidate-nas-memory.log"
echo "Pour désinstaller: ./scripts/install-memory-schedule.sh uninstall"
echo "Pour tester maintenant: launchctl start $LABEL"
