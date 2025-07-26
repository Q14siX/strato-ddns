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
    local github="$1"
    local local="$2"
    wget -O "$local" "$github"
}

echo "== System-Update & Installation benötigter Pakete =="
apt-get update -y && apt-get upgrade -y
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

echo "== Python-Abhängigkeiten installieren =="
pip3 install --break-system-packages openpyxl

mkdir -p "$APP_DIR/templates"

echo "[+] Zugangsdaten für Web-Login festlegen:"
read -p "Benutzername: " WEBUSER
read -s -p "Passwort: " WEBPASS
echo

# ====== config.json erstellen über ausgelagertes Skript ======
run_remote_script "scripts/strato-ddns-config.sh"

# ========== App und Templates einspielen ==========
run_remote_script "$REPO_URL/scripts/strato-ddns-app.py" "$APP_DIR/app.py"

run_remote_script "$REPO_URL/templates/default/_header.html" "$APP_DIR/templates/_header.html"
run_remote_script "$REPO_URL/templates/default/_layout.html" "$APP_DIR/templates/_layout.html"
run_remote_script "$REPO_URL/templates/default/config.html" "$APP_DIR/templates/config.html"
run_remote_script "$REPO_URL/templates/default/log.html" "$APP_DIR/templates/log.html"
run_remote_script "$REPO_URL/templates/default/login.html" "$APP_DIR/templates/login.html"
run_remote_script "$REPO_URL/templates/default/webupdate.html" "$APP_DIR/templates/webupdate.html"

# ========== Systemd-Service einspielen ==========
bash "$REPO_URL/scripts/strato-ddns-service.sh"

SERVER_IP=$(hostname -I | awk '{print $1}')
echo
echo "✅ Installation abgeschlossen: http://$SERVER_IP"
echo
echo "ℹ️ Verwenden Sie in der Fritz!Box eine der folgenden Update-URL´s."
echo "  http://$SERVER_IP/update?username=<username>&password=<pass>&myip=<ipaddr>,<ip6addr>"
echo "  http://$SERVER_IP/update?username=<username>&password=<pass>&myip=<ipaddr>"
echo "  http://$SERVER_IP/update?username=<username>&password=<pass>&myip=<ip6addr>"
echo
echo "🆘 Für weitere Informationen nutzen Sie die Hilfe oder das Handbuch Ihrer Fritz!Box."
