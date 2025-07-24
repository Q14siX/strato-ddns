#!/bin/bash
cat > "$APP_DIR/templates/login.html" <<'EOF_HTML'
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
    <a class="navbar-brand" href="#">Strato DDNS</a>
  </div>
</nav>
<div class="container mt-5">
  <div class="row justify-content-center">
    <div class="col-md-4">
      <div class="card shadow-sm">
        <div class="card-body">
          <h2 class="card-title text-center mb-4">Login</h2>
          {% if error %}
            <div class="alert alert-danger text-center">{{ error }}</div>
          {% endif %}
          <form method="post">
            <div class="form-floating mb-3">
              <input type="text" class="form-control" id="username" name="username" placeholder="Benutzername" required>
              <label for="username">Benutzername</label>
            </div>
            <div class="form-floating mb-3">
              <input type="password" class="form-control" id="password" name="password" placeholder="Passwort" required>
              <label for="password">Passwort</label>
            </div>
            <button type="submit" class="btn btn-primary w-100" {% if disabled %}disabled{% endif %}>Anmelden</button>
          </form>
        </div>
      </div>
    </div>
  </div>
</div>
</body>
</html>
EOF_HTML
