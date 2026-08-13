# Stack Research

**Domain:** Multi-restaurant management & reservations platform (cliente móvil + panel admin web + API + tiempo real + pagos online Colombia)
**Researched:** 2026-08-13
**Confidence:** HIGH (Python & Flutter layers — verified against PyPI/pub.dev Aug 2026) / MEDIUM (payment gateways — training-only, marcados en su sección)

---

## Recommended Stack

El stack core ya está decidido por el usuario. Esta investigación prescribe **las mejores librerías dentro de cada capa** con versiones verificadas a Aug 2026.

### Core Technologies — Backend (FastAPI)

| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|-----------------|
| **Python** | 3.12 (≥3.10) | Runtime | FastAPI 0.141 requiere ≥3.10; 3.12 es el sweet spot estable con mejoras de rendimiento y `TaskGroup`. 3.13 también soportado pero con menos wheels estables en dependencias nativas. **Confidence: HIGH** |
| **FastAPI** | 0.141.1 | Web framework + WebSocket nativo | Estándar de facto para APIs async en Python. Trae WebSocket nativo (`@app.websocket("/ws")`), OpenAPI automático, inyección de dependencias. Release Jul 29 2026 — desarrollo muy activo (12 releases en Jul 2026). **Confidence: HIGH** (verificado pypi.org/project/fastapi) |
| **uvicorn[standard]** | 0.52.2 | ASGI server | Server oficial recomendado por FastAPI. El extra `[standard]` instala `uvloop` (event loop en C, 2-4x más rápido) + `httptools` (parser C) + `websockets` + `watchfiles` + `python-dotenv`. Release Aug 13 2026. **Confidence: HIGH** |
| **Pydantic** | 2.x (incluido en FastAPI) | Validación + serialización | FastAPI trae Pydantic 2.0+, que es 5-50x más rápido que 1.x. NO configurar Pydantic 1.x. **Confidence: HIGH** |

### Core Technologies — Database (MySQL en Docker)

| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|-----------------|
| **MySQL** | 8.4 LTS | Base de datos relacional | LTS hasta Abr 2032. Soporta JSON fields, window functions, CTE recursivas. Mejor elección para longevidad que 8.0 (LTS 2026) o 9.x (innovation, no-LTS). **Confidence: HIGH** |
| **SQLAlchemy** | 2.0.52 | ORM + Core async | Estándar Python. La API 2.0 unificó typed mappings con `Mapped[T]`, soporta `AsyncSession` y `async_sessionmaker`. Release Aug 11 2026. **Confidence: HIGH** (verificado docs.sqlalchemy.org) |
| **asyncmy** | 0.2.14 | Driver asyncio MySQL para SQLAlchemy | **RECOMENDADO sobre aiomysql.** Reescrito en Cython, drop-in de aiomysql (misma API). Hasta 5x más rápido en resultsets grandes y 2x en pool. Tiene wheels Windows, macOS arm64, manylinux. Release Aug 12 2026. **Confidence: HIGH** (verificado pypi.org/project/asyncmy) |
| **Alembic** | 1.19.1 | Migraciones de schema | Del mismo autor que SQLAlchemy. Autogenerate migrations, soporta batch mode para SQLite y DDL transaccional. Release Aug 8 2026. **Confidence: HIGH** |

### Core Technologies — Auth & Seguridad

| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|-----------------|
| **PyJWT** | 2.13.0 | Codificación/decodificación JWT | **RECOMENDADO sobre python-jose.** Más activo (May 21 2026 vs May 28 2025 para jose), 4 releases en 2026 vs 0 de jose. API simple. Para auth en restaurantes (5 roles: super-admin/admin/mesero/cocina/cliente) alcanza y sobra. **Confidence: HIGH** (verificado pypi.org/project/PyJWT) |
| **bcrypt** o **argon2-cffi** | latest | Hash de passwords | bcrypt es el estándar probado; argon2-cffi es el sucesor moderno (recomendado por OWASP). Elegir **uno** consistentemente. **Confidence: HIGH** |
| **passlib[bcrypt]** | 1.7.4 | Wrapper de hashing | API uniforme sobre bcrypt/argon2. Permite cambiar algoritmo sin reescribir código. **Confidence: MEDIUM** (estable pero sin releases recientes; alternativa: usar `bcrypt` directo) |

