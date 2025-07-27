#!/bin/bash
set -e

# =============================================
# Strato DDNS - Updaten
# Datei: strato-ddns-webupdate.sh
# =============================================

REPO_URL="https://raw.githubusercontent.com/Q14siX/strato-ddns/main"
APP_DIR="/opt/strato-ddns"

if [ "$EUID" -ne 0 ]; then
  echo "❌ Keine Rechte..."
  exit 1
fi

echo "🔄 Betriebssystem updaten..."
apt-get update -qq 2>&1 >/dev/null && apt-get upgrade -qq 2>&1 >/dev/null

echo "📦 Pakete ggf. nachinstallieren..."
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

echo "🖥️ Applikation aktualisieren..."
wget -q -O "$APP_DIR/app.py" "$REPO_URL/scripts/strato-ddns-app.py"

echo "📄 Template aktualisieren..."
wget -q -O "$APP_DIR/templates/_header.html" "$REPO_URL/templates/default/_header.html"
wget -q -O "$APP_DIR/templates/_layout.html" "$REPO_URL/templates/default/_layout.html"
wget -q -O "$APP_DIR/templates/config.html" "$REPO_URL/templates/default/config.html"
wget -q -O "$APP_DIR/templates/log.html" "$REPO_URL/templates/default/log.html"
wget -q -O "$APP_DIR/templates/login.html" "$REPO_URL/templates/default/login.html"
wget -q -O "$APP_DIR/templates/webupdate.html" "$REPO_URL/templates/default/webupdate.html"
                
echo "🛠️ Service-Dienste werden in Kürze neu gestartet..."
echo "🔁 Neustart wird jetzt durchgeführt..." | tee /tmp/strato-restart.log
nohup bash -c 'sleep 2 && systemctl daemon-reload && systemctl restart strato-ddns' >/dev/null 2>&1 &
