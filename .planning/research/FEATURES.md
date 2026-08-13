# Feature Research

**Domain:** Multi-restaurante — gestión + reservas + pedidos por QR + pagos (dine-in, no delivery)
**Researched:** 2026-08-13
**Confidence:** HIGH para flujos centrales (reserva, QR ordering, KDS, estados de mesa); MEDIUM para gateways LatAm específicos (Wompi/PayU)

> **Fuente de verdad del proyecto:** `.planning/PROJECT.md`. Las features marcadas **[EN SCOPE v1]** ya están decididas por el usuario; las demás son análisis de ecosistema para informar el roadmap. Los mockups en `documentos/index.html` (admin) e `indexcliente.html` (cliente) anticipan la UI concreta.

---

## Feature Landscape

### Marco de plataformas de referencia

Antes de las tablas, conviene fijar contra qué compite/converge GRI:

| Plataforma | Fortaleza | Qué le falta a GRI v1 que ellos tienen |
|------------|-----------|------------------------------------------------|
| **OpenTable / Resy / Sevenrooms** | Reservas + CRM + reputación | GRI sí tiene reservas; le faltan CRM enriquecido y red de distribución |
| **Eat App** (Medio Oriente/LatAm) | Floor plan + waitlist + WhatsApp + pagos | GRI sí tiene mapa de mesas; le faltan waitlist y WhatsApp |
| **Toast / Square for Restaurants / Lightspeed** | POS + KDS + reportes financieros profundos | GRI **no es POS tradicional** (no cobra en caja); es solo pay-at-table por app |
| **Mr Yum / Bbot / Sunday / Slice** | QR ordering + pay-at-table | Esa es **la columna vertebral de GRI** |
| **RappiTable / iFood Dine-in** | Reservas en LatAm (incipiente) | GRI está mejor posicionado para QR ordering en local |

**Insight clave:** GRI v1 combina **3 productos típicamente separados** (reservas + QR ordering + dashboard operativo). Eso es ambicioso pero el usuario ya lo definió. La trampa es intentar también **ser POS completo** — ver Anti-Features.

---

### Table Stakes (Usuarios las esperan)

Si falta una de estas, la plataforma se siente rota. El usuario NO da crédito por tenerlas, pero penaliza su ausencia.

#### Cliente (App Móvil)

| Feature | Por qué se espera | Complejidad | Notas / Implementación |
|---------|-------------------|-------------|------------------------|
| **Buscar y ver restaurantes** [EN SCOPE v1] | Sin esto no hay punto de entrada | LOW | Lista + detalle. Filtros básicos (cocina, precio, ubicación) son sub-features; búsqueda por nombre basta para v1 con 1 restaurante demo |
| **Ver menú con precios e imágenes** [EN SCOPE v1] | Expectativa post-Rappi/iFood | MEDIUM | Categorías, ítems, modifiers, fotos. Sin fotos la conversión cae fuerte — sembrar el demo con imágenes reales |
| **Autenticación (cliente)** [EN SCOPE v1] | Necesario para reservas y pedidos vinculados | LOW | Email/password + teléfono. Login social (Google/Apple) es P2 |
| **Reservar mesa: fecha, hora, #personas** [EN SCOPE v1] | Razón de ser del producto | MEDIUM | Wizard: restaurante → fecha → hora → personas → mesa disponible → confirmar |
| **Ver disponibilidad de mesas en tiempo real** [EN SCOPE v1] | Sin esto el cliente reserva "ciego" | MEDIUM | Query de mesas `disponibles`/`reservadas` filtradas por capacidad y franja horaria |
| **Consultar/ver mis reservas** [EN SCOPE v1] | Tabla marcada en mockup (`GET /api/reservas/cliente/ID`) | LOW | Lista con estado (pendiente/confirmada/cancelada/completada) |
| **Escanear QR de mesa con cámara** [EN SCOPE v1] | Entrada al flujo de pedido | MEDIUM | Paquete `mobile_scanner` en Flutter. QR contiene `GRI-MESA-001` o URL |
| **Armar pedido (carrito)** [EN SCOPE v1] | Core del producto | HIGH | Modifiers (término de carne, sin cebolla), cantidades, notas por ítem, total en vivo |
| **Enviar pedido a cocina** [EN SCOPE v1] | Cierre del flujo de ordenar | MEDIUM | POST que crea pedido en estado `recibido` y emite evento WebSocket |
| **Ver estado del pedido en tiempo real** [EN SCOPE v1] | Promesa explícita del producto | MEDIUM | WebSocket push de transiciones de estado. Ver state machine abajo |
| **Pedir la cuenta (avisa mesero)** [EN SCOPE v1] | Reducción de fricción vs levantar mano | LOW | Botón que crea evento "solicitud de cuenta" para el mesero asignado a la mesa |
| **Pagar en línea** [EN SCOPE v1] | Pillar del producto QR-ordering moderno | HIGH | Ver sección Pagos. Precaución PCI/scope |
| **Calificar la experiencia** [EN SCOPE v1] | Cierre del ciclo; alimenta reportes | LOW | Estrellas 1-5 + comentario opcional, post-pago o post-servido |