### Core Technologies — Flutter (Cliente Móvil + Admin Web)

| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|-----------------|
| **Flutter SDK** | 3.35+ (stable Aug 2026) | UI framework | Soporta Android, iOS y Web desde el mismo código. La app cliente es móvil, el panel admin es web. **Confidence: HIGH** |
| **Dart** | 3.9+ | Lenguaje | Requerido por Flutter. Records y patterns (Dart 3) simplifican el manejo de estado de pedidos. **Confidence: HIGH** |
| **dio** | 5.11.0 | Cliente HTTP | Estándar de facto (8.3k likes en pub.dev, 3.95M downloads/semana, verified publisher flutter.cn). Interceptors, CancelToken, FormData, timeout, transformadores. Mejor que `http` para una app con auth JWT (interceptor para refrescar token). Release Aug 2026. **Confidence: HIGH** |
| **flutter_riverpod** | 3.4.2 | Estado + DI | **RECOMENDADO sobre Bloc.** Flutter Favorite. Soporta code-gen con `@riverpod` annotation, manejo nativo de async (AsyncValue/AsyncData/AsyncError), testing simple. 2.8k likes, 2.76M downloads/semana. Release Aug 2026. **Confidence: HIGH** |
| **go_router** | 17.5.0 | Navegación declarativa | **Oficial del Flutter team.** Flutter Favorite. Soporta deep linking (relevante para QR `https://gri.com/mesa/001` → abrir app en esa mesa), ShellRoute para sidebar del admin, redirects para auth guards. 5.7k likes, 3.7M downloads/semana. **NOTA:** Paquete declarado feature-complete (solo bug fixes), lo cual es **positivo** — API estable. Release Aug 2026. **Confidence: HIGH** |
| **web_socket_channel** | 3.0.3 | Cliente WebSocket | **Oficial del Dart team.** Estándar cross-platform (iOS/Android/Web/desktop). API Stream-based encaja con Riverpod (`StreamProvider`). 1.6k likes, 9M downloads/semana. **Confidence: HIGH** |
| **mobile_scanner** | 7.4.0 | QR/barcode scanner | De facto (2.2k likes, 1.25M downloads/semana, verified publisher steenbakker.dev). Usa ML Kit (Android) y AVFoundation/Apple Vision (iOS) — nativo y rápido. Soporta Android+iOS+macOS+Web. **Confidence: HIGH** |

### Core Technologies — Infraestructura

| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|-----------------|
| **Docker** | 27.x (Engine) + Compose v2 | Contenerización | Estándar de facto. Compose v2 ya viene integrado en `docker` (no más `docker-compose` aparte). **Confidence: HIGH** |
| **Ubuntu Server** | 24.04 LTS | Host OS | LTS hasta 2029. Soporta Docker nativo via apt. **Confidence: HIGH** |
| **Nginx** (opcional) | 1.27+ | Reverse proxy + TLS | Frente a uvicorn para TLS termination, static files del panel admin (Flutter Web), y rate limiting. Recomendado para producción; en dev se omite. **Confidence: HIGH** |
| **Redis** (opcional) | 7.4 | Pub/Sub para WebSockets escalables | **Solo si** se planea múltiples instancias de la API en producción. Para v1 (una instancia) no es necesario — la memoria del proceso FastAPI basta para mantener conexiones WS. **Confidence: MEDIUM** |

---

## Supporting Libraries

