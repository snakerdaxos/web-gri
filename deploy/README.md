# Guía de Deploy a Producción — GRI (Ubuntu Server 24.04)

> Stack: **nginx en el HOST** (apt, con certbot) + **Docker** (mysql:8.4.11 + API
> FastAPI en `127.0.0.1:8000`). El panel admin (Flutter Web) se sirve como
> estáticos desde nginx. Todo el tráfico pasa por nginx: same-origin por paths,
> un dominio, un certificado, CERO CORS para el panel.
>
> Esta guía asume CERO conocimiento previo del repo: cada comando es copiar/pegar
> desde la raíz del repositorio clonado. Dominio de ejemplo: `gri.example.com`
> — **reemplázalo por el real en cada paso donde aparezca**.

---

## 1) Prerrequisitos

- Un **Ubuntu Server 24.04 LTS** con acceso SSH (usuario con sudo).
- Un **dominio** tuyo (ej. `gri.example.com`).
- **DNS**: en el panel de tu registrador, crea un registro **A** apuntando el
  dominio a la IP pública del servidor. Verifica desde tu máquina:

  ```bash
  nslookup gri.example.com    # debe devolver la IP del servidor
  ```

- **Firewall**: abre 80 y 443 en el servidor:

  ```bash
  sudo ufw allow 80/tcp
  sudo ufw allow 443/tcp
  sudo ufw enable
  sudo ufw status
  ```

## 2) Instalar Docker (y Docker Compose v2 integrado)

```bash
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER
# cierra sesión y vuelve a entrar (para el grupo docker), luego verifica:
docker --version
docker compose version
```

## 3) Traer el código al servidor

```bash
sudo apt update && sudo apt install -y git
sudo git clone <URL-DE-ESTE-REPO> /opt/gri
sudo chown -R $USER:$USER /opt/gri
cd /opt/gri
```

(Alternativa sin git: desde tu máquina `rsync -avz --exclude '.git' --exclude 'backend/.venv' ./ usuario@servidor:/opt/gri/`)

## 4) Secretos: `.env.production`

```bash
cd /opt/gri
cp .env.production.example .env.production
```

Genera TODOS los secretos con Python (uno por línea, cópialos al archivo):

```bash
python3 -c "import secrets; print('MYSQL_ROOT_PASSWORD='+secrets.token_urlsafe(32))"
python3 -c "import secrets; print('MYSQL_APP_PASSWORD='+secrets.token_urlsafe(32))"
python3 -c "import secrets; print('JWT_SECRET='+secrets.token_urlsafe(48))"
python3 -c "import secrets; print('SUPER_ADMIN_PASSWORD='+secrets.token_urlsafe(16))"
```

Edita y completa **TODOS** los valores:

```bash
nano .env.production
```

Checklist del archivo:
- `MYSQL_ROOT_PASSWORD` / `MYSQL_APP_PASSWORD` — generados arriba.
- `JWT_SECRET` — generado arriba (**obligatorio** fuerte; con uno débil cualquiera forja tokens).
- `SUPER_ADMIN_EMAIL` / `SUPER_ADMIN_PASSWORD` — rota el password tras el primer login.
- `DEMO_MODE=false` y `SANDBOX_MODE=false` — **NO tocar**: prod jamás los cambia
  (el compose además los deja hardcodeados como defensa).
- `CORS_ORIGINS=https://gri.example.com` (tu dominio real).
- `WOMPI_*` — deja los placeholders; se completan cuando el KYC de Wompi esté
  aprobado (ver §12).

`.env.production` está en `.gitignore` — jamás se commitea.

## 5) Instalar nginx + certbot (en el HOST)

```bash
sudo apt install -y nginx certbot python3-certbot-nginx
sudo systemctl enable --now nginx
```

> nginx corre NATIVO (no en Docker) a propósito: `certbot --nginx` gestiona
> certificado + reload + auto-renew sin coreografía docker exec (evita el
> anti-patrón reload-dance de nginx-in-container).

## 6) Construir y copiar el panel admin (Flutter Web)

El servidor NO necesita Flutter: **construye en tu máquina de desarrollo** y copia.

En tu máquina dev (Windows, flutter en el PATH):

