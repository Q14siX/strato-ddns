#!/bin/bash
set -e

# ========== App einspielen ==========
echo "🐍 Neuste Version der Applikation wird aktualisiert."
wget -q -O "$APP_DIR/app.py" "$REPO_URL/scripts/strato-ddns-app.py"

# ========== Templates einspielen ==========
echo "📄 Neuste Version des Templates wird aktualisiert."
wget -q -O "$APP_DIR/templates/_header.html" "$REPO_URL/templates/default/_header.html"
wget -q -O "$APP_DIR/templates/_layout.html" "$REPO_URL/templates/default/_layout.html"
wget -q -O "$APP_DIR/templates/config.html" "$REPO_URL/templates/default/config.html"
wget -q -O "$APP_DIR/templates/log.html" "$REPO_URL/templates/default/log.html"
wget -q -O "$APP_DIR/templates/login.html" "$REPO_URL/templates/default/login.html"
wget -q -O "$APP_DIR/templates/webupdate.html" "$REPO_URL/templates/default/webupdate.html"
