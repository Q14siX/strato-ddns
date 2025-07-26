# -*- coding: utf-8 -*-

import base64
import hashlib
import json
import os
import smtplib
import subprocess
from collections import defaultdict
from datetime import datetime, timedelta
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText
from functools import wraps
from io import BytesIO
from zoneinfo import ZoneInfo

import openpyxl
import requests
from cryptography.fernet import Fernet
from flask import (Flask, Response, flash, jsonify, redirect,
                   render_template, request, send_file, session, url_for, stream_with_context)
from flask_limiter import Limiter
from flask_limiter.errors import RateLimitExceeded
from flask_limiter.util import get_remote_address
import xml.etree.ElementTree as ET

# --- Konstanten und Konfiguration ---
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
CONFIG_FILE = os.path.join(BASE_DIR, 'config.json')
TEMPLATES_DIR = os.path.join(BASE_DIR, 'templates')
LOG_FILE = os.path.join(BASE_DIR, 'log.xml')
TIMEZONE = ZoneInfo("Europe/Berlin")

# --- Flask App Initialisierung ---
app = Flask(__name__, template_folder=TEMPLATES_DIR)
limiter = Limiter(key_func=get_remote_address, storage_uri="memory://", app=app)
failed_attempts_auto = defaultdict(list)


# --- Hilfsfunktionen ---

def load_config():
    """Lädt die Konfigurationsdatei sicher."""
    try:
        with open(CONFIG_FILE, 'r', encoding='utf-8') as f:
            return json.load(f)
    except (FileNotFoundError, json.JSONDecodeError):
        return {}

def save_config(config):
    """Speichert die Konfiguration im JSON-Format."""
    with open(CONFIG_FILE, 'w', encoding='utf-8') as f:
        json.dump(config, f, indent=4, ensure_ascii=False)

def get_log_retention_hours():
    """Holt die Aufbewahrungsdauer für Logs aus der Konfiguration."""
    config = load_config()
    return int(config.get("log_retention_hours", 24))

def get_public_ip():
    """Ermittelt die öffentliche IP-Adresse."""
    try:
        response = requests.get("https://api.ipify.org", timeout=5)
        response.raise_for_status()
        return response.text
    except requests.RequestException:
        return None

def derive_key(password: str) -> bytes:
    """Leitet einen sicheren kryptographischen Schlüssel von einem Passwort ab."""
    return base64.urlsafe_b64encode(hashlib.sha256(password.encode()).digest())


# --- Logging ---

def prune_old_logs(root, retention_hours):
    """Entfernt veraltete Log-Einträge."""
    now = datetime.now(TIMEZONE)
    cutoff = now - timedelta(hours=retention_hours)
    to_remove = []
    for entry in root.findall('entry'):
        t = entry.findtext("timestamp") or ""
        try:
            dt_format = "%Y-%m-%d %H:%M:%S" if "-" in t else "%d.%m.%Y %H:%M:%S"
            dt = datetime.strptime(t, dt_format).replace(tzinfo=TIMEZONE)
            if dt < cutoff:
                to_remove.append(entry)
        except ValueError:
            continue
    for entry in to_remove:
        root.remove(entry)

def append_log_entries(new_entries):
    """Fügt neue Einträge zum Log hinzu."""
    retention_hours = get_log_retention_hours()
    try:
        if os.path.exists(LOG_FILE):
            tree = ET.parse(LOG_FILE)
            root = tree.getroot()
        else:
            root = ET.Element('log')
            tree = ET.ElementTree(root)

        prune_old_logs(root, retention_hours)

        for timestamp, event, trigger, domain, ip, status in new_entries:
            entry = ET.SubElement(root, 'entry')
            ET.SubElement(entry, 'timestamp').text = timestamp
            ET.SubElement(entry, 'event').text = event
            ET.SubElement(entry, 'trigger').text = trigger
            ET.SubElement(entry, 'domain').text = domain
            ET.SubElement(entry, 'ip').text = ip
            ET.SubElement(entry, 'status').text = status

        tree.write(LOG_FILE, encoding='utf-8', xml_declaration=True)
    except (ET.ParseError, IOError) as e:
        print(f"Fehler beim Schreiben der Log-Datei: {e}")


# --- Mail-Funktionen ---

