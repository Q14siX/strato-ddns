#!/bin/bash
cat > "$APP_DIR/templates/update.html" <<'EOF_HTML'
<!DOCTYPE html>
<html lang="de">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Update</title>
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/css/bootstrap.min.css" rel="stylesheet">
</head>
<body>
<nav class="navbar navbar-expand-lg navbar-dark bg-primary">
  <div class="container-fluid">
    <a class="navbar-brand" href="/">Strato DDNS</a>
    <button class="navbar-toggler" type="button" data-bs-toggle="collapse" data-bs-target="#navbarNav"><span class="navbar-toggler-icon"></span></button>
    <div class="collapse navbar-collapse" id="navbarNav">
      <ul class="navbar-nav me-auto">
        <li class="nav-item"><a class="nav-link" href="/log">Protokoll</a></li>
        <li class="nav-item"><a class="nav-link" href="/config">Konfiguration</a></li>
      </ul>
      <span class="navbar-text"><a href="/logout" class="btn btn-outline-light btn-sm">Logout</a></span>
    </div>
  </div>
</nav>
<div class="container mt-5 mb-4">
  <div class="row justify-content-center">
    <div class="col-lg-8">
      <div class="card shadow-sm">
        <div class="card-body">
          <h3 class="card-title mb-4">Strato DDNS Update</h3>
          <p>Aktualisierte öffentliche IP: <strong>{{ ip }}</strong></p>
          <ul class="list-group">
            {% for domain, result in results %}
            <li class="list-group-item d-flex justify-content-between">
              <span>{{ domain }}</span>
              <span class="badge {% if result.lower().startswith('good') or result.lower().startswith('nochg') %}bg-success{% else %}bg-danger{% endif %}">{{ result }}</span>
            </li>
            {% endfor %}
          </ul>
          <a href="/config" class="btn btn-secondary mt-3">Zurück zur Konfiguration</a>
        </div>
      </div>
    </div>
  </div>
</div>
<script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/js/bootstrap.bundle.min.js"></script>
</body>
</html>
EOF_HTML
