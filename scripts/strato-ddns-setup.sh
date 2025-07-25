#!/bin/bash
set -e

# =============================================
# Strato DDNS - Installation & Deinstallation
# Datei: strato-ddns-setup.sh
# =============================================

if [ "$EUID" -ne 0 ]; then
  echo "❌ Bitte führe dieses Skript als root oder mit sudo aus."
  exit 1
fi

# GitHub-Repo-URL (Basis für alle Skripte)
REPO_URL="https://raw.githubusercontent.com/Q14siX/strato-ddns/main"

APP_DIR="/opt/strato-ddns"
SERVICE_FILE="/etc/systemd/system/strato-ddns.service"

# Funktion zum direkten Ausführen eines Skripts aus dem Repo
run_remote_script() {
    local script="$1"
    source <(wget -qO- "$REPO_URL/$script")
}

echo "== System-Update & Installation benötigter Pakete =="
apt-get update
apt-get install -y \
  python3 \
  python3-pip \
  python3-flask \
  python3-flask-session \
  python3-flask-limiter \
  python3-bcrypt \
  python3-cryptography \
  ca-certificates \
  sudo

echo "== Python-Abhängigkeiten (pip) installieren =="
pip3 install --upgrade pip

pip3 install --break-system-packages openpyxl

mkdir -p "$APP_DIR/templates"

echo "[+] Zugangsdaten für Web-Login festlegen:"
read -p "Benutzername: " WEBUSER
read -s -p "Passwort: " WEBPASS
echo

# ====== config.json erstellen über ausgelagertes Skript ======
run_remote_script "scripts/strato-ddns-config.sh"

# ========== App und Templates einspielen ==========
run_remote_script "scripts/strato-ddns-app.sh"

run_remote_script "templates/default/strato-ddns-template-default-log.sh"
run_remote_script "templates/default/strato-ddns-template-default-config.sh"
run_remote_script "templates/default/strato-ddns-template-default-login.sh"
run_remote_script "templates/default/strato-ddns-template-default-update.sh"

# ========== Systemd-Service einspielen ==========
run_remote_script "scripts/strato-ddns-service.sh"

SERVER_IP=$(hostname -I | awk '{print $1}')
echo
echo "✅ Installation abgeschlossen: http://$SERVER_IP"
echo
echo "ℹ️ Verwenden Sie in der Fritz!Box eine der folgenden Update-URL´s."
echo "  http://$SERVER_IP/auto?username=<username>&password=<pass>&myip=<ipaddr>,<ip6addr>"
echo "  http://$SERVER_IP/auto?username=<username>&password=<pass>&myip=<ipaddr>"
echo "  http://$SERVER_IP/auto?username=<username>&password=<pass>&myip=<ip6addr>"
echo
echo "🆘 Für weitere Informationen nutzen Sie die Hilfe oder das Handbuch Ihrer Fritz!Box."