def get_mail_settings(config):
    """Holt Mail-Einstellungen mit Standardwerten."""
    ms = config.get("mail_settings", {})
    defaults = {
        "enabled": False, "recipients": "", "sender": "", "subject": "Strato DDNS",
        "smtp_user": "", "smtp_pass": "", "smtp_server": "", "smtp_port": 587,
        "notify_on_success": False, "notify_on_badauth": True,
        "notify_on_noip": True, "notify_on_abuse": True,
    }
    defaults.update(ms)
    return defaults

def build_html_mail(subject, entries, timestamp, event, trigger):
    """Erstellt eine HTML-Mail, die dem Web-Design nachempfunden ist."""
    try:
        dt = datetime.fromisoformat(timestamp)
        timestamp_str = dt.strftime("%d.%m.%Y - %H:%M:%S") + " Uhr"
    except (ValueError, TypeError):
        timestamp_str = str(timestamp)

    rows = ""
    for domain, ip, status in entries:
        color = "#16a34a" if status.lower().startswith(("good", "nochg")) else "#dc2626"
        rows += f'<tr><td style="padding: 12px 16px; border-bottom: 1px solid #e5e7eb; color: #0078d4; font-weight: 500;"><a href="http://{domain}" target="_blank" style="color: #0078d4; text-decoration: none;">{domain}</a></td><td style="padding: 12px 16px; border-bottom: 1px solid #e5e7eb; color: #4b5563; font-family: monospace;">{ip}</td><td style="padding: 12px 16px; border-bottom: 1px solid #e5e7eb; color: {color}; font-weight: 500;">{status}</td></tr>'

    return f'<!DOCTYPE html><html lang="de"><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width, initial-scale=1.0"><style>body{{margin:0; padding:0; background-color:#f3f4f6; font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif, "Apple Color Emoji", "Segoe UI Emoji", "Segoe UI Symbol";}}</style></head><body style="margin:0; padding:0; background-color:#f3f4f6;"><table role="presentation" style="width:100%; border-collapse:collapse; border:0; border-spacing:0; background:#f3f4f6;"><tr><td align="center" style="padding:20px 0;"><table role="presentation" style="width:600px; max-width:600px; border-collapse:collapse; border:0; border-spacing:0;"><tr><td style="background-color:#0078d4; padding:16px 24px;"><table role="presentation" style="width:100%; border-collapse:collapse; border:0; border-spacing:0;"><tr><td style="color:#ffffff; font-size:20px; font-weight:bold;">Strato DDNS</td></tr></table></td></tr><tr><td style="padding:32px 24px; background-color:#ffffff;"><h1 style="font-size:24px; margin:0 0 20px 0; color:#111827;">{subject}</h1><p style="margin:0 0 12px 0; font-size:16px; line-height:24px; color:#374151;"><strong>Datum:</strong> {timestamp_str}<br><strong>Ereignis:</strong> {event}<br><strong>Auslöser:</strong> {trigger}</p><table role="presentation" style="width:100%; border-collapse:collapse; border:1px solid #e5e7eb; border-spacing:0; border-radius: 8px; overflow: hidden;"><thead><tr style="background-color:#0078d4; color:#ffffff;"><th style="padding:12px 16px; text-align:left; font-size:14px;">Domain</th><th style="padding:12px 16px; text-align:left; font-size:14px;">IP-Adresse</th><th style="padding:12px 16px; text-align:left; font-size:14px;">Status</th></tr></thead><tbody>{rows}</tbody></table></td></tr><tr><td style="padding:16px 24px; background-color:#0078d4; text-align:center; color:#ffffff; font-size:14px;">© <a href="http://Q14siX.de" target="_blank" style="color:#ffffff; text-decoration:none;">Q14siX.de</a> | <a href="https://github.com/Q14siX/strato-ddns" target="_blank" style="color:#ffffff; text-decoration:none;">Projektseite auf GitHub</a></td></tr></table></td></tr></table></body></html>'


def send_mail(config, subject, entries, timestamp, event, trigger):
    """Versendet eine E-Mail."""
    ms = get_mail_settings(config)
    if not ms.get("enabled"):
        return False, "Mailversand ist deaktiviert."

    recipients = [r.strip() for r in ms.get("recipients", "").split(",") if r.strip()]
    if not recipients:
        return False, "Keine Empfänger konfiguriert."

    try:
        msg = MIMEMultipart("alternative")
        msg["Subject"] = subject
        msg["From"] = ms["sender"]
        msg["To"] = ", ".join(recipients)
        
        html_body = build_html_mail(subject, entries, timestamp, event, trigger)
        msg.attach(MIMEText(html_body, "html", "utf-8"))

        smtp_port = int(ms.get("smtp_port", 587))
        with smtplib.SMTP(ms["smtp_server"], smtp_port, timeout=10) as server:
            server.starttls()
            if ms.get("smtp_user") and ms.get("smtp_pass"):
                server.login(ms["smtp_user"], ms["smtp_pass"])
            server.sendmail(ms["sender"], recipients, msg.as_string())
        return True, "Mail erfolgreich versendet."
    except Exception as e:
        return False, f"Mail-Fehler: {e}"


