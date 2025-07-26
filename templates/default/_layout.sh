<!DOCTYPE html>
<html lang="de" class="h-full bg-gray-100">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Strato DDNS - {% block title %}{% endblock %}</title>
    <script src="https://cdn.tailwindcss.com"></script>
    <script src="//unpkg.com/alpinejs" defer></script>
    <style>
        :root {
            --color-primary: #0078d4;
            --color-primary-darker: #005a9e;
        }
        .bg-primary { background-color: var(--color-primary); }
        .bg-primary-darker { background-color: var(--color-primary-darker); }
        .text-primary { color: var(--color-primary); }
        .border-primary { border-color: var(--color-primary); }
        .accordion-button {
            background-color: var(--color-primary);
        }
        .accordion-button:hover {
            background-color: var(--color-primary-darker);
        }
        .table-header {
            background-color: var(--color-primary);
        }
        .form-button {
            background-color: var(--color-primary);
            color: white;
            padding: 0.5rem 1rem;
            border-radius: 0.375rem; /* rounded-md */
            font-size: 0.875rem; /* text-sm */
            font-weight: 500; /* font-medium */
        }
        .form-button:hover {
            background-color: var(--color-primary-darker);
        }
        .input-field {
            display: block;
            width: 100%;
            border-radius: 0.375rem; /* rounded-md */
            border: 1px solid #d1d5db; /* border-gray-300 */
            padding: 0.5rem 0.75rem; /* px-3 py-2 */
            color: #111827; /* text-gray-900 */
            box-shadow: 0 1px 2px 0 rgb(0 0 0 / 0.05); /* shadow-sm */
        }
        .input-field:focus {
            outline: 2px solid transparent;
            outline-offset: 2px;
            --tw-ring-color: var(--color-primary);
            border-color: var(--color-primary);
            box-shadow: 0 0 0 2px var(--tw-ring-color);
        }
        /* Styles for table sorting */
        th.sortable {
            cursor: pointer;
            position: relative;
            -webkit-user-select: none; /* Safari */
            -ms-user-select: none; /* IE 10+ */
            user-select: none; /* Standard syntax */
        }
        th.sortable::after {
            content: ' ';
            display: inline-block;
            width: 1em;
            height: 1em;
            margin-left: 0.25rem;
            vertical-align: middle;
            background-image: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='24' height='24' viewBox='0 0 24 24' fill='none' stroke='%23ffffff' stroke-width='2' stroke-linecap='round' stroke-linejoin='round'%3E%3Cpath d='m7 15 5 5 5-5'/%3E%3Cpath d='m7 9 5-5 5 5'/%3E%3C/svg%3E");
            background-repeat: no-repeat;
            background-size: contain;
            opacity: 0.4;
        }
        th.sortable.asc::after {
            background-image: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='24' height='24' viewBox='0 0 24 24' fill='none' stroke='%23ffffff' stroke-width='2' stroke-linecap='round' stroke-linejoin='round'%3E%3Cpath d='m18 15-6-6-6 6'/%3E%3C/svg%3E");
            opacity: 1;
        }
        th.sortable.desc::after {
            background-image: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='24' height='24' viewBox='0 0 24 24' fill='none' stroke='%23ffffff' stroke-width='2' stroke-linecap='round' stroke-linejoin='round'%3E%3Cpath d='m6 9 6 6 6-6'/%3E%3C/svg%3E");
            opacity: 1;
        }
        [x-cloak] { display: none !important; }
    </style>
