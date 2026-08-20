# Pendiente tras la Fase 11 — hallazgos de las pruebas reales del usuario

**Origen:** el usuario probó la app contra el proyecto real `p-gri-b5b40` el 2026-08-20, después de
cerrar la Fase 11. Todo lo de aquí lo encontró **usando el producto**, no una suite de tests.

---

## En curso

**Pedidos: índices con sentido invertido + consulta vs reglas** — plan 11-28, ejecutándose.
Verdad de campo medida contra producción con tokens de usuario reales:

| Consulta | Resultado | Causa |
|---|---|---|
| cocina: `rid + estado IN + orderBy createdAt ASC` | `FAILED_PRECONDITION` | índice declarado DESC |
| la misma en DESC | OK | — |
| reporte: `rid + estado== + rango createdAt` | `FAILED_PRECONDITION` | índice declarado DESC |
| cliente: `sesionId + orderBy` (como cliente real) | `PERMISSION_DENIED` | la query no restringe `usuarioId` |
| cliente: `sesionId + usuarioId + orderBy` | `FAILED_PRECONDITION` | falta ese índice |

`audit_indexes.mjs` no lo detectó: comprueba la **presencia** del índice, no su **sentido**.

---

## Cola de trabajo

### 1. Reservas — dos bugs de lógica  ✔ RESUELTO en el plan 11-29

**Bug A (bloqueante).** ARREGLADO. El bucle salta la mesa ocupada en vez de abortar, y solo
falla cuando ha examinado TODAS las candidatas. Custodiado por
`app_cliente/test/reservas/asignacion_mesa_test.dart`.

**Bug B.** ARREGLADO con la opción mínima que eligió el usuario: `tx.update` del estado de la
mesa **solo si el slot es de hoy**. Corolario aplicado: si para un slot futuro no se escribe el
estado, tampoco se consulta (el guard existía solo para proteger esa escritura). Y su simétrico:
`cancelarReserva` solo revierte la mesa si la reserva era de hoy — si no, podría liberar una mesa
que reservó OTRA reserva de esta tarde.

**DEUDA QUE SIGUE ABIERTA (declarada, no resuelta).** El mapa de mesas del panel pinta el campo
`estado`, así que una reserva para **más tarde hoy creada en un día anterior** ya no tiñe la mesa
de amarillo: es correcto respecto del momento presente, pero el operador pierde el aviso. Lo mismo
con el contador `mesasReservadas` del dashboard. El modelo correcto es que el mapa lea las
**reservas del día** en vez de depender de un campo en vivo.

### 2. Barrido de mensajes que culpan a lo equivocado  ✔ RESUELTO en el plan 11-29

El bug C (`reserva_controller.dart`) está arreglado: el error de dominio sube tal cual y lo que no
es de dominio pasa por el clasificador único de 11-23, con dos contextos nuevos (`crearReserva`,
`cancelarReserva`). Los dos `catch (_)` **mudos** que 11-23 dejó anotados como deuda ahora dejan
traza con el código de Firebase y su clasificación.

**Barrido completo de los 36 `catch` de las dos apps: no quedó ningún otro que afirme una causa
falsa.** El detalle, sitio por sitio, está en el SUMMARY de 11-29. Hallazgos menores anotados allí
(ninguno es una mentira sobre la causa).

### 3. Menú del cliente — imágenes y presentación

- **Las imágenes existen**: los 16 productos de producción tienen `imagenUrl` (Unsplash).
  El modelo tiene el campo en ambas apps. **La app cliente no las pinta**: no hay un solo widget de
  imagen en las pantallas de menú.
- **Petición del usuario:** *"se ve como lista, no como carta"*. Rediseñar a tarjetas con foto,
  nombre y descripción legibles, precio destacado y marca clara de agotado.
- Carga progresiva y caché; pedir el ancho adecuado en la URL (las de Unsplash aceptan `?w=`) para
  no descargar resolución completa en un móvil.
- **Marcador para platos sin foto**: hoy los 16 la tienen, pero los que cree el usuario no. Una
  cuadrícula con huecos vacíos se ve peor que una lista sin fotos.
- Cloud Storage **no está habilitado** y exige Blaze, así que subir archivos desde el panel no es
  opción hoy. El panel ya acepta `imagenUrl` como texto; esa es la vía.


### 4. LA CUENTA — hueco funcional grave (decidido por el usuario 2026-08-20)

**Nadie suma nunca los pedidos de una sesión.** Verificado: la única suma que existe en las dos
apps es la del carrito (`carrito_controller.dart:31`), antes de enviar un pedido. Después:
- el cliente pulsa "solicitar la cuenta" → solo activa una bandera `cuentaSolicitada`;
- el mesero pulsa "entregar cuenta" (`entregarCuenta`, `pedidos_staff_provider.dart:144`) →
  **cierra la sesión y manda la mesa a limpieza**, sin importe.

En ningún punto aparece cuánto debe pagar el cliente. **Hoy no se puede cobrar** sin ir a la base de
datos a sumar a mano. El ciclo del producto no cierra: se reciben pedidos y no se cobran.

Que se creen pedidos separados al pedir más veces desde la misma mesa **es correcto** y no se toca:
son comandas distintas para cocina, con un mismo `sesionId`. Lo que falta es la suma.

**Alcance:**
- Vista de cuenta para el CLIENTE al solicitarla: desglose de sus pedidos de la mesa y total.
- Vista para el MESERO al recibir el aviso: importe antes de cobrar y cerrar la sesión.

**DECISIÓN DEL USUARIO (2026-08-20): se cobran SOLO LOS PEDIDOS SERVIDOS.**
Los rechazados por cocina y los que no llegaron a servirse no se cobran. Criterio: si no se sirvió,
no se paga. Implica que el importe puede cambiar mientras haya pedidos en curso — la vista debe
dejar claro qué está incluido y qué queda pendiente de servir, para que ni el cliente ni el mesero
se lleven una sorpresa al cerrar.

Los datos ya lo permiten: cada pedido tiene `total` y `sesionId`, y el índice
`pedidos(sesionId, usuarioId, createdAt)` está desplegado. Ojo: la cuenta de la MESA puede abarcar
más de un comensal si varios piden desde la misma sesión — decidir si la vista del mesero suma por
sesión (mesa) y la del cliente solo lo suyo.

---

## Verificado y funcionando tras el despliegue del 2026-08-20

- Reglas desplegadas (ruleset `58bd92e8-453c-4a2f-ade2-b79fffae3874`), idénticas al repo.
- **El bug de abrir mesa está resuelto en producción**: `GRI-MESA-demo-001` pasó a `ocupada`,
  o sea que el usuario abrió la mesa con éxito.
- Panel publicado en `p-gri-b5b40.web.app` con la marca GRI (verificado por HTTP).
- APK de la app cliente construido (68,5 MB, firmado con la clave de depuración, cuya huella SHA-1
  está registrada — Google Sign-In funciona en él).

## Herramienta que faltaba

`scripts/probar_consultas_reales.mjs` (encargada en 11-28): firma un custom token para un uid,
lo canjea por idToken y lanza las consultas reales contra el proyecto indicado, distinguiendo
OK / `PERMISSION_DENIED` / `FAILED_PRECONDITION`.

Es la **única** comprobación que separa "falta índice" de "regla deniega": el emulador no valida
índices compuestos y `fake_cloud_firestore` no tiene motor de reglas. Los tres bugs de esta clase
aparecidos en el proyecto los encontró una persona usando la app.
