# -*- coding: utf-8 -*-

import base64
import hashlib
import json
import os
import smtplib
import subprocess
import time
import signal
from collections import defaultdict
from datetime import datetime, timedelta
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText
from functools import wraps
from io import BytesIO
from zoneinfo import ZoneInfo

import requests
from cryptography.fernet import Fernet
from flask import (Flask, Response, flash, jsonify, redirect,
                   render_template, request, send_file, session, url_for,
                   stream_with_context)
from flask_limiter import Limiter
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

def initialize_app_config():
    """Stellt sicher, dass notwendige Konfigurationen wie der Secret Key existieren."""
    config = load_config()
    if "secret_key" not in config or not config.get("secret_key"):
        config["secret_key"] = os.urandom(24).hex()
        save_config(config)

initialize_app_config()

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
    to_remove = [
        entry for entry in root.findall('entry')
        if (t := entry.findtext("timestamp")) and
           datetime.fromisoformat(t).astimezone(TIMEZONE) < cutoff
    ]
    for entry in to_remove:
        root.remove(entry)

def append_log_entries(new_entries):
    """Fügt neue Einträge zum Log hinzu."""
    config = load_config()
    retention_hours = int(config.get("log_retention_hours", 24))
    try:
        if os.path.exists(LOG_FILE):
            tree = ET.parse(LOG_FILE)
            root = tree.getroot()
        else:
            root = ET.Element('log')
            tree = ET.ElementTree(root)

        prune_old_logs(root, retention_hours)

        for log_data in new_entries:
            entry = ET.SubElement(root, 'entry')
            for key, value in log_data.items():
                ET.SubElement(entry, key).text = value

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

def build_html_mail(subject, entries, timestamp_iso, event, trigger):
    """Erstellt eine HTML-Mail."""
    try:
        dt = datetime.fromisoformat(timestamp_iso)
        timestamp_str = dt.strftime("%d.%m.%Y - %H:%M:%S") + " Uhr"
    except (ValueError, TypeError):
        timestamp_str = str(timestamp_iso)

    rows = ""
    for domain, ip, status in entries:
        color = "#16a34a" if str(status).lower().startswith(("good", "nochg")) else "#dc2626"
        rows += f'<tr><td style="padding: 12px 16px; border-bottom: 1px solid #e5e7eb; color: #0078d4; font-weight: 500;"><a href="http://{domain}" target="_blank" style="color: #0078d4; text-decoration: none;">{domain}</a></td><td style="padding: 12px 16px; border-bottom: 1px solid #e5e7eb; color: #4b5563; font-family: monospace;">{ip}</td><td style="padding: 12px 16px; border-bottom: 1px solid #e5e7eb; color: {color}; font-weight: 500;">{status}</td></tr>'

    return f'<!DOCTYPE html><html lang="de"><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width, initial-scale=1.0"><style>body{{margin:0; padding:0; background-color:#f3f4f6; font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif, "Apple Color Emoji", "Segoe UI Emoji", "Segoe UI Symbol";}}</style></head><body style="margin:0; padding:0; background-color:#f3f4f6;"><table role="presentation" style="width:100%; border-collapse:collapse; border:0; border-spacing:0; background:#f3f4f6;"><tr><td align="center" style="padding:20px 0;"><table role="presentation" style="width:600px; max-width:600px; border-collapse:collapse; border:0; border-spacing:0;"><tr><td style="background-color:#0078d4; padding:16px 24px;"><table role="presentation" style="width:100%; border-collapse:collapse; border:0; border-spacing:0;"><tr><td style="color:#ffffff; font-size:20px; font-weight:bold;">Strato DDNS</td></tr></table></td></tr><tr><td style="padding:32px 24px; background-color:#ffffff;"><h1 style="font-size:24px; margin:0 0 20px 0; color:#111827;">{subject}</h1><p style="margin:0 0 12px 0; font-size:16px; line-height:24px; color:#374151;"><strong>Datum:</strong> {timestamp_str}<br><strong>Ereignis:</strong> {event}<br><strong>Auslöser:</strong> {trigger}</p><table role="presentation" style="width:100%; border-collapse:collapse; border:1px solid #e5e7eb; border-spacing:0; border-radius: 8px; overflow: hidden;"><thead><tr style="background-color:#0078d4; color:#ffffff;"><th style="padding:12px 16px; text-align:left; font-size:14px;">Domain</th><th style="padding:12px 16px; text-align:left; font-size:14px;">IP-Adresse</th><th style="padding:12px 16px; text-align:left; font-size:14px;">Status</th></tr></thead><tbody>{rows}</tbody></table></td></tr><tr><td style="padding:16px 24px; background-color:#0078d4; text-align:center; color:#ffffff; font-size:14px;">© <a href="http://Q14siX.de" target="_blank" style="color:#ffffff; text-decoration:none;">Q14siX.de</a> | <a href="https://github.com/Q14siX/strato-ddns" target="_blank" style="color:#ffffff; text-decoration:none;">Projektseite auf GitHub</a></td></tr></table></td></tr></table></body></html>'

