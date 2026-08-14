# Requirements: GRI â€” GestiÃ³n y Reservas de Restaurantes

**Defined:** 2026-08-13
**Core Value:** Un cliente puede sentarse en una mesa, escanear su QR, pedir del menÃº y recibir su comida â€” con el pedido fluyendo en tiempo real hacia cocina â€” sin intermediarios.

## v1 Requirements

Requirements for initial release. Each maps to roadmap phases.

### Plataforma (Super-admin GRI)

- [x] **PLAT-01**: Super-admin puede iniciar sesiÃ³n en el panel web con sus credenciales
- [x] **PLAT-02**: Super-admin puede crear restaurantes con sus datos bÃ¡sicos (nombre, descripciÃ³n, tipo de cocina, direcciÃ³n)
- [x] **PLAT-03**: Super-admin puede crear usuarios staff (admin restaurante, mesero, cocina) y asignarlos a un restaurante
- [x] **PLAT-04**: El sistema siembra un restaurante demo con menÃº, mesas y datos de ejemplo al inicializarse
- [ ] **PLAT-05**: Super-admin puede ver la lista de restaurantes y desactivarlos

### AutenticaciÃ³n y Roles

- [ ] **AUTH-01**: Usuario puede registrarse como cliente con nombre, email y contraseÃ±a
- [ ] **AUTH-02**: Usuario puede iniciar sesiÃ³n y su sesiÃ³n persiste (JWT con refresh)
- [x] **AUTH-03**: El sistema distingue 5 roles: super_admin, admin_restaurante, mesero, cocina, cliente
- [x] **AUTH-04**: Un usuario staff solo puede acceder a los datos de su restaurante (aislamiento multi-tenant)
- [x] **AUTH-05**: Cliente puede ver y editar su perfil

### Restaurantes y MenÃº

- [x] **REST-01**: Cliente puede ver la lista de restaurantes activos con nombre, tipo de cocina y calificaciÃ³n
- [x] **REST-02**: Cliente puede ver el detalle de un restaurante con su menÃº (categorÃ­as y productos con precio y descripciÃ³n)
- [ ] **MENU-01**: Admin restaurante puede crear, editar y desactivar categorÃ­as del menÃº
- [ ] **MENU-02**: Admin restaurante puede crear, editar y desactivar productos con precio, descripciÃ³n, imagen y disponibilidad (agotado)

### Mesas y QR

- [ ] **MESA-01**: Admin restaurante puede crear y editar mesas con nÃºmero y capacidad
- [x] **MESA-02**: Cada mesa tiene un cÃ³digo QR Ãºnico que la identifica (formato GRI-MESA-XXX o URL)
- [ ] **MESA-03**: Admin restaurante puede ver e imprimir el QR de una mesa
- [x] **MESA-04**: Mesa tiene 4 estados: disponible, reservada, ocupada, limpieza â€” con transiciones vÃ¡lidas controladas
- [x] **MESA-05**: Cliente puede escanear el QR de una mesa desde la app con la cÃ¡mara del telÃ©fono
- [x] **MESA-06**: Al escanear un QR vÃ¡lido, el cliente queda vinculado a la mesa (sesiÃ³n de mesa) y ve el menÃº

### Reservas

- [x] **RESV-01**: Cliente puede reservar mesa indicando fecha, hora y nÃºmero de personas
- [x] **RESV-02**: El sistema valida disponibilidad real (capacidad de mesa y solapamiento de reservas) sin sobre-reservas por concurrencia
- [x] **RESV-03**: Cliente puede consultar sus reservas (prÃ³ximas y pasadas) y su estado (confirmada, pendiente, cancelada)
- [x] **RESV-04**: Cliente puede cancelar una reserva futura
- [x] **RESV-05**: Admin restaurante ve las reservas del dÃ­a y puede marcar mesa como ocupada al llegar el cliente (reserva â†’ mesa ocupada)

### Pedidos