# --- Decorators & Hooks ---

def login_required(f):
    @wraps(f)
    def decorated_function(*args, **kwargs):
        if 'logged_in' not in session:
            return redirect(url_for('login'))
        return f(*args, **kwargs)
    return decorated_function

@app.before_request
def setup_session():
    config = load_config()
    app.secret_key = config.get("secret_key", os.urandom(24))

@app.errorhandler(RateLimitExceeded)
def handle_ratelimit(e):
    flash(f"Zu viele Versuche. Limit: {e.description}", "danger")
    return render_template("login.html", disabled=True), 429

@app.errorhandler(404)
def not_found(e):
    if 'logged_in' in session:
        return redirect(url_for('log_page'))
    return redirect(url_for('login'))


# --- Hauptrouten ---

@app.route('/')
@login_required
def index():
    return redirect(url_for('log_page'))

@app.route('/login', methods=['GET', 'POST'])
@limiter.limit("10 per hour", methods=["POST"], error_message="Zu viele Login-Versuche.")
def login():
    if request.method == 'POST':
        config = load_config()
        user = request.form.get('username')
        pw = request.form.get('password')
        if user == config.get("webuser") and pw == config.get("webpass"):
            session['logged_in'] = True
            return redirect(url_for('log_page'))
        else:
            flash("Falsche Zugangsdaten.", "danger")
    return render_template('login.html')

@app.route('/logout')
def logout():
    session.clear()
    return redirect(url_for('login'))

@app.route('/log')
@login_required
def log_page():
    entries = []
    if os.path.exists(LOG_FILE):
        try:
            tree = ET.parse(LOG_FILE)
            root = tree.getroot()
            for entry in root.findall('entry'):
                entries.append({
                    "datetime": entry.findtext("timestamp", "N/A"),
                    "trigger": entry.findtext("trigger", "N/A"),
                    "domain": entry.findtext("domain", "N/A"),
                    "ip": entry.findtext("ip", "N/A"),
                    "status": entry.findtext("status", "N/A")
                })
            entries.sort(key=lambda x: x["datetime"], reverse=True)
        except ET.ParseError:
            flash("Fehler beim Lesen der Log-Datei.", "danger")
    return render_template("log.html", log_entries=entries, pagename="log")

@app.route('/config')
@login_required
def config_page():
    config = load_config()
    return render_template(
        'config.html',
        username=config.get("username", ""),
        password=config.get("password", ""),
        domains="\n".join(config.get("domains", [])),
        mail_settings=get_mail_settings(config),
        log_retention_hours=config.get("log_retention_hours", 24),
        pagename="config"
    )

@app.route('/webupdate')
@login_required
def webupdate_page():
    config = load_config()
    username = config.get("username", "")
    password = config.get("password", "")
    ip = get_public_ip()
    hostnames = config.get("domains", [])
    results = []
    new_log_entries = []
    now = datetime.now(TIMEZONE)
    timestamp = now.strftime("%Y-%m-%d %H:%M:%S")
    event = "Manuelles Update"
    trigger = "manuell"

    if not ip:
        flash("Konnte öffentliche IP nicht ermitteln.", "danger")
        return redirect(url_for('config_page'))

    for domain in hostnames:
        try:
            resp = requests.get(
                f"https://{username}:{password}@dyndns.strato.com/nic/update",
                params={'hostname': domain, 'myip': ip}, timeout=10
            )
            text_raw = resp.text.strip() if resp.status_code == 200 else f"error {resp.status_code}"
            status, returned_ip = text_raw.split(" ") if " " in text_raw else (text_raw, ip)
        except requests.RequestException as e:
            status, returned_ip = "error", str(e)
        
        results.append((domain, returned_ip, status))
        new_log_entries.append((timestamp, event, trigger, domain, returned_ip, status))

    append_log_entries(new_log_entries)
    
    ms = get_mail_settings(config)
    if ms.get("enabled") and ms.get("notify_on_success"):
        subject = f"{ms.get('subject', 'Strato DDNS')} – {event}"
        send_mail(config, subject, results, timestamp, event, trigger)

    return render_template('webupdate.html', ip=ip, results=results, pagename="update")


