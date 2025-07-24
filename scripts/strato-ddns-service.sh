#!/bin/bash

# ========== Systemd-Service schreiben ==========
cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=Strato DDNS Webapp
After=network.target

[Service]
WorkingDirectory=$APP_DIR
ExecStart=/usr/bin/python3 app.py
Restart=always
User=root

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now strato-ddns