def send_mail(config, subject, entries, timestamp_iso, event, trigger):
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
        
        html_body = build_html_mail(subject, entries, timestamp_iso, event, trigger)
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

def notify_on_event(config, event_type, ip="N/A"):
    """Zentrale Funktion für ereignisbasierte Benachrichtigungen."""
    ms = get_mail_settings(config)
    if not ms.get("enabled"): return

    event_map = {
        "badauth": "Login fehlgeschlagen",
        "noip": "Keine IP verfügbar",
        "abuse": "DDNS Sperre"
    }
    if event_type in event_map and ms.get(f"notify_on_{event_type}"):
        event_text = event_map[event_type]
        now = datetime.now(TIMEZONE)
        timestamp = now.isoformat()
        hostnames = config.get("domains", []) or ["N/A"]
        
        log_entries = [{
            "timestamp": timestamp, "event": event_text, "trigger": "automatisch",
            "domain": domain, "ip": ip, "status": event_type
        } for domain in hostnames]
        append_log_entries(log_entries)

        results = [(domain, ip, event_type) for domain in hostnames]
        subject = f"{ms.get('subject', 'Strato DDNS')} – {event_text}"
        send_mail(config, subject, results, timestamp, event_text, "automatisch")


# --- Decorators & Hooks ---

def login_required(f):
    @wraps(f)
    def decorated_function(*args, **kwargs):
        if 'logged_in' not in session:
            flash("Bitte melden Sie sich an, um diese Seite zu sehen.", "warning")
            return redirect(url_for('login'))
        return f(*args, **kwargs)
    return decorated_function

@app.before_request
def setup_session():
    """Wird vor jeder Anfrage ausgeführt, um die Sitzung zu konfigurieren."""
    config = load_config()
    secret = config.get("secret_key")
    
    if not secret:
        app.secret_key = "temporary-secret-key-to-prevent-crash"
    else:
        app.secret_key = secret
        
    app.permanent_session_lifetime = timedelta(days=30)

@app.errorhandler(429)
def handle_ratelimit(e):
    flash(f"Zu viele Anfragen. Limit: {e.description}", "danger")
    return render_template("login.html"), 429

@app.errorhandler(404)
def not_found(e):
    return redirect(url_for('login'))


# --- DDNS Update Core Logic ---

def _perform_ddns_update(config, ip_list, trigger):
    """Führt das DDNS-Update durch."""
    username = config.get("username", "")
    password = config.get("password", "")
    hostnames = config.get("domains", [])
    
    results, new_log_entries = [], []
    timestamp = datetime.now(TIMEZONE).isoformat()
    event = "Manuelles Update" if trigger == "manuell" else "Auto-Update"

    for domain in hostnames:
        for ip in ip_list:
            if not ip: continue
            try:
                resp = requests.get(
                    f"https://{username}:{password}@dyndns.strato.com/nic/update",
                    params={'hostname': domain, 'myip': ip}, timeout=10
                )
                text_raw = resp.text.strip()
                parts = text_raw.split()
                status = parts[0] if parts else "error"
                returned_ip = parts[1] if len(parts) > 1 else ip
            except requests.RequestException:
                status, returned_ip = "error", ip

            results.append((domain, returned_ip, status))
            new_log_entries.append({
                "timestamp": timestamp, "event": event, "trigger": trigger,
                "domain": domain, "ip": returned_ip, "status": status
            })

    if new_log_entries:
        append_log_entries(new_log_entries)

    ms = get_mail_settings(config)
    if results and ms.get("enabled"):
        statuses = {r[2].lower() for r in results}
        if ms.get("notify_on_success") and any(s in ["good", "nochg"] for s in statuses) or \
           ms.get("notify_on_badauth") and "badauth" in statuses:
            subject = f"{ms.get('subject', 'Strato DDNS')} – {event}"
            send_mail(config, subject, results, timestamp, event, trigger)
    
    return results