### Backend (Python)

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| **python-multipart** | latest | Parseo de form-data | Requerido por FastAPI para endpoints con `UploadFile` (subir fotos de platos del menú). Viene con `fastapi[standard]`. **Siempre** |
| **pydantic-settings** | 2.x | Config desde .env | Tipado fuerte de settings (`DATABASE_URL`, `JWT_SECRET`, `WOMPI_PRIVATE_KEY`). Mejor que `os.getenv` crudo. **Siempre** |
| **httpx** | 0.28+ | Cliente HTTP async para backend | Para llamar APIs de pasarelas de pago (Wompi/PayU) desde FastAPI. Async-native, mejor que `requests` en apps async. **Siempre** (pagos, integraciones externas) |
| **structlog** o **loguru** | latest | Logging estructurado | Para producción con JSON logs. `loguru` es más simple; `structlog` más configurable. **Recomendado en prod** |
| **pytest** + **pytest-asyncio** | 8.x / 0.24+ | Testing | pytest-asyncio necesario para testear endpoints async y WebSocket handlers. **Siempre (tests)** |
| **black** + **ruff** | latest | Formato + lint | Ruff reemplaza flake8/isort/pyupgrade en un solo binario Rust. Black para formato. **Siempre (dev)** |
| **emails** o **fastapi-mail** | latest | Email transaccional | Para confirmar cuenta y recuperación de password. `fastapi-mail` es async-native. **Solo si se requiere email en v1** |
| **python-dateutil** | latest | Parseo flexible de fechas | Útil para reservas con zonas horarias y formatos variables. **Opcional** |

### Flutter

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| **riverpod_generator** | 3.x | Code-gen para `@riverpod` | Junto con flutter_riverpod 3.x. Genera providers tipados desde annotations. **Siempre (con Riverpod)** |
| **riverpod_lint** | 3.x | Lint rules Riverpod | Avisa sobre anti-patterns (leer provider en build, etc). **Siempre (con Riverpod)** |
| **freezed** + **freezed_annotation** + **json_serializable** | latest | Modelos inmutables + JSON | Para DTOs (Mesa, Pedido, Reserva, ItemMenu). `freezed` da copyWith/equality/sealed classes; `json_serializable` genera fromJson/toJson. **Siempre** |
| **build_runner** | latest | Runner para code-gen | Requerido por freezed/riverpod_generator/json_serializable. **Siempre (dev)** |
| **flutter_dotenv** o **flutter_env** | latest | Variables de entorno | Para `BASE_URL` API, ambiente dev/prod. **Siempre** |
| **shared_preferences** | latest | Storage key-value persistente | Para guardar JWT y preferencias del usuario. Para JWT considerar también `flutter_secure_storage` (Keystore iOS / Keychain Android). **Siempre** |
| **flutter_secure_storage** | latest | Storage encriptado | **Recomendado para JWT** sobre shared_preferences (que es plano). Usa Android Keystore / iOS Keychain. **Siempre (auth)** |
| **cached_network_image** | latest | Cache de imágenes | Para fotos de platos y restaurantes con placeholder y fade-in. **Siempre (si hay imágenes)** |
| **qr_flutter** | latest | Generación de QR (no escaneo) | Para que el panel admin **genere** el QR de cada mesa (formato `GRI-MESA-001` o URL). `mobile_scanner` es para **escanear**; este es para **generar**. **Para panel admin** |
| **intl** | latest | Internacionalización + formatos | Para formato de moneda COP (`$ 25.000`), fechas, pluralización. Aunque v1 es solo español, intl maneja los formatos regionales. **Siempre** |
| **google_fonts** | latest | Fuentes Material | Carga Inter/Roboto/Poppins dinámicamente. Coincide con mockups admin que tienen identidad visual definida. **Opcional** |
| **fl_chart** | latest | Gráficos del dashboard | Para estadísticas del admin (ventas por día, mesas más usadas). **Panel admin** |
| **data_table_2** | latest | Tablas paginadas | Para gestión de clientes, reservas, pedidos en el admin. Mejor que el DataTable nativo. **Panel admin** |

---

## Development Tools

