#!/bin/bash
cat > "$APP_DIR/app.py" <<'EOF_PY'
from flask import Flask, render_template, request, redirect, url_for, session, Response
import requests, json, os, smtplib
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText
from flask_limiter import Limiter
from flask_limiter.util import get_remote_address
from flask_limiter.errors import RateLimitExceeded
from datetime import datetime, timedelta
from zoneinfo import ZoneInfo
TIMEZONE = ZoneInfo("Europe/Berlin")

from collections import defaultdict
from urllib.parse import urljoin

CONFIG_FILE = os.path.join(os.path.dirname(__file__), 'config.json')
TEMPLATES_DIR = os.path.join(os.path.dirname(__file__), 'templates')
LOG_FILE = os.path.join(os.path.dirname(__file__), 'log.xml')

def load_config():
    with open(CONFIG_FILE) as f:
        return json.load(f)

def save_config(config):
    with open(CONFIG_FILE, 'w') as f:
        json.dump(config, f, indent=4)

def log_entry(timestamp, event, trigger, domain, ip, status):
    try:
        from xml.etree.ElementTree import Element, SubElement, ElementTree, parse
        if os.path.exists(LOG_FILE):
            tree = parse(LOG_FILE)
            root = tree.getroot()
        else:
            root = Element('log')
            tree = ElementTree(root)
        entry = SubElement(root, 'entry')
        SubElement(entry, 'timestamp').text = timestamp
        SubElement(entry, 'event').text = event
        SubElement(entry, 'trigger').text = trigger
        SubElement(entry, 'domain').text = domain
        SubElement(entry, 'ip').text = ip
        SubElement(entry, 'status').text = status
        tree.write(LOG_FILE, encoding='utf-8', xml_declaration=True)
    except Exception as e:
        print("Log error:", e)

def get_public_ip():
    try:
        return requests.get("https://api.ipify.org").text
    except:
        return None

def get_mail_settings(config):
    ms = config.get("mail_settings", {})
    default = {
        "enabled": False,
        "recipients": "",
        "sender": "",
        "subject": "Strato DDNS",
        "smtp_user": "",
        "smtp_pass": "",
        "smtp_server": "",
        "smtp_port": "",
        "notify_on_success": False,
        "notify_on_badauth": True,
        "notify_on_noip": True,
        "notify_on_abuse": True,
    }
    for k in default:
        ms.setdefault(k, default[k])
    return ms

def get_mail_subject(config, suffix=None):
    ms = get_mail_settings(config)
    subject = ms.get("subject") or "Strato DDNS"
    if suffix:
        return f"{subject} – {suffix}"
    return subject

def build_html_mail(subject, entries, timestamp, event, trigger):
    from datetime import datetime

    # Timestamp-String direkt umwandeln (und unter demselben Namen behalten)
    try:
        # ISO-Format mit Mikrosekunden und Zeitzone parsen
        dt = datetime.fromisoformat(timestamp)
        timestamp = dt.strftime("%d.%m.%Y %H:%M.%S") + "Uhr"
    except:
        pass
    
    html_rows = ""
    for domain, ip, status in entries:
        color = "#198754" if status.lower().startswith(("good", "nochg")) else "#dc3545"
        html_rows += f"""
            <tr>
                <td>{domain}</td>
                <td>{ip}</td>
                <td style="color:{color}; font-weight:bold;">{status}</td>
            </tr>
        """

    html = f"""
    <!DOCTYPE html>
    <html lang="de">
    <head>
        <meta charset="UTF-8">
        <style>
            body {{ font-family: Arial, sans-serif; background-color: #f8f9fa; color: #212529; }}
            .container {{ max-width: 700px; margin: 20px auto; background: white; padding: 20px; border-radius: 6px; box-shadow: 0 0 10px rgba(0,0,0,0.1); }}
            h2 {{ color: #0d6efd; }}
            table {{ width: 100%; border-collapse: collapse; margin-top: 20px; }}
            th, td {{ padding: 10px; text-align: left; border-bottom: 1px solid #ddd; }}
            th {{ background-color: #e9ecef; }}
            .footer {{ font-size: small; color: gray; margin-top: 32px; }}
        </style>
    </head>
    <body>
        <div class="container">
            <h2>{subject}</h2>
            <p><strong>Datum:</strong> {timestamp}<br>
               <strong>Ereignis:</strong> {event}<br>
               <strong>Trigger:</strong> {trigger}</p>
            <table>
                <thead>
                    <tr>
                        <th>Domain</th>
                        <th>IP-Adresse</th>
                        <th>Status</th>
                    </tr>
                </thead>
                <tbody>
                    {html_rows}
                </tbody>
            </table>
            <div class="footer">Strato DDNS Dienst – <a href="https://github.com/Q14siX/strato-ddns">Projektseite auf GitHub</a></div>
        </div>
    </body>
    </html>
    """
    return html