# --- Hauptrouten (Seiten) ---

@app.route('/')
def index():
    """Leitet den Benutzer je nach Anmeldestatus weiter."""
    if 'logged_in' in session:
        return redirect(url_for('log_page'))
    return redirect(url_for('login'))

@app.route('/login', methods=['GET', 'POST'])
@limiter.limit("10 per hour", methods=["POST"], error_message="Zu viele Login-Versuche.")
def login():
    if 'logged_in' in session:
        return redirect(url_for('log_page'))
        
    if request.method == 'POST':
        config = load_config()
        if request.form.get('username') == config.get("webuser") and \
           request.form.get('password') == config.get("webpass"):
            session['logged_in'] = True
            session.permanent = True
            return redirect(url_for('log_page'))
        else:
            flash("Falsche Zugangsdaten.", "danger")
    return render_template('login.html')

@app.route('/logout')
def logout():
    session.clear()
    return render_template('logout.html')

@app.route('/log')
@login_required
def log_page():
    entries = []
    if os.path.exists(LOG_FILE):
        try:
            tree = ET.parse(LOG_FILE)
            root = tree.getroot()
            for entry in root.findall('entry'):
                dt_str = entry.findtext("timestamp", "N/A")
                try:
                    display_dt = datetime.fromisoformat(dt_str).strftime("%d.%m.%Y %H:%M:%S")
                except (ValueError, TypeError):
                    display_dt = dt_str
                entries.append({
                    "datetime": display_dt,
                    "trigger": entry.findtext("trigger", "N/A"),
                    "domain": entry.findtext("domain", "N/A"),
                    "ip": entry.findtext("ip", "N/A"),
                    "status": entry.findtext("status", "N/A"),
                    "raw_datetime": dt_str
                })
            entries.sort(key=lambda x: x["raw_datetime"], reverse=True)
        except ET.ParseError:
            flash("Fehler beim Lesen der Log-Datei.", "danger")
    return render_template("log.html", log_entries=entries, log_exists=os.path.exists(LOG_FILE))

@app.route('/config')
@login_required
def config_page():
    return render_template('config.html', config=load_config(), mail_settings=get_mail_settings(load_config()))

@app.route('/webupdate')
@login_required
def webupdate_page():
    ip = get_public_ip()
    if not ip:
        flash("Öffentliche IP-Adresse konnte nicht ermittelt werden.", "danger")
        return redirect(url_for('config_page'))
    results = _perform_ddns_update(load_config(), [ip], "manuell")
    return render_template('webupdate.html', ip=ip, results=results)


# --- API Endpunkte ---

@app.route('/api/save/access', methods=['POST'])
@login_required
def api_save_access():
    config = load_config()
    new_pass = request.form.get("new_webpass", "")
    if new_pass and (new_pass != request.form.get("confirm_webpass", "") or len(new_pass) < 8):
        flash("Passwörter stimmen nicht überein oder sind zu kurz (min. 8 Zeichen).", "danger")
        return redirect(url_for('config_page'))
    
    if new_user := request.form.get("new_webuser", "").strip(): config["webuser"] = new_user
    if new_pass: config["webpass"] = new_pass
        
    if new_user or new_pass:
        save_config(config)
        flash("Zugangsdaten aktualisiert. Bitte melden Sie sich neu an.", "success")
        session.clear()
        return redirect(url_for('login'))
    
    flash("Keine Änderungen vorgenommen.", "info")
    return redirect(url_for('config_page'))

@app.route('/api/save/strato', methods=['POST'])
@login_required
def api_save_strato():
    config = load_config()
    config["username"] = request.form.get("username", "").strip()
    config["password"] = request.form.get("password", "")
    config["domains"] = [d.strip() for d in request.form.get("domains", "").splitlines() if d.strip()]
    save_config(config)
    flash("Strato DDNS Einstellungen gespeichert.", "success")
    return redirect(url_for('config_page'))