# --- API Endpunkte ---

@app.route('/api/save/strato', methods=['POST'])
@login_required
def api_save_strato():
    config = load_config()
    config["username"] = request.form.get("username", "").strip()
    config["password"] = request.form.get("password", "")
    config["domains"] = [d.strip() for d in request.form.get("domains", "").splitlines() if d.strip()]
    save_config(config)
    return jsonify(success=True, message="Strato DDNS Einstellungen gespeichert.")

@app.route('/api/save/mail', methods=['POST'])
@login_required
def api_save_mail():
    config = load_config()
    ms = config.get("mail_settings", {})
    ms["enabled"] = "mail_enabled" in request.form
    ms["recipients"] = request.form.get("mail_recipients", "")
    ms["sender"] = request.form.get("mail_sender", "")
    ms["subject"] = request.form.get("mail_subject", "")
    ms["smtp_user"] = request.form.get("mail_smtp_user", "")
    ms["smtp_pass"] = request.form.get("mail_smtp_pass", "")
    ms["smtp_server"] = request.form.get("mail_smtp_server", "")
    ms["smtp_port"] = request.form.get("mail_smtp_port", "587")
    ms["notify_on_success"] = "mail_notify_success" in request.form
    ms["notify_on_badauth"] = "mail_notify_badauth" in request.form
    ms["notify_on_noip"] = "mail_notify_noip" in request.form
    ms["notify_on_abuse"] = "mail_notify_abuse" in request.form
    config["mail_settings"] = ms
    save_config(config)
    return jsonify(success=True, message="Mail-Einstellungen gespeichert.")

@app.route('/api/save/access', methods=['POST'])
@login_required
def api_save_access():
    config = load_config()
    new_user = request.form.get("new_webuser", "").strip()
    new_pass = request.form.get("new_webpass", "")
    if new_pass and new_pass != request.form.get("confirm_webpass", ""):
        return jsonify(success=False, message="Passwörter stimmen nicht überein!"), 400
    if new_user:
        config["webuser"] = new_user
    if new_pass:
        config["webpass"] = new_pass
    save_config(config)
    return jsonify(success=True, message="Zugangsdaten aktualisiert.")

@app.route('/api/save/log_settings', methods=['POST'])
@login_required
def api_save_log_settings():
    config = load_config()
    try:
        hours = int(request.form.get("log_retention_hours", 24))
        if hours < 1:
            return jsonify(success=False, message="Aufbewahrungsdauer muss mindestens 1 Stunde betragen."), 400
        config["log_retention_hours"] = hours
        save_config(config)
        return jsonify(success=True, message="Protokoll-Einstellungen gespeichert.")
    except (ValueError, TypeError):
        return jsonify(success=False, message="Ungültiger Wert für Stunden."), 400

@app.route('/api/backup/download', methods=['POST'])
@login_required
def api_download_backup():
    pw = request.form.get("backup_password")
    if not pw:
        return jsonify(success=False, message="Passwort für die Verschlüsselung erforderlich."), 400
    
    key = derive_key(pw)
    fernet = Fernet(key)
    try:
        config_data = json.dumps(load_config(), indent=4).encode('utf-8')
        encrypted = fernet.encrypt(config_data)
        return send_file(
            BytesIO(encrypted),
            as_attachment=True,
            download_name=f"strato_ddns_backup_{datetime.now().strftime('%Y%m%d')}.json.enc",
            mimetype="application/octet-stream"
        )
    except Exception as e:
        return jsonify(success=False, message=f"Fehler bei der Sicherung: {e}"), 500

@app.route('/api/backup/restore', methods=['POST'])
@login_required
def api_restore_backup():
    pw = request.form.get("restore_password")
    file = request.files.get("restore_file")
    if not pw or not file:
        return jsonify(success=False, message="Datei und Passwort sind erforderlich."), 400
    
    key = derive_key(pw)
    fernet = Fernet(key)
    try:
        decrypted = fernet.decrypt(file.read())
        config_data = json.loads(decrypted)
        save_config(config_data)
        return jsonify(success=True, message="Konfiguration erfolgreich wiederhergestellt. Die Seite wird neu geladen.")
    except Exception as e:
        return jsonify(success=False, message=f"Wiederherstellung fehlgeschlagen: {e}"), 400

