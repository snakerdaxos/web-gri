# SMOKE E2E — GRI sobre Firebase (Opción B) · Gate final Fase 10

> 🛑 **SUPERADO — documento histórico.** Este runbook es el gate de la **Fase
> 10** y parte del **seed** (`scripts/seed_firebase.mjs`), por lo que nunca
> ejercita el arranque de una plataforma desde cero. Su checkpoint humano
> tampoco llegó a ejecutarse.
>
> **Usa [`docs/SMOKE-E2E-v2.md`](SMOKE-E2E-v2.md)**, que arranca de una base de
> datos **VACÍA** y añade el bootstrap del primer `super_admin`, el alta de
> staff, el QR de mesa, la política de contraseñas, la baja de personal y el
> ingreso con Google.
>
> Se conserva sin tocar como registro de lo que se verificó (y de lo que no) en
> la Fase 10.

> Runbook paso a paso del flujo e2e completo (MIGRA-03/04/05/06): preparar
> emuladores + seed → levantar panel y app cliente → flujo reserva → ocupar
> → QR → pedido → cocina avanza → servido → cuenta → cerrar mesa → calificar
> → promedio visible → super-admin → **deploy de rules+indexes al proyecto
> real `p-gri-b5b40`** (gate oficial de la fase).
>
> Referencias: [`docs/FIREBASE_SETUP.md`](FIREBASE_SETUP.md) (guía de
> operación) · `scripts/seed_firebase.mjs` (seed idempotente).
> Todos los comandos son **PowerShell** desde la raíz del repo salvo indicación.

---

## 0. Requisitos y credenciales

| Requisito | Verificación | Nota |
|---|---|---|
| Node 18+ | `node --version` | Seed + firebase-tools |
| Java JRE 11+ | `java -version` | **SOLO emuladores** — ver §1 si falta |
| Flutter 3.47 | `$env:Path += ";C:\src\flutter\bin"; flutter --version` | Antes de cada comando flutter |
| firebase-tools 15.27.0 | `npx --prefix scripts firebase --version` | Vía `scripts/`, NO global |
| Tooling node instalado | `cd scripts; npm install; cd ..` | Una vez (en Windows `npm install --prefix scripts` falla) |

**Credenciales demo** (todas con password `Demo!1234`, claims `{role, rid}`):

| Email | Rol | rid |
|---|---|---|
| carlos@demo.gri.dev | cliente | — |
| maria@demo.gri.dev | cliente | — |
| admin@demo.gri.dev | admin_restaurante | demo |
| mesero@demo.gri.dev | mesero | demo |
| cocina@demo.gri.dev | cocina | demo |
| admin@gri.dev | super_admin | — |

**Datos sembrados:** restaurante `demo` ("Restaurante Demo GRI") · mesas
`GRI-MESA-demo-001..008` (capacidades 2,2,4,4,4,6,6,8) · 4 categorías · 16
productos (Bandeja Paisa $32.000, Limonada de Coco $9.000, …).

> 🔴 **Regla de oro del smoke:** las apps SIEMPRE con
> `--dart-define=USE_EMULATORS=true` mientras se verifica contra emuladores.
> Sin el flag las apps tocan el **proyecto real** (ver §4 [P]). El bootstrap
> cablea emuladores solo con el flag (`defaultValue: false`).

---

## 1. Limitación registrada — máquina sin Java (esta dev box)

La máquina que produjo planes/tests de la fase **NO tiene Java**: los
emuladores no pueden correr localmente aquí. Evidencia (2026-08-16):

```text
$ npx firebase emulators:exec --only auth,firestore "node ../scripts/seed_firebase.mjs"
Error: Could not spawn `java -version`. Please make sure Java is installed and on your system PATH.
```

Impacto y compensación:

| Qué queda pendiente | Cómo queda cubierto |
|---|---|
| Idempotencia del seed EN VIVO (doble corrida contra emuladores) | Validada por diseño en 10-01 (natural key antes de cada write) + **[O]** doble corrida contra el proyecto REAL tras deploy (comando exacto abajo) — o correr §2 en cualquier máquina con Java 11+ |
| Smoke A–M contra emuladores | **[P]** smoke manual contra el proyecto REAL (pasos incluidos) tras el deploy [N] |

Instalar un JRE 11+ (`winget install EclipseAdoptium.Temurin.11.JRE` o
similar) habilita §2–[M] tal cual en esta máquina.

---

## 2. Terminal 1 — emuladores + seed + idempotencia (requiere Java)

```powershell
# (a) One-shot: doble corrida del seed = prueba de idempotencia EN VIVO,
#     y deja estado exportado en ./emulator_data (gitignored) para el smoke:
npx --prefix scripts firebase emulators:exec --only auth,firestore --export-on-exit=./emulator_data "node scripts/seed_firebase.mjs && node scripts/seed_firebase.mjs"
#     → La SEGUNDA corrida debe loguear: usuarios 6/6 existentes,
#       categorías 4/4 existentes, productos 16/16 existentes (0 duplicados).

# (b) Dejar los emuladores CORRIENDO para el smoke (importa el estado (a)):
npx --prefix scripts firebase emulators:start --only auth,firestore --import=./emulator_data --export-on-exit=./emulator_data
```