@app.route('/api/save/mail', methods=['POST'])
@login_required
def api_save_mail():
    config = load_config()
    ms = config.get("mail_settings", {})
    form_data = {
        "enabled": "mail_enabled" in request.form,
        "recipients": request.form.get("mail_recipients", ""),
        "sender": request.form.get("mail_sender", ""),
        "subject": request.form.get("mail_subject", ""),
        "smtp_user": request.form.get("mail_smtp_user", ""),
        "smtp_pass": request.form.get("mail_smtp_pass", ""),
        "smtp_server": request.form.get("mail_smtp_server", ""),
        "smtp_port": request.form.get("mail_smtp_port", "587"),
        "notify_on_success": "mail_notify_success" in request.form,
        "notify_on_badauth": "mail_notify_badauth" in request.form,
        "notify_on_noip": "mail_notify_noip" in request.form,
        "notify_on_abuse": "mail_notify_abuse" in request.form
    }
    ms.update(form_data)
    config["mail_settings"] = ms
    save_config(config)
    flash("Mail-Einstellungen gespeichert.", "success")
    return redirect(url_for('config_page'))

@app.route('/api/save/log_settings', methods=['POST'])
@login_required
def api_save_log_settings():
    config = load_config()
    try:
        hours = int(request.form.get("log_retention_hours", 24))
        if hours < 1: raise ValueError
        config["log_retention_hours"] = hours
        save_config(config)
        flash("Protokoll-Einstellungen gespeichert.", "success")
    except (ValueError, TypeError):
        flash("Ungültiger Wert für Stunden.", "danger")
    return redirect(url_for('config_page'))

@app.route('/api/backup/download', methods=['POST'])
@login_required
def api_download_backup():
    pw = request.form.get("backup_password")
    if not pw or len(pw) < 8:
        return jsonify(success=False, message="Passwort mit min. 8 Zeichen erforderlich."), 400
    
    try:
        encrypted = Fernet(derive_key(pw)).encrypt(json.dumps(load_config()).encode('utf-8'))
        filename = f"backup-{datetime.now(TIMEZONE).strftime('%Y%m%d-%H%M%S')}.conf"
        return send_file(BytesIO(encrypted), as_attachment=True, download_name=filename)
    except Exception as e:
        return jsonify(success=False, message=f"Fehler bei der Sicherung: {e}"), 500

@app.route('/api/backup/restore', methods=['POST'])
@login_required
def api_restore_backup():
    pw = request.form.get("restore_password")
    file = request.files.get("restore_file")
    if not pw or len(pw) < 8 or not file:
        return jsonify(success=False, message="Passwort (min. 8 Zeichen) und Datei erforderlich."), 400
    
    try:
        decrypted = Fernet(derive_key(pw)).decrypt(file.read())
        save_config(json.loads(decrypted))
        session.clear()
        return jsonify(success=True, message="Konfiguration wiederhergestellt. Sie werden abgemeldet.")
    except Exception:
        return jsonify(success=False, message="Wiederherstellung fehlgeschlagen: Passwort falsch oder Datei beschädigt."), 400

@app.route('/api/testmail', methods=['POST'])
@login_required
def api_testmail():
    test_config = {"mail_settings": {k: request.form.get(f"mail_{k}") for k in ["recipients", "sender", "subject", "smtp_user", "smtp_pass", "smtp_server", "smtp_port"]}}
    test_config["mail_settings"]["enabled"] = True
    success, info = send_mail(test_config, f"{test_config['mail_settings']['subject']} – Test", [("test.domain.com", "127.0.0.1", "good")], datetime.now(TIMEZONE).isoformat(), "Test", "manuell")
    return jsonify(success=success, message=info)