def send_mail(config, subject, entries, timestamp, event, trigger, decrypt_pw=None):
    ms = get_mail_settings(config)
    if not ms["enabled"]:
        return False, "Mailversand deaktiviert"
    try:
        recipients = [a.strip() for a in ms["recipients"].split(",") if a.strip()]
        if not recipients:
            return False, "Keine Empfänger angegeben"

        html_body = build_html_mail(subject, entries, timestamp, event, trigger)
        plain_body = "\n".join(f"{d}: {ip} – {status}" for d, ip, status in entries)

        msg = MIMEMultipart("alternative")
        msg["Subject"] = subject
        msg["From"] = ms["sender"]
        msg["To"] = ", ".join(recipients)

        part_text = MIMEText(plain_body, "plain", "utf-8")
        part_html = MIMEText(html_body, "html", "utf-8")

        msg.attach(part_text)
        msg.attach(part_html)

        smtp_user = ms["smtp_user"]
        smtp_pass = ms["smtp_pass"]
        smtp_server = ms["smtp_server"]
        smtp_port = int(ms["smtp_port"]) if str(ms["smtp_port"]).isdigit() else 587

        server = smtplib.SMTP(smtp_server, smtp_port)
        server.starttls()
        if smtp_user and smtp_pass:
            server.login(smtp_user, smtp_pass)
        server.sendmail(ms["sender"], recipients, msg.as_string())
        server.quit()
        return True, "OK"
    except Exception as e:
        return False, str(e)

app = Flask(__name__, template_folder=TEMPLATES_DIR)
app.secret_key = load_config()["secret_key"]
limiter = Limiter(app=app, key_func=get_remote_address, storage_uri="memory://")

failed_attempts_auto = defaultdict(list)

def login_required(f):
    from functools import wraps
    @wraps(f)
    def decorated(*args, **kwargs):
        if not session.get('logged_in'):
            return redirect(url_for('login'))
        return f(*args, **kwargs)
    return decorated

@app.errorhandler(RateLimitExceeded)
def handle_ratelimit(e):
    if request.endpoint == "login":
        return render_template("login.html", error=str(e.description), disabled=True), 429
    return "Too Many Requests", 429

@app.route('/')
@app.route('/log')
@login_required
def log_page():
    entries = []
    import xml.etree.ElementTree as ET
    if os.path.exists(LOG_FILE):
        tree = ET.parse(LOG_FILE)
        root = tree.getroot()
        for entry in root.findall('entry'):
            entries.append({
                "datetime": entry.findtext("timestamp"),
                "event": entry.findtext("event"),
                "trigger": entry.findtext("trigger"),
                "domain": entry.findtext("domain"),
                "ip": entry.findtext("ip"),
                "status": entry.findtext("status")
            })
    entries.sort(key=lambda x: x["datetime"], reverse=True)
    return render_template("log.html", log_entries=entries)