**Esperado:** UI de emuladores en <http://localhost:4000> → Firestore:
colecciones `restaurantes/demo`, `mesas` (8 docs `GRI-MESA-demo-00*`),
`categorias` (4), `productos` (16); Authentication: 6 usuarios.
Auth escucha en 9099 y Firestore en 8080.

> Corridas siguientes: usar siempre el comando (b) con `--import/--export-on-exit`
> para que el estado sobreviva (sin eso el emulador borra TODO al apagar).

---

## 3. Terminales 2 y 3 — panel y app cliente (SIEMPRE con el flag)

```powershell
# Terminal 2 — panel admin (workdir panel_admin):
$env:Path += ";C:\src\flutter\bin"
flutter run -d chrome --dart-define=USE_EMULATORS=true

# Terminal 3 — app cliente (workdir app_cliente):
$env:Path += ";C:\src\flutter\bin"
flutter run -d chrome --dart-define=USE_EMULATORS=true
```

**Esperado:** ambas apps abren en Chrome. Síntoma de haber olvidado el flag:
`permission-denied` inesperado (las apps están tocando el proyecto real —
cerrar y relanzar con el flag).

---

## 4. Flujo e2e — pasos [A]…[P]

> Realizar en orden. En cada paso se indica la ventana (📱 cliente · 🖥️ panel)
> y el resultado esperado. **Ningún paso debe requerir refresh del navegador.**

[A]. 📱 Login cliente: en la app cliente ingresar `carlos@demo.gri.dev` / `Demo!1234`. **Esperado:** home/discover con "Restaurante Demo GRI" (★ sin calificaciones aún), accesos "Escanear mesa" y "Mis reservas".

[B]. 📱 Reservar: desde el detalle del restaurante → "Reservar una mesa" → wizard con **2 personas, fecha HOY+1, hora 19:00** → confirmar. **Esperado:** reserva confirmada (nace `confirmada`), visible en "Mis reservas"; la tx marcó la mesa asignada como `reservada` (asignación automática por capacidad).

[C]. 🖥️ Panel staff: login `admin@demo.gri.dev` / `Demo!1234` → Dashboard: mapa de mesas EN VIVO (la mesa de la reserva se ve `reservada` — color de la leyenda), stats "Reservas hoy" y "Mesas disponibles". La reserva de [B] es de MAÑANA → NO aparece en "📅 Reservas" (solo las de hoy) — esperado. Ver también "👥 Clientes" con Carlos tras su primer pedido ([F]).

[D]. 🖥️ Marcar mesa ocupada (llegada): en Dashboard/Mesas tocar una mesa LIBRE de sesión (p.ej. `GRI-MESA-demo-008`) → sheet → **"Marcar ocupada"** → luego **"Marcar en limpieza"** → **"Liberar"**. **Esperado:** cada transición aplica y el mapa cambia de color al instante (transiciones inválidas ni siquiera se ofrecen). ⚠️ NO marcar `ocupada` la mesa del QR de [E]: abrir sesión por QR exige mesa `disponible|reservada` — la transición a `ocupada` la dispara el QR del cliente.

[E]. 📱 Abrir sesión por QR: home → "Escanear mesa" → **input manual** (la cámara en Chrome no es necesaria; el input es de primera clase) escribir el código de la mesa — la de la reserva de [B] (ver "Mis reservas") o `GRI-MESA-demo-001`. **Esperado:** banner "Estás en la Mesa N", menú con 4 categorías y 16 productos con precios COP; la mesa pasa a `ocupada` (si era la reservada: `reservada→ocupada` por la tx del cliente).

[F]. 📱 Pedir: agregar **Bandeja Paisa ($32.000) + Limonada de Coco ($9.000)** al carrito → enviar pedido. **Esperado:** pantalla de estado del pedido EN VIVO (chip "Enviado", total $41.000); 🖥️ en paralelo el card aparece solo en "📋 Pedidos" del panel (badge `Mesa N`, items ×cantidad, total, "Pedido por Carlos…").

[G]. 🖥️ Cocina avanza: en "📋 Pedidos" sobre el card: **"Aceptar"** → **"En preparación"** → **"Servido"**. **Esperado:** 📱 el chip del pedido cambia EN VIVO en cada avance (Enviado→Aceptado→En preparación→Servido) sin refresh; el card sale de la cola al quedar `servido`.

[H]. 📱 Solicitar cuenta: botón **"Pedir la cuenta"**. **Esperado:** 📱 banner "Cuenta solicitada ✓" + snackbar "el mesero viene en camino"; 🖥️ el header de "📋 Pedidos" muestra el badge amarillo **"1 mesa pidió la cuenta"** y el card el badge "🍽️ pidió la cuenta" — al instante.

[I]. 🖥️ Entregar cuenta y cerrar mesa: tocar el badge → sheet "Mesas que pidieron la cuenta" → tocar **"Mesa N"** → "Entregar cuenta". **Esperado:** snackbar "cuenta entregada (sesión cerrada)"; el badge desaparece SOLO (la sesión ya no está activa); en UNA transacción la sesión pasó a `cerrada` y la mesa a `limpieza` (opcional: Dashboard → mesa en limpieza → "Liberar" → `disponible`). 📱 el banner de sesión refleja el cierre en vivo.

