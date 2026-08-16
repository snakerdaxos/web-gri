# Deferred Items — Phase 10

## Índices Firestore no definidos en 10-01 (detectados en 10-03)

10-03 resolvió con orden/filtro **client-side** (resultado idéntico, N chico por restaurante).
Si el volumen crece y se quiere server-side, agregar a `firestore.indexes.json`:

- `categorias(restauranteId ASC, orden ASC)` — para
  `where('restauranteId').orderBy('orden')` en restauranteDetalle.
- `mesas(restauranteId ASC, capacidad ASC, numero ASC)` — para
  `where('restauranteId').where('capacidad', isGreaterThanOrEqualTo: n).orderBy('numero')`
  en crearReserva (hoy: where+orderBy numero server-side, capacidad client-side).

Archivos afectados si se migran a server-side:
`app_cliente/lib/features/restaurantes/restaurantes_provider.dart`,
`app_cliente/lib/features/reservas/reserva_controller.dart`.

## Otros (fuera de scope de 10-03)

- `documentos/google-services.json` y `documentos/sdk.png` aparecen untracked en el
  repo — decidir si se ignoran o commitean (no son de este plan).
