#!/bin/bash
set -e

# =============================================
# Strato DDNS - Installation & Deinstallation
# Datei: strato-ddns-setup.sh
# Installiert oder entfernt den Strato-DDNS-Dienst.
# =============================================

if [ "$EUID" -ne 0 ]; then
  echo "❌ Bitte führe dieses Skript als root oder mit sudo aus."
  exit 1
fi

APP_DIR="/opt/strato-ddns"
SERVICE_FILE="/etc/systemd/system/strato-ddns.service"
PYTHON_PACKAGES="flask flask-session flask-limiter bcrypt cryptography"

if [ -d "$APP_DIR" ]; then
  echo "== Strato-DDNS scheint installiert zu sein =="
  echo "Starte Deinstallation…"
  systemctl stop strato-ddns || true
  systemctl disable strato-ddns || true
  rm -f "$SERVICE_FILE"
  systemctl daemon-reload
  rm -rf "$APP_DIR"
  echo "✅ Deinstallation abgeschlossen."
  exit 0
fi

echo "== System-Update & Installation benötigter Pakete =="
apt-get update
apt-get install -y python3 python3-pip

echo "== Installiere Python-Module =="
pip3 install --quiet --root-user-action=ignore $PYTHON_PACKAGES >/dev/null

mkdir -p "$APP_DIR/templates"

echo "[+] Zugangsdaten für Web-Login festlegen:"
read -p "Benutzername: " WEBUSER
read -s -p "Passwort: " WEBPASS
echo

HASHED_WEBPASS=$(echo "$WEBPASS" | python3 -c "import bcrypt,sys; print(bcrypt.hashpw(sys.stdin.read().strip().encode(), bcrypt.gensalt()).decode())")
SALT=$(python3 -c "import base64,os; print(base64.urlsafe_b64encode(os.urandom(16)).decode())")
SECRET_KEY=$(python3 -c "import base64,os; print(base64.urlsafe_b64encode(os.urandom(24)).decode())")

cat > "$APP_DIR/config.json" <<EOF
{
  "username_enc": "",
  "password_enc": "",
  "domains": [],
  "webuser": "$WEBUSER",
  "webpass_hash": "$HASHED_WEBPASS",
  "salt": "$SALT",
  "secret_key": "$SECRET_KEY"
}
EOF

cat > "$APP_DIR/app.py" <<'EOF_PY'
from flask import Flask, render_template, request, redirect, url_for, session, Response
import requests, json, os, base64
from bcrypt import checkpw
from flask_limiter import Limiter
from flask_limiter.util import get_remote_address
from flask_limiter.errors import RateLimitExceeded
from cryptography.hazmat.primitives.kdf.pbkdf2 import PBKDF2HMAC
from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.backends import default_backend
from cryptography.fernet import Fernet
from datetime import datetime, timedelta
from collections import defaultdict

CONFIG_FILE = os.path.join(os.path.dirname(__file__), 'config.json')

def load_config():
    with open(CONFIG_FILE) as f: return json.load(f)

config = load_config()

app = Flask(__name__)
app.secret_key = base64.urlsafe_b64decode(config["secret_key"])
limiter = Limiter(app=app, key_func=get_remote_address, storage_uri="memory://")

def derive_key(password, salt):
    kdf = PBKDF2HMAC(algorithm=hashes.SHA256(), length=32, salt=salt, iterations=100000, backend=default_backend())
    return base64.urlsafe_b64encode(kdf.derive(password.encode()))

def encrypt(value, password, salt): return Fernet(derive_key(password, salt)).encrypt(value.encode()).decode()
def decrypt(token, password, salt): return Fernet(derive_key(password, salt)).decrypt(token.encode()).decode()
def save_config(c): open(CONFIG_FILE,'w').write(json.dumps(c,indent=4))
def verify_password(pw, pw_hash): return checkpw(pw.encode(), pw_hash.encode())
def get_public_ip():
    try: return requests.get("https://api.ipify.org").text
    except: return None

@app.errorhandler(RateLimitExceeded)
def handle_ratelimit(e):
    if request.endpoint=="login":
        return render_template("login.html",error=str(e.description),disabled=True),429
    return "Too Many Requests",429

failed_attempts_auto = defaultdict(list)

