#!/bin/bash
set -e

clear

# GitHub-Repo-URL (ohne Datei)
REPO_URL="https://raw.githubusercontent.com/Q14siX/strato-ddns/main"

# Prüfen, ob als root
if [ "$EUID" -ne 0 ]; then
  echo "❌ Bitte führe dieses Skript als root oder mit sudo aus."
  exit 1
fi

# Funktion zum direkten Ausführen eines Skripts aus dem Repo
run_remote_script() {
    local script="$1"
    bash <(wget -qO- "$REPO_URL/$script")
    echo
    read -rp "➡️  Drücke [ENTER], um zurück zum Menü zu gelangen …"
}

# Prüfen, ob bereits installiert (Verzeichnis vorhanden?)
if [ ! -d /opt/strato-ddns ]; then
    echo "🚀 Erste Ausführung erkannt — Installation wird gestartet …"
    run_remote_script "installer.sh"
    echo
    echo "✅ Installation abgeschlossen. Starte das Menü …"
    sleep 1
fi

# Menü anzeigen
while true; do
    clear
    echo "🌐 ====== Strato DDNS Verwaltung ====== 🌐"
    echo
    echo "  1) 🔓 Sperre aufheben"
    echo "     ➝ Entfernt eine mögliche Sperre nach zu vielen Login-Versuchen."
    echo
    echo "  2) 🔑 Zugangsdaten ändern"
    echo "     ➝ Ändert die Zugangsdaten für das Web-Frontend und Strato."
    echo "        (Sperre wird ggf. durch user.sh selbst aufgehoben)"
    echo
    echo "  9) 🗑️ Deinstallieren"
    echo "     ➝ Entfernt den Dienst komplett vom System."
    echo
    echo "  X) 👋 Beenden"
    echo "     ➝ Beendet dieses Menü."
    echo
    echo "========================================"
    read -rp "Bitte wähle eine Option: " option

    case "$option" in
        1)
            echo "🔄 Starte: Sperre aufheben …"
            sleep 1
            run_remote_script "lock.sh"
            ;;
        2)
            echo "🔄 Starte: Zugangsdaten ändern …"
            sleep 1
            run_remote_script "user.sh"
            ;;
        9)
            echo "🔄 Starte: Deinstallation …"
            sleep 1
            bash <(wget -qO- "$REPO_URL/installer.sh")
            echo
            read -rp "➡️  Drücke [ENTER], um das Menü zu schließen …"
            clear
            echo "🗑️  Dienst wurde deinstalliert. Bis bald!"
            exit 0
            ;;
        [Xx])
            echo "👋 Bis bald!"
            exit 0
            ;;
        *)
            echo "❌ Ungültige Auswahl. Bitte erneut versuchen."
            sleep 1
            ;;
    esac
done