- [x] **PEDI-01**: Cliente con sesiÃ³n de mesa activa puede agregar productos del menÃº a un pedido
- [x] **PEDI-02**: Cliente puede enviar el pedido a cocina y este aparece en la vista de cocina del restaurante
- [x] **PEDI-03**: Pedido sigue una mÃ¡quina de estados: enviado â†’ aceptado â†’ en_preparaciÃ³n â†’ servido (y rechazado como terminal)
- [x] **PEDI-04**: Cliente puede ver el estado de su pedido en tiempo real desde la app
- [x] **PEDI-05**: Cocina puede aceptar, marcar en preparaciÃ³n y marcar servido un pedido
- [x] **PEDI-06**: Mesero y admin ven los pedidos activos con su detalle (mesa, productos, total)

### Tiempo Real

- [ ] **RT-01**: Cambios de estado de pedidos llegan a cocina, mesero y cliente sin refrescar (WebSockets)
- [ ] **RT-02**: Cambios de estado de mesas se reflejan en el mapa de mesas del panel sin refrescar
- [ ] **RT-03**: La app se recupera de desconexiones (reconexiÃ³n + re-sincronizaciÃ³n de estado al reconectar)

### Cuenta y Pago

- [x] **PAGO-01**: Cliente puede solicitar la cuenta desde la app y el mesero/mesero-panel recibe el aviso
- [ ] **PAGO-02**: Cliente puede pagar en lÃ­nea el total de su consumo (pasarela a definir: Wompi/PayU/Mercado Pago)
- [ ] **PAGO-03**: El pago es idempotente: reintentos o webhooks duplicados no generan doble cobre ni estados corruptos
- [ ] **PAGO-04**: Al confirmarse el pago, la mesa se libera (pasa a limpieza) y la sesiÃ³n de mesa se cierra

### Calificaciones

- [ ] **CALI-01**: Cliente puede calificar su experiencia (estrellas + comentario) despuÃ©s de un pedido pagado
- [ ] **CALI-02**: La calificaciÃ³n promedio del restaurante es visible en la lista y detalle de restaurantes

### Panel Admin (Web)

- [x] **ADMN-01**: Panel muestra dashboard con estadÃ­sticas: mesas disponibles/ocupadas, reservas del dÃ­a, pedidos activos
- [x] **ADMN-02**: Panel muestra mapa de mesas con su estado codificado por color (verde/rojo/amarillo/azul) y actualizaciÃ³n en vivo
- [ ] **ADMN-03**: Admin restaurante puede gestionar clientes (ver lista e historial)
- [ ] **ADMN-04**: Admin puede cambiar estado de mesa (marcar en limpieza, liberar) desde el mapa
- [x] **ADMN-05**: Panel incluye vista de cocina: cola de pedidos con estado y capacidad de avanzarlos

### Reportes

- [ ] **REPO-01**: Admin restaurante puede ver reporte de ventas por dÃ­a/rango (total, nÃºmero de pedidos)
- [ ] **REPO-02**: Admin restaurante puede ver platos mÃ¡s vendidos

### Infraestructura

- [x] **INFR-01**: MySQL corre en Docker con volumen persistente, charset utf8mb4 y timezone America/Bogota
- [x] **INFR-02**: La API FastAPI corre en Docker (Ubuntu Server) y se conecta a MySQL por configuraciÃ³n de entorno
- [x] **INFR-03**: Las migraciones (Alembic) y el seed demo se ejecutan como parte del despliegue

## v2 Requirements

Deferred to future release. Tracked but not in current roadmap.

### Notificaciones

- **NOTF-01**: Cliente recibe push de confirmaciÃ³n de reserva
- **NOTF-02**: Cliente recibe push cuando su pedido estÃ¡ servido

### OperaciÃ³n

- **OPER-01**: Mesero tiene vista mÃ³vil dedicada (no web)
- **OPER-02**: Multi-idioma (inglÃ©s)
- **OPER-03**: Item 86: pausar plato agotado desde cocina con un toque
- **OPER-04**: Token efÃ­mero en QR (rotaciÃ³n) y estadÃ­sticas de escaneo

### Plataforma