@app.route('/api/testmail', methods=['POST'])
@login_required
def api_testmail():
    test_config = {
        "mail_settings": {
            "enabled": True,
            "recipients": request.form.get("mail_recipients"),
            "sender": request.form.get("mail_sender"),
            "subject": request.form.get("mail_subject"),
            "smtp_user": request.form.get("mail_smtp_user"),
            "smtp_pass": request.form.get("mail_smtp_pass"),
            "smtp_server": request.form.get("mail_smtp_server"),
            "smtp_port": request.form.get("mail_smtp_port"),
        }
    }
    now = datetime.now(TIMEZONE)
    timestamp = now.isoformat()
    subject = f"{test_config['mail_settings']['subject']} – Testnachricht"
    entries = [("test.domain.com", "127.0.0.1", "good")]
    
    success, info = send_mail(test_config, subject, entries, timestamp, "Test", "manuell")
    
    if success:
        return jsonify(success=True, message=info)
    else:
        return jsonify(success=False, message=info), 500

@app.route('/api/system_update')
@login_required
def system_update():
    def generate_output():
        script_commands = """
        export APP_DIR="{app_dir}"
        export REPO_URL="https://raw.githubusercontent.com/Q14siX/strato-ddns/main"
        set -e
        
        # ========== App einspielen ==========
        echo "🐍 Neuste Version der Applikation wird aktualisiert."
        wget -q -O "$APP_DIR/app.py" "$REPO_URL/scripts/strato-ddns-app.py"
        echo "   Applikation aktualisiert."
        
        # ========== Templates einspielen ==========
        echo "📄 Neuste Version des Templates wird aktualisiert."
        wget -q -O "$APP_DIR/templates/_header.html" "$REPO_URL/templates/default/_header.html"
        wget -q -O "$APP_DIR/templates/_layout.html" "$REPO_URL/templates/default/_layout.html"
        wget -q -O "$APP_DIR/templates/config.html" "$REPO_URL/templates/default/config.html"
        wget -q -O "$APP_DIR/templates/log.html" "$REPO_URL/templates/default/log.html"
        wget -q -O "$APP_DIR/templates/login.html" "$REPO_URL/templates/default/login.html"
        wget -q -O "$APP_DIR/templates/webupdate.html" "$REPO_URL/templates/default/webupdate.html"
        echo "   Templates aktualisiert."
                        
        echo "📦 Service-Dienste werden neu gestartet."
        systemctl daemon-reload
        systemctl enable --now strato-ddns
        echo "   Neustart abgeschlossen."
        
        echo ""
        echo "🔄 Update erfolgreich abgeschlossen!"
        """.format(app_dir=BASE_DIR)
        
        process = subprocess.Popen(
            ['bash', '-c', script_commands],
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            bufsize=1,
            universal_newlines=True
        )
        
        for line in iter(process.stdout.readline, ''):
            yield f"data: {line.strip()}\n\n"
            
        process.wait()
        
        if process.returncode == 0:
            yield "event: close\ndata: Update erfolgreich abgeschlossen.\n\n"
        else:
            yield f"event: error\ndata: Update mit Fehlercode {process.returncode} fehlgeschlagen.\n\n"

    return Response(stream_with_context(generate_output()), mimetype='text/event-stream')


@app.route('/log/download_excel')
@login_required
def download_log_excel():
    if not os.path.exists(LOG_FILE):
        return "Log-Datei nicht gefunden.", 404

    wb = openpyxl.Workbook()
    ws = wb.active
    ws.title = "Protokoll"
    ws.append(["Datum", "Uhrzeit", "Auslösung", "Domain", "IP-Adresse(n)", "Status"])

    try:
        tree = ET.parse(LOG_FILE)
        root = tree.getroot()
        for entry in root.findall('entry'):
            dt_str = entry.findtext("timestamp", "")
            datum, uhrzeit = "N/A", "N/A"
            if dt_str:
                try:
                    dt_obj = datetime.strptime(dt_str, "%Y-%m-%d %H:%M:%S")
                    datum = dt_obj.strftime("%d.%m.%Y")
                    uhrzeit = dt_obj.strftime("%H:%M:%S")
                except ValueError:
                    datum = dt_str.split(" ")[0] if " " in dt_str else dt_str
            ws.append([
                datum, uhrzeit,
                entry.findtext("trigger", ""),
                entry.findtext("domain", ""),
                entry.findtext("ip", ""),
                entry.findtext("status", "")
            ])
    except ET.ParseError:
        return "Fehler beim Parsen der Log-Datei.", 500

    tmp = BytesIO()
    wb.save(tmp)
    tmp.seek(0)
    return send_file(tmp, as_attachment=True, download_name="strato_ddns_log.xlsx", mimetype="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet")

