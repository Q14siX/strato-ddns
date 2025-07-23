#!/bin/bash
set -e

# Bildschirm leeren
clear

if [ -d /opt/strato-ddns ]; then
    echo "📥 Lade aktuelles Menü von GitHub …"
else
    echo "🚀 Installation wird gestartet …"
fi

bash <(wget -qO- "https://raw.githubusercontent.com/Q14siX/strato-ddns/main/scripts/menu.sh")