- **PLT2-01**: Autoregistro de restaurantes con aprobaciÃ³n
- **PLT2-02**: Redis Pub/Sub para mÃºltiples instancias de la API
- **PLT2-03**: Delivery/domicilios

## Out of Scope

Explicitly excluded. Documented to prevent scope creep.

| Feature | Reason |
|---------|--------|
| POS tradicional con caja (efectivo, cierre de caja, impresoras fiscales) | Triplica el scope; GRI es capa digital sobre el POS existente del restaurante, no su reemplazo |
| Pagos en efectivo desde la app | El efectivo se maneja fuera de GRI; la app solo avisa que se solicitÃ³ la cuenta |
| Push notifications (FCM/APNs) | Defer a v2; tiempo real v1 es dentro de app abierta |
| Delivery/domicilios | GRI es solo para consumo en el local |
| Multi-idioma | EspaÃ±ol Ãºnicamente en v1 |
| Autoregistro de restaurantes | Solo super-admin crea; evita flujo de moderaciÃ³n |
| IntegraciÃ³n con sistemas POS externos | Complejidad de integraciÃ³n alta sin valor validado aÃºn |

## Traceability

Which phases cover which requirements. Updated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| PLAT-01 | Fase 4 | Complete |
| PLAT-02 | Fase 2 | Complete |
| PLAT-03 | Fase 2 | Complete |
| PLAT-04 | Fase 3 | Done |
| PLAT-05 | Fase 8 | Pending |
| AUTH-01 | Fase 2 | Pending |
| AUTH-02 | Fase 2 | Pending |
| AUTH-03 | Fase 2 | Complete |
| AUTH-04 | Fase 2 | Complete |
| AUTH-05 | Fase 5 | Done |
| REST-01 | Fase 5 | Done |
| REST-02 | Fase 5 | Done |
| MENU-01 | Fase 8 | Pending |
| MENU-02 | Fase 8 | Pending |
| MESA-01 | Fase 8 | Pending |
| MESA-02 | Fase 3 | Done |
| MESA-03 | Fase 8 | Pending |
| MESA-04 | Fase 5 | Complete (05-02) |
| MESA-05 | Fase 6 | Complete |
| MESA-06 | Fase 6 | Complete |
| RESV-01 | Fase 5 | Done |
| RESV-02 | Fase 5 | Done |
| RESV-03 | Fase 5 | Done |
| RESV-04 | Fase 5 | Done |
| RESV-05 | Fase 5 | Complete (05-02) |
| PEDI-01 | Fase 6 | Complete |
| PEDI-02 | Fase 6 | Complete |
| PEDI-03 | Fase 6 | Complete |
| PEDI-04 | Fase 6 | Complete |
| PEDI-05 | Fase 6 | Complete |
| PEDI-06 | Fase 6 | Complete |
| RT-01 | Fase 7 | Pending |
| RT-02 | Fase 7 | Pending |
| RT-03 | Fase 7 | Pending |
| PAGO-01 | Fase 6 | Complete |
| PAGO-02 | Fase 9 | Pending |
| PAGO-03 | Fase 9 | Pending |
| PAGO-04 | Fase 9 | Pending |
| CALI-01 | Fase 9 | Pending |
| CALI-02 | Fase 9 | Pending |
| ADMN-01 | Fase 4 | Complete |
| ADMN-02 | Fase 4 | Complete |
| ADMN-03 | Fase 8 | Pending |
| ADMN-04 | Fase 8 | Pending |
| ADMN-05 | Fase 6 | Complete |
| REPO-01 | Fase 8 | Pending |
| REPO-02 | Fase 8 | Pending |
| INFR-01 | Fase 1 | Complete |
| INFR-02 | Fase 1 | Complete |
| INFR-03 | Fase 3 | Done |

**Coverage:**
- v1 requirements: 50 total (nota: este archivo decÃ­a "47 total" por error aritmÃ©tico; el conteo real de IDs enumerados es 50)
- Mapped to phases: 50
- Unmapped: 0

---
*Requirements defined: 2026-08-13*
*Last updated: 2026-08-13 after roadmap creation (9 fases)*