@app.route('/',methods=['GET','POST'])
def index():
    if not session.get('logged_in'): return redirect(url_for('login'))
    config=load_config()
    salt=base64.urlsafe_b64decode(config['salt'])
    ip=get_public_ip()
    if request.method=='POST':
        config['username_enc']=encrypt(request.form['username'],session['webpass'],salt)
        config['password_enc']=encrypt(request.form['password'],session['webpass'],salt)
        config['domains']=[d.strip() for d in request.form['domains'].splitlines() if d.strip()]
        save_config(config)
        return redirect(url_for('index'))
    try: username=decrypt(config['username_enc'],session['webpass'],salt)
    except: username=''
    try: password=decrypt(config['password_enc'],session['webpass'],salt)
    except: password=''
    domains_str="\n".join(config['domains'])
    return render_template('index.html',ip=ip,username=username,password=password,domains=domains_str)

@app.route('/login',methods=['GET','POST'])
@limiter.limit("5 per hour", methods=["POST"], error_message="Zu viele Fehlversuche. Bitte später erneut versuchen.")
def login():
    config=load_config()
    error,disabled=None,False
    if request.method=='POST':
        user,pw=request.form['username'],request.form['password']
        if user==config['webuser'] and verify_password(pw,config['webpass_hash']):
            session['logged_in']=True
            session['webpass']=pw
            return redirect(url_for('index'))
        else: error="Falsche Zugangsdaten"
    return render_template('login.html',error=error,disabled=disabled)

@app.route('/logout')
def logout():
    session.clear()
    return redirect(url_for('login'))

@app.route('/update')
def update():
    if not session.get('logged_in'): return redirect(url_for('login'))
    config=load_config()
    salt=base64.urlsafe_b64decode(config['salt'])
    username=decrypt(config['username_enc'],session['webpass'],salt)
    password=decrypt(config['password_enc'],session['webpass'],salt)
    ip=get_public_ip()
    hostnames=config['domains']
    results=[]
    for domain in hostnames:
        try:
            resp=requests.get(
                f"https://{username}:{password}@dyndns.strato.com/nic/update",
                params={'hostname':domain,'myip':ip},timeout=10
            )
            text=resp.text.strip() if resp.status_code==200 else f"error {resp.status_code}"
        except Exception as e: text=f"error {e}"
        results.append((domain,text))
    return render_template('update.html',ip=ip,results=results)

@app.route('/auto')
def auto():
    config=load_config()
    salt=base64.urlsafe_b64decode(config['salt'])
    req_user,req_pass=request.args.get('username'),request.args.get('password')
    req_ip=request.args.get('myip')
    ip_list = [i.strip() for i in req_ip.split(',')] if req_ip else [get_public_ip()]
    client_ip = request.remote_addr

    now = datetime.now()
    failed_attempts_auto[client_ip] = [t for t in failed_attempts_auto[client_ip] if now - t < timedelta(hours=1)]

    if len(failed_attempts_auto[client_ip]) >= 5:
        return Response(f"abuse {ip_list[0]}",mimetype='text/plain')

    if not(req_user==config['webuser'] and verify_password(req_pass,config['webpass_hash'])):
        failed_attempts_auto[client_ip].append(now)
        return Response(f"badauth {ip_list[0]}",mimetype='text/plain')

    try:
        username=decrypt(config['username_enc'],req_pass,salt)
        password=decrypt(config['password_enc'],req_pass,salt)
    except:
        return Response(f"configerror {ip_list[0]}",mimetype='text/plain')

    hostnames=config['domains']
    worst="nochg"
    worst_ip=ip_list[0]
    priority=["911","nohost","badauth","notfqdn","badagent","abuse","good","nochg"]

    for domain in hostnames:
        for ip in ip_list:
            try:
                resp=requests.get(
                    f"https://{username}:{password}@dyndns.strato.com/nic/update",
                    params={'hostname':domain,'myip':ip},timeout=10
                )
                result=resp.text.strip().split()[0] if resp.status_code==200 else "error"
            except Exception: result="error"
            if priority.index(result) < priority.index(worst):
                worst= result
                worst_ip=ip

    return Response(f"{worst} {worst_ip}",mimetype='text/plain')

if __name__=='__main__':
    app.run(host='0.0.0.0',port=5000)
EOF_PY

