# GRI — Gestión y Reservas de Restaurantes

## What This Is

GRI es una plataforma multi-restaurante para gestión y reservas. Los clientes usan una app móvil (Flutter) para descubrir restaurantes, reservar mesas, escanear el QR de la mesa, pedir del menú, seguir su pedido en tiempo real, solicitar la cuenta y pagar en línea. Los restaurantes administran su operación (mesas, reservas, pedidos, menú, clientes, reportes) desde un panel web (Flutter Web), y la plataforma GRI es gestionada por un super-admin que crea los restaurantes.

## Core Value

Un cliente puede sentarse en una mesa, escanear su QR, pedir del menú y recibir su comida — con el pedido fluyendo en tiempo real hacia cocina — sin intermediarios.

## Requirements

### Validated

(None yet — ship to validate)

### Active

- [ ] Multi-restaurante: solo el super-admin GRI registra restaurantes; se siembra un restaurante demo con menú, mesas y datos de ejemplo
- [ ] Autenticación obligatoria para todas las apps, con 5 roles: super-admin GRI, admin restaurante, mesero, cocina, cliente
- [ ] App Cliente (Flutter móvil): buscar restaurantes, ver disponibilidad, reservar mesa, consultar reserva, escanear QR de mesa, ver menú, armar pedido, enviar pedido a cocina, consultar estado del pedido en tiempo real, solicitar la cuenta (avisa al mesero), pagar en línea, calificar la experiencia
- [ ] Panel Admin (Flutter Web): dashboard con estadísticas, mapa de mesas con 4 estados (disponible/ocupada/reservada/limpieza), gestión de mesas, reservas, pedidos, clientes, menú, reportes, configuración
- [ ] Pedidos y estado de mesas en tiempo real (WebSockets)
- [ ] API REST (FastAPI) que conecta ambas apps con MySQL
- [ ] Infraestructura Docker: MySQL + API en Ubuntu Server, con la conexión a BD apuntando al servidor

### Out of Scope

- Autoregistro de restaurantes — solo el super-admin crea; evita moderación de registros en v1
- Notificaciones push (FCM/APNs) — defer a v2; en v1 el tiempo real es dentro de la app abierta
- App nativa separada por plataforma — Flutter cubre Android/iOS desde un código
- Multi-idioma — español únicamente en v1
- Delivery/domicilios — GRI es solo para consumo en el local

## Context

- Documentación original en `documentos/`: `configuración.docx` (funcionalidades), `index.html` (mockup admin), `indexcliente.html` (mockup cliente), `flujograma.png` y `mockup.png` (imágenes no legibles por el modelo — el usuario conoce su contenido)
- Los mockups HTML definen identidad visual: primario naranja `#ff4c05`, sidebar oscuro `#1f2329`, fondo `#f5f6f8`, estados de mesa verde `#20b26b` / rojo `#e74c3c` / amarillo `#f5b82e` / azul `#3478f6`
- Los mockups anticipan endpoints: `GET /api/mesas/1`, `POST /api/reservas`, `GET /api/reservas/cliente/ID`
- Formato de QR de mesa propuesto: `GRI-MESA-001` o URL `https://gri.com/mesa/001`
- Proyecto previo en esta carpeta ("Linterna PRO") fue reemplazado por GRI
- El panel admin es una **app web** (no móvil); la app del cliente es **móvil**
- Repositorio git recién inicializado

## Constraints

- **Tech stack**: Flutter/Dart (cliente móvil + admin web) — decisión del usuario
- **Tech stack**: FastAPI (Python) para la API — decisión del usuario
- **Tech stack**: MySQL como base de datos — decisión del usuario
- **Infraestructura**: MySQL y API se despliegan en Docker sobre Ubuntu Server; la conexión a BD debe configurarse hacia ese servidor (no localhost en producción)
- **Tiempo real**: WebSockets para pedidos y estados de mesa — decisión del usuario
- **Pagos**: pago en línea incluido; pasarela concreta (Wompi/PayU/Mercado Pago/Stripe) se decide en su fase

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| FastAPI para el backend | Decisión del usuario; ecosistema maduro con MySQL y WebSockets | — Pending |
| Flutter Web para admin, Flutter móvil para cliente | El admin es app web (decisión del usuario); un solo lenguaje para ambas apps | — Pending |
| MySQL en Docker sobre Ubuntu Server | Infraestructura definida por el usuario; conexión a BD apunta al server | — Pending |
| Multi-restaurante con creación exclusiva del super-admin | Evita flujo de aprobación de registros en v1 | — Pending |
| WebSockets para tiempo real | El usuario requiere que cocina vea pedidos al instante | — Pending |
| Pago en línea + aviso a mesero para la cuenta | El usuario requiere ambos mecanismos | — Pending |
| Restaurante demo sembrado con datos de ejemplo | Facilita desarrollo y pruebas desde el día 1 | — Pending |

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition** (via `/gsd-transition`):
1. Requirements invalidated? → Move to Out of Scope with reason
2. Requirements validated? → Move to Validated with phase reference
3. New requirements emerged? → Add to Active
4. Decisions to log? → Add to Key Decisions
5. "What This Is" still accurate? → Update if drifted

**After each milestone** (via `/gsd:complete-milestone`):
1. Full review of all sections
2. Core Value check — still the right priority?
3. Audit Out of Scope — reasons still valid?
4. Update Context with current state

---
*Last updated: 2026-08-13 after initialization*
