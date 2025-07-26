cat > "$APP_DIR/templates/config.html" <<'EOF_HTML'
{% extends "_layout.html" %}

{% block title %}Konfiguration{% endblock %}

{% block content %}
<div class="max-w-4xl mx-auto" x-data="{ openAccordion: 'access' }">
    <h1 class="text-2xl font-bold text-gray-900 mb-6">Konfiguration</h1>
    <div class="space-y-4">
        
        <!-- Accordion Item: Verwaltungszugang -->
        <div>
            <h2>
                <button @click="openAccordion = openAccordion === 'access' ? '' : 'access'" type="button" class="accordion-button flex items-center justify-between w-full p-4 font-medium text-left text-white rounded-md focus:outline-none">
                    <span>Verwaltungszugang</span>
                    <svg :class="{'rotate-180': openAccordion === 'access'}" class="w-5 h-5 shrink-0 transition-transform duration-200" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7" /></svg>
                </button>
            </h2>
            <div x-show="openAccordion === 'access'" class="p-5 bg-white border border-gray-200 rounded-b-md">
                <form id="form-access" class="space-y-4">
                    <div>
                        <label for="new_webuser" class="block text-sm font-medium text-gray-700">Neuer Benutzername</label>
                        <input type="text" name="new_webuser" id="new_webuser" class="input-field" placeholder="Aktuellen beibehalten">
                    </div>
                    <div>
                        <label for="new_webpass" class="block text-sm font-medium text-gray-700">Neues Passwort</label>
                        <input type="password" name="new_webpass" id="new_webpass" class="input-field" placeholder="••••••••">
                    </div>
                    <div>
                        <label for="confirm_webpass" class="block text-sm font-medium text-gray-700">Passwort wiederholen</label>
                        <input type="password" name="confirm_webpass" id="confirm_webpass" class="input-field" placeholder="••••••••">
                    </div>
                    <div class="text-right">
                        <button type="button" onclick="saveForm('form-access', 'access')" class="form-button">Speichern</button>
                    </div>
                </form>
            </div>
        </div>

        <!-- Accordion Item: Strato DDNS -->
        <div>
            <h2>
                <button @click="openAccordion = openAccordion === 'strato' ? '' : 'strato'" type="button" class="accordion-button flex items-center justify-between w-full p-4 font-medium text-left text-white rounded-md focus:outline-none">
                    <span>Strato DDNS</span>
                    <svg :class="{'rotate-180': openAccordion === 'strato'}" class="w-5 h-5 shrink-0 transition-transform duration-200" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7" /></svg>
                </button>
            </h2>
            <div x-show="openAccordion === 'strato'" class="p-5 bg-white border border-gray-200 rounded-b-md">
                <form id="form-strato" class="space-y-4">
                    <div>
                        <label for="username" class="block text-sm font-medium text-gray-700">Strato Benutzername</label>
                        <input type="text" name="username" id="username" value="{{ username }}" class="input-field">
                    </div>
                    <div>
                        <label for="password" class="block text-sm font-medium text-gray-700">Strato Passwort</label>
                        <input type="password" name="password" id="password" value="{{ password }}" class="input-field">
                    </div>
                    <div>
                        <label for="domains" class="block text-sm font-medium text-gray-700">Domains (eine pro Zeile)</label>
                        <textarea name="domains" id="domains" rows="5" class="input-field">{{ domains }}</textarea>
                    </div>
                    <div class="text-right space-x-2">
                        <button type="button" onclick="startUpdate()" class="bg-gray-200 text-gray-800 px-4 py-2 rounded-md text-sm font-medium hover:bg-gray-300">Update jetzt ausführen</button>
                        <button type="button" onclick="saveForm('form-strato', 'strato')" class="form-button">Speichern</button>
                    </div>
                </form>
            </div>
        </div>

        <!-- Accordion Item: Mail-Benachrichtigungen -->
        <div>
            <h2>
                <button @click="openAccordion = openAccordion === 'mail' ? '' : 'mail'" type="button" class="accordion-button flex items-center justify-between w-full p-4 font-medium text-left text-white rounded-md focus:outline-none">
                    <span>Mail-Benachrichtigungen</span>
                    <svg :class="{'rotate-180': openAccordion === 'mail'}" class="w-5 h-5 shrink-0 transition-transform duration-200" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7" /></svg>
                </button>
            </h2>
            <div x-show="openAccordion === 'mail'" class="p-5 bg-white border border-gray-200 rounded-b-md">
                <form id="form-mail" class="space-y-4">
                    <div class="relative flex items-start"><div class="flex h-5 items-center"><input id="mail_enabled" name="mail_enabled" type="checkbox" class="h-4 w-4 rounded border-gray-300 text-primary focus:ring-primary" {% if mail_settings.enabled %}checked{% endif %}></div><div class="ml-3 text-sm"><label for="mail_enabled" class="font-medium text-gray-700">Mail-Benachrichtigungen aktivieren</label></div></div>
                    <div class="space-y-4">
                        <input type="text" name="mail_recipients" placeholder="Empfänger (Komma-getrennt)" value="{{ mail_settings.recipients }}" class="input-field">
                        <input type="text" name="mail_sender" placeholder="Absenderadresse" value="{{ mail_settings.sender }}" class="input-field">
                        <input type="text" name="mail_subject" placeholder="Betreff" value="{{ mail_settings.subject }}" class="input-field">
                        <input type="text" name="mail_smtp_server" placeholder="SMTP-Server" value="{{ mail_settings.smtp_server }}" class="input-field">
                        <input type="number" name="mail_smtp_port" placeholder="SMTP-Port" value="{{ mail_settings.smtp_port }}" class="input-field">
                        <input type="text" name="mail_smtp_user" placeholder="SMTP-Benutzername" value="{{ mail_settings.smtp_user }}" class="input-field">
                        <input type="password" name="mail_smtp_pass" placeholder="SMTP-Passwort" value="{{ mail_settings.smtp_pass }}" class="input-field">
                    </div>
                    <fieldset class="mt-4"><legend class="text-sm font-medium text-gray-900">Wann sollen E-Mails gesendet werden?</legend><div class="mt-2 space-y-2"><div class="relative flex items-start"><div class="flex h-5 items-center"><input id="mail_notify_success" name="mail_notify_success" type="checkbox" class="h-4 w-4 rounded border-gray-300 text-primary focus:ring-primary" {% if mail_settings.notify_on_success %}checked{% endif %}></div><div class="ml-3 text-sm"><label for="mail_notify_success" class="text-gray-600">Update erfolgreich</label></div></div><div class="relative flex items-start"><div class="flex h-5 items-center"><input id="mail_notify_badauth" name="mail_notify_badauth" type="checkbox" class="h-4 w-4 rounded border-gray-300 text-primary focus:ring-primary" {% if mail_settings.notify_on_badauth %}checked{% endif %}></div><div class="ml-3 text-sm"><label for="mail_notify_badauth" class="text-gray-600">Login fehlgeschlagen</label></div></div><div class="relative flex items-start"><div class="flex h-5 items-center"><input id="mail_notify_noip" name="mail_notify_noip" type="checkbox" class="h-4 w-4 rounded border-gray-300 text-primary focus:ring-primary" {% if mail_settings.notify_on_noip %}checked{% endif %}></div><div class="ml-3 text-sm"><label for="mail_notify_noip" class="text-gray-600">Keine IP verfügbar</label></div></div><div class="relative flex items-start"><div class="flex h-5 items-center"><input id="mail_notify_abuse" name="mail_notify_abuse" type="checkbox" class="h-4 w-4 rounded border-gray-300 text-primary focus:ring-primary" {% if mail_settings.notify_on_abuse %}checked{% endif %}></div><div class="ml-3 text-sm"><label for="mail_notify_abuse" class="text-gray-600">DDNS Sperre</label></div></div></div></fieldset>
                    <div class="text-right space-x-2">
                        <button type="button" id="testMailBtn" class="bg-gray-200 text-gray-800 px-4 py-2 rounded-md text-sm font-medium hover:bg-gray-300">Testen</button>
                        <button type="button" onclick="saveForm('form-mail', 'mail')" class="form-button">Speichern</button>
                    </div>
                </form>
            </div>
        </div>

        <!-- Accordion Item: Protokoll & Sicherung -->
        <div>
            <h2>
                <button @click="openAccordion = openAccordion === 'system' ? '' : 'system'" type="button" class="accordion-button flex items-center justify-between w-full p-4 font-medium text-left text-white rounded-md focus:outline-none">
                    <span>Protokoll & Sicherung</span>
                    <svg :class="{'rotate-180': openAccordion === 'system'}" class="w-5 h-5 shrink-0 transition-transform duration-200" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7" /></svg>
                </button>
            </h2>
            <div x-show="openAccordion === 'system'" class="p-5 bg-white border border-gray-200 rounded-b-md divide-y">
                <form id="form-log_settings" class="py-4 space-y-2">
                    <label for="log_retention_hours" class="block text-sm font-medium text-gray-700">Aufbewahrungsdauer Protokoll (in Stunden)</label>
                    <div class="flex items-center space-x-2">
                        <input type="number" name="log_retention_hours" id="log_retention_hours" value="{{ log_retention_hours }}" min="1" class="input-field flex-grow">
                        <button type="button" onclick="saveForm('form-log_settings', 'log_settings')" class="form-button">Speichern</button>
                    </div>
                </form>
                <div class="py-4 space-y-4">
                    <form id="form-backup" class="space-y-2">
                        <label for="backup_password" class="block text-sm font-medium text-gray-700">Passwort für Sicherung</label>
                        <input type="password" name="backup_password" id="backup_password" class="input-field" placeholder="••••••••">
                        <button type="button" id="backupBtn" class="w-full bg-gray-200 text-gray-800 px-4 py-2 rounded-md text-sm font-medium hover:bg-gray-300">Sicherung erstellen</button>
                    </form>
                    <form id="form-restore" class="space-y-2">
                        <label for="restore_password" class="block text-sm font-medium text-gray-700">Passwort für Wiederherstellung</label>
                        <input type="password" name="restore_password" id="restore_password" class="input-field" placeholder="••••••••">
                        <label for="restore_file" class="block text-sm font-medium text-gray-700">Sicherungsdatei</label>
                        <input type="file" name="restore_file" id="restore_file" accept=".enc" class="input-field file:mr-4 file:py-2 file:px-4 file:rounded-md file:border-0 file:text-sm file:font-semibold file:bg-blue-50 file:text-primary hover:file:bg-blue-100">
                        <button type="button" id="restoreBtn" class="w-full form-button">Wiederherstellen</button>
                    </form>
                </div>
            </div>
        </div>
        
        <!-- Accordion Item: Systemupdate -->
        <div>
            <h2>
                <button @click="openAccordion = openAccordion === 'update' ? '' : 'update'" type="button" class="accordion-button flex items-center justify-between w-full p-4 font-medium text-left text-white rounded-md focus:outline-none">
                    <span>Systemupdate</span>
                    <svg :class="{'rotate-180': openAccordion === 'update'}" class="w-5 h-5 shrink-0 transition-transform duration-200" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7" /></svg>
                </button>
            </h2>
            <div x-show="openAccordion === 'update'" class="p-5 bg-white border border-gray-200 rounded-b-md">
                <div class="space-y-4">
                    <p class="text-sm text-gray-600">Führt ein Update der Anwendung auf die neueste Version von GitHub durch. Der Dienst wird danach automatisch neu gestartet.</p>
                    <button id="systemUpdateBtn" onclick="startSystemUpdate()" class="form-button w-full">Systemupdate starten</button>
                </div>
            </div>
        </div>

    </div>
