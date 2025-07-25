#!/bin/bash
set -e

# =============================================
# Strato DDNS - Sperre aufheben
# Datei: strato-ddns-lock.sh
# Entfernt ggf. gesetzte Sperren (z.B. nach
# zu vielen Fehlversuchen) und startet den Dienst neu.
# =============================================

CONFIG_FILE="/opt/strato-ddns/config.json"
SERVICE_NAME="strato-ddns"

if [ "$EUID" -ne 0 ]; then
  echo "❌ Bitte führe dieses Skript als root oder mit sudo aus."
  exit 1
fi

if [ ! -f "$CONFIG_FILE" ]; then
  echo "❌ Konfigurationsdatei $CONFIG_FILE nicht gefunden!"
  exit 1
fi

echo
echo "🔓 Hebe eventuelle Sperren auf …"
echo
echo "[+] Starte den Dienst $SERVICE_NAME neu …"
systemctl restart "$SERVICE_NAME"
echo "✅ Dienst $SERVICE_NAME wurde neu gestartet."