| Tool | Purpose | Notes |
|------|---------|-------|
| **uv** | Gestión de dependencias Python (reemplaza pip/pip-tools/poetry) | FastAPI docs ahora recomiendan `uv add fastapi[standard]`. 10-100x más rápido que pip. Usar desde el inicio |
| **Docker Compose** | Orquestación local de MySQL + API | Compose v2 (integrado en docker CLI). Ver archivo ejemplo abajo |
| **ruff** | Linter + formatter (alternativa parcial a Black) | Reemplaza flake8, isort, pyupgrade, pydocstyle en un binario Rust. Configurar en `pyproject.toml` |
| **DBeaver** o **MySQL Workbench** | GUI para inspeccionar MySQL | DBeaver es universal y más potente; Workbench es oficial de MySQL |
| ** Bruno** o **Postman** | Cliente HTTP para probar API | Bruno es open-source y guarda collections en git (mejor para equipo) |
| **flutter_launcher_icons** + **flutter_native_splash** | Genera íconos y splash | Para branding GRI en Android/iOS |

---

## Installation

### Backend (`backend/`)

```bash
# Crear entorno con uv (recomendado sobre pip+venv)
cd backend
uv init --python 3.12
source .venv/bin/activate   # Linux/Mac
# o: .venv\Scripts\activate  # Windows

# Core
uv add "fastapi[standard]" uvicorn[standard]

# DB
uv add "sqlalchemy[asyncio]" asyncmy alembic

# Auth
uv add pyjwt bcrypt pydantic-settings

# HTTP client (para pasarelas de pago)
uv add httpx

# Dev dependencies
uv add --dev ruff black pytest pytest-asyncio httpx
```

**`pyproject.toml` recomendado:**
```toml
[project]
name = "gri-backend"
version = "0.1.0"
requires-python = ">=3.12"
dependencies = [
    "fastapi[standard]>=0.141.0",
    "uvicorn[standard]>=0.52.0",
    "sqlalchemy[asyncio]>=2.0.52",
    "asyncmy>=0.2.14",
    "alembic>=1.19.0",
    "pyjwt>=2.13.0",
    "bcrypt>=4.0",
    "pydantic-settings>=2.0",
    "httpx>=0.28",
]

[tool.ruff]
line-length = 100
target-version = "py312"

[tool.ruff.lint]
select = ["E", "F", "I", "B", "UP", "ASYNC", "S", "T20"]
# E/F: pycodestyle/pyflakes
# I: isort, B: bugbear, UP: pyupgrade
# ASYNC: async lints, S: security (bandit), T20: no print
ignore = ["S101"]  # allow assert in tests
```

### App Cliente (`app_cliente/`) y Panel Admin (`panel_admin/`)

Pueden ser **un solo repo Flutter** con `--platforms=android,ios,web` o **dos proyectos** separados. Recomendado: dos proyectos distintos para mantener builds livianos y target SDK específico.

```bash
# App cliente (móvil)
flutter create --org com.gri --platforms=android,ios gri_cliente
cd gri_cliente

flutter pub add \
  flutter_riverpod riverpod_annotation riverpod_lint \
  dio web_socket_channel mobile_scanner \
  freezed_annotation json_annotation \
  flutter_secure_storage shared_preferences \
  cached_network_image intl

flutter pub add --dev \
  build_runner riverpod_generator freezed json_serializable \
  custom_lint

# Generar código
dart run build_runner build --delete-conflicting-outputs

# Panel admin (web)
flutter create --org com.gri --platforms=web gri_admin
cd gri_admin

flutter pub add \
  flutter_riverpod riverpod_annotation \
  dio web_socket_channel \
  freezed_annotation json_annotation \
  flutter_secure_storage \
  qr_flutter fl_chart data_table_2 intl

flutter pub add --dev \
  build_runner riverpod_generator freezed json_serializable custom_lint
```

**`pubspec.yaml` (extracto, app cliente):**
```yaml
environment:
  sdk: ^3.9.0

dependencies:
  flutter:
    sdk: flutter
  flutter_riverpod: ^3.4.2
  riverpod_annotation: ^3.0.0
  dio: ^5.11.0
  web_socket_channel: ^3.0.3
  mobile_scanner: ^7.4.0
  freezed_annotation: ^2.4.0
  json_annotation: ^4.9.0
  flutter_secure_storage: ^9.2.0
  cached_network_image: ^3.4.0
  intl: ^0.19.0

dev_dependencies:
  build_runner: ^2.4.0
  riverpod_generator: ^3.0.0
  freezed: ^2.5.0
  json_serializable: ^6.8.0
  riverpod_lint: ^3.0.0
  custom_lint: ^0.6.0
```

