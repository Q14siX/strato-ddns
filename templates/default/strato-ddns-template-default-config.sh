cat > "$APP_DIR/templates/config.html" <<'EOF_HTML'
<!DOCTYPE html>
<html lang="de">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Strato DDNS</title>
  <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/css/bootstrap.min.css" rel="stylesheet">
</head>
<body>
<nav class="navbar navbar-expand-lg navbar-dark bg-primary">
  <div class="container-fluid">
    <a class="navbar-brand" href="/">Strato DDNS</a>
    <button class="navbar-toggler" type="button" data-bs-toggle="collapse" data-bs-target="#navbarConfig" aria-controls="navbarConfig" aria-expanded="false" aria-label="Toggle navigation">
      <span class="navbar-toggler-icon"></span>
    </button>
    <div class="collapse navbar-collapse" id="navbarConfig">
      <ul class="navbar-nav me-auto mb-2 mb-lg-0">
        <li class="nav-item"><a class="nav-link" href="/log">Protokoll</a></li>
        <li class="nav-item"><a class="nav-link active" href="/config">Konfiguration</a></li>
      </ul>
      <ul class="navbar-nav ms-auto">
        <li class="nav-item">
          <a class="nav-link" href="/logout">Logout</a>
        </li>
      </ul>
    </div>
  </div>
</nav>

