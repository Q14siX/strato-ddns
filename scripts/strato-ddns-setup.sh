#!/bin/bash
set -e

# =============================================
# Strato DDNS - Installation & Deinstallation
# Datei: strato-ddns-setup.sh
# =============================================

if [ "$EUID" -ne 0 ]; then
  echo "❌ Bitte führe dieses Skript als root oder mit sudo aus."
  exit 1
fi

APP_DIR="/opt/strato-ddns"
SERVICE_FILE="/etc/systemd/system/strato-ddns.service"
LOG_FILE="$APP_DIR/log.xml"

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
apt-get install -y \
  python3 \
  python3-pip \
  python3-flask \
  python3-flask-session \
  python3-flask-limiter \
  python3-bcrypt \
  python3-cryptography \
  ca-certificates \
  sudo

mkdir -p "$APP_DIR/templates"

# log.xml anlegen (falls nicht vorhanden)
if [ ! -f "$LOG_FILE" ]; then
  echo '<?xml version="1.0" encoding="UTF-8"?><log></log>' > "$LOG_FILE"
fi

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
import xml.etree.ElementTree as ET
from xml.dom import minidom

CONFIG_FILE = os.path.join(os.path.dirname(__file__), 'config.json')
LOG_FILE = os.path.join(os.path.dirname(__file__), 'log.xml')

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

def write_log_entry(source, domain, ips, status):
    # Initialisiere log.xml falls sie nicht existiert
    if not os.path.isfile(LOG_FILE):
        with open(LOG_FILE, "w", encoding="utf-8") as f:
            f.write('<?xml version="1.0" encoding="UTF-8"?><log></log>')
    tree = ET.parse(LOG_FILE)
    root = tree.getroot()
    entry = ET.SubElement(root, "entry")
    now = datetime.now()
    ET.SubElement(entry, "date").text = now.strftime("%Y-%m-%d")
    ET.SubElement(entry, "time").text = now.strftime("%H:%M:%S")
    ET.SubElement(entry, "source").text = source
    ET.SubElement(entry, "domain").text = domain
    ET.SubElement(entry, "ip").text = "\n".join(ips) if isinstance(ips, list) else str(ips)
    ET.SubElement(entry, "status").text = status
    xmlstr = minidom.parseString(ET.tostring(root)).toprettyxml(indent="  ")
    with open(LOG_FILE, "w", encoding="utf-8") as f:
        f.write(xmlstr)
@app.errorhandler(RateLimitExceeded)
def handle_ratelimit(e):
    if request.endpoint=="login":
        return render_template("login.html",error=str(e.description),disabled=True),429
    return "Too Many Requests",429

failed_attempts_auto = defaultdict(list)

@app.route('/',methods=['GET','POST'])
def log_view():
    if not session.get('logged_in'): return redirect(url_for('login'))
    # Parse log.xml and show as table
    log_entries = []
    if os.path.isfile(LOG_FILE):
        tree = ET.parse(LOG_FILE)
        for entry in tree.getroot().findall("entry"):
            log_entries.append({
                "date": entry.findtext("date", ""),
                "time": entry.findtext("time", ""),
                "source": entry.findtext("source", ""),
                "domain": entry.findtext("domain", ""),
                "ip": entry.findtext("ip", "").replace("\n", "<br>"),
                "status": entry.findtext("status", ""),
            })
    # Neueste Einträge zuerst
    log_entries = sorted(log_entries, key=lambda e: (e['date'], e['time']), reverse=True)
    return render_template('log.html', entries=log_entries)

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
            return redirect(url_for('log_view'))
        else: error="Falsche Zugangsdaten"
    return render_template('login.html',error=error,disabled=disabled)

@app.route('/logout')
def logout():
    session.clear()
    return redirect(url_for('login'))