@app.route('/log/clear', methods=['POST'])
@login_required
def clear_log():
    try:
        if os.path.exists(LOG_FILE):
            os.remove(LOG_FILE)
        return jsonify(success=True, message="Protokoll wurde erfolgreich gelöscht.")
    except OSError as e:
        return jsonify(success=False, message=f"Fehler beim Löschen des Protokolls: {e}"), 500

# --- DynDNS Auto-Update Endpunkt ---
@app.route('/update')
def update():
    config = load_config()
    client_ip = get_remote_address()
    now = datetime.now(TIMEZONE)
    timestamp = now.strftime("%Y-%m-%d %H:%M:%S")
    
    failed_attempts_auto[client_ip] = [t for t in failed_attempts_auto.get(client_ip, []) if now - t < timedelta(hours=1)]
    if len(failed_attempts_auto.get(client_ip, [])) >= 10:
        return Response("abuse", mimetype='text/plain'), 429

    req_user = request.args.get('username')
    req_pass = request.args.get('password')
    req_ip = request.args.get('myip')
    ip_list = [i.strip() for i in req_ip.split(',')] if req_ip else [get_public_ip()]
    
    if not (req_user == config.get("webuser") and req_pass == config.get("webpass")):
        failed_attempts_auto[client_ip].append(now)
        
        hostnames = config.get("domains", []) or ["N/A"]
        ms = get_mail_settings(config)
        event = "Login fehlgeschlagen"
        trigger = "automatisch"
        status = "badauth"
        
        badauth_log_entries = [(timestamp, event, trigger, domain, ip_list[0] if ip_list else 'N/A', status) for domain in hostnames]
        append_log_entries(badauth_log_entries)

        if ms.get("enabled") and ms.get("notify_on_badauth"):
            results = [(domain, ip_list[0] if ip_list else 'N/A', status) for domain in hostnames]
            subject = f"{ms.get('subject', 'Strato DDNS')} – {event}"
            send_mail(config, subject, results, timestamp, event, trigger)
            
        return Response("badauth", mimetype='text/plain'), 401

    if not any(ip_list):
        return Response("noip", mimetype='text/plain'), 400
        
    username = config.get("username", "")
    password = config.get("password", "")
    hostnames = config.get("domains", [])
    results, new_log_entries = [], []
    
    overall_status = "nochg"
    status_priority = ["911", "nohost", "badauth", "notfqdn", "badagent", "abuse", "error", "good", "nochg"]

    for domain in hostnames:
        for ip in ip_list:
            if not ip: continue
            try:
                resp = requests.get(
                    f"https://{username}:{password}@dyndns.strato.com/nic/update",
                    params={'hostname': domain, 'myip': ip}, timeout=10
                )
                text_raw = resp.text.strip()
                status = text_raw.split(" ")[0] if " " in text_raw else text_raw
                returned_ip = text_raw.split(" ")[1] if len(text_raw.split()) > 1 else ip
            except requests.RequestException:
                status, returned_ip = "error", ip

            results.append((domain, returned_ip, status))
            new_log_entries.append((timestamp, "Auto-Update", "automatisch", domain, returned_ip, status))
            
            try:
                if status_priority.index(status) < status_priority.index(overall_status):
                    overall_status = status
            except ValueError:
                overall_status = "error"

    if new_log_entries:
        append_log_entries(new_log_entries)

    ms = get_mail_settings(config)
    if results and ms.get("enabled"):
        has_success = any(r[2].lower() in ["good", "nochg"] for r in results)
        has_error = not has_success
        
        if (ms.get("notify_on_success") and has_success) or (ms.get("notify_on_badauth") and has_error):
            subject = f"{ms.get('subject', 'Strato DDNS')} – Auto-Update"
            send_mail(config, subject, results, timestamp, "Auto-Update", "automatisch")

    return Response(f"{overall_status} {ip_list[0]}", mimetype='text/plain')


if __name__ == '__main__':
    app.run(host='0.0.0.0', port=80, debug=False)