[J]. 📱 Calificar: en la pantalla de pedidos, la card `servida` con sesión cerrada muestra **"Calificar"** → sheet "¿Cómo estuvo todo?" → **5★ + comentario** → "Enviar calificación". **Esperado:** confirmación; la calificación es 1:1 por pedido (repetir está bloqueado).

[K]. 📱 Promedio visible: volver al discover (home). **Esperado:** "Restaurante Demo GRI" ahora muestra **★ 5.0 (1)** — `califProm`/`califCount` recompute atómico en la misma tx de calificar (0→5, 0→1).

[L]. Realtime transversal (dos ventanas lado a lado): durante [E]–[I] ya se observó onSnapshot puro (pedido aparece/avanza en panel sin refresh; estados y mapa cambian en el cliente sin refresh). Verificación explícita: en otra mesa libre repetir [E]+[F] mirando SIMULTÁNEAMENTE 🖥️ Dashboard (mesa a `ocupada` + pedido en cola, al instante) y 📱 (chip "Enviado"). Cerrar esa segunda sesión con [H]+[I] (o dejarla para seguir probando).

[M]. Super-admin: en el panel cerrar sesión → login `admin@gri.dev` / `Demo!1234` → "⚙️ Configuración" → pestaña **Restaurantes** (solo super): lista con switches. Toggle "GRI Sur (inactivo)" ON. **Esperado:** 📱 el restaurante aparece en discover EN VIVO; toggle OFF → desaparece (query pública filtra `activo == true`). **Dejar el estado como estaba** (Sur OFF).

[N]. DEPLOY REAL — gate oficial de la fase (lo corre el USUARIO): prerequisites: Firestore creado (Console → Firestore Database → Create database, modo producción). Luego:

```powershell
npx --prefix scripts firebase login    # OAuth interactivo — UNA vez, abre navegador
npx --prefix scripts firebase deploy --only firestore:rules,firestore:indexes
```

**Esperado:** `✔ Deploy complete!` con release de `firestore.rules` (las 9 colecciones, autorización por claims); los 9 índices compuestos quedan BUILDING (tardan minutos — Console → Firestore → Indexes). ⚠️ Rules mal desplegadas cortan TODO el acceso: este deploy sale del `firestore.rules` ya validado en 10-01 y SOLO tras el smoke verde.

[O]. Seed del proyecto REAL + idempotencia en vivo (post-deploy): (1) Console → Authentication → Sign-in method → **Email/Password → Enable**; (2) Console → Project Settings → Service Accounts → **Generate new private key** → guardar como `scripts/serviceAccountKey.json` (🔴 GITIGNORED — jamás commitearlo); (3):

```powershell
$env:GOOGLE_APPLICATION_CREDENTIALS="./scripts/serviceAccountKey.json"
node scripts/seed_firebase.mjs
node scripts/seed_firebase.mjs   # doble corrida = idempotencia EN VIVO contra el real
```

**Esperado:** log `[modo] PROYECTO REAL (p-gri-b5b40)`; la SEGUNDA corrida muestra usuarios 6/6, categorías 4/4 y productos 16/16 como `existente` — cero duplicados (MIGRA-04 sellado).

[P]. Smoke contra el proyecto REAL (alternativa/complemento si no hay Java): cerrar emuladores (Ctrl+C en Terminal 1) y relanzar ambas apps **SIN el flag**:

```powershell
# panel_admin y app_cliente (una terminal por app):
$env:Path += ";C:\src\flutter\bin"
flutter run -d chrome        # USE_EMULATORS=false por defecto → p-gri-b5b40 REAL
```

**Esperado:** repetir el flujo [A]–[M] resumido (login carlos → QR `GRI-MESA-demo-00X` → pedido → panel cocina avanza → cuenta → entregar → calificar → ★ en discover → super-admin toggle). Nota: esto crea datos demo reales (reserva/pedido/calificación) — aceptable para el smoke; el staff puede pasar la mesa por limpieza→disponible después.

---

## 5. Checklist final del checkpoint (resume-signal)

- [ ] Idempotencia del seed demostrada (§2 emuladores **o** [O] real): segunda corrida 6/6 · 4/4 · 16/16 `existente`
- [ ] Flujo [A]–[M] verde (emuladores o [P] real): ningún `permission-denied` inesperado, todo en vivo sin refresh
- [ ] [N] deploy OK con release en output — **o diferimiento explícito** (decisión del usuario, registrar en el SUMMARY)
- [ ] `git status` NO muestra `scripts/serviceAccountKey.json` ni `emulator_data/`
- [ ] Responder **"approved"** si todo funciona (deploy OK o diferido conscientemente), o listar los pasos que fallaron con lo observado

Troubleshooting: ver §9 de [`docs/FIREBASE_SETUP.md`](FIREBASE_SETUP.md)
(`permission-denied` por query, índices faltantes, datos volátiles del
emulador, claims sin propagar).