@app.route('/config',methods=['GET','POST'])
def config_view():
    if not session.get('logged_in'): return redirect(url_for('login'))
    config=load_config()
    salt=base64.urlsafe_b64decode(config['salt'])
    ip=get_public_ip()
    if request.method=='POST':
        config['username_enc']=encrypt(request.form['username'],session['webpass'],salt)
        config['password_enc']=encrypt(request.form['password'],session['webpass'],salt)
        config['domains']=[d.strip() for d in request.form['domains'].splitlines() if d.strip()]
        save_config(config)
        return redirect(url_for('config_view'))
    try: username=decrypt(config['username_enc'],session['webpass'],salt)
    except: username=''
    try: password=decrypt(config['password_enc'],session['webpass'],salt)
    except: password=''
    domains_str="\n".join(config['domains'])
    return render_template('index.html',ip=ip,username=username,password=password,domains=domains_str)

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
        # Logging (manuell)
        write_log_entry("manuell", domain, [ip], text)
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
        write_log_entry("automatisch", "ABUSE", ip_list, "abuse")
        return Response(f"abuse {ip_list[0]}",mimetype='text/plain')

    if not(req_user==config['webuser'] and verify_password(req_pass,config['webpass_hash'])):
        failed_attempts_auto[client_ip].append(now)
        write_log_entry("automatisch", "BADAUTH", ip_list, "badauth")
        return Response(f"badauth {ip_list[0]}",mimetype='text/plain')

    try:
        username=decrypt(config['username_enc'],req_pass,salt)
        password=decrypt(config['password_enc'],req_pass,salt)
    except:
        write_log_entry("automatisch", "CONFIGERROR", ip_list, "configerror")
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
            except Exception as e:
                result="error"
            if priority.index(result) < priority.index(worst):
                worst= result
                worst_ip=ip
            # Logging (automatisch)
            write_log_entry("automatisch", domain, [ip], result)

    return Response(f"{worst} {worst_ip}",mimetype='text/plain')

if __name__=='__main__':
    app.run(host='0.0.0.0',port=5000)
EOF_PY
# --- Responsive Login-Seite ---
cat > "$APP_DIR/templates/login.html" <<'EOF_HTML'
<!DOCTYPE html><html lang="de"><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width, initial-scale=1"><title>Login</title><link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/css/bootstrap.min.css" rel="stylesheet"></head><body><div class="container mt-5"><div class="row justify-content-center"><div class="col-12 col-md-6 col-lg-4"><div class="card shadow-sm"><div class="card-body"><h4 class="card-title text-center mb-4">Strato DDNS Login</h4>{% if error %}<div class="alert alert-danger text-center">{{ error }}</div>{% endif %}<form method="post"><div class="form-floating mb-3"><input type="text" class="form-control" id="username" name="username" placeholder="Benutzername" required><label for="username">Benutzername</label></div><div class="form-floating mb-3"><input type="password" class="form-control" id="password" name="password" placeholder="Passwort" required><label for="password">Passwort</label></div><button type="submit" class="btn btn-primary w-100" {% if disabled %}disabled{% endif %}>Anmelden</button></form></div></div></div></div></div></body></html>
EOF_HTML

# --- Responsive Konfigurationsseite (jetzt /config) ---
cat > "$APP_DIR/templates/index.html" <<'EOF_HTML'
<!DOCTYPE html><html lang="de"><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width, initial-scale=1"><title>Konfiguration</title><link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/css/bootstrap.min.css" rel="stylesheet"></head><body><nav class="navbar navbar-expand-lg navbar-dark bg-primary"><div class="container-fluid"><a class="navbar-brand" href="/">Strato DDNS</a><button class="navbar-toggler" type="button" data-bs-toggle="collapse" data-bs-target="#navbarConfig" aria-controls="navbarConfig" aria-expanded="false" aria-label="Toggle navigation"><span class="navbar-toggler-icon"></span></button><div class="collapse navbar-collapse" id="navbarConfig"><ul class="navbar-nav me-auto mb-2 mb-lg-0"><li class="nav-item"><a class="nav-link" href="/">Log</a></li><li class="nav-item"><a class="nav-link active" href="/config">Konfiguration</a></li></ul><span class="navbar-text"><a href="/logout" class="btn btn-outline-light btn-sm">Logout</a></span></div></div></nav><div class="container mt-5"><div class="row justify-content-center"><div class="col-12 col-md-10 col-lg-8"><div class="card shadow-sm"><div class="card-body"><h3 class="card-title mb-4">Strato DDNS Konfiguration</h3><p>Aktuelle öffentliche IP: <strong>{{ ip }}</strong></p><form method="post"><div class="form-floating mb-3"><input type="text" class="form-control" name="username" id="username" placeholder="Strato Benutzername" value="{{ username }}"><label for="username">Strato Benutzername</label></div><div class="form-floating mb-3"><input type="password" class="form-control" name="password" id="password" placeholder="Strato Passwort" value="{{ password }}"><label for="password">Strato Passwort</label></div><div class="mb-3"><label>Domains (eine pro Zeile)</label><textarea class="form-control" name="domains" rows="5">{{ domains }}</textarea></div><div class="row mt-4"><div class="col-12 col-md-6 d-grid gap-2"><button type="submit" class="btn btn-primary">Speichern</button><a href="{{ url_for('update') }}" class="btn btn-success">Jetzt updaten</a></div></div></form></div></div></div></div></div><script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/js/bootstrap.bundle.min.js"></script></body></html>
EOF_HTML

