# Phase 11 — Alcance

**Origen:** auditoría del sistema del 2026-08-19 (`.planning/codebase/`, commit 34a2f98).
**Síntoma reportado por el usuario:** "no sirven sus funciones ni permite crear nada desde 0 si la
base de datos no tiene contenido" + "hay errores visuales, no es amigable, no hay responsive, se ve
desordenado, no permite revisar claves — está lejos de ser una app profesional", en móvil y en admin.

**Estado de partida:** `flutter analyze` 0 issues en ambas apps, 175 tests verdes. Nada de lo de abajo
lo detecta un linter — por eso pasó los gates de la Fase 10.

---

## Bloque 1 — Funcional (bloqueante)

### 1a. Bootstrap desde base vacía
Hoy no existe ninguna ruta en producto para arrancar de cero. `firestore.rules` permite
`create` de `restaurantes` solo a `isSuper()`, y los custom claims `{role, rid}` solo los escribe
`scripts/seed_firebase.mjs` con el Admin SDK.
`panel_admin/lib/features/configuracion/restaurantes_admin_provider.dart` solo lista y hace toggle
de `activo` — no hay función de crear.

- Pantalla + función de crear restaurante para `super_admin` en el panel (las rules ya lo permiten).
- **Restricción dura:** el doc ID del restaurante debe ser un slug `[a-z0-9-]+`. El escáner valida
  `^GRI-MESA-[a-z0-9-]+-\d{3}$` (`app_cliente/lib/features/sesion_qr/scan_screen.dart:41`) y el doc ID
  de mesa deriva del rid. Un rid con mayúsculas o acentos deja las mesas inescaneables.
- Vía para crear usuarios staff con claims: decidir entre Cloud Function callable (recomendado, mantiene
  el Admin SDK del lado servidor) vs. script documentado. Sin esto no se puede dar de alta un
  restaurante nuevo con su equipo.

### 1b. Query vs rules — el menú del cliente está denegado siempre
`app_cliente/lib/features/restaurantes/restaurantes_provider.dart:46-53` consulta `categorias` y
`productos` filtrando `activo` **client-side**. Firestore evalúa las rules contra la consulta, no
contra los documentos devueltos → `permission-denied` incondicional.
Arreglo: añadir `where('activo', isEqualTo: true)` y, en `productos`, también
`where('disponible', isEqualTo: true)`. El propio `firestore.rules:109-111` ya advertía de esto.
Ojo: los índices compuestos resultantes deben añadirse también.

### 1c. Índice compuesto faltante
`panel_admin/lib/features/menu/menu_provider.dart:35-39` hace `where('restauranteId') + orderBy('orden')`
sobre `categorias`, y `firestore.indexes.json` no tiene **ningún** índice de `categorias`
→ `FAILED_PRECONDITION` en cada carga del menú del panel.

### 1d. Cerrar el punto ciego de tests
- Suite de `firestore.rules` con `@firebase/rules-unit-testing` contra el emulador (hoy: cero tests de rules).
- Tests de base vacía / primer arranque en ambas apps. El fixture `buildFakeFirestoreConSeed()`
  siempre pre-siembra, así que el escenario que falla es el único nunca probado.
- Chequeo de que cada query del código tenga su índice declarado.

---

## Bloque 2 — Quick wins de UI

- Toggle ver/ocultar contraseña en los 5 campos: `app_cliente` login:144, register:142,
  perfil:131 y 143; `panel_admin` login:142. Hoy no existe ni uno en todo el repo.
- Campo de confirmar contraseña en el registro.
- Branding propio en lugar de los defaults de Flutter: ícono y splash en móvil; en web
  `panel_admin/web/manifest.json`, `index.html` (título "A new Flutter project", theme-color
  `#0175C2` en vez del `#FF4C05` real) y `favicon.png`.
- Estados vacíos con guía en todas las listas. Crítico: `menu_mesa_screen.dart:116-141` queda
  en blanco sin mensaje cuando el menú no tiene categorías.
- Confirmación antes de desactivar un restaurante.
- Página 404 en go_router.

---

## Bloque 3 — Sistema de diseño y responsive

- Tokens centralizados de color y tipografía vía `ThemeData`/`textTheme`. Hoy: 36 hex crudos fuera
  de paleta en el panel, duplicados en `app_cliente/lib/models/pedido.dart:78-95`, cero uso de
  `textTheme`.
- Escala de espaciado (hoy no hay ninguna).
- Responsive real: quitar el `maxWidth: 480` fijo de
  `app_cliente/lib/features/shared/app_shell.dart:31-35` (no hay un solo `LayoutBuilder` en las 68
  fuentes del móvil) y hacer responsive las 6 de 9 pantallas del panel que no lo son.
- Overflow: `reserva_wizard_screen.dart:340-361` y `reservas_screen.dart`.
- Accesibilidad: `Semantics` (hoy cero), tooltips en IconButtons (5 de 6 sin etiqueta),
  targets mínimos de 48dp (`home_screen.dart:308-310` está en 45), contraste.

---

## Bloque 4 — Verificación del flujo completo

Pedido explícito del usuario: *"revisa también que se pueda crear restaurante, que las mesas
funcionen con su QR y el flujo completo"*.

E2E contra el emulador, arrancando de una base **vacía**:

1. Crear restaurante como `super_admin` desde el panel.
2. Crear staff del restaurante (admin/mesero/cocina) con sus claims.
3. Crear mesas → verificar doc ID `GRI-MESA-{rid}-{NNN}` y que el QR generado sea escaneable.
4. Crear categorías y productos del menú desde el panel.
5. Cliente: registro → descubrir restaurante → ver menú (la regresión de 1b).
6. Cliente: escanear QR → abrir sesión → mesa pasa a `ocupada`.
7. Cliente: pedir del menú → pedido en estado `enviado`.
8. Cocina: `enviado` → `aceptado` → `en_preparacion` → `servido`.
9. Cliente: solicitar la cuenta → staff entrega y cierra sesión → mesa a `limpieza` → `disponible`.
10. Cliente: calificar el pedido servido.
11. Reservas: crear, verificar anti-sobre-reserva y cancelar.

Esto absorbe el checkpoint humano que quedó pendiente de la Fase 10 (`docs/SMOKE-E2E.md`), ahora
partiendo de cero en vez de partir del seed.

---

## Evidencia

- `.planning/codebase/CONCERNS.md` — riesgos rankeados con file:line
- `.planning/codebase/ARCHITECTURE.md` — traza del bootstrap
- `.planning/codebase/TESTING.md` — por qué los tests no lo detectaron
- `.planning/codebase/audit/UI-REVIEW-app_cliente.md` — 19/60, 6 críticos
- `.planning/codebase/audit/UI-REVIEW-panel_admin.md` — 2 críticos, 8 altos
