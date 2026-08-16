# Deferred Items — Phase 10

> Hallazgos fuera de scope descubiertos durante la ejecución. NO corregir
> inline: pertenecen a los waves/plans indicados.

## 1. Panel admin: pantalla "Clientes" no puede listar `usuarios/`

- **Encontrado en:** 10-01 Task 1 (diseño de rules)
- **Issue:** `match /usuarios/{uid}` permite read solo a self o super_admin
  (privacidad de emails). El panel (features/clientes) no podrá hacer query
  sobre `usuarios/` con rol admin_restaurante — además los clientes son
  cross-tenant (`restauranteId: null`), así que no hay key por la que
  filtrarlos por restaurante.
- **Sugerencia (wave panel):** derivar la lista de clientes del stream de
  `pedidos where restauranteId == rid` (campos denormalizados `usuarioId` +
  `clienteNombre`), o ampliar rules si se decide otra política de privacidad.
- **Owner:** plan del panel (10-05/10-06 según numeración final).

## 2. Doble corrida del seed contra emuladores pendiente (sin Java)

- **Encontrado en:** 10-01 Task 2 (entorno sin JRE)
- **Issue:** la prueba de idempotencia en vivo (seed ×2 contra emuladores)
  no pudo ejecutarse — la máquina no tiene Java. Documentada en
  docs/FIREBASE_SETUP.md §3.
- **Owner:** gate de verificación de 10-07 (o cualquier máquina con Java 11+).