<div class="container mt-5">
  <div class="row justify-content-center">
    <div class="col-lg-10">
      <div class="card shadow-sm">
        <div class="card-body">
          <h2 class="card-title mb-4">Konfiguration</h2>
          <div id="globalMsg">
            {% if msg %}
              <div class="alert alert-success">{{ msg }}</div>
            {% elif error %}
              <div class="alert alert-danger">{{ error }}</div>
            {% endif %}
          </div>
          <div class="accordion" id="settingsAccordion">

            <!-- Verwaltungszugang -->
            <div class="accordion-item">
              <h2 class="accordion-header" id="headingAccess">
                <button class="accordion-button" type="button" data-bs-toggle="collapse" data-bs-target="#collapseAccess" aria-expanded="true" aria-controls="collapseAccess" style="box-shadow:none !important;outline:none !important;">
                  Verwaltungszugang
                </button>
              </h2>
              <div id="collapseAccess" class="accordion-collapse collapse" aria-labelledby="headingAccess" data-bs-parent="#settingsAccordion">
                <div class="accordion-body">
                  <form id="form-access" autocomplete="off">
                    <div class="form-floating mb-3">
                      <input type="text" class="form-control" name="new_webuser" id="new_webuser" placeholder="Neuer Benutzername">
                      <label for="new_webuser">Neuer Benutzername</label>
                    </div>
                    <div class="form-floating mb-3">
                      <input type="password" class="form-control" name="new_webpass" id="new_webpass" placeholder="Neues Passwort">
                      <label for="new_webpass">Neues Passwort</label>
                    </div>
                    <div class="form-floating mb-3">
                      <input type="password" class="form-control" name="confirm_webpass" id="confirm_webpass" placeholder="Passwort bestätigen">
                      <label for="confirm_webpass">Passwort wiederholen</label>
                    </div>
                    <button type="button" class="btn btn-primary" onclick="saveAccess()">Speichern</button>
                  </form>
                </div>
              </div>
            </div>

            <!-- Strato DDNS Einstellungen -->
            <div class="accordion-item">
              <h2 class="accordion-header" id="headingStrato">
                <button class="accordion-button collapsed" type="button" data-bs-toggle="collapse" data-bs-target="#collapseStrato" aria-expanded="false" aria-controls="collapseStrato" style="box-shadow:none !important;outline:none !important;">
                  Strato DDNS
                </button>
              </h2>
              <div id="collapseStrato" class="accordion-collapse collapse show" aria-labelledby="headingStrato" data-bs-parent="#settingsAccordion">
                <div class="accordion-body">
                  <form id="form-strato" autocomplete="off">
                    <div class="form-floating mb-3">
                      <input type="text" class="form-control" name="username" id="username" placeholder="Strato Benutzername" value="{{ username }}">
                      <label for="username">Strato Benutzername</label>
                    </div>
                    <div class="form-floating mb-3">
                      <input type="password" class="form-control" name="password" id="password" placeholder="Strato Passwort" value="{{ password }}">
                      <label for="password">Strato Passwort</label>
                    </div>
                    <div class="mb-3">
                      <label>Domains (eine pro Zeile)</label>
                      <textarea class="form-control" name="domains" rows="5">{{ domains }}</textarea>
                    </div>
                    <div class="mb-3 d-flex gap-2">
                      <button type="button" class="btn btn-primary" onclick="saveStrato()">Speichern</button>
                      <button type="button" class="btn btn-secondary" onclick="runUpdate()">Update jetzt ausführen</button>
                    </div>
                  </form>
                </div>
              </div>
            </div>

            <!-- Mail-Benachrichtigung Einstellungen -->
            <div class="accordion-item">
              <h2 class="accordion-header" id="headingMail">
                <button class="accordion-button collapsed" type="button" data-bs-toggle="collapse" data-bs-target="#collapseMail" aria-expanded="false" aria-controls="collapseMail" style="box-shadow:none !important;outline:none !important;">
                  Mail-Benachrichtigungen
                </button>
              </h2>
              <div id="collapseMail" class="accordion-collapse collapse" aria-labelledby="headingMail" data-bs-parent="#settingsAccordion">
                <div class="accordion-body">
                  <form id="form-mail" autocomplete="off">
                    <div class="form-check form-switch mb-3">
                      <input class="form-check-input" type="checkbox" name="mail_enabled" id="mail_enabled" {% if mail_settings.enabled %}checked{% endif %}>
                      <label class="form-check-label" for="mail_enabled">Mail-Benachrichtigungen aktivieren</label>
                    </div>
                    <div class="form-floating mb-3">
                      <input type="text" class="form-control" name="mail_recipients" id="mail_recipients" placeholder="Empfängeradresse(n)" value="{{ mail_settings.recipients }}">
                      <label for="mail_recipients">Empfängeradresse(n) (Komma getrennt)</label>
                    </div>
                    <div class="form-floating mb-3">
                      <input type="text" class="form-control" name="mail_sender" id="mail_sender" placeholder="Absenderadresse" value="{{ mail_settings.sender }}">
                      <label for="mail_sender">Absenderadresse</label>
                    </div>
                    <div class="form-floating mb-3">
                      <input type="text" class="form-control" name="mail_subject" id="mail_subject" placeholder="Betreff" value="{{ mail_settings.subject }}">
                      <label for="mail_subject">Betreff</label>
                    </div>
                    <div class="form-floating mb-3">
                      <input type="text" class="form-control" name="mail_smtp_user" id="mail_smtp_user" placeholder="SMTP-Benutzername" value="{{ mail_settings.smtp_user }}">
                      <label for="mail_smtp_user">SMTP-Benutzername</label>
                    </div>
                    <div class="form-floating mb-3">
                      <input type="password" class="form-control" name="mail_smtp_pass" id="mail_smtp_pass" placeholder="SMTP-Passwort" value="{{ mail_settings.smtp_pass }}">
                      <label for="mail_smtp_pass">SMTP-Passwort</label>
                    </div>
                    <div class="form-floating mb-3">
                      <input type="text" class="form-control" name="mail_smtp_server" id="mail_smtp_server" placeholder="SMTP-Server" value="{{ mail_settings.smtp_server }}">
                      <label for="mail_smtp_server">SMTP-Server</label>
                    </div>
                    <div class="form-floating mb-3">
                      <input type="number" class="form-control" name="mail_smtp_port" id="mail_smtp_port" placeholder="SMTP-Port" value="{{ mail_settings.smtp_port }}">
                      <label for="mail_smtp_port">SMTP-Port</label>
                    </div>
                    <label class="form-label mt-3">Wann sollen E-Mails gesendet werden?</label>
                    <div class="form-check form-switch">
                      <input class="form-check-input" type="checkbox" name="mail_notify_success" id="mail_notify_success" {% if mail_settings.notify_on_success %}checked{% endif %}>
                      <label class="form-check-label" for="mail_notify_success">Update erfolgreich (IP wurde aktualisiert)</label>
                    </div>
                    <div class="form-check form-switch">
                      <input class="form-check-input" type="checkbox" name="mail_notify_badauth" id="mail_notify_badauth" {% if mail_settings.notify_on_badauth %}checked{% endif %}>
                      <label class="form-check-label" for="mail_notify_badauth">Strato DDNS: Login fehlgeschlagen</label>
                    </div>
                    <div class="form-check form-switch">
                      <input class="form-check-input" type="checkbox" name="mail_notify_noip" id="mail_notify_noip" {% if mail_settings.notify_on_noip %}checked{% endif %}>
                      <label class="form-check-label" for="mail_notify_noip">Keine IP verfügbar</label>
                    </div>
                    <div class="form-check form-switch mb-3">
                      <input class="form-check-input" type="checkbox" name="mail_notify_abuse" id="mail_notify_abuse" {% if mail_settings.notify_on_abuse %}checked{% endif %}>
                      <label class="form-check-label" for="mail_notify_abuse">DDNS Sperre durch Missbrauchsversuche</label>
                    </div>
                    <div class="mb-3 d-flex gap-2">
                      <button type="button" class="btn btn-primary" onclick="saveMail()">Speichern</button>
                      <button type="button" class="btn btn-secondary" id="testMailBtn">Mail-Einstellungen testen</button>
                      <span id="mailTestResult" class="ms-2"></span>
                    </div>
                  </form>
                </div>
              </div>
            </div>

            <!-- Backup / Restore -->
            <div class="accordion-item">
              <h2 class="accordion-header" id="headingBackup">
                <button class="accordion-button collapsed" type="button" data-bs-toggle="collapse" data-bs-target="#collapseBackup" aria-expanded="false" aria-controls="collapseBackup" style="box-shadow:none !important;outline:none !important;">
                  Sichern & Wiederherstellen
                </button>
              </h2>
              <div id="collapseBackup" class="accordion-collapse collapse" aria-labelledby="headingBackup" data-bs-parent="#settingsAccordion">
                <div class="accordion-body">
                  <form id="form-backup" class="mb-2" onsubmit="return false;">
                    <div class="form-floating mb-3">
                      <input type="password" class="form-control" name="backup_password" id="backup_password" placeholder="Passwort">
                      <label for="backup_password">Passwort für Verschlüsselung</label>
                    </div>
                    <button type="button" class="btn btn-primary" id="downloadConfigBtn">Sichern</button>
                  </form>
                  <hr>
                  <form id="form-restore" enctype="multipart/form-data" onsubmit="return false;">
                    <div class="form-floating mb-3">
                      <input type="password" class="form-control" name="restore_password" id="restore_password" placeholder="Passwort">
                      <label for="restore_password">Passwort zum Entschlüsseln</label>
                    </div>
                    <div class="mb-3">
                      <label for="restore_file" class="form-label">Datei auswählen (.enc)</label>
                      <input class="form-control" type="file" id="restore_file" name="restore_file" accept=".enc">
                    </div>
                    <button type="button" class="btn btn-primary" id="restoreBtn">Wiederherstellen</button>
                    <span id="restoreResult" class="ms-2"></span>
                  </form>
                </div>
              </div>
            </div>

          </div>
        </div>
      </div>
    </div>
  </div>