```powershell
cd panel_admin
flutter build web --release
```

Copia el resultado al servidor (rsync/scp desde tu máquina):

```bash
rsync -avz --delete panel_admin/build/web/ usuario@SERVIDOR:/tmp/gri-panel/
# en el servidor:
sudo mkdir -p /var/www/gri-panel
sudo rm -rf /var/www/gri-panel/*
sudo cp -r /tmp/gri-panel/* /var/www/gri-panel/
sudo chown -R www-data:www-data /var/www/gri-panel
```

Verifica: `ls /var/www/gri-panel/index.html` debe existir.

## 7) Configurar nginx (sitio GRI)

```bash
sudo cp deploy/nginx/gri.conf /etc/nginx/sites-available/gri
sudo ln -s /etc/nginx/sites-available/gri /etc/nginx/sites-enabled/gri
sudo rm -f /etc/nginx/sites-enabled/default
```

Reemplaza el dominio placeholder por el REAL (4 apariciones: 2 server_name +
2 rutas de certificado):

```bash
sudo sed -i 's/gri\.example\.com/TU-DOMINIO-REAL/g' /etc/nginx/sites-available/gri
grep -c TU-DOMINIO-REAL /etc/nginx/sites-available/gri   # debe imprimir 4
```

> Nota: los `ssl_certificate` apuntan a `/etc/letsencrypt/live/TU-DOMINIO/...`
> que certbot creará en el paso 9 — por eso el test de nginx se hace DESPUÉS
> de certbot. Puedes validar ya la sintaxis con `sudo nginx -t` y esperar el
> error "cannot load certificate" (normal pre-certbot).

## 8) Levantar el stack de producción (mysql + API)

```bash
cd /opt/gri
docker compose --env-file .env.production -f deploy/docker-compose.prod.yml up -d --build
```

- **Las migraciones corren solas en el boot** (el CMD del Dockerfile ejecuta
  `alembic upgrade head` antes de uvicorn) — no hay paso manual de migraciones.
- La primera vez tarda (build de la imagen + primer boot de MySQL ~1-2 min).
- La API queda publicada **SOLO en 127.0.0.1:8000** (nadie la ve desde fuera)
  y MySQL **sin puertos expuestos** (solo red interna de Docker).

Verifica que quedó healthy:

```bash
docker compose --env-file .env.production -f deploy/docker-compose.prod.yml ps
curl -s http://127.0.0.1:8000/health     # {"status":"ok",...}
docker logs gri-prod-api --tail 20       # arranque limpio, sin errores
```

## 9) TLS con certbot (certificado + redirect + auto-renew)

```bash
sudo certbot --nginx -d TU-DOMINIO-REAL
# responde: email válido > acepta términos > NO compartir email (opcional) > redirect: SÍ (2)
```

certbot instala el certificado, edita solo el site de nginx (ACME + redirect)
y crea el timer de renovación. Verifica el auto-renew:

```bash
systemctl list-timers | grep certbot     # certbot.timer ACTIVO
sudo certbot renew --dry-run             # debe terminar sin errores
```

Y recarga nginx con la config completa ya válida:

```bash
sudo nginx -t && sudo systemctl reload nginx
```

## 10) Verificación post-deploy

Desde cualquier navegador/máquina:

```bash
curl -s https://TU-DOMINIO-REAL/health          # 200 {"status":"ok",...} — API vía nginx+TLS
curl -s -o /dev/null -w "%{http_code}\n" https://TU-DOMINIO-REAL/   # 200 — panel index.html
curl -s -o /dev/null -w "%{http_code}\n" https://TU-DOMINIO-REAL/pagos/sandbox/checkout/x  # 404 — CORRECTO
```

- Abre `https://TU-DOMINIO-REAL/` → debe cargar el panel admin (login super-admin).
- **El 404 de `/pagos/sandbox/*` es lo esperado**: el sandbox de pagos NO existe
  en producción (SANDBOX_MODE=false — el router ni se monta).
- WebSocket: abre el panel, inicia sesión y observa la consola de red: la
  conexión `wss://TU-DOMINIO-REAL/ws/staff?token=...` debe quedar abierta
  (101 Switching Protocols) sin cerrarse a los 60s.
