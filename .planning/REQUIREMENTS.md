# Requirements: GRI — Gestión y Reservas de Restaurantes

**Defined:** 2026-08-13
**Core Value:** Un cliente puede sentarse en una mesa, escanear su QR, pedir del menú y recibir su comida — con el pedido fluyendo en tiempo real hacia cocina — sin intermediarios.

## v1 Requirements

Requirements for initial release. Each maps to roadmap phases.

### Plataforma (Super-admin GRI)

- [ ] **PLAT-01**: Super-admin puede iniciar sesión en el panel web con sus credenciales
- [ ] **PLAT-02**: Super-admin puede crear restaurantes con sus datos básicos (nombre, descripción, tipo de cocina, dirección)
- [ ] **PLAT-03**: Super-admin puede crear usuarios staff (admin restaurante, mesero, cocina) y asignarlos a un restaurante
- [ ] **PLAT-04**: El sistema siembra un restaurante demo con menú, mesas y datos de ejemplo al inicializarse
- [ ] **PLAT-05**: Super-admin puede ver la lista de restaurantes y desactivarlos

### Autenticación y Roles

- [ ] **AUTH-01**: Usuario puede registrarse como cliente con nombre, email y contraseña
- [ ] **AUTH-02**: Usuario puede iniciar sesión y su sesión persiste (JWT con refresh)
- [ ] **AUTH-03**: El sistema distingue 5 roles: super_admin, admin_restaurante, mesero, cocina, cliente
- [ ] **AUTH-04**: Un usuario staff solo puede acceder a los datos de su restaurante (aislamiento multi-tenant)
- [ ] **AUTH-05**: Cliente puede ver y editar su perfil

### Restaurantes y Menú

- [ ] **REST-01**: Cliente puede ver la lista de restaurantes activos con nombre, tipo de cocina y calificación
- [ ] **REST-02**: Cliente puede ver el detalle de un restaurante con su menú (categorías y productos con precio y descripción)
- [ ] **MENU-01**: Admin restaurante puede crear, editar y desactivar categorías del menú
- [ ] **MENU-02**: Admin restaurante puede crear, editar y desactivar productos con precio, descripción, imagen y disponibilidad (agotado)

### Mesas y QR

- [ ] **MESA-01**: Admin restaurante puede crear y editar mesas con número y capacidad
- [ ] **MESA-02**: Cada mesa tiene un código QR único que la identifica (formato GRI-MESA-XXX o URL)
- [ ] **MESA-03**: Admin restaurante puede ver e imprimir el QR de una mesa
- [ ] **MESA-04**: Mesa tiene 4 estados: disponible, reservada, ocupada, limpieza — con transiciones válidas controladas
- [ ] **MESA-05**: Cliente puede escanear el QR de una mesa desde la app con la cámara del teléfono
- [ ] **MESA-06**: Al escanear un QR válido, el cliente queda vinculado a la mesa (sesión de mesa) y ve el menú

### Reservas

- [ ] **RESV-01**: Cliente puede reservar mesa indicando fecha, hora y número de personas
- [ ] **RESV-02**: El sistema valida disponibilidad real (capacidad de mesa y solapamiento de reservas) sin sobre-reservas por concurrencia
- [ ] **RESV-03**: Cliente puede consultar sus reservas (próximas y pasadas) y su estado (confirmada, pendiente, cancelada)
- [ ] **RESV-04**: Cliente puede cancelar una reserva futura
- [ ] **RESV-05**: Admin restaurante ve las reservas del día y puede marcar mesa como ocupada al llegar el cliente (reserva → mesa ocupada)

### Pedidos

- [ ] **PEDI-01**: Cliente con sesión de mesa activa puede agregar productos del menú a un pedido
- [ ] **PEDI-02**: Cliente puede enviar el pedido a cocina y este aparece en la vista de cocina del restaurante
- [ ] **PEDI-03**: Pedido sigue una máquina de estados: enviado → aceptado → en_preparación → servido (y rechazado como terminal)
- [ ] **PEDI-04**: Cliente puede ver el estado de su pedido en tiempo real desde la app
- [ ] **PEDI-05**: Cocina puede aceptar, marcar en preparación y marcar servido un pedido
- [ ] **PEDI-06**: Mesero y admin ven los pedidos activos con su detalle (mesa, productos, total)

### Tiempo Real