</div>
<script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/js/bootstrap.bundle.min.js"></script>
<script>
function showMsg(html, type="success") {
  const msgBox = document.getElementById('globalMsg');
  msgBox.innerHTML = `<div class="alert alert-${type}">${html}</div>`;
}
function clearMsg() {
  document.getElementById('globalMsg').innerHTML = "";
}
function saveStrato() {
  clearMsg();
  const form = document.getElementById('form-strato');
  const data = new FormData(form);
  fetch('/config/save_strato', {
    method: 'POST',
    body: data
  })
  .then(res => res.json())
  .then(data => {
    if(data.success) showMsg(data.msg, "success");
    else showMsg(data.msg, "danger");
  });
}
function saveMail() {
  clearMsg();
  const form = document.getElementById('form-mail');
  const data = new FormData(form);
  fetch('/config/save_mail', {
    method: 'POST',
    body: data
  })
  .then(res => res.json())
  .then(data => {
    if(data.success) showMsg(data.msg, "success");
    else showMsg(data.msg, "danger");
  });
}
function saveAccess() {
  clearMsg();
  const form = document.getElementById('form-access');
  const data = new FormData(form);
  fetch('/config/save_access', {
    method: 'POST',
    body: data
  })
  .then(res => res.json())
  .then(data => {
    if(data.success) showMsg(data.msg, "success");
    else showMsg(data.msg, "danger");
  });
}
function runUpdate() {
  window.location.href = "/update";
}
document.getElementById('downloadConfigBtn').onclick = function() {
  clearMsg();
  const pw = document.getElementById('backup_password').value;
  if (!pw) {
    showMsg("Bitte ein Passwort für die Sicherung eingeben!", "danger");
    return;
  }
  const form = document.getElementById('form-backup');
  const formData = new FormData();
  formData.append('backup_password', pw);
  fetch('/backup/download', {
    method: 'POST',
    body: formData
  }).then(r => {
    if (!r.ok) throw new Error("Fehler beim Download");
    return r.blob();
  }).then(blob => {
    const url = window.URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = "config.json.enc";
    document.body.appendChild(a);
    a.click();
    a.remove();
    window.URL.revokeObjectURL(url);
    showMsg("Konfiguration wurde heruntergeladen.", "success");
  }).catch(e => {
    showMsg("Fehler beim Download: " + e.message, "danger");
  });
};
document.getElementById('restoreBtn').onclick = function() {
  clearMsg();
  const pw = document.getElementById('restore_password').value;
  const file = document.getElementById('restore_file').files[0];
  const result = document.getElementById('restoreResult');
  if (!pw || !file) {
    result.textContent = "❌ Datei und Passwort angeben!";
    result.className = "ms-2 text-danger";
    return;
  }
  const formData = new FormData();
  formData.append('restore_password', pw);
  formData.append('restore_file', file);
  fetch('/backup/upload', {
    method: 'POST',
    body: formData
  })
  .then(r => r.json())
  .then(data => {
    if(data.success) {
      result.textContent = "✅ Wiederherstellung erfolgreich!";
      result.className = "ms-2 text-success";
      showMsg("Wiederherstellung erfolgreich!", "success");
      setTimeout(()=>location.reload(), 1500);
    } else {
      result.textContent = "❌ "+data.msg;
      result.className = "ms-2 text-danger";
      showMsg(data.msg, "danger");
    }
  })
  .catch(e => {
    result.textContent = "❌ Fehler!";
    result.className = "ms-2 text-danger";
    showMsg("Fehler: " + e.message, "danger");
  });
};
// Testmail bleibt
document.getElementById('testMailBtn').onclick = function() {
  const btn = this;
  const result = document.getElementById('mailTestResult');
  btn.disabled = true;
  result.textContent = "Teste...";
  result.className = "ms-2 text-secondary";
  const form = document.getElementById('form-mail');
  const data = new FormData(form);
  fetch('/testmail', {
    method: 'POST',
    body: data
  }).then(r => {
    if (r.ok) return r.text();
    else throw new Error("Fehler beim Senden");
  }).then(msg => {
    result.textContent = "✅ Test erfolgreich!";
    result.className = "ms-2 text-success";
  }).catch(e => {
    result.textContent = "❌ Test fehlgeschlagen!";
    result.className = "ms-2 text-danger";
  }).finally(() => {
    btn.disabled = false;
  });
};
</script>
</body>
</html>
EOF_HTML
