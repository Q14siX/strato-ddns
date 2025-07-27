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

echo "🔄 Betriebssystem updaten..."
apt-get update -qq 2>&1 >/dev/null && apt-get upgrade -qq 2>&1 >/dev/null

echo "📦 Pakete ggf. installieren..."
apt-get install -yqq \
  python3 \
  python3-pip \
  python3-flask \
  python3-flask-session \
  python3-flask-limiter \
  python3-bcrypt \
  python3-cryptography \
  ca-certificates \
  sudo

echo "🐍 Python Abhängigkeiten ggf. nachinstallieren..."
pip3 install --break-system-packages --quiet --root-user-action=ignore openpyxl

echo "📂 Templateverzeichnis erstellen..."
mkdir -p "$APP_DIR/templates"

echo "👤 Zugangsdaten für Web-Login festlegen..."
read -p "Benutzername: " WEBUSER
read -s -p "Passwort: " WEBPASS

echo "🛠️ Konfigurationsdatei schreiben..."
source <(wget -qO- "$REPO_URL/scripts/strato-ddns-config.sh")

echo "🖥️ Applikation installieren..."
wget -q -O "$APP_DIR/app.py" "$REPO_URL/scripts/strato-ddns-app.py"

echo "📄 Template installieren..."
wget -q -O "$APP_DIR/templates/_header.html" "$REPO_URL/templates/default/_header.html"
wget -q -O "$APP_DIR/templates/_layout.html" "$REPO_URL/templates/default/_layout.html"
wget -q -O "$APP_DIR/templates/config.html" "$REPO_URL/templates/default/config.html"
wget -q -O "$APP_DIR/templates/log.html" "$REPO_URL/templates/default/log.html"
wget -q -O "$APP_DIR/templates/login.html" "$REPO_URL/templates/default/login.html"
wget -q -O "$APP_DIR/templates/logout.html" "$REPO_URL/templates/default/logout.html"
wget -q -O "$APP_DIR/templates/webupdate.html" "$REPO_URL/templates/default/webupdate.html"

echo "🔧 Service erstellen und starten..."
source <(wget -qO- "$REPO_URL/scripts/strato-ddns-service.sh")

SERVER_IP=$(hostname -I | awk '{print $1}')
echo "✅ Installation abgeschlossen..."
echo
echo
echo "🟢 Starten Sie Ihren Browser und rufen Sie das Webfrontend auf."
echo "  http://$SERVER_IP"
echo "ℹ️ Verwenden Sie in der Fritz!Box eine der folgenden Update-URL´s."
echo "  http://$SERVER_IP/update?username=<username>&password=<pass>&myip=<ipaddr>,<ip6addr>"
echo "  http://$SERVER_IP/update?username=<username>&password=<pass>&myip=<ipaddr>"
echo "  http://$SERVER_IP/update?username=<username>&password=<pass>&myip=<ip6addr>"
echo
echo "🆘 Für weitere Informationen nutzen Sie die Hilfe oder das Handbuch Ihrer Fritz!Box."