- [ ] **RT-01**: Cambios de estado de pedidos llegan a cocina, mesero y cliente sin refrescar (WebSockets)
- [ ] **RT-02**: Cambios de estado de mesas se reflejan en el mapa de mesas del panel sin refrescar
- [ ] **RT-03**: La app se recupera de desconexiones (reconexión + re-sincronización de estado al reconectar)

### Cuenta y Pago

- [ ] **PAGO-01**: Cliente puede solicitar la cuenta desde la app y el mesero/mesero-panel recibe el aviso
- [ ] **PAGO-02**: Cliente puede pagar en línea el total de su consumo (pasarela a definir: Wompi/PayU/Mercado Pago)
- [ ] **PAGO-03**: El pago es idempotente: reintentos o webhooks duplicados no generan doble cobre ni estados corruptos
- [ ] **PAGO-04**: Al confirmarse el pago, la mesa se libera (pasa a limpieza) y la sesión de mesa se cierra

### Calificaciones

- [ ] **CALI-01**: Cliente puede calificar su experiencia (estrellas + comentario) después de un pedido pagado
- [ ] **CALI-02**: La calificación promedio del restaurante es visible en la lista y detalle de restaurantes

### Panel Admin (Web)

- [ ] **ADMN-01**: Panel muestra dashboard con estadísticas: mesas disponibles/ocupadas, reservas del día, pedidos activos
- [ ] **ADMN-02**: Panel muestra mapa de mesas con su estado codificado por color (verde/rojo/amarillo/azul) y actualización en vivo
- [ ] **ADMN-03**: Admin restaurante puede gestionar clientes (ver lista e historial)
- [ ] **ADMN-04**: Admin puede cambiar estado de mesa (marcar en limpieza, liberar) desde el mapa
- [ ] **ADMN-05**: Panel incluye vista de cocina: cola de pedidos con estado y capacidad de avanzarlos

### Reportes

- [ ] **REPO-01**: Admin restaurante puede ver reporte de ventas por día/rango (total, número de pedidos)
- [ ] **REPO-02**: Admin restaurante puede ver platos más vendidos

### Infraestructura

- [ ] **INFR-01**: MySQL corre en Docker con volumen persistente, charset utf8mb4 y timezone America/Bogota
- [ ] **INFR-02**: La API FastAPI corre en Docker (Ubuntu Server) y se conecta a MySQL por configuración de entorno
- [ ] **INFR-03**: Las migraciones (Alembic) y el seed demo se ejecutan como parte del despliegue

## v2 Requirements

Deferred to future release. Tracked but not in current roadmap.

### Notificaciones

- **NOTF-01**: Cliente recibe push de confirmación de reserva
- **NOTF-02**: Cliente recibe push cuando su pedido está servido

### Operación

- **OPER-01**: Mesero tiene vista móvil dedicada (no web)
- **OPER-02**: Multi-idioma (inglés)
- **OPER-03**: Item 86: pausar plato agotado desde cocina con un toque
- **OPER-04**: Token efímero en QR (rotación) y estadísticas de escaneo

### Plataforma

- **PLT2-01**: Autoregistro de restaurantes con aprobación
- **PLT2-02**: Redis Pub/Sub para múltiples instancias de la API
- **PLT2-03**: Delivery/domicilios

## Out of Scope

Explicitly excluded. Documented to prevent scope creep.

| Feature | Reason |
|---------|--------|
| POS tradicional con caja (efectivo, cierre de caja, impresoras fiscales) | Triplica el scope; GRI es capa digital sobre el POS existente del restaurante, no su reemplazo |
| Pagos en efectivo desde la app | El efectivo se maneja fuera de GRI; la app solo avisa que se solicitó la cuenta |
| Push notifications (FCM/APNs) | Defer a v2; tiempo real v1 es dentro de app abierta |
| Delivery/domicilios | GRI es solo para consumo en el local |
| Multi-idioma | Español únicamente en v1 |
| Autoregistro de restaurantes | Solo super-admin crea; evita flujo de moderación |
| Integración con sistemas POS externos | Complejidad de integración alta sin valor validado aún |

## Traceability

Which phases cover which requirements. Updated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| (filled during roadmap creation) | | |

**Coverage:**
- v1 requirements: 47 total
- Mapped to phases: 0
- Unmapped: 47 ⚠️

---
*Requirements defined: 2026-08-13*
*Last updated: 2026-08-13 after initial definition*
