#!/bin/bash
cat > "$APP_DIR/templates/log.html" <<'EOF_HTML'
<!DOCTYPE html>
<html lang="de">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Strato DDNS</title>
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/css/bootstrap.min.css" rel="stylesheet">
    <style>
    th.sortable { user-select:none; }
    th.sortable.asc:after { content: " ▲"; }
    th.sortable.desc:after { content: " ▼"; }
    </style>
</head>
<body>
<nav class="navbar navbar-expand-lg navbar-dark bg-primary">
  <div class="container-fluid">
    <a class="navbar-brand" href="/log">Strato DDNS</a>
    <button class="navbar-toggler" type="button" data-bs-toggle="collapse" data-bs-target="#navbarNav">
      <span class="navbar-toggler-icon"></span>
    </button>
    <div class="collapse navbar-collapse" id="navbarNav">
      <ul class="navbar-nav me-auto">
        <li class="nav-item"><a class="nav-link active" href="/log">Protokoll</a></li>
        <li class="nav-item"><a class="nav-link" href="/config">Konfiguration</a></li>
      </ul>
      <ul class="navbar-nav ms-auto">
        <li class="nav-item">
          <a class="nav-link" href="/logout">Logout</a>
        </li>
      </ul>
    </div>
  </div>
</nav>
<div class="container mt-5 mb-4">
  <div class="row justify-content-center">
    <div class="col-lg-10">
      <div class="card shadow-sm">
        <div class="card-body">
          <h2 class="card-title mb-4">Protokoll</h2>
          <div class="table-responsive">
            <table class="table table-striped align-middle">
              <thead>
                <tr>
                  <th scope="col" class="sortable" data-sort="date">Datum</th>
                  <th scope="col" class="sortable" data-sort="time">Uhrzeit</th>
                  <th scope="col" class="sortable" data-sort="trigger">Auslösung</th>
                  <th scope="col" class="sortable" data-sort="domain">Domain</th>
                  <th scope="col" class="sortable" data-sort="ip">IP-Adresse(n)</th>
                  <th scope="col" class="sortable" data-sort="status">Status</th>
                </tr>
              </thead>
              <tbody>
                {% for entry in log_entries %}
                  <tr>
                    {% set date_parts = entry.datetime.split(' ')[0].split('-') %}
                    <td>{{ date_parts[2] }}.{{ date_parts[1] }}.{{ date_parts[0] }}</td>
                    <td>{{ entry.datetime.split(' ')[1] }}</td>
                    <td>{{ entry.trigger }}</td>
                    <td>
                      <a href="https://{{ entry.domain }}" target="_blank" class="link-primary text-decoration-underline">{{ entry.domain }}</a>
                    </td>
                    <td style="white-space:pre-line">{{ entry.ip }}</td>
                    <td>
                      {% set result = entry.status.lower() %}
                      <span class="badge 
                        {% if result.startswith('good') or result.startswith('nochg') %}bg-success
                        {% elif result.startswith('abuse') or result.startswith('badauth') or result.startswith('configerror') or result.startswith('911') %}bg-danger
                        {% else %}bg-warning text-dark{% endif %}">{{ entry.status }}</span>
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
</div>
<script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/js/bootstrap.bundle.min.js"></script>
<script>
document.querySelectorAll('th.sortable').forEach(function(th, thIdx) {
  th.style.cursor = "pointer";
  th.addEventListener('click', function() {
    var table = th.closest('table');
    var tbody = table.querySelector('tbody');
    var rows = Array.from(tbody.querySelectorAll('tr'));
    var asc = !th.classList.contains('asc');
    // Remove sort indicators
    table.querySelectorAll('th.sortable').forEach(function(th2) {
      th2.classList.remove('asc','desc');
    });
    th.classList.add(asc ? 'asc' : 'desc');
    var sortType = th.getAttribute('data-sort');
    rows.sort(function(a, b) {
      var cellA = a.children[thIdx].innerText.trim();
      var cellB = b.children[thIdx].innerText.trim();
      // Custom parsing for date, time, ip
      if(sortType === 'date') {
        // DD.MM.YYYY nach YYYYMMDD
        cellA = cellA.split('.').reverse().join('');
        cellB = cellB.split('.').reverse().join('');
      }
      if(sortType === 'time') {
        // HH:MM:SS lexikalisch ok
      }
      if(sortType === 'ip') {
        // Sortiere nach IP-String
      }
      // Für Status und andere Spalten: Standardvergleich
      if (asc) {
        return cellA.localeCompare(cellB, undefined, {numeric:true});
      } else {
        return cellB.localeCompare(cellA, undefined, {numeric:true});
      }
    });
    rows.forEach(function(tr) { tbody.appendChild(tr); });
  });
});
</script>
</body>
</html>
EOF_HTML
