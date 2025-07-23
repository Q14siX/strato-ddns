#!/bin/bash
set -e

clear

APP_DIR="/opt/strato-ddns"

if [ "$EUID" -ne 0 ]; then
  echo "❌ Bitte führe dieses Skript als root oder mit sudo aus."
  exit 1
fi

# GitHub-Repo-URL (ohne Datei)
REPO_URL="https://raw.githubusercontent.com/Q14siX/strato-ddns/main"

# Funktion zum direkten Ausführen eines Skripts aus dem Repo
run_remote_script() {
    local script="$1"
    bash <(wget -qO- "$REPO_URL/$script")
}

# Prüfen, ob bereits installiert
if [ ! -f /opt/strato-ddns/installed ]; then
    echo "➡️  Erste Ausführung — Installation wird gestartet…"
    run_remote_script "installer.sh"
    exit 0
fi

# Menü anzeigen
while true; do
    clear
    echo "====== Strato DDNS Verwaltung ======"
    echo "1) Sperre aufheben"
    echo "2) Zugangsdaten ändern"
    echo "9) Deinstallieren"
    echo "X) Beenden"
    echo "===================================="
    read -rp "Bitte wähle eine Option: " option

    case "$option" in
        1)
            echo "🔓 Sperre wird zurückgesetzt…"
            run_remote_script "lock.sh"
            ;;
        2)
            echo "👤 Zugangsdaten werden geändert und Sperre zurücksetzen…"
            run_remote_script "user.sh"
            run_remote_script "lock.sh"
            ;;
        9)
            echo "🗑️ Deinstallation…"
            run_remote_script "installer.sh"
            ;;
        [Xx])
            echo "👋 Beendet."
            exit 0
            ;;
        *)
            echo "❌ Ungültige Auswahl."
            sleep 1
            ;;
    esac
done