</div>
{% endblock %}

{% block scripts %}
<script>
    function saveForm(formId, apiEndpoint) {
        const form = document.getElementById(formId);
        const formData = new FormData(form);
        
        showModal('Speichere...', 'info');
        fetch(`/api/save/${apiEndpoint}`, { method: 'POST', body: formData })
            .then(res => res.json())
            .then(data => {
                if (data.success) {
                    showModal(data.message, 'success');
                } else {
                    showModal(data.message || 'Ein unbekannter Fehler ist aufgetreten.', 'danger');
                }
            })
            .catch(err => showModal(`Netzwerkfehler: ${err}`, 'danger'));
    }

    function startUpdate() {
        showModal('Das Update wird gestartet...', 'info', 'Update läuft');
        setTimeout(() => {
            window.location.href = "{{ url_for('webupdate_page') }}";
        }, 1500); // 1.5 Sekunden Verzögerung
    }

    function startSystemUpdate() {
        // Die schwarze Box mit fester Höhe und Scroll-Verhalten
        const updateMessage = `<div class="mt-4 p-4 bg-gray-900 text-white font-mono text-sm rounded-md overflow-y-auto" style="height: 250px;"><pre id="update-output-pre" class="whitespace-pre-wrap">Verbindung wird hergestellt...\n</pre></div>`;
        
        // Modal für den Update-Fortschritt anzeigen (gelb, Button deaktiviert)
        window.dispatchEvent(new CustomEvent('show-modal', {
            detail: {
                type: 'warning', // Gelb
                title: 'Systemupdate läuft',
                message: updateMessage,
                onConfirm: null,
                showCancel: false,
                disableConfirm: true, // Button deaktiviert
                confirmText: 'Update läuft...'
            }
        }));

        const evtSource = new EventSource("{{ url_for('system_update') }}");

        evtSource.onmessage = function(event) {
            const outputPre = document.getElementById('update-output-pre');
            if (outputPre && outputPre.textContent.startsWith('Verbindung wird hergestellt...')) {
                outputPre.textContent = ''; // Initiale Nachricht löschen
            }
            if (outputPre) {
                outputPre.textContent += event.data + '\n';
                outputPre.parentElement.scrollTop = outputPre.parentElement.scrollHeight; // Auto-scroll
            }
        };

        const onUpdateFinish = (success, details) => {
            evtSource.close();
            
            // Warten bis das Modal-Element sicher im DOM ist
            setTimeout(() => {
                const finalOutputPre = document.getElementById('update-output-pre');
                if (!finalOutputPre) return;

                const finalState = {
                    showCancel: false,
                    disableConfirm: false, // Button wieder freigeben
                    onConfirm: () => window.location.reload(), // Aktion: Seite neu laden
                    confirmText: 'OK'
                };

                if (success) {
                    finalState.type = 'success'; // Grün
                    finalState.title = 'Update erfolgreich';
                    finalOutputPre.textContent += '\n--- Update erfolgreich abgeschlossen ---\n';
                } else {
                    finalState.type = 'danger'; // Rot
                    finalState.title = 'Update fehlgeschlagen';
                    finalOutputPre.textContent += `\n--- Update fehlgeschlagen ---\nDetails: ${details || 'Keine Details verfügbar.'}\n`;
                }
                
                finalOutputPre.parentElement.scrollTop = finalOutputPre.parentElement.scrollHeight;
                
                // Behalte den Log bei und update nur den "Rahmen" des Modals
                finalState.message = finalOutputPre.parentElement.outerHTML;

                // Modal mit dem finalen Status (grün/rot) und aktiviertem Button aktualisieren
                window.dispatchEvent(new CustomEvent('show-modal', { detail: finalState }));
            }, 100); // Kurze Verzögerung zur Sicherheit
        };

        evtSource.addEventListener("close", (event) => onUpdateFinish(true, event.data));
        evtSource.addEventListener("error", (event) => onUpdateFinish(false, event.data));
        evtSource.onerror = (err) => {
            console.error("EventSource failed:", err);
            onUpdateFinish(false, "Verbindung zum Server verloren.");
        };
    }

    document.getElementById('testMailBtn').addEventListener('click', function() {
        const btn = this;
        btn.disabled = true;
        btn.textContent = 'Sende...';
        const formData = new FormData(document.getElementById('form-mail'));
        showModal('Sende Test-Mail...', 'info');
        fetch('/api/testmail', { method: 'POST', body: formData })
            .then(res => res.json())
            .then(data => data.success ? showModal(data.message, 'success') : showModal(data.message, 'danger'))
            .catch(err => showModal(`Netzwerkfehler: ${err}`, 'danger'))
            .finally(() => {
                btn.disabled = false;
                btn.textContent = 'Testen';
            });
    });

    document.getElementById('backupBtn').addEventListener('click', function() {
        const pw = document.getElementById('backup_password').value;
        if (!pw) {
            showModal('Bitte geben Sie ein Passwort für die Verschlüsselung an.', 'warning');
            return;
        }
        const formData = new FormData(document.getElementById('form-backup'));
        showModal('Sicherung wird erstellt...', 'info');
        fetch('/api/backup/download', { method: 'POST', body: formData })
            .then(async res => {
                if (!res.ok) {
                    const data = await res.json().catch(() => ({message: 'Serverfehler'}));
                    throw new Error(data.message || 'Unbekannter Fehler');
                }
                return res.blob();
            })
            .then(blob => {
                const url = window.URL.createObjectURL(blob);
                const a = document.createElement('a');
                a.href = url;
                a.download = 'strato_ddns_backup.json.enc';
                document.body.appendChild(a);
                a.click();
                a.remove();
                window.URL.revokeObjectURL(url);
                showModal('Sicherung wurde erfolgreich heruntergeladen.', 'success');
            })
            .catch(err => showModal(`Fehler bei der Sicherung: ${err.message}`, 'danger'));
    });

    document.getElementById('restoreBtn').addEventListener('click', function() {
        const pw = document.getElementById('restore_password').value;
        const file = document.getElementById('restore_file').files[0];
        if (!pw || !file) {
            showModal('Bitte wählen Sie eine Datei und geben Sie das Passwort an.', 'warning');
            return;
        }
        const formData = new FormData(document.getElementById('form-restore'));
        formData.append('restore_password', pw);
        formData.append('restore_file', file);
        showModal('Sicherung wird wiederhergestellt...', 'info');
        fetch('/api/backup/restore', { method: 'POST', body: formData })
            .then(res => res.json())
            .then(data => {
                if (data.success) {
                    showModal(data.message, 'success');
                    setTimeout(() => window.location.reload(), 2000);
                } else {
                    showModal(data.message, 'danger');
                }
            })
            .catch(err => showModal(`Netzwerkfehler: ${err}`, 'danger'));
    });
</script>
{% endblock %}
EOF_HTML
