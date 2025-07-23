#!/bin/bash
set -e

# Bildschirm leeren
clear

REPO_BASE_URL="https://raw.githubusercontent.com/Q14siX/strato-ddns/main"

if [ -d /opt/strato-ddns ]; then
    echo "📥 Lade aktuelles Menü von GitHub …"
else
    echo "🚀 Installation wird gestartet …"
fi

bash <(wget -qO- "$REPO_BASE_URL/scripts/strato-ddns-menu.sh")