@app.route('/api/system_update')
@login_required
def system_update():
    def generate_output():
        try:
            # Schritt 1: Überprüfen, ob es sich um ein Git-Repository handelt
            yield "data: Prüfe Git-Repository...\n\n"
            if not os.path.isdir(os.path.join(BASE_DIR, '.git')):
                raise RuntimeError("Anwendungsverzeichnis ist kein Git-Repository.")

            # Schritt 2: Code von GitHub herunterladen (git fetch)
            yield "data: Lade Änderungen von GitHub (git fetch)...\n\n"
            fetch_process = subprocess.Popen(
                ['git', 'fetch', 'origin', 'main'],
                cwd=BASE_DIR, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True
            )
            for line in iter(fetch_process.stdout.readline, ''):
                yield f"data: {line.strip()}\n\n"
            fetch_process.wait()
            if fetch_process.returncode != 0:
                raise subprocess.CalledProcessError(fetch_process.returncode, 'git fetch')

            # Schritt 3: Lokalen Code auf den neuesten Stand bringen (git reset)
            yield "data: \nSetze Anwendung auf neuesten Stand (git reset)...\n\n"
            reset_process = subprocess.Popen(
                ['git', 'reset', '--hard', 'origin/main'],
                cwd=BASE_DIR, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True
            )
            for line in iter(reset_process.stdout.readline, ''):
                yield f"data: {line.strip()}\n\n"
            reset_process.wait()
            if reset_process.returncode != 0:
                raise subprocess.CalledProcessError(reset_process.returncode, 'git reset')

            # Schritt 4: Warten und Neustart auslösen
            yield f"data: \nUpdate erfolgreich. Warte 4 Sekunden auf den Neustart...\n\n"
            time.sleep(4)

            yield f"event: close\ndata: Server wird neu gestartet. Bitte melden Sie sich erneut an.\n\n"
            
            # Versuche einen sauberen Neustart über den Parent-Prozess (funktioniert mit Gunicorn/uWSGI)
            os.kill(os.getppid(), signal.SIGHUP)

        except (subprocess.CalledProcessError, RuntimeError) as e:
            error_message = str(e)
            if isinstance(e, subprocess.CalledProcessError):
                error_message = f"Fehler bei '{e.cmd}' (Code: {e.returncode})."
            yield f"event: update_error\ndata: 🛑 {error_message}\n\n"
        except FileNotFoundError:
            yield f"event: update_error\ndata: 🛑 'git' wurde nicht gefunden. Ist Git auf dem Server installiert?\n\n"
        except Exception as e:
            yield f"event: update_error\ndata: 🛑 Ein unerwarteter Fehler ist aufgetreten: {e}\n\n"
            
    return Response(stream_with_context(generate_output()), mimetype='text/event-stream')

# --- Log-Verwaltung ---

@app.route('/log/download_xml')
@login_required
def download_log_xml():
    return send_file(LOG_FILE, as_attachment=True, download_name=f"log_{datetime.now(TIMEZONE).strftime('%Y%m%d')}.xml")

@app.route('/log/clear', methods=['POST'])
@login_required
def clear_log():
    if os.path.exists(LOG_FILE):
        os.remove(LOG_FILE)
    return jsonify(success=True, message="Protokoll geleert.")

# --- DynDNS Auto-Update Endpunkt ---
@app.route('/update')
def update():
    config = load_config()
    client_ip = get_remote_address()
    now = datetime.now(TIMEZONE)
    
    failed_attempts_auto[client_ip] = [t for t in failed_attempts_auto.get(client_ip, []) if now - t < timedelta(hours=1)]
    if len(failed_attempts_auto.get(client_ip, [])) >= 10:
        notify_on_event(config, "abuse", client_ip)
        return "abuse", 429

    if not (request.args.get('username') == config.get("webuser") and request.args.get('password') == config.get("webpass")):
        failed_attempts_auto[client_ip].append(now)
        notify_on_event(config, "badauth", client_ip)
        return "badauth", 401

    ip_list = [i.strip() for i in request.args.get('myip', '').split(',') if i.strip()] or [get_public_ip()]
    if not any(ip for ip in ip_list):
        notify_on_event(config, "noip")
        return "noip", 400
        
    results = _perform_ddns_update(config, ip_list, "automatisch")
    
    status_priority = ["911", "nohost", "badauth", "notfqdn", "badagent", "abuse", "error", "good", "nochg"]
    overall_status = min((r[2] for r in results), key=lambda s: status_priority.index(s) if s in status_priority else 99, default="nochg")
    return f"{overall_status} {ip_list[0] if ip_list else ''}"


if __name__ == '__main__':
    app.run(host='0.0.0.0', port=80, debug=False)
