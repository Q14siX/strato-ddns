#!/bin/bash
set -e

clear

APP_DIR="/opt/strato-ddns"

if [ "$EUID" -ne 0 ]; then
  echo "❌ Bitte führe dieses Skript als root oder mit sudo aus."
  exit 1
fi

# erster Aufruf → Installation
if [ ! -d "$APP_DIR" ]; then
  echo "🚀 Erster Start erkannt. Starte Installation…"
  ./installer.sh
  exit 0
fi

# Funktion zum Warten
pause() {
  echo
  read -p "↩️  Drücken Sie [Enter], um ins Menü zurückzukehren…"
}

# Menü
while true; do
  echo "=============================="
  echo " Strato-DDNS Verwaltung"
  echo "=============================="
  echo
  echo "1) Sperre zurücksetzen"
  echo "2) Zugangsdaten ändern"
  echo "9) Deinstallieren"
  echo "X) Beenden"
  echo
  read -p "Bitte wählen: " choice

  case "$choice" in
    1)
      echo "🔓 Sperre wird zurückgesetzt…"
      ./lock.sh
      pause
      ;;
    2)
      echo "👤 Zugangsdaten werden geändert…"
      ./user.sh
      echo "🔓 Sperre wird zurückgesetzt…"
      ./lock.sh
      pause
      ;;
    9)
      echo "🗑️ Deinstallation…"
      ./installer.sh
      exit 0
      ;;
    [Xx])
      echo "👋 Beende…"
      exit 0
      ;;
    *)
      echo "❌ Ungültige Eingabe!"
      sleep 1
      ;;
  esac
done
