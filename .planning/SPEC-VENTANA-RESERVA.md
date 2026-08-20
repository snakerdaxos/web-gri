# Especificación — Ventana de bloqueo de la mesa por reserva

**Decisión del usuario, 2026-08-20**, en respuesta al problema de coherencia del mapa de mesas que
dejó abierto el plan 11-31.

> *"Lo que bloquee la mesa solo será media hora antes de la reserva y media hora después, para el
> tiempo de espera. Si el usuario que reservó no hace pedido, se libera. O el admin podría liberar
> la mesa."*

---

## El problema que resuelve

Tras habilitar las reservas del mismo día (plan 11-31), el mapa del panel quedó incoherente y
además demasiado agresivo:

| Situación | Comportamiento actual | Por qué está mal |
|---|---|---|
| Reserva creada hoy para hoy | la mesa se pone `reservada` al crearla | la bloquea horas antes de que llegue nadie |
| Reserva creada ayer para hoy | la mesa **no** se pone `reservada` | el mesero pierde el aviso |
| El cliente no aparece | **nada libera la mesa** | queda inutilizable el resto del turno |

El amarillo aparece "a veces" y el operador no puede deducir de dónde viene. Con el margen de 4
horas, una mesa podía quedar bloqueada media tarde por una reserva que quizá no se presente.

## La regla

**La mesa solo está bloqueada por una reserva dentro de la ventana `[reserva − 30 min, reserva + 30 min]`.**

- **Antes de esa ventana**: la mesa está libre y se puede usar para quien entre por la puerta.
- **Dentro de la ventana**: bloqueada, esperando al cliente que reservó.
- **Después de +30 min sin que el cliente haya pedido**: se libera sola. Es el tiempo de cortesía.
- **En cualquier momento**: el administrador puede liberarla a mano.

"Hacer pedido" es la señal de que el cliente llegó — abrir sesión en la mesa y pedir. Si eso ocurre
dentro de la ventana, la mesa pasa a `ocupada` por la vía normal y la reserva se considera cumplida.

## Consecuencia de diseño: el mapa deja de depender del campo `estado`

Esta regla **no se puede implementar** manteniendo el bloqueo en el campo `estado` de la mesa,
porque ese campo no sabe qué hora es: alguien tendría que escribirlo al entrar en la ventana y
borrarlo al salir, y no hay quien lo haga sin un proceso en servidor (que no existe: sin Blaze no
hay Cloud Functions).

**El mapa debe derivar el color de las reservas del día**, comparándolas con la hora actual. Esa es
justamente la deuda que 11-29 y 11-31 dejaron declarada, y esta decisión la convierte en necesaria
en vez de opcional. Ventajas: se acaba la incoherencia "creada hoy sí, creada ayer no", el estado
vuelve a significar solo lo que pasa ahora mismo, y no hace falta ningún proceso que escriba nada.

Datos disponibles: el panel ya consulta `reservasHoy` con la ventana del día, y esa consulta ya
funciona en producción.

## Puntos a resolver al implementar

- **Quién considera "no se presentó"**: si el mapa deriva el color de la hora, la liberación
  automática es implícita — pasados los 30 minutos la reserva deja de teñir la mesa. No hace falta
  escribir nada. Verificar si además conviene marcar la reserva como `no_show` para los reportes, o
  dejarla `confirmada` sin más.
- **La acción del administrador**: hoy existe cancelar por no-show en el panel
  (`cancelarReservaNoShow`). Revisar si esa acción ya cubre "liberar la mesa" o si hace falta algo
  distinto. Ojo: 11-29 dejó anotado que su guard de transición valida contra un modelo local
  desactualizado y por tanto no protege de carreras.
- **Coherencia con la escritura de estado**: si el mapa pasa a derivar, hay que revisar si
  `crearReserva` debe seguir escribiendo `estado: 'reservada'` para las reservas de hoy. Lo
  probable es que **no** deba escribirlo en absoluto, lo que simplifica también `cancelarReserva`.
- **El contador `mesasReservadas`** del dashboard tiene el mismo problema y debe derivar igual.
- Las reglas de Firestore ya validan la transición de mesa; comprobar que quitar esa escritura no
  rompe ninguno de los 290 tests de reglas.

## Fuera de alcance

Notificar al cliente que su reserva expiró. Reasignar automáticamente la mesa a otra reserva.

---

# Dos hallazgos más del usuario (2026-08-20), a resolver en el mismo trabajo

## A. El super_admin no puede OPERAR

Reproducido por el usuario al pulsar "entregar cuenta": `permission-denied` en el commit que
escribe `sesiones/{id}.estado = 'cerrada'` y `mesas/{id}.estado = 'limpieza'`.

Causa: `staffOf(r) = signedIn() && r == rid() && role() in ['admin_restaurante','mesero','cocina']`.
El `super_admin` no está en la lista y no tiene `rid`, así que la condición es falsa. Puede LEER
todo pero no cerrar sesiones, ni cambiar estado de mesa, ni cancelar reservas. En `pedidos` sí está
contemplado con `isSuper()`; en el resto no. La auditoría de reglas (plan 11-04) ya lo marcó como
asimetría a decidir y nadie lo tropezó hasta operar de verdad como super.

**Arreglo:** permitir al `super_admin` las operaciones de staff. No abre nada nuevo — ya puede leer
esos documentos; se le permite actuar sobre ellos. Con sus tests y redespliegue de reglas.
Nota de producto: si algún día la plataforma tuviera restaurantes de dueños distintos, quizá
convenga lo contrario. Hoy el usuario es dueño de la plataforma Y operador del restaurante.

Rodeo mientras tanto: operar con `admin@demo.gri.dev` (rol `admin_restaurante`, rid `demo`).

## B. El panel no ve las reservas futuras

`panel_admin/lib/features/reservas/reservas_provider.dart:30-42` acota la consulta a
`fecha >= inicioHoy && fecha < inicioManana` — **hoy y solo hoy**.

Y hasta el plan 11-31 el cliente solo podía reservar de mañana en adelante (`firstDate: mañana`).
Es decir: **ninguna reserva ha sido nunca visible para el restaurante hasta el día en que ocurría.**
Un restaurante que no ve las reservas de mañana no puede planificar compras ni turnos.

**Arreglo:** que el panel muestre las próximas reservas, no solo las de hoy. Decidir la ventana
(¿próximos 7 días? ¿todas las futuras con paginación?) y si conviene separar "hoy" de "próximas" en
la interfaz, porque el uso es distinto: hoy se opera, mañana se planifica.
Ojo al índice: `reservas(restauranteId, fecha)` ya existe y sirve para una ventana más amplia, pero
verificar con `audit_indexes.mjs` y con la sonda contra producción.