@app.route('/config', methods=['GET', 'POST'])
@login_required
def config_page():
    config = load_config()
    msg = ""

    username = config.get("username", "")
    password = config.get("password", "")
    domains_str = "\n".join(config.get("domains", []))
    mail_settings = get_mail_settings(config)

    if request.method == "POST":
        config["username"] = request.form.get("username", "")
        config["password"] = request.form.get("password", "")
        config["domains"] = [d.strip() for d in request.form.get("domains", "").splitlines() if d.strip()]
        config["mail_settings"] = {
            "enabled": "mail_enabled" in request.form,
            "recipients": request.form.get("mail_recipients", ""),
            "sender": request.form.get("mail_sender", ""),
            "subject": request.form.get("mail_subject", ""),
            "smtp_user": request.form.get("mail_smtp_user", ""),
            "smtp_pass": request.form.get("mail_smtp_pass", ""),
            "smtp_server": request.form.get("mail_smtp_server", ""),
            "smtp_port": request.form.get("mail_smtp_port", ""),
            "notify_on_success": "mail_notify_success" in request.form,
            "notify_on_badauth": "mail_notify_badauth" in request.form,
            "notify_on_noip": "mail_notify_noip" in request.form,
            "notify_on_abuse": "mail_notify_abuse" in request.form,
        }

        save_config(config)
        msg = "Gespeichert!"

        if "run_update" in request.form:
            return redirect(url_for("update"))

        username = config["username"]
        password = config["password"]
        domains_str = "\n".join(config.get("domains", []))
        mail_settings = config["mail_settings"]

    return render_template(
        'config.html',
        username=username,
        password=password,
        domains=domains_str,
        mail_settings=mail_settings,
        msg=msg
    )

@app.route('/testmail', methods=['POST'])
@login_required
def testmail():
    config = load_config()
    ms = get_mail_settings(config)

    ms["enabled"] = True
    ms["recipients"] = request.form.get("mail_recipients", "")
    ms["sender"] = request.form.get("mail_sender", "")
    ms["subject"] = request.form.get("mail_subject", "")
    ms["smtp_user"] = request.form.get("mail_smtp_user", "")
    ms["smtp_pass"] = request.form.get("mail_smtp_pass", "")
    ms["smtp_server"] = request.form.get("mail_smtp_server", "")
    ms["smtp_port"] = request.form.get("mail_smtp_port", "")

    now = datetime.now(TIMEZONE)
    timestamp = now.strftime("%Y-%m-%d %H:%M:%S")
    event = "Testmail"
    trigger = "manuell"
    subject = get_mail_subject(config, "Testnachricht")
    entries = [("test.domain", "127.0.0.1", "OK")]

    success, info = send_mail(config, subject, entries, timestamp, event, trigger)
    if success:
        return "OK", 200
    else:
        return f"Fehler: {info}", 500

@app.route('/login', methods=['GET', 'POST'])
@limiter.limit("5 per hour", methods=["POST"], error_message="Zu viele Fehlversuche. Bitte später erneut versuchen.")
def login():
    config = load_config()
    error, disabled = None, False

    if request.method == 'POST':
        user = request.form['username']
        pw = request.form['password']
        if user == config.get("webuser") and pw == config.get("webpass"):
            session['logged_in'] = True
            return redirect(url_for('log_page'))
        else:
            error = "Falsche Zugangsdaten"

    return render_template('login.html', error=error, disabled=disabled)

@app.route('/logout')
def logout():
    session.clear()
    return redirect(url_for('login'))

@app.route('/update')
@login_required
def update():
    config = load_config()
    username = config.get("username", "")
    password = config.get("password", "")
    ip = get_public_ip()
    hostnames = config.get("domains", [])
    results = []
    now = datetime.now(TIMEZONE)
    timestamp = now.strftime("%Y-%m-%d %H:%M:%S")
    event = "Update"
    trigger = "manuell"
    mail_settings = get_mail_settings(config)

    for domain in hostnames:
        try:
            resp = requests.get(
                f"https://{username}:{password}@dyndns.strato.com/nic/update",
                params={'hostname': domain, 'myip': ip}, timeout=10
            )
            text_raw = resp.text.strip() if resp.status_code == 200 else f"error {resp.status_code}"
            text = text_raw.split(" ")[0]
        except Exception:
            text = "error"
        results.append((domain, ip, text))
        log_entry(timestamp, event, trigger, domain, ip, text)

    if mail_settings.get("enabled") and mail_settings.get("notify_on_success"):
        subject = get_mail_subject(config, f"{event} erfolgreich")
        send_mail(config, subject, results, timestamp, event, trigger)

    return render_template('update.html', ip=ip, results=results)

