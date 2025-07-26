{% extends "_layout.html" %}

{% block title %}Update-Ergebnis{% endblock %}

{% block content %}
<div class="max-w-4xl mx-auto">
    <div class="sm:flex sm:items-center">
        <div class="sm:flex-auto">
            <h1 class="text-2xl font-bold text-gray-900">Update-Ergebnis</h1>
            <p class="mt-2 text-sm text-gray-700">Die öffentliche IP <strong class="text-gray-900 font-mono">{{ ip }}</strong> wurde an Strato gemeldet. Hier sind die Ergebnisse.</p>
        </div>
        <div class="mt-4 sm:mt-0 sm:ml-16 sm:flex-none">
            <a href="{{ url_for('config_page') }}" class="bg-primary text-white px-4 py-2 rounded-md text-sm font-medium hover:bg-primary-darker">Zurück zur Konfiguration</a>
        </div>
    </div>
    <div class="mt-8 flex flex-col">
        <div class="-my-2 -mx-4 overflow-x-auto sm:-mx-6 lg:-mx-8">
            <div class="inline-block min-w-full py-2 align-middle md:px-6 lg:px-8">
                <div class="overflow-hidden shadow ring-1 ring-black ring-opacity-5 md:rounded-lg">
                    <table class="min-w-full divide-y divide-gray-300" id="update-table">
                        <thead class="table-header text-white">
                            <tr>
                                <th scope="col" class="py-3.5 pl-4 pr-3 text-left text-sm font-semibold sm:pl-6 sortable">Domain</th>
                                <th scope="col" class="px-3 py-3.5 text-left text-sm font-semibold sortable">Gemeldete IP</th>
                                <th scope="col" class="px-3 py-3.5 text-left text-sm font-semibold sortable">Status</th>
                            </tr>
                        </thead>
                        <tbody class="divide-y divide-gray-200 bg-white">
                            {% for domain, returned_ip, result in results %}
                            <tr>
                                <td class="whitespace-nowrap py-4 pl-4 pr-3 text-sm font-medium text-gray-900 sm:pl-6">
                                    <a href="http://{{ domain }}" target="_blank" rel="noopener" class="text-primary hover:underline">{{ domain }}</a>
                                </td>
                                <td class="whitespace-nowrap px-3 py-4 text-sm text-gray-500 font-mono">{{ returned_ip }}</td>
                                <td class="whitespace-nowrap px-3 py-4 text-sm">
                                    {% set status = result.lower() %}
                                    <span class="inline-flex items-center rounded-full px-2.5 py-0.5 text-xs font-medium
                                        {% if status.startswith('good') or status.startswith('nochg') %} bg-green-100 text-green-800
                                        {% elif status.startswith('abuse') or status.startswith('badauth') or status.startswith('error') %} bg-red-100 text-red-800
                                        {% else %} bg-yellow-100 text-yellow-800 {% endif %}">
                                        {{ result }}
                                    </span>
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

                    return cellA.localeCompare(cellB, 'de', { numeric: true, sensitivity: 'base' }) * direction;
                });

                tbody.innerHTML = '';
                rows.forEach(row => tbody.appendChild(row));
            });
        });
    }

    document.addEventListener('DOMContentLoaded', () => {
        makeTableSortable('update-table');
    });
</script>
{% endblock %}
