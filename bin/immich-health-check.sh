#!/bin/bash

PING_ENDPOINT="http://localhost:2283/api/server/ping"
CPU_THRESHOLD=90
RAM_THRESHOLD=85
LOG_FILE="/Volumes/NAS-LOGO-DATA/journaux/immich-health.log"

log_event() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

# Check Immich API
if ! curl -s -m 5 "$PING_ENDPOINT" 2>/dev/null | grep -q '"res":"pong"'; then
  log_event "❌ Immich API DOWN — relaunching Colima"
  colima stop >/dev/null 2>&1
  sleep 5
  colima start >/dev/null 2>&1
  log_event "✓ Colima restarted"
  exit 1
fi

# Check Colima CPU/RAM
COLIMA_PID=$(pgrep -f "com.apple.Virtualization.VirtualMachine" | head -1)
if [ -z "$COLIMA_PID" ]; then
  log_event "❌ Colima PID not found"
  exit 1
fi

CPU=$(ps aux | awk -v pid=$COLIMA_PID '$2==pid {print $3}' | cut -d. -f1)
RAM=$(ps aux | awk -v pid=$COLIMA_PID '$2==pid {print $4}' | cut -d. -f1)

if [ "$CPU" -gt "$CPU_THRESHOLD" ] 2>/dev/null; then
  log_event "⚠️  Colima CPU HIGH: ${CPU}% (threshold: ${CPU_THRESHOLD}%)"
fi

if [ "$RAM" -gt "$RAM_THRESHOLD" ] 2>/dev/null; then
  log_event "⚠️  Colima RAM HIGH: ${RAM}% (threshold: ${RAM_THRESHOLD}%)"
fi

log_event "✓ Health check OK — Immich: online, Colima: CPU ${CPU}%, RAM ${RAM}%"
