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

python3 - <<EOF
import json

config_path = "$CONFIG_FILE"

with open(config_path) as f:
    config = json.load(f)

if config.get("lock"):
    config["lock"] = False
    with open(config_path, "w") as f:
        json.dump(config, f, indent=4)
    print("✅ Sperre wurde entfernt.")
else:
    print("ℹ️  Keine Sperre vorhanden.")
EOF

echo
echo "[+] Starte den Dienst $SERVICE_NAME neu …"
systemctl restart "$SERVICE_NAME"
echo "✅ Dienst $SERVICE_NAME wurde neu gestartet."
