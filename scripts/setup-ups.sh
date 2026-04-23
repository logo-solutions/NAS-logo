#!/bin/bash
# Setup apcupsd pour APC Back-UPS BX750MI sur Mac Mini (Apple Silicon)
set -euo pipefail

CONF="/opt/homebrew/etc/apcupsd/apcupsd.conf"

echo "==> Installation apcupsd"
if brew list apcupsd &>/dev/null; then
  echo "    apcupsd déjà installé"
else
  brew install apcupsd
fi

echo "==> Configuration"
cat > "$CONF" <<'EOF'
UPSNAME NAS-BX750MI
UPSCABLE usb
UPSTYPE usb
DEVICE
UPSCLASS standalone
UPSMODE disable

BATTERYLEVEL 20
MINUTES 5
TIMEOUT 0

ANNOY 300
ANNOYDELAY 60
NOLOGON disable
KILLDELAY 0

NETSERVER on
NISIP 127.0.0.1
NISPORT 3551

EVENTSFILE /opt/homebrew/var/log/apcupsd.events
EVENTSLIMIT 10

STATFILE /opt/homebrew/var/run/apcupsd.status
LOGSTATS off
STATTIME 0

DATATIME 0
FACILITY LOG_DAEMON
EOF

echo "==> Démarrage du service"
sudo brew services start apcupsd
sleep 3

echo "==> Vérification"
if apcaccess status 2>/dev/null | grep -q "STATUS"; then
  echo ""
  apcaccess status | grep -E "^(UPSNAME|STATUS|BCHARGE|TIMELEFT|BATTV|LINEV|MODEL)"
  echo ""
  echo "OK — apcupsd opérationnel"
else
  echo "ERREUR — apcupsd ne répond pas, vérifier : sudo brew services list"
  exit 1
fi
