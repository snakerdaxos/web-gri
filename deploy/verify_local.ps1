#Requires -Version 5.1
<#
.SYNOPSIS
    Verificacion local production-like del deploy de GRI (09-04 Task 2).

.DESCRIPTION
    Baja el stack DEV (nota: si otro agente lo estaba usando, se restaura al
    final), levanta el stack PROD (deploy/docker-compose.prod.yml) con un
    .env.production.local derivado del example (passwords de test, flags prod
    intactos), arranca nginx:1.24 con deploy/nginx/local-verify.conf en :8080
    conectado a la red del proyecto prod, y verifica de punta a punta:

        1. health de la API (directo y a traves de nginx)
        2. panel sirve index.html via / (try_files SPA de nginx)
        3. /pagos/sandbox/* responde 404 REAL (SANDBOX_MODE=false: el router
           no esta montado — misma garantia que en produccion)
        4. WebSocket conecta con JWT real A TRAVES de nginx (headers Upgrade)

    Al final (aunque algo falle): teardown del stack prod + RESTAURA el stack
    dev. Salida: PASO/FAIL por check + exit 0 solo si TODO paso.

.NOTES
    Windows PowerShell 5.1 (sin Get-Date -AsUTC: se usa [DateTimeOffset]).
    Requiere Docker Desktop corriendo. El panel se construye con flutter si
    panel_admin/build/web no existe (PATH += C:\src\flutter\bin).
#>

# NOTA PS 5.1: EAP=Continue A PROPÓSITO — docker/flutter escriben progreso a
# stderr y con EAP=Stop + `2>&1` la primera línea stderr mataba el script
# (NativeCommandError). Los errores se controlan explícito con $LASTEXITCODE.
$ErrorActionPreference = "Continue"
Set-Location -LiteralPath (Split-Path -Parent $PSScriptRoot)   # repo root

if (-not (Test-Path .env.production.example)) {
    Write-Output "FAIL  falta .env.production.example en la raíz del repo"
    exit 1
}

$script:pass = 0
$script:fail = 0

function Write-Check([string]$name, [bool]$cond) {
    if ($cond) { Write-Output "PASO  $name"; $script:pass++ }
    else       { Write-Output "FAIL  $name"; $script:fail++ }
}

function Get-HttpStatus([string]$url) {
    try {
        $r = Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 20
        return [int]$r.StatusCode
    } catch {
        if ($_.Exception.Response) { return [int]$_.Exception.Response.StatusCode }
        return -1   # connection refused / timeout / DNS
    }
}

function Wait-HttpStatus([string]$url, [int]$expected, [int]$timeoutSec) {
    $deadline = [DateTimeOffset]::UtcNow.AddSeconds($timeoutSec)
    while ([DateTimeOffset]::UtcNow -lt $deadline) {
        if ((Get-HttpStatus $url) -eq $expected) { return $true }
        Start-Sleep -Seconds 3
    }
    return $false
}

Write-Output "=== GRI verificacion local production-like ==="

# --- (a) bajar stack dev (se restaura en el finally) ---------------------------
Write-Output "PASO-informativo: bajando stack dev (docker compose down)..."
docker compose down 2>&1 | Out-Null

# --- (b) .env.production.local del example + passwords de test ----------------
$envContent = Get-Content .env.production.example -Raw
$envContent = $envContent `
    -replace '(?m)^MYSQL_ROOT_PASSWORD=.*$',  'MYSQL_ROOT_PASSWORD=verify-local-root-pw' `
    -replace '(?m)^MYSQL_APP_PASSWORD=.*$',   'MYSQL_APP_PASSWORD=verify-local-app-pw' `
    -replace '(?m)^JWT_SECRET=.*$',           'JWT_SECRET=verify-local-jwt-secret-0123456789abcdef' `
    -replace '(?m)^SUPER_ADMIN_EMAIL=.*$',    'SUPER_ADMIN_EMAIL=verify-admin@gri.dev' `
    -replace '(?m)^SUPER_ADMIN_PASSWORD=.*$', 'SUPER_ADMIN_PASSWORD=verify-local-admin-pw'
# DEMO_MODE=false y SANDBOX_MODE=false quedan INTACTOS del example (prod real).
Set-Content -Path .env.production.local -Value $envContent -Encoding ASCII

# --- (f) panel: construir si falta el build (flutter build web --release) -----
if (-not (Test-Path "panel_admin\build\web\index.html")) {
    Write-Output "PASO-informativo: construyendo panel (flutter build web)..."
    Push-Location panel_admin
    try {
        $env:Path += ";C:\src\flutter\bin"
        flutter build web --release 2>&1 | Select-Object -Last 3
        if ($LASTEXITCODE -ne 0) { throw "flutter build web fallo (exit $LASTEXITCODE)" }
    } finally { Pop-Location }
}

try {
    # --- (c) levantar stack prod -------------------------------------------------
    Write-Output "PASO-informativo: levantando stack prod (--build)..."
    docker compose --env-file .env.production.local -f deploy/docker-compose.prod.yml up -d --build 2>&1 | Select-Object -Last 5
    if ($LASTEXITCODE -ne 0) { throw "docker compose up prod fallo" }

    # --- (d) esperar health directo :8000 (incluye primer boot de mysql) --------
    $healthy = Wait-HttpStatus "http://localhost:8000/health" 200 120
    Write-Check "health API directa :8000 (200 tras boot)" $healthy
    if (-not $healthy) { throw "la API prod no quedo healthy en 120s" }

    # --- (e) sandbox 404 REAL (SANDBOX_MODE=false: router NO montado) ----------
    $sb = Get-HttpStatus "http://localhost:8000/pagos/sandbox/checkout/VERIFY"
    Write-Check "sandbox OFF en prod real (/pagos/sandbox/* = 404, no 403/500)" ($sb -eq 404)

    # --- (g) nginx verify container en la red del proyecto prod ----------------
    $net = (docker inspect gri-prod-api --format '{{json .NetworkSettings.Networks}}' | ConvertFrom-Json).PSObject.Properties.Name
    Write-Output "PASO-informativo: red del stack prod = $net"
    docker rm -f gri-nginx-verify 2>&1 | Out-Null
    docker run -d --name gri-nginx-verify --network $net -p 8080:8080 `
        -v "${PWD}\deploy\nginx\local-verify.conf:/etc/nginx/conf.d/default.conf:ro" `
        -v "${PWD}\panel_admin\build\web:/usr/share/nginx/html:ro" nginx:1.24 | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "no pudo arrancar el contenedor nginx de verificacion" }

    # --- (h) asserts via nginx :8080 ---------------------------------------------
    $ready = Wait-HttpStatus "http://localhost:8080/health" 200 30
    Write-Check "health via nginx :8080 (proxy + regex location)" $ready

    $homeResp = Invoke-WebRequest -Uri "http://localhost:8080/" -UseBasicParsing -TimeoutSec 20
    $panelOk = ([int]$homeResp.StatusCode -eq 200) -and ($homeResp.Content -match "gri_panel_admin")
    Write-Check "panel sirve index.html via / (try_files SPA)" $panelOk

    Push-Location backend
    try {
        uv run python ../deploy/verify_ws.py --base http://localhost:8080 2>&1 | Write-Output
        Write-Check "WebSocket con JWT real a traves de nginx (verify_ws.py)" ($LASTEXITCODE -eq 0)
    } finally { Pop-Location }
}
finally {
    # --- (i) teardown SIEMPRE + restaurar dev -----------------------------------
    Write-Output "PASO-informativo: teardown prod + restauracion stack dev..."
    docker rm -f gri-nginx-verify 2>&1 | Out-Null
    if (Test-Path .env.production.local) {
        docker compose --env-file .env.production.local -f deploy/docker-compose.prod.yml down 2>&1 | Out-Null
        Remove-Item .env.production.local -Force
    }
    docker compose up -d 2>&1 | Select-Object -Last 3
    $devHealthy = Wait-HttpStatus "http://localhost:8000/health" 200 90
    Write-Check "stack DEV restaurado arriba (health 200)" $devHealthy
}

Write-Output ""
Write-Output "=== RESULTADO: $($script:pass) PASO / $($script:fail) FAIL ==="
if ($script:fail -gt 0) { exit 1 } else { exit 0 }