@app.route('/auto')
def auto():
    config = load_config()
    req_user = request.args.get('username')
    req_pass = request.args.get('password')
    req_ip = request.args.get('myip')
    ip_list = [i.strip() for i in req_ip.split(',')] if req_ip else [get_public_ip()]
    client_ip = request.remote_addr
    now = datetime.now(TIMEZONE)
    timestamp = now.strftime("%Y-%m-%d %H:%M:%S")
    event = "Auto-Update"
    trigger = "automatisch"
    mail_settings = get_mail_settings(config)
    hostnames = config.get("domains", [])
    results = []

    # Missbrauchsschutz (5 Fehlversuche)
    failed_attempts_auto[client_ip] = [t for t in failed_attempts_auto[client_ip] if now - t < timedelta(hours=1)]
    if len(failed_attempts_auto[client_ip]) >= 5:
        for domain in hostnames:
            log_entry(timestamp, "Sperre", trigger, domain, ",".join(ip_list), "abuse")
            results.append((domain, ",".join(ip_list), "abuse"))
        if mail_settings.get("enabled") and mail_settings.get("notify_on_abuse"):
            subject = get_mail_subject(config, "Sperre durch Missbrauchsversuche")
            send_mail(config, subject, results, timestamp, "Sperre", trigger)
        return Response(f"abuse {ip_list[0]}", mimetype='text/plain')

    # Keine IP verfügbar
    if not ip_list or not ip_list[0]:
        for domain in hostnames:
            log_entry(timestamp, event, trigger, domain, "keine IP", "noip")
            results.append((domain, "keine IP", "noip"))
        if mail_settings.get("enabled") and mail_settings.get("notify_on_noip"):
            subject = get_mail_subject(config, "Keine IP verfügbar")
            send_mail(config, subject, results, timestamp, event, trigger)
        return Response("noip", mimetype="text/plain")

    # Web-Login fehlgeschlagen
    if not (req_user == config.get("webuser") and req_pass == config.get("webpass")):
        failed_attempts_auto[client_ip].append(now)
        for domain in hostnames:
            log_entry(timestamp, "Login fehlgeschlagen", trigger, domain, ",".join(ip_list), "badauth-web")
            results.append((domain, ",".join(ip_list), "badauth-web"))
        if mail_settings.get("enabled") and mail_settings.get("notify_on_badauth"):
            subject = get_mail_subject(config, "Login fehlgeschlagen (Web)")
            send_mail(config, subject, results, timestamp, "Login fehlgeschlagen", trigger)
        return Response(f"badauth {ip_list[0]}", mimetype='text/plain')

    # Strato-Update
    username = config.get("username", "")
    password = config.get("password", "")
    priority = ["911", "nohost", "badauth", "notfqdn", "badagent", "abuse", "good", "nochg"]
    worst = "nochg"
    worst_ip = ip_list[0]

    for domain in hostnames:
        for ip in ip_list:
            try:
                resp = requests.get(
                    f"https://{username}:{password}@dyndns.strato.com/nic/update",
                    params={'hostname': domain, 'myip': ip}, timeout=10
                )
                result_line = resp.text.strip()
                status = result_line.split()[0] if resp.status_code == 200 else "error"
            except Exception:
                result_line = "error"
                status = "error"

            if priority.index(status) < priority.index(worst):
                worst = status
                worst_ip = ip

            returned_ip = result_line.split()[1] if len(result_line.split()) > 1 else ip
            log_entry(timestamp, event, trigger, domain, returned_ip, status)
            results.append((domain, returned_ip, status))

    # Mail bei Erfolg
    if mail_settings.get("enabled") and mail_settings.get("notify_on_success"):
        subject = get_mail_subject(config, "Update erfolgreich")
        send_mail(config, subject, results, timestamp, event, trigger)

    return Response(f"{worst} {worst_ip}", mimetype='text/plain')

@app.errorhandler(404)
def not_found(e):
    if session.get('logged_in'):
        return redirect(url_for('log_page'))
    return redirect(url_for('login'))

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=80)
EOF_PY