#### Admin Restaurante (Panel Web)

| Feature | Por qué se espera | Complejidad | Notas / Implementación |
|---------|-------------------|-------------|------------------------|
| **Dashboard con estadísticas clave** [EN SCOPE v1] | El panel abre aquí en el mockup | MEDIUM | Cards: mesas disponibles/ocupadas, reservas hoy, pedidos activos (mockup ya lo define) |
| **Mapa de mesas con 4 estados** [EN SCOPE v1] | Definido explícitamente: disponible/ocupada/reservada/limpieza | HIGH | Grid tipo mockup. Estados: verde `#20b26b` / rojo `#e74c3c` / amarillo `#f5b82e` / azul `#3478f6`. Sync WebSocket |
| **Gestión de mesas (CRUD)** [EN SCOPE v1] | Mockup tiene "+ Nueva mesa" | LOW | Número, capacidad, ubicación, QR generado/imprimible |
| **Gestión de reservas** [EN SCOPE v1] | Sidebar del mockup | MEDIUM | Lista + filtros + confirmar/cancelar/marcar no-show |
| **Gestión de pedidos** [EN SCOPE v1] | Sidebar del mockup | MEDIUM | Lista de pedidos activos + historial. Estados visualizables |
| **Gestión de clientes** [EN SCOPE v1] | Sidebar del mockup | LOW | Lista + detalle (historial de reservas y pedidos) |
| **Gestión de menú (CRUD)** [EN SCOPE v1] | Sin menú no hay pedidos | MEDIUM | Categorías → ítems → modifiers → disponibilidad on/off (86 un ítem agotado) |
| **Reportes básicos** [EN SCOPE v1] | Sidebar del mockup | MEDIUM | Ver sección Reportes. Ventas del día/semana, top items, ocupación promedio |
| **Configuración del restaurante** [EN SCOPE v1] | Sidebar del mockup | LOW | Horarios, datos de contacto, reglas de reserva (anticipación mínima, duración turno) |
| **Roles y permisos (admin/mesero/cocina)** [EN SCOPE v1] | Definido en PROJECT.md | MEDIUM | 5 roles: super-admin GRI, admin restaurante, mesero, cocina, cliente |

#### Operacional (transversal)

| Feature | Por qué se espera | Complejidad | Notas / Implementación |
|---------|-------------------|-------------|------------------------|
| **Auth JWT + refresh** [EN SCOPE v1] | Sin auth no hay multirol seguro | MEDIUM | FastAPI + OAuth2PasswordBearer. Refresh token rotation |
| **Tiempo real con WebSockets** [EN SCOPE v1] | Decisión del usuario; cocina debe ver pedidos al instante | HIGH | Sala por restaurante; eventos: `pedido.nuevo`, `pedido.estado`, `mesa.estado`, `cuenta.solicitada` |
| **Vista Kitchen display (cocina)** [EN SCOPE v1 — implícito en "enviar a cocina"] | Si cocina no ve pedidos el flujo se rompe | MEDIUM | Pantalla simplificada: lista de pedidos con tiempo transcurrido, botón "listo". No requiere KDS avanzado en v1 |
| **Vista mesero (cuenta solicitada)** [EN SCOPE v1 — implícito] | Mesero debe recibir el aviso de cuenta | LOW | Lista de mesas que solicitaron cuenta + notificación visual |

