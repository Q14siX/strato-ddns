SECRET_KEY=$(openssl rand -hex 64)

cat > "$APP_DIR/config.json" <<EOF
{
  "username": "",
  "password": "",
  "domains": [],
  "webuser": "$WEBUSER",
  "webpass": "$WEBPASS",
  "secret_key": "$SECRET_KEY",
  "mail_settings": {
    "enabled": false,
    "recipients": "",
    "sender": "",
    "subject": "Strato DDNS Update",
    "smtp_user": "",
    "smtp_pass": "",
    "smtp_server": "",
    "smtp_port": "587",
    "notify_on_success": false,
    "notify_on_badauth": true,
    "notify_on_noip": true,
    "notify_on_abuse": true
  }
}
EOF
