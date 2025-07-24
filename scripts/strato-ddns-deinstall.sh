#!/bin/bash
set -e

APP_DIR="/opt/strato-ddns"
SERVICE_FILE="/etc/systemd/system/strato-ddns.service"

# Deinstallation bei bestehender Installation
if [ -d "$APP_DIR" ]; then
  echo "Starte Deinstallation…"
  systemctl stop strato-ddns || true
  systemctl disable strato-ddns || true
  rm -f "$SERVICE_FILE"
  systemctl daemon-reload
  rm -rf "$APP_DIR"
  echo "✅ Deinstallation abgeschlossen."
  exit 0
fi
