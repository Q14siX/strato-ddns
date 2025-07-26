#!/bin/bash
set -e

# =============================================
# Strato DDNS - Updaten
# Datei: strato-ddns-update.sh
# =============================================

if [ "$EUID" -ne 0 ]; then
  echo "❌ Bitte führe dieses Skript als root oder mit sudo aus."
  exit 1
fi

echo
echo "🔄 Aktualisiere die lokalen Dateien …"
echo

# GitHub-Repo-URL (Basis für alle Skripte)
REPO_URL="https://raw.githubusercontent.com/Q14siX/strato-ddns/main"

APP_DIR="/opt/strato-ddns"
SERVICE_FILE="/etc/systemd/system/strato-ddns.service"

systemctl stop strato-ddns || true
systemctl disable strato-ddns || true
rm -f "$SERVICE_FILE"
systemctl daemon-reload

echo "== System-Update & Installation benötigter Pakete =="
apt-get update && apt-get upgrade
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

# ========== App und Templates einspielen ==========
wget -q -O "$APP_DIR/app.py" "$REPO_URL/scripts/strato-ddns-app.py"

wget -q -O "$APP_DIR/templates/_header.html" "$REPO_URL/templates/default/_header.html"
wget -q -O "$APP_DIR/templates/_layout.html" "$REPO_URL/templates/default/_layout.html"
wget -q -O "$APP_DIR/templates/config.html" "$REPO_URL/templates/default/config.html"
wget -q -O "$APP_DIR/templates/log.html" "$REPO_URL/templates/default/log.html"
wget -q -O "$APP_DIR/templates/login.html" "$REPO_URL/templates/default/login.html"
wget -q -O "$APP_DIR/templates/webupdate.html" "$REPO_URL/templates/default/webupdate.html"

# ========== Systemd-Service einspielen ==========
source <(wget -qO- "$REPO_URL/scripts/strato-ddns-service.sh")

echo "✅ Update durchgeführt."