### Infraestructura (Docker Compose)

**`docker-compose.yml`** en la raíz del backend (corre en el Ubuntu Server):

```yaml
services:
  mysql:
    image: mysql:8.4-lts
    container_name: gri-mysql
    restart: unless-stopped
    environment:
      MYSQL_ROOT_PASSWORD: ${MYSQL_ROOT_PASSWORD}
      MYSQL_DATABASE: gri
      MYSQL_USER: gri_app
      MYSQL_PASSWORD: ${MYSQL_APP_PASSWORD}
    ports:
      - "3306:3306"   # En producción: NO exponer; solo internal network
    volumes:
      - gri_mysql_data:/var/lib/mysql
    command: --default-authentication-plugin=caching_sha2_password
             --character-set-server=utf8mb4
             --collation-server=utf8mb4_unicode_ci
    healthcheck:
      test: ["CMD", "mysqladmin", "ping", "-h", "localhost", "-u", "root", "-p${MYSQL_ROOT_PASSWORD}"]
      interval: 10s
      timeout: 5s
      retries: 5

  api:
    build: .
    container_name: gri-api
    restart: unless-stopped
    depends_on:
      mysql:
        condition: service_healthy
    environment:
      DATABASE_URL: "mysql+asyncmy://gri_app:${MYSQL_APP_PASSWORD}@mysql:3306/gri"
      JWT_SECRET: ${JWT_SECRET}
      ENVIRONMENT: production
    ports:
      - "8000:8000"
    command: uvicorn app.main:app --host 0.0.0.0 --port 8000 --workers 4

volumes:
  gri_mysql_data:
```

**`Dockerfile`:**
```dockerfile
FROM python:3.12-slim

WORKDIR /app

# Deps del sistema para asyncmy (compila Cython) + bcrypt
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential default-libmysqlclient-dev pkg-config \
    && rm -rf /var/lib/apt/lists/*

COPY pyproject.toml uv.lock ./
RUN pip install uv && uv sync --frozen --no-dev

COPY . .

# Alembic upgrade antes de arrancar
CMD ["sh", "-c", "uv run alembic upgrade head && uv run uvicorn app.main:app --host 0.0.0.0 --port 8000 --workers 4"]
```

---

## Alternatives Considered

| Recommended | Alternative | When to Use Alternative |
|-------------|-------------|-------------------------|
| **asyncmy** | **aiomysql 0.3.2** | Si vas a desplegar en arquitectura sin wheels precompilados (raro en 2026). aiomysql es pure Python (sin compilar Cython). También está marcado como `3 - Alpha` en PyPI, lo cual es bandera roja para producción. **Default: asyncmy** |
| **asyncmy** | **mysqlclient (sync)** | Solo si no querés async. Pero perdés la ventaja principal de FastAPI. **No recomendado** |
| **PyJWT** | **python-jose 3.5.0** | Solo si necesitás JWE (cifrado, no solo firma) o JWS con algoritmos exóticos. Para auth de restaurante con HS256/RS256, PyJWT es suficiente y más activo. **Default: PyJWT** |
| **flutter_riverpod** | **flutter_bloc 9.1.1** | Si el equipo viene de Android y conoce Bloc/Cubit. Bloc es muy estable (Flutter Favorite) pero más verboso y su curva de aprendizaje es mayor. Para empezar greenfield: Riverpod por mejor DX y menos boilerplate. **Default: Riverpod** |
| **flutter_riverpod** | **Provider** | NO. Provider está deprecado implícitamente (el mismísimo autor, Remi Rousselet, lo reemplazó con Riverpod). Flutter Favorite pero **legacy**. **Default: Riverpod** |
| **dio** | **http (Dart core)** | Solo para scripts triviales. Para app con auth, interceptors para refresh token, y manejo de errores: dio es estándar. **Default: dio** |
| **go_router** | **auto_route** | auto_route tiene type-safe routing con code-gen, pero NO es del Flutter team. go_router es oficial y feature-complete. **Default: go_router** |
| **MySQL 8.4 LTS** | **PostgreSQL 16** | PostgreSQL es objetivamente mejor DB (JSON, arrays, partial indexes), pero **el usuario decidió MySQL**. No cambiar. **Default: MySQL** (decisión del usuario) |
| **MySQL 8.4 LTS** | **MariaDB 11** | Compatible en protocolo pero divergiendo. MySQL oficial tiene mejor soporte de Docker y ML Kit. **Default: MySQL** |
| **uvicorn** | **hypercorn** o **granian** | Granian (Rust) es más rápido pero menos probado. Hypercorn soporta HTTP/2 y trio. Para prod estándar: uvicorn con `--workers 4`. Para escalar horizontalmente: nginx + múltiples uvicorn. **Default: uvicorn** |

