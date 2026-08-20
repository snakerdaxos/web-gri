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

**DEUDA QUE SIGUE ABIERTA (declarada, no resuelta) — Y AHORA ES MÁS VISIBLE.** El mapa de mesas
del panel pinta el campo `estado`, así que una reserva para **más tarde hoy creada en un día
anterior** no tiñe la mesa de amarillo: es correcto respecto del momento presente, pero el operador
pierde el aviso. Lo mismo con el contador `mesasReservadas` del dashboard. El modelo correcto es que
el mapa lea las **reservas del día** en vez de depender de un campo en vivo.

Tras el plan 11-31 (reservar para hoy con 4 h de margen) el mapa pasa de «nunca avisa» a **«avisa a
veces»**, que es peor de interpretar:

| Reserva | ¿Tiñe la mesa de amarillo? |
|---|---|
| Creada HOY para más tarde HOY (nuevo desde 11-31) | **Sí** |
| Creada AYER para HOY | No |
| Creada hoy para mañana o más allá | No (correcto: describe este momento) |

Antes de 11-31 el amarillo lo ponía **solo el staff** a mano, y eso era una lectura uniforme. Ahora
el operador no puede deducir de dónde viene. **Verificado leyendo el código, no con datos reales:**
`stats_provider.dart:71` cuenta `mesa.estado == reservada`, mientras que el contador `reservasHoy`
del mismo provider consulta la colección `reservas` con la ventana del día — así que ESE sí muestra
todas las reservas de hoy, vengan de cuando vengan. Las pantallas de reservas del panel tampoco
dependen del estado de la mesa.

Efecto secundario nuevo: con el margen de 4 h, una mesa reservada para hoy queda amarilla **al menos
4 horas** antes del turno, y nada la devuelve a `disponible` si el cliente no aparece (el operador
tiene que moverla a mano; ya pasaba con el «Marcar reservada» del staff). No se ha tocado: cambiar
el modelo del mapa es una decisión de arquitectura, no un arreglo colado dentro de este plan.

### 2. Barrido de mensajes que culpan a lo equivocado  ✔ RESUELTO en el plan 11-29

El bug C (`reserva_controller.dart`) está arreglado: el error de dominio sube tal cual y lo que no
es de dominio pasa por el clasificador único de 11-23, con dos contextos nuevos (`crearReserva`,
`cancelarReserva`). Los dos `catch (_)` **mudos** que 11-23 dejó anotados como deuda ahora dejan
traza con el código de Firebase y su clasificación.

**Barrido completo de los 36 `catch` de las dos apps: no quedó ningún otro que afirme una causa
falsa.** El detalle, sitio por sitio, está en el SUMMARY de 11-29. Hallazgos menores anotados allí
(ninguno es una mentira sobre la causa).

### 2-bis. Reservar el mismo día  ✔ RESUELTO en el plan 11-31

`firstDate` era MAÑANA: hoy no se podía ni seleccionar. Decisión del usuario (2026-08-20): «sí pero
con un margen de 4 horas, ya que no se puede reservar para la misma hora».

Regla implantada: **`slot >= ahora + 4 h`, con la igualdad incluida**. Como los slots son horas en
punto, a las 14:30 el primero de hoy es las 19:00 y a las 14:00 clavadas son las 18:00; a partir de
las 17:01 hoy ya no admite nada (el turno acaba a las 21:00) y el calendario abre en mañana. Las
tres caras —calendario, desplegable y validación— salen del mismo predicado
(`slotRespetaMargen`, en `reserva_controller.dart`). El margen está **también en
`firestore.rules`** (`fecha >= request.time + duration.value(4, 'h')`), con casos de borde en
`scripts/test/rules/reservas.test.mjs`.

Consecuencia: la rama `esHoy` del controller —la que marca la mesa `reservada` y la que salta las
mesas ocupadas—, que 11-29 midió como **inalcanzable desde el producto**, pasa a ejecutarse de
verdad. Está cubierta ahora también desde la UI. Ver el efecto en el mapa del panel arriba.

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


### 5. Un stream que FALLA se pintaba como un stream que CARGA  ✔ RESUELTO en el plan 11-33

Reportado por el usuario: «el cliente en ver pedido se queda cargando». Su build era anterior
al arreglo de `usuarioId` (11-28), así que el listener venía denegado — pero un listener
denegado tiene que salir como un error accionable, nunca como un spinner eterno.

**Causa raíz, y no estaba en nuestro código:** Riverpod 3 reintenta cualquier excepción que no
sea un `Error` de Dart **diez veces** con backoff hasta 6,4 s, y mientras reintenta el estado
es `AsyncLoading` **con el error dentro** (`element.dart:790`). `when` despacha por
`isLoading` antes que por el error → **~38 s de spinner mudo por cada fallo**, en TODAS las
pantallas de LAS DOS apps. El barrido de los 36 `catch` de 11-29 no podía verlo: **un Stream
que falla no pasa por ningún `catch`**.

Arreglado con `core/async_fallo.dart` en las dos apps (`reintentoGri` + `cuandoConFallo`) y
los **24 consumidores de `AsyncValue`** revisados uno a uno. Dos de ellos eran MENTIRAS
(«este cliente no tiene pedidos» y «No hay restaurante seleccionado» ante un fallo de lectura)
y dos eran SILENCIOS (`SizedBox.shrink()` en el topbar). Detalle en el SUMMARY de 11-33.

El panel no tenía clasificador; ahora tiene el suyo, con LAS MISMAS seis causas y los mismos
criterios de 11-23 pero con textos para staff. Un test de paridad prueba el mismo vector de
códigos en las dos suites para que las copias no deriven en silencio.

**Dos bugs de DINERO encontrados por el camino, los dos arreglados.** El importe de la fila
del mesero y **el recibo del cobro** se renderizaban como CERO ante un fallo de lectura.
11-32 tuvo el cuidado de mostrar un guion durante la CARGA por esta misma razón; la rama de
ERROR se lo saltaba. El del recibo se escribe con la sesión ya cerrada detrás y el aviso ya
desaparecido, así que no había forma de deshacerlo.

**Y el desborde que 11-32 anunció sin poder medir:** el resumen de la cuenta del comensal
desbordaba **101 px a 320 px**. Medido y arreglado (la etiqueta cede, la cifra nunca).

### 6. Verificación contra el proyecto real — HECHA (2026-08-20, plan 11-33)

`node scripts/probar_consultas_reales.mjs` contra `p-gri-b5b40`, las dos identidades:

| Identidad | Resultado |
|---|---|
| cliente `d7c4xzmrbYcgiaGW0mCnqrdMril2` | 23 consultas · 12 OK · **0 sin índice** · 11 denegadas |
| super_admin `np9HetsgY6UcVCdC1sGhsUloI6D3` | 23 consultas · **23 OK** · 0 sin índice · 0 denegadas |

**Cero `FAILED_PRECONDITION` en las dos pasadas**: los dos índices que 11-28 dejó pendientes
de desplegar están construidos y sirven a sus consultas. **Las 7 consultas de `app_cliente`
salen OK con un uid de cliente real**, incluida la del incidente
(`pedidos sesionId== usuarioId== orderBy(createdAt)`).

Las 11 denegadas son **todas** consultas de `panel_admin` ejecutadas con uid de cliente: es lo
correcto por diseño, un comensal no es staff. **No queda ningún defecto vivo de consultas ni
de índices.**

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
