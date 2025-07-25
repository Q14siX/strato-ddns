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

rm -rf "$APP_DIR/templates"
mkdir -p "$APP_DIR/templates"
rm "$APP_DIR/app.py"

# ========== App und Templates einspielen ==========
run_remote_script "scripts/strato-ddns-app.sh"

run_remote_script "templates/default/strato-ddns-template-default-log.sh"
run_remote_script "templates/default/strato-ddns-template-default-config.sh"
run_remote_script "templates/default/strato-ddns-template-default-login.sh"
run_remote_script "templates/default/strato-ddns-template-default-update.sh"

# ========== Systemd-Service einspielen ==========
run_remote_script "scripts/strato-ddns-service.sh"

echo "✅ Update durchgeführt."
