#!/bin/bash
set -e

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
echo "[+] Neue Zugangsdaten für das Web-Frontend festlegen:"
read -p "Benutzername: " WEBUSER
read -s -p "Passwort: " WEBPASS
echo

python3 - <<EOF
import json

with open("$CONFIG_FILE") as f:
    config = json.load(f)

config["webuser"] = "$WEBUSER"
config["webpass"] = "$WEBPASS"

with open("$CONFIG_FILE", "w") as f:
    json.dump(config, f, indent=2)

print("✅ Zugangsdaten wurden aktualisiert.")
EOF

echo "[+] Starte den Dienst $SERVICE_NAME neu …"
systemctl restart "$SERVICE_NAME"
echo "✅ Dienst $SERVICE_NAME wurde neu gestartet."
