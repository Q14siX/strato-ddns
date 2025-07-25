{% extends "_layout.html" %}

{% block title %}Protokoll{% endblock %}

{% block content %}
<div class="max-w-4xl mx-auto">
    <div class="sm:flex sm:items-center">
        <div class="sm:flex-auto">
            <h1 class="text-2xl font-bold text-gray-900">Protokoll</h1>
            <p class="mt-2 text-sm text-gray-700">Eine Liste der letzten DynDNS-Update-Aktivitäten.</p>
        </div>
        <div class="mt-4 sm:mt-0 sm:ml-16 sm:flex-none">
            <button type="button" onclick="downloadExcel()" class="inline-flex items-center justify-center rounded-md border border-gray-300 bg-white px-4 py-2 text-sm font-medium text-gray-700 shadow-sm hover:bg-gray-50">
                Excel-Export
            </button>
            <button type="button" onclick="confirmClearLog()" class="ml-3 inline-flex items-center justify-center rounded-md border border-transparent bg-red-600 px-4 py-2 text-sm font-medium text-white shadow-sm hover:bg-red-700">
                Leeren
            </button>
        </div>
    </div>
    <div class="mt-8 flex flex-col">
        <div class="-my-2 -mx-4 overflow-x-auto sm:-mx-6 lg:-mx-8">
            <div class="inline-block min-w-full py-2 align-middle md:px-6 lg:px-8">
                <div class="overflow-hidden shadow ring-1 ring-black ring-opacity-5 md:rounded-lg">
                    <table class="min-w-full divide-y divide-gray-300" id="log-table">
                        <thead class="table-header text-white">
                            <tr>
                                <th scope="col" class="py-3.5 pl-4 pr-3 text-left text-sm font-semibold sm:pl-6 sortable" data-sort-type="date">Datum & Uhrzeit</th>
                                <th scope="col" class="px-3 py-3.5 text-left text-sm font-semibold sortable">Auslöser</th>
                                <th scope="col" class="px-3 py-3.5 text-left text-sm font-semibold sortable">Domain</th>
                                <th scope="col" class="px-3 py-3.5 text-left text-sm font-semibold sortable">IP-Adresse(n)</th>
                                <th scope="col" class="px-3 py-3.5 text-left text-sm font-semibold sortable">Status</th>
                            </tr>
                        </thead>
                        <tbody class="divide-y divide-gray-200 bg-white">
                            {% for entry in log_entries %}
                            <tr>
                                <td class="whitespace-nowrap py-4 pl-4 pr-3 text-sm text-gray-500 sm:pl-6">
                                    {% set dt_parts = entry.datetime.split(' ') %}
                                    {% set date_parts = dt_parts[0].split('-') %}
                                    {{ date_parts[2] }}.{{ date_parts[1] }}.{{ date_parts[0] }}
                                    <span class="text-gray-400">{{ dt_parts[1] }}</span>
                                </td>
                                <td class="whitespace-nowrap px-3 py-4 text-sm text-gray-500">{{ entry.trigger }}</td>
                                <td class="whitespace-nowrap px-3 py-4 text-sm font-medium text-gray-900">
                                    <a href="https://{{ entry.domain }}" target="_blank" class="text-primary hover:underline">{{ entry.domain }}</a>
                                </td>
                                <td class="whitespace-pre-line px-3 py-4 text-sm text-gray-500 font-mono">{{ entry.ip }}</td>
                                <td class="whitespace-nowrap px-3 py-4 text-sm">
                                    {% set result = entry.status.lower() %}
                                    <span class="inline-flex items-center rounded-full px-2.5 py-0.5 text-xs font-medium
                                        {% if result.startswith('good') or result.startswith('nochg') %} bg-green-100 text-green-800
                                        {% elif result.startswith('abuse') or result.startswith('badauth') or result.startswith('configerror') or result.startswith('911') or result.startswith('error') %} bg-red-100 text-red-800
                                        {% else %} bg-yellow-100 text-yellow-800 {% endif %}">
                                        {{ entry.status }}
                                    </span>
                                </td>
                            </tr>
                            {% else %}
                            <tr>
                                <td colspan="5" class="px-6 py-16 text-center text-sm text-gray-500">
                                    <p class="font-semibold">Das Protokoll ist leer.</p>
                                    <p class="mt-1">Es wurden noch keine DDNS-Updates durchgeführt.</p>
                                </td>
                            </tr>
                            {% endfor %}
                        </tbody>
                    </table>
                </div>
            </div>
        </div>
    </div>
</div>
{% endblock %}

{% block scripts %}
<script>
    function makeTableSortable(tableId) {
        const table = document.getElementById(tableId);
        if (!table) return;
        const headers = table.querySelectorAll('th.sortable');
        const tbody = table.querySelector('tbody');

        headers.forEach((header, index) => {
            header.addEventListener('click', () => {
                const rows = Array.from(tbody.querySelectorAll('tr'));
                const isAsc = header.classList.contains('asc');
                const direction = isAsc ? -1 : 1;

                headers.forEach(h => h.classList.remove('asc', 'desc'));
                header.classList.toggle('asc', !isAsc);
                header.classList.toggle('desc', isAsc);

                rows.sort((rowA, rowB) => {
                    let cellA = rowA.children[index].innerText.trim();
                    let cellB = rowB.children[index].innerText.trim();

                    if (header.dataset.sortType === 'date') {
                        const parseDate = str => {
                            const [date, time] = str.split(' ');
                            const [d, m, y] = date.split('.');
                            return `${y}${m}${d}${time ? time.replace(/:/g, '') : ''}`;
                        };
                        cellA = parseDate(cellA);
                        cellB = parseDate(cellB);
                    }

                    return cellA.localeCompare(cellB, 'de', { numeric: true, sensitivity: 'base' }) * direction;
                });

                tbody.innerHTML = '';
                rows.forEach(row => tbody.appendChild(row));
            });
        });
    }

    document.addEventListener('DOMContentLoaded', () => {
        makeTableSortable('log-table');
    });

    function downloadExcel() {
        showModal('Excel-Export wird vorbereitet...', 'info', 'Download');
        fetch("{{ url_for('download_log_excel') }}")
            .then(async (res) => {
                if (!res.ok) throw new Error(await res.text());
                return res.blob();
            })
            .then(blob => {
                const url = window.URL.createObjectURL(blob);
                const a = document.createElement('a');
                a.style.display = 'none';
                a.href = url;
                a.download = 'strato_ddns_log.xlsx';
                document.body.appendChild(a);
                a.click();
                window.URL.revokeObjectURL(url);
                a.remove();
                showModal('Der Download wurde erfolgreich gestartet.', 'success');
            })
            .catch(error => showModal(`Fehler beim Export: ${error.message}`, 'danger'));
    }

    function confirmClearLog() {
        showModal(
            'Möchten Sie das Protokoll wirklich unwiderruflich löschen?', 
            'confirm_danger', 
            'Protokoll leeren',
            () => clearLog()
        );
    }
    
    function clearLog() {
        fetch("{{ url_for('clear_log') }}", { method: 'POST' })
            .then(res => res.json())
            .then(data => {
                if (data.success) {
                    showModal(data.message, 'success');
                    setTimeout(() => window.location.reload(), 1500);
                } else {
                    showModal(data.message, 'danger');
                }
            })
            .catch(error => showModal(`Ein unerwarteter Fehler ist aufgetreten: ${error}`, 'danger'));
    }
</script>
{% endblock %}