cat > "$APP_DIR/templates/login.html" <<'EOF_HTML'
<!DOCTYPE html><html lang="de"><head><meta charset="UTF-8"><title>Login</title><link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/css/bootstrap.min.css" rel="stylesheet"></head><body><div class="container mt-5"><div class="row justify-content-center"><div class="col-md-4"><div class="card shadow-sm"><div class="card-body"><h4 class="card-title text-center mb-4">Strato DDNS Login</h4>{% if error %}<div class="alert alert-danger text-center">{{ error }}</div>{% endif %}<form method="post"><div class="form-floating mb-3"><input type="text" class="form-control" id="username" name="username" placeholder="Benutzername" required><label for="username">Benutzername</label></div><div class="form-floating mb-3"><input type="password" class="form-control" id="password" name="password" placeholder="Passwort" required><label for="password">Passwort</label></div><button type="submit" class="btn btn-primary w-100" {% if disabled %}disabled{% endif %}>Anmelden</button></form></div></div></div></div></div></body></html>
EOF_HTML

cat > "$APP_DIR/templates/index.html" <<'EOF_HTML'
<!DOCTYPE html><html lang="de"><head><meta charset="UTF-8"><title>Konfiguration</title><link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/css/bootstrap.min.css" rel="stylesheet"></head><body><div class="container mt-5"><div class="row justify-content-center"><div class="col-md-8"><div class="card shadow-sm"><div class="card-body"><h3 class="card-title mb-4">Strato DDNS Konfiguration</h3><p>Aktuelle öffentliche IP: <strong>{{ ip }}</strong></p><form method="post"><div class="form-floating mb-3"><input type="text" class="form-control" name="username" id="username" placeholder="Strato Benutzername" value="{{ username }}"><label for="username">Strato Benutzername</label></div><div class="form-floating mb-3"><input type="password" class="form-control" name="password" id="password" placeholder="Strato Passwort" value="{{ password }}"><label for="password">Strato Passwort</label></div><div class="mb-3"><label>Domains (eine pro Zeile)</label><textarea class="form-control" name="domains" rows="5">{{ domains }}</textarea></div><div class="row mt-4"><div class="col d-flex gap-2"><button type="submit" class="btn btn-primary">Speichern</button><a href="{{ url_for('update') }}" class="btn btn-success">Jetzt updaten</a></div><div class="col text-end"><a href="{{ url_for('logout') }}" class="btn btn-danger">Logout</a></div></div></form></div></div></div></div></div></body></html>
EOF_HTML

cat > "$APP_DIR/templates/update.html" <<'EOF_HTML'
<!DOCTYPE html><html lang="de"><head><meta charset="UTF-8"><title>Update</title><link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/css/bootstrap.min.css" rel="stylesheet"></head><body><div class="container mt-5"><div class="row justify-content-center"><div class="col-md-8"><div class="card shadow-sm"><div class="card-body"><h3 class="card-title mb-4">Strato DDNS Update</h3><p>Aktualisierte öffentliche IP: <strong>{{ ip }}</strong></p><ul class="list-group">{% for domain, result in results %}<li class="list-group-item d-flex justify-content-between"><span>{{ domain }}</span><span class="badge {% if result.lower().startswith('good') or result.lower().startswith('nochg') %}bg-success{% else %}bg-danger{% endif %}">{{ result }}</span></li>{% endfor %}</ul><a href="{{ url_for('index') }}" class="btn btn-primary mt-3">Zurück</a></div></div></div></div></div></body></html>
EOF_HTML

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

SERVER_IP=$(hostname -I | awk '{print $1}')
echo
echo "✅ Installation abgeschlossen: http://$SERVER_IP:5000"
echo
echo "ℹ️ Verwenden Sie in der Fritz!Box eine der folgenden Update-URL´s."
echo "  http://$SERVER_IP:5000/auto?username=<username>&password=<pass>&myip=<ipaddr>,<ip6addr>"
echo "  http://$SERVER_IP:5000/auto?username=<username>&password=<pass>&myip=<ipaddr>"
echo "  http://$SERVER_IP:5000/auto?username=<username>&password=<pass>&myip=<ip6addr>"
echo
echo "🆘 Für weitere Informationen nutzen Sie die Hilfe oder das Handbuch Ihrer Fritz!Box."
