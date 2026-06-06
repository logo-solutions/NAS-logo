#!/bin/bash
# Arrêt propre et gracieux de tous les services avant redémarrage

set -e
export DOCKER_HOST=unix:///Users/logo/.colima/default/docker.sock
export PATH=/opt/homebrew/bin:/opt/homebrew/sbin:/usr/local/bin:/usr/bin:/bin

SERVICES_DIR=$HOME
TIMEOUT=30

echo "🛑 Arrêt gracieux des services..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Arrêter immich
if [ -d "$SERVICES_DIR/immich" ]; then
  echo "⏹️  Arrêt Immich..."
  cd "$SERVICES_DIR/immich"
  timeout $TIMEOUT docker compose down --remove-orphans || true
  sleep 2
fi

# Arrêter paperless
if [ -d "$SERVICES_DIR/paperless" ]; then
  echo "⏹️  Arrêt Paperless..."
  cd "$SERVICES_DIR/paperless"
  timeout $TIMEOUT docker compose down --remove-orphans || true
  sleep 2
fi

# Arrêter n8n
if [ -d "$SERVICES_DIR/n8n" ]; then
  echo "⏹️  Arrêt n8n..."
  cd "$SERVICES_DIR/n8n"
  timeout $TIMEOUT docker compose down --remove-orphans || true
  sleep 2
fi

# Attendre que les conteneurs se terminent
echo "⏳ Attente de la fin des conteneurs (max ${TIMEOUT}s)..."
START=$(date +%s)
while docker ps -q | wc -l | grep -qv '^0$'; do
  if [ $(($(date +%s) - START)) -gt $TIMEOUT ]; then
    echo "⚠️  Timeout atteint, force l'arrêt des conteneurs restants..."
    docker ps -q | xargs -r docker kill || true
    break
  fi
  sleep 1
done

# Arrêter Colima
echo "🛑 Arrêt de Colima..."
colima stop || true
sleep 2

# Flush des buffers disque
echo "💾 Flush des buffers disque..."
sync
sync
sleep 1

# Unmount (démonter proprement sans éjecter)
echo "🔌 Démontage des volumes..."
diskutil unmount "/Volumes/NAS-LOGO-DATA" 2>/dev/null || echo "⚠️  /Volumes/NAS-LOGO-DATA non trouvé"
diskutil unmount "/Volumes/Expansion12" 2>/dev/null || echo "⚠️  /Volumes/Expansion12 non trouvé"
sleep 2

echo ""
echo "✅ Arrêt gracieux terminé"
echo "🔄 Redémarrage du système..."
sleep 2

osascript -e 'tell application "System Events" to restart'
