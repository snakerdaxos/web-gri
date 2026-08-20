# Especificación — La cuenta de la mesa

**Origen:** el usuario, probando el producto el 2026-08-20, notó que al pedir dos veces desde la
misma mesa se creaban dos pedidos separados. Los pedidos separados son correctos; lo que faltaba
es que **nadie los suma nunca**.

**Decisión del usuario (2026-08-20): se cobran SOLO LOS PEDIDOS SERVIDOS.**

---

## El hueco, verificado

La única suma que existe en las dos apps es la del carrito (`carrito_controller.dart:31`), y ocurre
**antes** de enviar un pedido. Después de eso:

| Acción | Qué hace hoy | Qué falta |
|---|---|---|
| Cliente pulsa "solicitar la cuenta" | activa la bandera `cuentaSolicitada` | no ve ningún importe |
| Mesero pulsa "entregar cuenta" (`pedidos_staff_provider.dart:144`) | cierra la sesión y manda la mesa a limpieza | cobra sin saber cuánto |

**Consecuencia:** hoy no se puede cobrar sin ir a la base de datos a sumar a mano. El ciclo del
producto no cierra — se reciben pedidos y no se cobran.

## Lo que NO se toca

Que pedir varias veces desde la misma mesa cree pedidos separados **es correcto y deliberado**: son
comandas distintas que llegan a cocina en momentos distintos, unidas por el mismo `sesionId`. Nadie
debe "acumularlas" en un solo documento.

## Alcance

### Vista del cliente
Al solicitar la cuenta, ver el desglose de sus pedidos en esa mesa y el total a pagar.

### Vista del mesero
Al recibir el aviso de que la mesa pide la cuenta, ver el importe **antes** de cobrar y cerrar la
sesión. Hoy el aviso llega sin cifra.

## Reglas de negocio

**Solo entran los pedidos en estado `servido`.** Los rechazados por cocina y los que no llegaron a
servirse no se cobran. Criterio del usuario: si no se sirvió, no se paga.

**Consecuencia que la interfaz DEBE manejar:** el importe cambia mientras haya pedidos en curso.
Si el cliente pide la cuenta con un plato aún en preparación, ese plato no está en el total — y
cuando se sirva, el total sube. La vista tiene que distinguir con claridad **lo que ya se cobra** de
**lo que sigue pendiente de servir**, o el cliente pagará una cifra y verá otra. Este es el punto
más delicado del diseño y no debe resolverse con un total a secas.

## RESUELTO — una sesión, un usuario (decisión del usuario, 2026-08-20)

*"Una mesa solo se puede [abrir] de a un usuario, sin importar que tengan 4 personas."*

Quien escanea el QR es el dueño de la sesión y pide por todos los de la mesa. Por tanto
**la cuenta del cliente y la cuenta de la mesa son la misma cosa**, y esto simplifica el diseño:

- No hay comensales múltiples que reconciliar. El mesero y el cliente ven **el mismo importe**.
- **No hay que tocar `firestore.rules`.** La rama que ya existe —el cliente ve los pedidos cuyo
  `usuarioId` es el suyo— cubre la cuenta entera, porque todos los pedidos de esa sesión son suyos.
- **No hace falta índice nuevo.** `pedidos(sesionId, usuarioId, createdAt)` ya está desplegado y
  verificado en producción, y es exactamente la consulta que necesita la vista del cliente.

Consecuencia de producto que conviene tener presente, no un problema a resolver ahora: si un
segundo comensal quisiera pedir desde su propio móvil en esa misma mesa, no podría — la regla de
sesión única por mesa se lo impide. Es una decisión deliberada y coherente con cómo funciona el
QR de mesa, pero condiciona el reparto de cuenta si algún día se quisiera.

## Datos y restricciones técnicas

- Cada pedido ya tiene `total` (int COP) y `sesionId`. No hace falta modelo nuevo.
- Los items van con nombre y precio **congelados** en el momento del pedido, así que el importe
  histórico no cambia aunque suban los precios. Eso ya está bien resuelto.
- Índice `pedidos(sesionId, usuarioId, createdAt)` **desplegado y verificado** en producción.
- **Cuidado con las reglas:** la consulta del cliente sobre `pedidos` DEBE restringir `usuarioId`, o
  Firestore deniega la suscripción entera (se verificó contra producción: sin ese filtro devuelve
  `PERMISSION_DENIED`). Si la vista del cliente necesita ver la cuenta de toda la mesa y no solo la
  suya, **habrá que revisar la regla y probablemente un índice nuevo** — no dar por hecho que la
  consulta actual sirve.
- La vista del mesero consulta como staff, cuya rama de la regla sí permite ver los pedidos del
  restaurante.
- Verificar cualquier consulta nueva con `scripts/probar_consultas_reales.mjs` contra el proyecto
  real: el emulador no valida índices compuestos y `fake_cloud_firestore` no evalúa reglas.

## Fuera de alcance

Cobro en línea. Los pagos están diferidos desde la Fase 10; esto es solo mostrar el importe para
cobrar por los medios que el restaurante ya use.