---

## What NOT to Use

| Avoid | Why | Use Instead |
|-------|-----|-------------|
| **Provider** | Deprecado por su autor (Rousselet). Sin soporte para casos modernos (family, autoDispose). Genera memory leaks y bugs sutiles | **flutter_riverpod 3.x** |
| **aiomysql** (en nuevos proyectos) | Marcado `3 - Alpha` en PyPI. Más lento (5x en resultsets grandes vs asyncmy). Solo se justifica si tenés restricciones de compilación | **asyncmy 0.2.14** |
| **python-jose** (para proyectos nuevos) | Sin releases desde May 2025. PyJWT es más activo y suficiente para JWT estándar | **PyJWT 2.13.0** |
| **SQLAlchemy 1.4** | Deprecado. La API 1.x no tiene typing, AsyncSession es limitado, el estilo "Query" (`session.query(User)`) está obsoleto | **SQLAlchemy 2.0** con `select(User)` |
| **Tortoise ORM** | Bien diseñado pero ecosistema chico vs SQLAlchemy. Pérdida de migración de conocimiento entre proyectos. Sin soporte para escenarios avanzados (CTE, window functions, partial indexes) | **SQLAlchemy 2.0** |
| **Flask** | Sync por defecto. Para WebSockets en tiempo real (pedidos), FastAPI async es la elección correcta — el usuario ya lo decidió | **FastAPI** |
| **Django** | Incluye ORM propio (no SQLAlchemy), admin ya hecho (no necesitamos, vamos a hacer panel custom en Flutter Web). Overkill para este scope | **FastAPI** |
| **`requests`** (en FastAPI) | Bloquea el event loop. Es sync. | **httpx** (async) |
| **SQLAlchemy `session.query()`** API | Estilo legacy 1.x. Será removido. | `session.execute(select(User))` |
| **`os.getenv("VAR")`** directo | Sin tipado ni validación. Errores solo en runtime. | **pydantic-settings** con `BaseSettings` |
| **print() en backend** | Sin estructura ni niveles. Imposible de filtrar en prod | **structlog** o **loguru** |
| **shared_preferences para JWT** | Storage plano en XML/JSON. Root/jailbreak lo lee | **flutter_secure_storage** (Keystore/Keychain) |
| **qr_code_scanner** (Flutter) | Paquete **deprecated** desde 2023. Sin soporte iOS 17+ | **mobile_scanner 7.4.0** |
| **Stripe** (para Colombia v1) | Stripe en Colombia solo soporta USD para payouts. No procesa COP nativo. Cuenta bancaria US requerida | **Wompi** (ver abajo) |

---

## Stack Patterns by Variant

### Variante: Panel admin en Flutter Web

**Si** desplegás el panel admin como Flutter Web:
- Compilá con `flutter build web --release` (usa CanvasKit/Wasm render, no HTML)
- Serví los estáticos desde nginx o desde el mismo FastAPI con `StaticFiles`
- CORS: configurá FastAPI con `CORSMiddleware` permitiendo el origen del admin
- WebSockets funcionan en web vía `web_socket_channel` (implementación `HtmlWebSocketChannel`)

### Variante: Multi-instancia de API en producción

