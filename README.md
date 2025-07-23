
# 📡 Strato-DDNS

[![Version](https://img.shields.io/github/v/release/Q14siX/strato-ddns)](https://github.com/Q14siX/strato-ddns/releases)
![MIT License](https://img.shields.io/badge/license-MIT-green.svg)
![Bash](https://img.shields.io/badge/script-bash-blue.svg)
![Status](https://img.shields.io/badge/status-stable-brightgreen.svg)
![Downloads](https://img.shields.io/github/downloads/Q14siX/strato-ddns/total)

Ein moderner, einfacher und flexibler **DynDNS-Dienst für Strato-Domains** – mit Web-Frontend, Sperrmechanismus, einfacher Verwaltung und automatischer Installation.  
Dieses Projekt ermöglicht es dir, deine öffentliche IP-Adresse automatisch bei Strato zu aktualisieren und deine Domains damit aktuell zu halten.  
Zusätzlich bietet es eine intuitive Verwaltung über ein webbasiertes Frontend sowie komfortable Skripte zur Verwaltung direkt im Terminal.

---

## 🚀 Features

✅ Automatisches Updaten deiner Strato-Domains über DynDNS  
✅ Web-Frontend für einfache Konfiguration  
✅ Passwortschutz und Hashing (bcrypt)  
✅ Sperrmechanismus nach zu vielen Fehlversuchen mit Entsperr-Skript  
✅ Installations-, Deinstallations- und Verwaltungsskripte  
✅ Systemd-Service zur automatischen Ausführung beim Boot  
✅ Start direkt vom GitHub-Repository möglich — keine Installation nötig
✅ **Protokollierung aller Änderungen und Updates in log.xml**  
✅ **Responsives Log-Frontend als neue Hauptseite (tabellarische, farbige Ansicht aller Updates)**  
✅ **Navigationsmenü (Log, Konfiguration, Logout) im Web-Frontend**

---

## 📂 Ordnerstruktur

```
strato-ddns-start.sh           # Startet das Menü (liegt im Hauptverzeichnis)
scripts/
├── strato-ddns-menu.sh        # Hauptmenü
├── strato-ddns-setup.sh       # Installiert / deinstalliert den Dienst
├── strato-ddns-lock.sh        # Hebt eine Sperre auf
├── strato-ddns-credentials.sh # Setzt neue Zugangsdaten
```

---

## ⚙️ Schnellstart

Du brauchst lediglich `bash` und `wget`.  
Alles andere wird automatisch erledigt.  
Du kannst das Menü **direkt vom letzten Release auf GitHub starten**, ohne erst Dateien manuell herunterladen zu müssen.

### 📥 Direkt starten:
```bash
bash <(wget -qO- https://github.com/Q14siX/strato-ddns/releases/latest/download/strato-ddns-start.sh)
```

💡 Dieser Befehl lädt die aktuelle `strato-ddns-start.sh` aus dem neuesten Release, prüft den Installationsstatus und startet dann das Menü.

---

## 🖥️ Web-Frontend

Nach der Installation läuft der Web-Frontend-Server standardmäßig auf Port `5000`.

**Neue Hauptseite nach Login:**  
Du siehst ein Protokoll aller Updates und Änderungen in einer responsiven, tabellarischen Übersicht (`log.html`).  
Über das Menü kannst du jederzeit zur Konfiguration (`/config`) oder zurück zum Log wechseln.  
Jeder Update-Vorgang (ob manuell oder automatisch) wird mit Datum, Uhrzeit, Auslöser, Domain, IP-Adresse(n) und Status dokumentiert.

### 🔐 Login

![Login-Ansicht](https://raw.githubusercontent.com/Q14siX/strato-ddns/main/images/frontend/login.png)

### ⚙️ Konfiguration

![Konfigurationsansicht](https://raw.githubusercontent.com/Q14siX/strato-ddns/main/images/frontend/config.png)

---

## 🔄 Navigation im Web-Frontend

Im Web-Frontend gibt es ein Navigationsmenü oben auf allen Seiten:

| Menüpunkt       | Beschreibung                                         |
|-----------------|------------------------------------------------------|
| **Log**         | Protokoll aller Updates/Aktionen (Startseite)        |
| **Konfiguration** | Zugangsdaten und Domains verwalten                |
| **Logout**      | Aktuelle Session beenden                             |

---

## 🔄 Verwaltung per Menü (Terminal)

Das Terminal-Menü bietet folgende Optionen:

| Option | Beschreibung         |
|--------|----------------------|
| 1      | Sperre aufheben      |
| 2      | Zugangsdaten ändern  |
| 9      | Deinstallation       |
| X      | Beenden              |

---

## 💻 Anforderungen

- Linux-Server oder -VM
- `bash`
- `wget`
- `python3`
- `systemd`

---

## ❤️ Autor

🛠️ Erstellt & gepflegt von [Q14siX](https://github.com/Q14siX)  
📬 Feedback & Pull Requests sind willkommen!
