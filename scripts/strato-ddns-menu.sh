#!/bin/bash
set -e

# =============================================
# Strato DDNS Verwaltung - Menü
# Datei: strato-ddns-menu.sh
# Lädt und startet Unterskripte aus dem Repo.
# =============================================

# Prüfen, ob als root
if [ "$EUID" -ne 0 ]; then
  echo "❌ Bitte führe dieses Skript als root oder mit sudo aus."
  exit 1
fi

# GitHub-Repo-URL (Basis für alle Skripte)
REPO_URL="https://raw.githubusercontent.com/Q14siX/strato-ddns/main/scripts"

# Bildschirm leeren
clear

# Funktion zum direkten Ausführen eines Skripts aus dem Repo
run_remote_script() {
    local script="$1"
    bash <(wget -qO- "$REPO_URL/$script")
    echo
    read -rp "➡️  Drücke [ENTER], um zurück zum Menü zu gelangen …"
}

# Prüfen, ob bereits installiert (Verzeichnis vorhanden?)
if [ ! -d /opt/strato-ddns ]; then
    echo "🚀 Installation wird gestartet …"
    run_remote_script "strato-ddns-setup.sh"
    echo
    echo "✅ Installation abgeschlossen. Starte das Menü …"
    sleep 1
else
    echo "📥 Lade aktuelles Menü von GitHub …"
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
    echo "     ➝ Ändert die Zugangsdaten für das Web-Frontend."
    echo
    echo "  3) 🔑 System updaten"
    echo "     ➝ Aktualisiert alle lokalen Dateien, inkl. dem Web-Frontend."
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
            run_remote_script "strato-ddns-lock.sh"
            ;;
        2)
            echo "🔄 Starte: Zugangsdaten ändern …"
            sleep 1
            run_remote_script "strato-ddns-credentials.sh"
            ;;
        3)
            echo "🔄 Starte: Updatevorgang …"
            sleep 1
            run_remote_script "strato-ddns-update.sh"
            ;;
        9)
            echo "🔄 Starte: Deinstallation …"
            sleep 1
            bash <(wget -qO- "$REPO_URL/strato-ddns-deinstall.sh")
            echo
            read -rp "➡️  Drücke [ENTER], um das Menü zu schließen …"
            clear
            echo "🗑️  Dienst wurde deinstalliert. Bis bald!"
            sleep 1
            clear
            exit 0
            ;;
        [Xx])
            echo "👋 Bis bald!"
            sleep 1
            clear
            exit 0
            ;;
        *)
            echo "❌ Ungültige Auswahl. Bitte erneut versuchen."
            sleep 1
            ;;
    esac
done
