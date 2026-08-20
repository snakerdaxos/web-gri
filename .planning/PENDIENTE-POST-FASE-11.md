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

### 1. Reservas — dos bugs de lógica, heredados del backend archivado

**Bug A (bloqueante).** `app_cliente/lib/features/reservas/reserva_controller.dart:112-120`.
El bucle sobre mesas candidatas es incoherente: si el **slot** está tomado hace `continue` y prueba
la siguiente mesa, pero si la **mesa está ocupada** lanza excepción y **aborta el bucle entero**.
Una sola mesa ocupada impide reservar aunque haya siete libres. Reproducido: `GRI-MESA-demo-001`
(capacidad 2) está `ocupada`, y es la primera candidata para 2 personas.
Arreglo: saltar la mesa, no abortar.

**Bug B — DECISIÓN DEL USUARIO (2026-08-20): opción "tocar el estado solo si la reserva es para hoy".**
`reserva_controller.dart:115` hace `tx.update(mesa, {'estado':'reservada'})` al crear la reserva,
**sea para la fecha que sea**. Reservar para el martes que viene marca la mesa reservada hoy,
bloqueándola para clientes que entren por la puerta.
El estado de la mesa describe *este momento*; una reserva futura no debería tocarlo. Lo correcto a
futuro es que el mapa lea las reservas del día; el usuario elige el cambio mínimo ahora:
**solo actualizar el estado si el slot cae en el día de hoy.** Dejar anotado como deuda que el
modelo correcto es que el estado no dependa de reservas futuras.

### 2. Barrido de mensajes que culpan a lo equivocado

Tercera aparición del mismo patrón en esta sesión, y cada una costó tiempo real al usuario:
- El escáner decía "verifica el código" ante un `permission-denied` (arreglado en 11-23).
- El panel decía "El restaurante no existe" ante una función no desplegada (arreglado en 11-26).
- **Reservas**: `reserva_controller.dart:239-245` aplasta tres causas distintas —slot tomado,
  capacidad insuficiente, estado de mesa inválido— en el mensaje "Ese horario acaba de ser
  reservado, elige otro", **descartando el mensaje preciso** que ya lanzaba la lógica interna.
  El propio comentario lo admite: *"409-equivalentes del port (capacidad/slot tomado/estado mesa)"*.

No basta con arreglar este: **barrer todos los `catch` de ambas apps** buscando el patrón de
sustituir un mensaje específico por uno genérico o equivocado, con el criterio que fijó 11-23.

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