</head>
<body class="flex flex-col min-h-screen">

    {% include '_header.html' %}

    <main class="flex-grow">
        <div class="mx-auto max-w-7xl py-6 sm:px-6 lg:px-8">
            {% block content %}{% endblock %}
        </div>
    </main>

    <footer class="bg-primary text-white text-center p-4">
        © <a href="http://Q14siX.de" target="_blank" class="text-white no-underline hover:text-gray-200" style="text-decoration: none;">Q14siX.de</a> | 
        <a href="https://github.com/Q14siX/strato-ddns" target="_blank" class="text-white no-underline hover:text-gray-200" style="text-decoration: none;">Projektseite auf GitHub</a>
    </footer>

    <!-- Globales Modal-Fenster -->
    <div x-data="{ show: false, type: 'info', title: '', message: '', confirmCallback: null, showCancel: true, confirmDisabled: false, confirmText: '' }"
         @show-modal.window="
            show = true;
            // Nur Eigenschaften aktualisieren, die im Event vorhanden sind
            if ($event.detail.type !== undefined) type = $event.detail.type;
            if ($event.detail.title !== undefined) title = $event.detail.title;
            if ($event.detail.message !== undefined) message = $event.detail.message;
            if ($event.detail.onConfirm !== undefined) confirmCallback = $event.detail.onConfirm;
            if ($event.detail.showCancel !== undefined) showCancel = $event.detail.showCancel;
            confirmDisabled = $event.detail.disableConfirm || false;
            confirmText = $event.detail.confirmText || '';
         "
         x-show="show"
         x-cloak
         class="fixed inset-0 z-50 flex items-center justify-center bg-black bg-opacity-50"
         aria-labelledby="modal-title" role="dialog" aria-modal="true">
        
        <div @click.away="if (!confirmDisabled) show = false" 
             x-show="show"
             x-transition:enter="ease-out duration-300"
             x-transition:enter-start="opacity-0 scale-95"
             x-transition:enter-end="opacity-100 scale-100"
             x-transition:leave="ease-in duration-200"
             x-transition:leave-start="opacity-100 scale-100"
             x-transition:leave-end="opacity-0 scale-95"
             class="relative w-full max-w-lg p-6 bg-white rounded-lg shadow-xl border-t-4"
             :class="{
                 'border-red-500': ['danger', 'error', 'confirm_danger'].includes(type),
                 'border-green-500': type === 'success',
                 'border-yellow-500': type === 'warning',
                 'border-primary': type === 'info'
             }">
            
            <h3 class="text-lg font-medium text-gray-900" x-text="title"></h3>
            <div class="mt-2">
                <p class="text-sm text-gray-600" x-html="message"></p>
            </div>
            <div class="mt-4 flex justify-end space-x-2">
                <template x-if="showCancel">
                    <button @click="show = false" type="button" class="px-4 py-2 text-sm font-medium text-gray-700 bg-white border border-gray-300 rounded-md hover:bg-gray-50">
                        Abbrechen
                    </button>
                </template>
                <button 
                    @click="if (confirmCallback) { confirmCallback(); } if (!confirmCallback) { show = false; }" 
                    type="button" 
                    class="form-button"
                    :disabled="confirmDisabled"
                    :class="{
                        'bg-red-600 hover:bg-red-700': type === 'confirm_danger', 
                        'bg-primary hover:bg-primary-darker': type !== 'confirm_danger',
                        'bg-gray-400 cursor-not-allowed': confirmDisabled
                    }"
                    x-text="confirmText || (confirmCallback ? 'Ja, ausführen' : 'OK')">
                </button>
            </div>
        </div>
    </div>

    <script>
        // Globale Funktion zum Anzeigen des Modals
        function showModal(message, type = 'info', title = '', onConfirm = null) {
            const showCancelButton = !!onConfirm;
            const typeMap = {
                success: 'Erfolg',
                danger: 'Fehler',
                error: 'Fehler',
                warning: 'Warnung',
                info: 'Information',
                confirm_danger: 'Bestätigung erforderlich'
            };
            const event = new CustomEvent('show-modal', {
                detail: {
                    type: type,
                    title: title || typeMap[type] || 'Information',
                    message: message,
                    onConfirm: onConfirm,
                    showCancel: showCancelButton
                }
            });
            window.dispatchEvent(event);
        }

        // Funktion zum Anzeigen von Flash-Nachrichten vom Server im Modal
        document.addEventListener('DOMContentLoaded', () => {
            const flashMessages = {{ get_flashed_messages(with_categories=true) | tojson | safe }};
            if (flashMessages) {
                flashMessages.forEach(function(flash) {
                    const category = flash[0];
                    const message = flash[1];
                    showModal(message, category);
                });
            }
        });
    </script>
    {% block scripts %}{% endblock %}
</body>
</html>