---

### Differentiators (Ventaja competitiva)

No son obligatorias, pero crean diferenciación. Las marcadas **[EN SCOPE v1]** ya están decididas; el resto son sugerencias para V1.x o V2.

| Feature | Propuesta de valor | Complejidad | Notas / Implementación |
|---------|---------------------|-------------|------------------------|
| **QR ordering + reservas en una sola app** [EN SCOPE v1] | Mr Yum solo hace QR; OpenTable solo reservas. GRI une ambos | — | Ya está decidido; **es la diferencia estructural clave** |
| **Restaurante demo sembrado con datos** [EN SCOPE v1] | Validación instantánea desde el día 1 sin configuración manual | LOW | Seed con mesas, menú, clientes y reservas ficticias |
| **Mapa visual de mesas con 4 estados en tiempo real** [EN SCOPE v1] | Competencia local suele usar planillas. Esto se ve "profesional" | HIGH | Ya en mockup. Sync WebSocket al instante |
| **Multi-restaurante con super-admin** [EN SCOPE v1] | Plataforma SaaS-ready desde v1, no un solo local | MEDIUM | Tenant scoping por `restaurante_id` en cada tabla |
| **Pago en línea sin caja tradicional** [EN SCOPE v1] | Elimina fricción de "pedir la cuenta" — modelo Sunday/Bbot | HIGH | Ver sección Pagos |
| **Solicitar cuenta → aviso a mesero** [EN SCOPE v1] | Híbrido: cliente pide por app pero mesero confirma (mejor UX que auto-pago 100%) | LOW | Ya decidido |
| **Catálogo de calificaciones por restaurante** [EN SCOPE v1] | Genera reputación dentro de la plataforma | LOW | Rating promedio + count (mockup ya muestra ⭐ 4.8 (245 opiniones)) |
| **Idioma visualmente coherente con mockup (naranja #ff4c05)** [EN SCOPE v1] | Identidad fuerte desde el primer release | LOW | Design system ya decidido |
| **Vista cocina con tiempos por color (KDS ligero)** | Diferenciación vs planillas de papel | MEDIUM | Verde <5min, amarillo 5-10min, rojo >10min. Sin routing por estación en v1 |
| **Notas de alérgenos en el menú** | Expectativa creciente; valor de seguridad | LOW | Flag booleano + icono en ítem de menú. P2 |
| **Recordatorio de reserva por WhatsApp** [DEFER v2 — push está out of scope v1] | En LatAm WhatsApp > email para confirmaciones | MEDIUM | Requiere cuenta de WhatsApp Business API. Ver Anti-Features para no introducir push nativo en v1 |
| **Lista de espera (waitlist) con SMS/WhatsApp** | Captura walk-ins sin frustración | MEDIUM | Defer a V1.x. Eat App lo tiene como feature destacada |
| **CRM ligero de cliente (preferencias, historial)** | Personalización para repetir clientes | MEDIUM | Defer a V1.x. Mínimo viable en v1: historial de pedidos/reservas por cliente |
| **Split bill / dividir cuenta** | Mesas grandes lo esperan | MEDIUM | Defer. Pago simple por sesión en v1 |
| **Propina desde la app** | Complemento natural del pago en línea | LOW | Selector 10/15/20/custom antes de pagar. Incluir en v1 si el gateway lo permite sin fricción |
| **Reporte de no-shows y ocupación por franja** | Optimización de ingresos para el admin | MEDIUM | Defer a V1.x cuando haya datos reales |
| **Multi-sede por grupo restaurantero** | SaaS scaling | HIGH | Defer a V2 |
| **Programa de lealtad / puntos** | Retención | HIGH | Defer a V2 |

---

### Anti-Features (Lo que NO construir deliberadamente)

Estas features parecen buenas pero crean problemas. Documentadas para prevenir scope creep.

| Feature | Por qué se pide | Por qué es problemática | Alternativa |
|---------|-----------------|-------------------------|-------------|
| **POS tradicional con caja e impresora de tickets** | "Para que reemplace el POS actual" | Triplica el scope: manejo de efectivo, cierre de caja, integración con impresoras fiscales, conciliación bancaria, certificación fiscal por país. GRI no compite con Toast/Square; compite en QR ordering + reservas | Mantener GRI como capa **digital sobre** el POS existente. Pago solo por app/web |
| **Autoregistro de restaurantes** | "Para escalar tipo SaaS self-service" | Requiere flujo de aprobación, KYC, validación de identidad legal, gestión de fraude. Definido explícitamente como out-of-scope en PROJECT.md | Solo el super-admin GRI crea restaurantes en v1 |
| **Notificaciones push nativas (FCM/APNs)** | "Para avisar al cliente fuera de la app" | Requiere certificados, manejo de permisos iOS/Android, estrategia de notificaciones, opt-in. PROJECT.md lo marca out-of-scope v1 | Tiempo real solo con app abierta (WebSocket). Defer push a v2 |
| **Delivery / domicilios** | "Para competir con Rappi" | Modelo operativo completamente distinto: riders, geocercas, ruteo, estimación de tiempos. Diluye el foco de dine-in | GRI es **solo para consumo en el local**. Decision explícita del usuario |
| **Multi-idioma (i18n)** | "Para soportar inglés/turistas" | Duplica el effort de UX, contenido, QA. PROJECT.md marca español único en v1 | Solo español en v1. Arquitectura de strings preparada para i18n futuro, sin activar |
| **Pago cripto / wallets alternativas** | "Moderno" | Baja adopción, alta complejidad contable | Wompi/PayU/Mercado Pago/Stripe — ver STACK.md |
| **Integración con Google/TripAdvisor reservations** | "Para distribución tipo OpenTable" | Requiere partnership comercial con Google Reserve/TripAdvisor Connect. Inviabile para v1 verde | Widget propio; integraciones de red en v2 |
| **Reservas con depósito/garantía (no-show fee)** | "Para reducir no-shows" | Complejo legalmente en LatAm; requiere pre-auth en tarjeta del cliente al reservar; fricción alta para el cliente; disputas | Política simple de cancelación con ventana de tiempo. Penalización solo blanda (no poder reservar X horas). V2 puede evaluar depósito |
| **AI chatbot de recomendaciones** | "Moderno" | Ruido sin valor demostrado en v1; costo de LLM; riesgo de alucinación en pedidos | Búsqueda/filtros clásicos. V2 si hay señal de usuarios pidiéndolo |
| **App nativa separada por plataforma** | "Mejor performance" | PROJECT.md ya decidió Flutter (un código para iOS+Android) | Flutter cubre ambas plataformas |
| **Reservas para eventos privados / banquets** | Parece extensión natural | Modelo de pricing, capacidad y bloqueo de mesas distinto. Complejiza el floor plan | Solo reservas estándar. V2 |
| **KDS con routing por estación (parrilla/fry/ensaladas)** | "Para cocina grande" | Solo 1 restaurante demo en v1; no se justifica. Comería tiempo valioso | KDS simple de lista única. Re-evaluar cuando un restaurante real tenga >1 estación |

---

## Feature Dependencies

```
┌─────────────────────────────────────────────────────────────────┐
│  Núcleo de infraestructura (todo depende de esto)                │
└─────────────────────────────────────────────────────────────────┘
[Auth JWT + roles (5)]
    └──requires──> [Multi-restaurante (tenant scoping)]
                        └──requires──> [Seed: restaurante demo + super-admin]

┌─────────────────────────────────────────────────────────────────┐
│  Cadena de reservas                                              │
└─────────────────────────────────────────────────────────────────┘
[Gestión de mesas (CRUD + capacidad)]
    └──requires──> [Disponibilidad por fecha/hora/#personas]
                        └──requires──> [Reservar mesa (cliente)]
                                            └──requires──> [Consultar mis reservas]
                                            └──enhances────> [Mapa de mesas con estado 'reservada']

┌─────────────────────────────────────────────────────────────────┐
│  Cadena de pedidos por QR                                        │
└─────────────────────────────────────────────────────────────────┘
[Gestión de menú (CRUD + modifiers + disponibilidad)]
    └──requires──> [Escanear QR → vincular mesa + sesión]
                        └──requires──> [Ver menú + armar carrito]
                                            └──requires──> [Enviar pedido a cocina]
                                                                 └──requires──> [WebSocket: pedido.nuevo]
                                                                                      └──requires──> [Vista cocina (KDS ligero)]
                                                                                                            └──requires──> [WebSocket: pedido.estado]
                                                                                                                                 └──requires──> [Ver estado en app cliente]

┌─────────────────────────────────────────────────────────────────┐
│  Cierre del ciclo (cuenta + pago + calificación)                 │
└─────────────────────────────────────────────────────────────────┘
[Pedido servido/completado]
    ├──requires──> [Pedir la cuenta → aviso mesero]
    │                   └──requires──> [Pago en línea (gateway)]
    │                                        └──requires──> [Calificar experiencia]
    └──requires──> [Liberar mesa → estado 'limpieza' → 'disponible']

┌─────────────────────────────────────────────────────────────────┐
│  Reportes (consume todo lo anterior)                             │
└─────────────────────────────────────────────────────────────────┘
[Reservas + Pedidos + Pagos + Clientes + Mesas]
    └──enhances──> [Dashboard de estadísticas]
    └──enhances──> [Reportes de restaurante]

┌─────────────────────────────────────────────────────────────────┐
│  Conflictos (no combinar en misma fase)                          │
└─────────────────────────────────────────────────────────────────┘
[Pago en línea con pre-auth al reservar] ──conflicts──> [Política de reserva sin garantía]
    Razón: o se cobra garantía o no se cobra; ambigüedad rompe la UX

[KDS con routing por estación] ──conflicts──> [Restaurante demo único en v1]
    Razón: no hay volumen para justificarlo; agregar cuando haya demanda

[Notas de alérgenos como campo libre] ──conflicts──> [Filtro por alérgeno en menú]
    Razón: si los alérgenos son texto libre, no se puede filtrar; modelar como flags desde el inicio si se quiere filtrar después
```

### Dependency Notes

- **Todo requiere Auth + multi-tenant + seed demo:** sin esto no hay base sobre la que construir. Es la fase 0 obligatoria.
- **La cadena de pedidos por QR es la más larga (7 eslabones):** es donde el roadmap puede trabarse. Se recomienda planearla como una fase dedicada.
- **Pago en línea es la feature de mayor riesgo técnico:** depende de un gateway externo con sandboxes distintos a producción. Aislarla en su propia fase con spike previo.
- **Calificación requiere pago previo:** para evitar reviews falsas, vincular la reseña al `pedido_id` o `reserva_id` completado.
- **Mapa de mesas requiere WebSocket funcionando:** si la sincronización en tiempo real no anda, el mapa miente. No construir el mapa antes que el WebSocket.

---

## State Machines (referencia para diseño)

No son features per se, pero determinan features implícitas y son críticas para el roadmap.

### Pedido (más granular que KDS porque es client-facing)

```
                ┌─────────────────────────────────────────────┐
                ▼                                             │
   [recibido] ─► [en_preparacion] ─► [listo] ─► [servido] ─► [pagado]
        │              │                  │
        │              │                  └─► (recall) ─► [en_preparacion]
        │              │
        └─► [rechazado] (cocina no puede: agotado, etc.)
                       │
                       └─► cliente recibe notificación + motivo

   Cualquier estado previo a [servido] ─► [cancelado] (con motivo)
```

**Estados client-facing recomendados (4):** Recibido → En preparación → Listo → Servido. Internamente `pagado` y `cancelado` son estados administrativos.

### Mesa

```
[disponible] ──cliente se sienta (QR o walk-in)──► [ocupada]
     ▲                                               │
     │                                               ├──cierra cuenta──► [limpieza] ──mesero confirma──► [disponible]
     │                                               │
     └──reserva confirmada para ahora──► [reservada]─┘
                                              │
                                              └──cliente se sienta──► [ocupada]
```

**Transición `limpieza → disponible` requiere acción humana (mesero confirma).** No automatizar — los turnos reales de limpieza varían.

### Reserva

```
[pendiente] ──admin confirma──► [confirmada] ──cliente llega──► [completada]
     │                              │
     │                              ├──no llega (ventana pasada)──► [no_show]
     │                              │
     │                              └──cliente cancela──► [cancelada]
     │
     └──admin rechaza──► [rechazada]
```

**Pregunta de diseño abierta (defer a SPEC de fase):** ¿reservas en v1 son siempre `confirmada` automáticamente (auto-confirm), o requieren aprobación manual del admin? Auto-confirm es más simple y recomendado para v1; introducir aprobación manual solo si el restaurante lo pide.

---

## MVP Definition

### Launch With (v1) — ya definido en PROJECT.md

Mínimo para validar el concepto de "sentarse, escanear, pedir, recibir, pagar".

- [ ] **Auth multirol (5 roles)** — sin esto nada del resto es seguro
- [ ] **Multi-restaurante + super-admin + restaurante demo sembrado** — base de tenant y datos para probar
- [ ] **Gestión de mesas (CRUD) + 4 estados** — el mapa del mockup, sincronizado por WebSocket
- [ ] **Reservas: crear, consultar, cancelar** — flujo completo del cliente
- [ ] **Gestión de menú (CRUD) con modifiers** — sin esto no hay pedidos
- [ ] **Escanear QR + armar pedido + enviar a cocina** — el core del producto
- [ ] **Estado de pedido en tiempo real (WebSocket)** — la promesa diferenciadora
- [ ] **Vista cocina (KDS ligero)** — cocina debe poder actuar
- [ ] **Pedir cuenta + pago en línea** — cierre del ciclo financiero
- [ ] **Calificación post-experiencia** — retroalimentación para reportes
- [ ] **Dashboard admin + reportes básicos** — visibilidad operativa
- [ ] **Gestión de clientes (lista + historial)** — el CRM mínimo viable

### Add After Validation (v1.x)

Features para añadir una vez que el core funciona en producción con 1 restaurante real.

- [ ] **Propina desde la app** — cuando el gateway elegido la soporte limpio
- [ ] **Notas de alérgenos como flags** — cuando haya señal de clientes preguntando
- [ ] **Reportes avanzados (no-show, ocupación por franja, ticket promedio)** — cuando haya datos reales que analizar
- [ ] **CRM enriquecido (preferencias, tags)** — cuando el restaurante quiera segmentar para marketing
- [ ] **Lista de espera (waitlist) con SMS/WhatsApp** — cuando haya walk-ins frecuentes
- [ ] **Cancelar/modificar reserva con ventana de tiempo** — cuando aparezcan disputas
- [ ] **Split bill** — cuando mesas grandes lo pidan
- [ ] **Pausar/disabled item del menú (86)** — cuando se agoten platos en servicio

### Future Consideration (v2+)

Defer hasta haber validado product-market fit.

- [ ] **Notificaciones push (FCM/APNs)** — deferred explícitamente por PROJECT.md
- [ ] **WhatsApp Business API para confirmaciones** — deferred por complejidad de cuenta
- [ ] **Multi-idioma** — deferred explícitamente
- [ ] **Multi-sede por grupo restaurantero** — cuando un cliente lo pida
- [ ] **Programa de lealtad / puntos** — cuando el churn sea un problema
- [ ] **Integración con Google/TripAdvisor** — cuando la distribución importe
- [ ] **Reservas con depósito/garantía** — cuando los no-shows cuesten dinero real
- [ ] **Autoregistro de restaurantes** — cuando el modelo SaaS self-service sea viable
- [ ] **App para mesero (no solo admin web)** — si los meseros necesitan móvil en piso
- [ ] **KDS avanzado con routing por estación** — cuando un restaurante tenga >1 estación

---

## Feature Prioritization Matrix

| Feature | Valor para usuario | Costo de impl. | Prioridad |
|---------|--------------------|-----------------|-----------|
| Auth multirol + multi-tenant | HIGH | MEDIUM | **P1** |
| Restaurante demo sembrado | HIGH | LOW | **P1** |
| Gestión de mesas + 4 estados | HIGH | MEDIUM | **P1** |
| Mapa de mesas en tiempo real | HIGH | HIGH | **P1** |
| WebSocket tiempo real | HIGH | HIGH | **P1** |
| Reservar mesa (cliente) | HIGH | MEDIUM | **P1** |
| Escanear QR + sesión de mesa | HIGH | MEDIUM | **P1** |
| Gestión de menú con modifiers | HIGH | MEDIUM | **P1** |
| Armar pedido (carrito) | HIGH | HIGH | **P1** |
| Enviar pedido a cocina | HIGH | LOW | **P1** |
| Vista cocina (KDS ligero) | HIGH | MEDIUM | **P1** |
| Ver estado del pedido en vivo | HIGH | MEDIUM | **P1** |
| Pedir cuenta → aviso mesero | HIGH | LOW | **P1** |
| Pago en línea (gateway) | HIGH | HIGH | **P1** |
| Calificar experiencia | MEDIUM | LOW | **P1** |
| Dashboard admin | HIGH | MEDIUM | **P1** |
| Reportes básicos | MEDIUM | MEDIUM | **P1** |
| Gestión de clientes (historial) | MEDIUM | LOW | **P1** |
| Propina desde la app | MEDIUM | LOW | P2 |
| 86 item (pausar plato) | MEDIUM | LOW | P2 |
| Waitlist SMS/WhatsApp | MEDIUM | HIGH | P2 |
| CRM enriquecido + segmentación | MEDIUM | MEDIUM | P2 |
| Reportes avanzados | MEDIUM | MEDIUM | P2 |
| Split bill | MEDIUM | MEDIUM | P2 |
| Notas de alérgenos (flags) | LOW | LOW | P2 |
| Push notifications | MEDIUM | HIGH | P3 |
| WhatsApp confirmaciones | MEDIUM | HIGH | P3 |
| Multi-idioma | LOW | MEDIUM | P3 |
| Lealtad / puntos | MEDIUM | HIGH | P3 |
| Multi-sede | MEDIUM | HIGH | P3 |
| Depósito/garantía de reserva | LOW | HIGH | P3 |
| KDS con routing | LOW | HIGH | P3 |
| Autoregistro restaurantes | LOW | HIGH | P3 |

**Prioridad key:**
- **P1:** Lanzamiento v1 — alineado con PROJECT.md
- **P2:** Añadir tras validación (v1.x)
- **P3:** Futuro (v2+)

---

## Competitor Feature Analysis

| Feature | OpenTable/Resy | Toast/Square POS | Mr Yum/Bbot/Sunday | **GRI (plan v1)** |
|---------|----------------|------------------|--------------------|--------------------|
| Reservas online | ✓ (fortaleza) | Parcial | ✗ | ✓ |
| Floor plan visual | ✓ avanzado | ✓ | ✗ | ✓ (grid 4 estados) |
| Walklist/waitlist | ✓ | Parcial | ✗ | ✗ (defer v1.x) |
| QR ordering | ✗ | ✓ (algunos) | ✓ (fortaleza) | ✓ |
| KDS | ✗ | ✓ avanzado | Parcial | ✓ (ligero) |
| Pay-at-table | ✓ (algunos) | ✓ | ✓ (fortaleza) | ✓ |
| CRM / perfiles | ✓ profundo | ✓ | Básico | Básico (historial) |
| Reportes financieros | Básico | ✓ profundo | Básico | Básico |
| Multi-restaurante SaaS | ✓ | ✓ | ✓ | ✓ (super-admin) |
| Distribución (Google/TripAdvisor) | ✓ | ✗ | ✗ | ✗ (defer v2) |
| POS tradicional con caja | ✗ | ✓ (fortaleza) | ✗ | ✗ (anti-feature) |
| Delivery | ✗ | ✓ (vía integra) | ✗ | ✗ (anti-feature) |
| Programa lealtad | ✓ | ✓ | ✗ | ✗ (defer v2) |
| WhatsApp messaging | ✓ (Eat App) | ✗ | ✗ | ✗ (defer v2) |

**Lectura:** GRI v1 se posiciona en el **cruce** de OpenTable (reservas) + Mr Yum (QR ordering) sin intentar ser Toast (POS completo). Esa frontera es deliberada y está bien trazada en Anti-Features.

---

## Sources

### Alta confianza (vendor sites / docs oficiales)

- **Eat App — Features page** (`restaurant.eatapp.co/features`): referencia directa de plataforma de reservas + table management. Lista de features observada: Online reservations, Table management (timeline/grid/floor/list), Capacity & shifts, Stay in sync (multi-device sync cada 3s), Turn more tables, Phone integration, Guest profiles/CRM, Analytics & Reports, Surveys & Feedback, Walk-ins & Waitlist (SMS), Payments & Events, Loyalty Suite, WhatsApp messaging, Pay At Table, Review management, Shift management, Venue management, Roles & permissions, Floorplan editor, Offline mode.
- **Mockups del usuario** (`documentos/index.html`, `documentos/indexcliente.html`): definición concreta de UI, sidebar admin (Dashboard, Mesas, Pedidos, Reservas, Clientes, Reportes, Configuración), navegación cliente (Inicio, Restaurantes, Reservas, Perfil), endpoints anticipados (`GET /api/mesas/1`, `POST /api/reservas`, `GET /api/reservas/cliente/ID`), paleta cromática y formato QR (`GRI-MESA-001`).
- **`.planning/PROJECT.md`**: fuente de verdad del scope v1, out-of-scope y decisiones.

### Media confianza (conocimiento de dominio verificado)

- Patrones de estados de KDS (Toast KDS, Square KDS, Lightspeed KDS, Aloha): estados `New → Preparing → Ready → Bumped`, color coding por elapsed time, allergy alerts, expeditor routing. Conocimiento de training data, consistente con múltiples vendors.
- State machines de QR ordering (Mr Yum, Bbot, Sunday, Slice, GloriaFood): modifiers groups, multi-round ordering, pay-at-table, tip selection. Conocimiento de training data, corroborado por la features page de Eat App.
- Flujos de reserva (OpenTable, Resy, Sevenrooms, TheFork): pending → confirmed → seated → completed/no-show/cancelled, ventana de cancelación, política de no-show. Conocimiento de training data.

### Baja confianza (a verificar en fase específica)

- **Gateways LatAm concretos (Wompi vs PayU vs Mercado Pago)**: conocimiento parcial de training data. Verificar API actual, sandbox, certificación PCI, y soporte para propinas split. Requiere investigación en la fase de pagos.
- **WhatsApp Business API**: requisitos de cuenta y pricing actual. Verificar en v2.
- **FCM/APNs**: requisitos actuales de permisos iOS. Solo relevante en v2.

### Intentado pero no accesible

- WebstaurantStore blog (404 en URL específica de KDS).
- Toast blog (404).
- OpenTable availability API (timeout).
- Brave Search (API key no configurada en este entorno).
- Lightspeed/Clover blogs (requieren JS o devuelven 404).

---

*Feature research for: plataforma multi-restaurante de gestión y reservas (GRI)*
*Researched: 2026-08-13*
