#!/bin/bash
set -e

CONFIG_FILE="/opt/strato-ddns/config.json"
SERVICE_NAME="strato-ddns"
REPO_URL="https://raw.githubusercontent.com/Q14siX/strato-ddns/main"

if [ "$EUID" -ne 0 ]; then
  echo "❌ Bitte führe dieses Skript als root oder mit sudo aus."
  exit 1
fi

if [ ! -f "$CONFIG_FILE" ]; then
  echo "❌ Konfigurationsdatei $CONFIG_FILE nicht gefunden!"
  exit 1
fi

echo
echo "⚠️  Dieses Skript wird die Strato-Zugangsdaten (Benutzername, Passwort, Domains) unwiderruflich löschen."
echo "⚠️  Die Web-Frontend-Zugangsdaten werden auf die neuen Werte gesetzt."
echo
read -p "Möchten Sie fortfahren? [j/N]: " confirm

if [[ ! "$confirm" =~ ^[Jj]$ ]]; then
  echo "🚫 Abgebrochen."
  exit 0
fi

echo
echo "[+] Neue Zugangsdaten für das Web-Frontend festlegen:"
read -p "Benutzername: " WEBUSER
read -s -p "Passwort: " WEBPASS
echo

# Passwort hashen
HASHED_WEBPASS=$(echo "$WEBPASS" | python3 -c "import bcrypt,sys; print(bcrypt.hashpw(sys.stdin.read().strip().encode(), bcrypt.gensalt()).decode())")

# Salt und Secret Key aus der config holen
SALT=$(python3 -c "import json; c=json.load(open('$CONFIG_FILE')); print(c['salt'])")
SECRET_KEY=$(python3 -c "import json; c=json.load(open('$CONFIG_FILE')); print(c['secret_key'])")

# neue config zusammenbauen
python3 - <<EOF
import json

config_path = "$CONFIG_FILE"

with open(config_path) as f:
    config = json.load(f)

config['webuser'] = "$WEBUSER"
config['webpass_hash'] = "$HASHED_WEBPASS"

# Strato Daten zurücksetzen
config['username_enc'] = ""
config['password_enc'] = ""
config['domains'] = []

with open(config_path, 'w') as f:
    json.dump(config, f, indent=4)

print("✅ Zugangsdaten aktualisiert und Strato-Daten entfernt.")
EOF

echo "[+] Starte den Dienst $SERVICE_NAME neu…"
systemctl restart "$SERVICE_NAME"
echo "✅ Dienst $SERVICE_NAME wurde neu gestartet."

echo
echo "[+] Hebe eventuelle Sperre auf …"
bash <(wget -qO- "$REPO_URL/lock.sh")
echo "✅ Sperre wurde aufgehoben."