# --- Responsive Update-Seite ---
cat > "$APP_DIR/templates/update.html" <<'EOF_HTML'
<!DOCTYPE html><html lang="de"><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width, initial-scale=1"><title>Update</title><link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/css/bootstrap.min.css" rel="stylesheet"></head><body><nav class="navbar navbar-expand-lg navbar-dark bg-primary"><div class="container-fluid"><a class="navbar-brand" href="/">Strato DDNS</a><button class="navbar-toggler" type="button" data-bs-toggle="collapse" data-bs-target="#navbarNav" aria-controls="navbarNav" aria-expanded="false" aria-label="Toggle navigation"><span class="navbar-toggler-icon"></span></button><div class="collapse navbar-collapse" id="navbarNav"><ul class="navbar-nav me-auto mb-2 mb-lg-0"><li class="nav-item"><a class="nav-link" href="/">Log</a></li><li class="nav-item"><a class="nav-link" href="/config">Konfiguration</a></li></ul><span class="navbar-text"><a href="/logout" class="btn btn-outline-light btn-sm">Logout</a></span></div></div></nav><div class="container mt-5"><div class="row justify-content-center"><div class="col-12 col-md-10 col-lg-8"><div class="card shadow-sm"><div class="card-body"><h3 class="card-title mb-4">Strato DDNS Update</h3><p>Aktualisierte öffentliche IP: <strong>{{ ip }}</strong></p><ul class="list-group">{% for domain, result in results %}<li class="list-group-item d-flex justify-content-between"><span>{{ domain }}</span><span class="badge {% if result.lower().startswith('good') or result.lower().startswith('nochg') %}bg-success{% else %}bg-danger{% endif %}">{{ result }}</span></li>{% endfor %}</ul><a href="{{ url_for('config_view') }}" class="btn btn-primary mt-3 w-100">Zurück zur Konfiguration</a></div></div></div></div></div></body></html>
EOF_HTML

# --- Responsive Log-Seite (Startseite, mit Menü!) ---
cat > "$APP_DIR/templates/log.html" <<'EOF_HTML'
<!DOCTYPE html><html lang="de"><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width, initial-scale=1"><title>Protokoll</title><link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/css/bootstrap.min.css" rel="stylesheet"></head><body><nav class="navbar navbar-expand-lg navbar-dark bg-primary"><div class="container-fluid"><a class="navbar-brand" href="/">Strato DDNS</a><button class="navbar-toggler" type="button" data-bs-toggle="collapse" data-bs-target="#navbarLog" aria-controls="navbarLog" aria-expanded="false" aria-label="Toggle navigation"><span class="navbar-toggler-icon"></span></button><div class="collapse navbar-collapse" id="navbarLog"><ul class="navbar-nav me-auto mb-2 mb-lg-0"><li class="nav-item"><a class="nav-link active" href="/">Log</a></li><li class="nav-item"><a class="nav-link" href="/config">Konfiguration</a></li></ul><span class="navbar-text"><a href="/logout" class="btn btn-outline-light btn-sm">Logout</a></span></div></div></nav><div class="container mt-5"><div class="row justify-content-center"><div class="col-12"><div class="card shadow-sm"><div class="card-body"><h3 class="card-title mb-4">Strato DDNS Protokoll</h3><div class="table-responsive"><table class="table table-bordered table-striped align-middle"><thead class="table-light"><tr><th>Datum</th><th>Uhrzeit</th><th>Auslösung</th><th>Domain</th><th>IP-Adresse(n)</th><th>Status</th></tr></thead><tbody>{% for e in entries %}<tr><td>{{ e.date }}</td><td>{{ e.time }}</td><td>{{ e.source }}</td><td><a href="http://{{ e.domain }}" target="_blank">{{ e.domain }}</a></td><td>{{ e.ip|safe }}</td><td><span class="badge {% if e.status.lower().startswith('good') or e.status.lower().startswith('nochg') %}bg-success{% else %}bg-danger{% endif %}">{{ e.status }}</span></td></tr>{% endfor %}</tbody></table></div></div></div></div></div></div><script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/js/bootstrap.bundle.min.js"></script></body></html>
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