**Si** necesitás >1 instancia de FastAPI (escalar):
- Los WebSockets se conectan a una instancia específica → dos clientes conectados a instancias distintas no se ven
- Solución: **Redis Pub/Sub** como bus. Cada instancia publica cambios en `pedidos:{restaurante_id}` y se suscribe a los cambios de otras
- Librería: `redis[hiredis]` 5.x async
- Para v1 (1 sola instancia) **no es necesario** — arrancá sin Redis

### Variante: Pasarela de pago — Colombia

**Si** estás decidiendo pasarela colombiana para v1 (decisión pendiente en PROJECT.md):

| Pasarela | Mejor para | Pros | Contras | Comisión aprox |
|----------|-----------|------|---------|---------------|
| **Wompi** (Kushki) | **Recomendado default** para restaurantes CO | Soporta PSE + tarjetas + NEQUI + Botón Bancolombia + Efecty. Docs en español. COP nativo. Webhooks confiables. Sandbox completo | Requiere KYC del restaurante (responsabilidad fiscal). API menos documentada que MP | ~2.9% + $900 COP |
| **Mercado Pago** | Si querés Checkout Pro (sin capturar tarjeta en tu server) | API excelente y muy documentada. Mercado Pago Checkout redirige (offsite) → **no tocás datos de tarjeta** (PCI-DSS trivial). Plugin Flutter existente | Menos métodos CO-nativos (no NEQU ni Bancolombia directo). Branding "Mercado Pago" visible al usuario | ~3.49% + IVA |
| **PayU** | Solo si necesitás soporte multi-país LATAM desde el día 1 | Líder regional. Soporta muchos métodos de pago CO | API compleja, docs fragmentados, onboarding más lento. Soporte al cliente con quejas frecuentes | ~3.5% + $900 COP |

**Recomendación:** **Wompi** para v1 si querés métodos CO nativos (PSE + NEQUI son expected por clientes colombianos). **Mercado Pago** como segunda opción si querés simplicidad de integración y PCI compliance trivial vía redirect.

**Confidence: MEDIUM** — basado en training data; los detalles de comisiones cambian. Verificar precios y métodos en la fase de pagos consultando los sitios oficiales (developers.wompi.co, mercadopago.com.co/developers, payu.com.co).

### Variante: Cantidad de restaurantes activos

**Si** esperás <50 restaurantes en v1 (escenario probable):
- 1 instancia de FastAPI con `--workers 4` alcanza
- MySQL con config default + conexión pool de 20
- No necesitas Redis (ver variante anterior)

**Si** esperás >200 restaurantes o >10k pedidos/día:
- Múltiples instancias con nginx upstream
- Redis Pub/Sub (ver arriba)
- MySQL con pool tuning (`pool_size=50`, `max_overflow=20`)
- Leer replicas MySQL

---

## Version Compatibility

| Package A | Compatible With | Notes |
|-----------|-----------------|-------|
| `fastapi>=0.141` | `python>=3.10` (recomendado 3.12) | FastAPI 0.140 (Jul 24 2026) marcó el primer release con Python 3.10 mínimo |
| `sqlalchemy[asyncio] 2.0.52` | `greenlet` + driver async (`asyncmy`) | Instalar con `sqlalchemy[asyncio]` asegura `greenlet` |
| `asyncmy 0.2.14` | `python 3.9-3.14` (wheels para todos) | Drop-in de aiomysql. Migrar: cambiar `import aiomysql` por `import asyncmy` |
| `alembic 1.19.1` | `sqlalchemy>=2.0` (no 1.x) | Mismo autor, sincronizado con versiones SQLAlchemy |
| `uvicorn[standard] 0.52.2` | trae `uvloop`, `httptools`, `websockets`, `watchfiles` | En Docker usar imagen `python:3.12-slim` + instalar deps build para uvloop |
| `flutter_riverpod 3.4.2` | requiere `riverpod 3.4.2` (auto) + Flutter SDK latest | v3.x rompió API de v2.x — leer migration guide |
| `flutter_bloc 9.1.1` | `bloc ^9.0.0` + `provider ^6.0.0` | v9 cambia `BlocOverrides` por `Bloc.observer` static |
| `go_router 17.5.0` | Flutter SDK 3.27+ | v17 trajo breaking changes — ver `flutter.dev/go/go-router-v17-breaking-changes` |
| `mobile_scanner 7.4.0` | iOS 12+, Android `minSdkVersion 21` | Android: añadir ML Kit deps. iOS: `NSCameraUsageDescription` en Info.plist |
| `web_socket_channel 3.0.3` | trae `web_socket>=0.1.5` | v3.x separa impls web/io/html internamente |
| `dio 5.11.0` | Flutter Web usa `dio_web_adapter` automáticamente | CORS en web requiere configurar el servidor (FastAPI `CORSMiddleware`) |
| `pydantic 2.x` (incluido en FastAPI) | NO compatible con código Pydantic 1.x sin migrar | FastAPI 0.100+ ya requiere Pydantic 2 |

