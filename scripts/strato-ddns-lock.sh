#!/bin/bash
set -e

if [ "$EUID" -ne 0 ]; then
  echo "❌ Bitte führe dieses Skript als root oder mit sudo aus."
  exit 1
fi

echo "🔄 Starte den Strato-DDNS Dienst neu, um alle Sperren zurückzusetzen …"
systemctl restart strato-ddns
echo "✅ Alle Sperren wurden entfernt und der Dienst wurde neu gestartet."