- HTTP debe redirigir a HTTPS: `curl -sI http://TU-DOMINIO-REAL/ | head -1` → `301`.

## 11) Operación

**Actualizar a una nueva versión del código:**

```bash
cd /opt/gri
git pull
docker compose --env-file .env.production -f deploy/docker-compose.prod.yml up -d --build
```

(las migraciones nuevas se aplican solas en el boot; `restart: unless-stopped`
levanta todo tras reinicios del servidor).

**Logs:**

```bash
docker logs gri-prod-api --tail 100 -f      # API
docker logs gri-prod-mysql --tail 100       # MySQL
```

**Backup de MySQL** (agrégalo a un cron diario):

```bash
docker exec gri-prod-mysql sh -c 'mysqldump -u root -p"$MYSQL_ROOT_PASSWORD" gri' > backup-gri-$(date +%F).sql
```

**Rotación de secretos** (si `JWT_SECRET` se filtra: cambiarlo invalida TODOS
los tokens emitidos — los usuarios deben re-login):

```bash
nano .env.production                     # nuevo JWT_SECRET
docker compose --env-file .env.production -f deploy/docker-compose.prod.yml up -d
```

## 12) Troubleshooting + Wompi futuro

| Síntoma | Causa probable | Solución |
|---|---|---|
| WS se corta a los ~60s | `proxy_read_timeout` default (60s) | Verifica que `/etc/nginx/sites-available/gri` tenga `location /ws/` con `proxy_read_timeout 3600s;` + `proxy_http_version 1.1;` + headers `Upgrade`/`Connection` (viene así en `deploy/nginx/gri.conf`) |
| WS no conecta (handshake muere) | nginx sin `proxy_http_version 1.1` | Ídem anterior — nginx 1.24 (Ubuntu 24.04) lo REQUIERE explícito |
| `sudo nginx -t` → "cannot load certificate" | certbot aún no corrió | Normal antes del paso 9; corre `certbot --nginx -d TU-DOMINIO` primero |
| certbot renewal falla | nginx corriendo en Docker (anti-patrón) | Esta guía usa nginx en el HOST — verifica `sudo systemctl status nginx` |
| `/pagos/sandbox/*` da 404 | **Es lo esperado en prod** | SANDBOX_MODE=false: sin credenciales Wompi reales no hay flujo de pago |
| Panel carga pero login falla | API caída | `docker logs gri-prod-api`; `curl 127.0.0.1:8000/health` en el server |
| `curl :8000` desde fuera funciona | Alguien quitó el bind 127.0.0.1 | Restaurar `"127.0.0.1:8000:8000"` en `deploy/docker-compose.prod.yml` |

**Cuando el KYC de Wompi esté aprobado** (habilitar pagos reales):

1. Obtén las 4 keys del dashboard Wompi (merchant): `WOMPI_PUBLIC_KEY`,
   `WOMPI_PRIVATE_KEY`, `WOMPI_EVENTS_SECRET`, `WOMPI_INTEGRITY_SECRET`.
2. Edítalas en `.env.production` (deja `SANDBOX_MODE=false` como está).
3. En el dashboard Wompi → Configuración → **Webhooks**, registra:
   `https://TU-DOMINIO-REAL/webhooks/pago` (evento `transaction.updated`).
4. Reinicia: `docker compose --env-file .env.production -f deploy/docker-compose.prod.yml up -d`.
5. Prueba un pago real de baja cantidad y verifica `docker logs gri-prod-api`.

---

## Apéndice: verificación LOCAL (sin servidor)

`deploy/verify_local.ps1` reproduce este stack en tu máquina de desarrollo
(Windows): baja el stack dev, levanta el prod con secretos de prueba, monta
nginx:1.24 en :8080 con la config de verificación, y valida health + panel +
sandbox-off + WS por nginx. Restaura el stack dev al terminar.

```powershell
powershell -File deploy\verify_local.ps1    # desde la raíz del repo
```

Artefactos de este deploy: `deploy/docker-compose.prod.yml`, `deploy/nginx/gri.conf`
(producción), `deploy/nginx/local-verify.conf` + `deploy/verify_local.ps1` +
`deploy/verify_ws.py` (solo verificación local), `.env.production.example`.