---

## Sources

### Verificados directamente (HIGH confidence)

- **pypi.org/project/fastapi** — versión 0.141.1, release Jul 29 2026, Python ≥3.10 ✓
- **pypi.org/project/uvicorn** — versión 0.52.2, release Aug 13 2026 ✓
- **pypi.org/project/aiomysql** — versión 0.3.2, marcado `3 - Alpha`, release Oct 22 2025 ✓
- **pypi.org/project/asyncmy** — versión 0.2.14, release Aug 12 2026, "fastest asyncio MySQL driver", benchmarks contra aiomysql ✓
- **pypi.org/project/PyJWT** — versión 2.13.0, release May 21 2026 ✓
- **pypi.org/project/python-jose** — versión 3.5.0, release May 28 2025 (sin releases 2026) ✓
- **pypi.org/project/alembic** — versión 1.19.1, release Aug 8 2026 ✓
- **docs.sqlalchemy.org/en/20/orm/extensions/asyncio.html** — SQLAlchemy 2.0.52, AsyncSession API confirmada ✓
- **pub.dev/packages/flutter_riverpod** — versión 3.4.2, Flutter Favorite, 2.76M downloads/sem ✓
- **pub.dev/packages/flutter_bloc** — versión 9.1.1, Flutter Favorite ✓
- **pub.dev/packages/dio** — versión 5.11.0, verified publisher flutter.cn, 3.95M downloads/sem ✓
- **pub.dev/packages/go_router** — versión 17.5.0, oficial Flutter team, "feature-complete", 3.7M downloads/sem ✓
- **pub.dev/packages/mobile_scanner** — versión 7.4.0, verified publisher steenbakker.dev, 1.25M downloads/sem ✓
- **pub.dev/packages/web_socket_channel** — versión 3.0.3, oficial Dart team, 9M downloads/sem ✓

### Training data + conocimiento de ecosistema (MEDIUM confidence)

- **Wompi/PayU/Mercado Pago en Colombia** — no pude scrapear docs oficiales (403 / too large). Información de capacidades y comisiones basada en training data de 2024-2025. **Verificar precios exactos y métodos disponibles antes de decidir en la fase de pagos.** Las APIs y políticas de comisiones cambian anualmente.
- **MySQL 8.4 LTS** —周期 de soporte hasta Abr 2032 según Oracle LTS policy (training data)
- **bcrypt vs argon2** — recomendaciones OWASP Password Storage Cheat Sheet (training data)

### No verificado / requiere confirmación (LOW confidence)

- **Estructura exacta de webhooks de Wompi** — necesita spike en su fase. Endpoint que reciben eventos: `/webhooks/wompi`. Headers `X-Event-Signature` a verificar con `events_secret` (no confirmado).
- **Si Wompi Colombia soporta pagos en sitio (sin redirect) o solo redirect** — el widget Wompi `Checkout.js` parece existir pero no confirmado para CO. Mercado Pago tiene Checkout API (capture) y Checkout Pro (redirect).
- **Política de comisiones actuales 2026** — verificar en sitio oficial antes de comprometerse

---

*Stack research for: Plataforma multi-restaurante de gestión y reservas (GRI)*
*Researched: 2026-08-13*
*Confidence general: HIGH para capas Python/Flutter (verificado PyPI/pub.dev); MEDIUM para pasarelas de pago (training data, pendiente de verificación en su fase)*
