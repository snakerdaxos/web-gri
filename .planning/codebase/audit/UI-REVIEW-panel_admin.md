# UI Review — panel_admin (Flutter Web Admin Panel)

**Audited:** 2026-08-19
**Baseline:** No UI-SPEC.md found for this codebase — audited against the 6 requested pillars + the user's own complaint as the spine.
**Screenshots:** NOT captured — no dev server detected on :3000, :5173, or :8080 (all returned status `000`). This is a **code-only audit**. Every finding below is evidence-based (file:line) but visual severity (e.g. exact overflow pixel counts) should be re-verified against real screenshots once a dev server/build is available.
**Scope:** `panel_admin/lib/**/*.dart` — login, app shell/sidebar, dashboard, mesas, menú (tab), reservas, cocina, clientes, reportes, configuración, plus `web/manifest.json`, `web/index.html`, `web/favicon.png`.

---

## Validating the user's complaint

| User's complaint | Verdict | Evidence |
|---|---|---|
| "hay errores visuales" | **CONFIRMED** | `reservas_screen.dart:181-227` unguarded Row overflow risk; duplicated shadow/button code producing visual drift between screens |
| "no es amigable el interfaz con el usuario" | **CONFIRMED** | zero `Semantics`, 1 `Tooltip` in the whole app, emoji-as-icon with no accessible label, dead-end empty state in Configuración |
| "no hay responsive y se ve todo muy desordenado" | **CONFIRMED** | only 3 of 9 screens use `LayoutBuilder`; 0 uses of `MediaQuery`; no max-content-width anywhere except dialogs/login |
| "no permite revisar claves para comprobar si está bien" | **CONFIRMED** | `login_screen.dart:142` — the ONLY password field in the app, `obscureText: true`, no visibility toggle anywhere in the codebase |
| "está lejos de ser una app bien profesional" | **CONFIRMED** | `web/manifest.json` and `web/favicon.png` are untouched Flutter template defaults; no restaurant/staff creation UI exists at all |

---

## Score Card

| Pillar | Score /10 | Key finding |
|---|---|---|
| 1. Layout & Responsive | **3/10** | Only dashboard/mesas/app_shell adapt to viewport; 6 other screens have zero breakpoint logic; likely RenderFlex overflow in `reservas_screen.dart` |
| 2. Visual Hierarchy & Spacing | **5/10** | No spacing scale; shadow/card decoration copy-pasted 4x; inconsistent page-title sizes (18/24/28) |
| 3. Design System Consistency | **4/10** | Mesa-state colors ARE centralized correctly (credit given); everything else (buttons, typography, 36 raw hex literals) is ad hoc per screen |
| 4. Forms & Input UX | **4/10** | No password visibility toggle (only password field in the app); destructive restaurant-deactivation has no confirmation, unlike mesa deletion |
| 5. Feedback & States | **4/10** | 6/8 screens have good empty states; but there is **no UI at all** to create a restaurant or a staff user — a fresh database cannot be bootstrapped from the app |
| 6. Accessibility & Polish | **3/10** | Web manifest/favicon are unedited Flutter template defaults; 0 `Semantics`, 1 `Tooltip` app-wide; borderline text contrast |

**Overall: ~3.8/10 average — the user's assessment ("lejos de ser una app profesional") is accurate and evidenced.**

---

## Detailed Findings

### Pillar 1 — Layout & Responsive (3/10)

**[HIGH] Only 3 of 9 screens implement any responsive behavior at all**
Where: grep for `LayoutBuilder` across `panel_admin/lib/features/**` returns exactly `dashboard_screen.dart`, `mesas_screen.dart`, `shared/app_shell.dart`. `MediaQuery` returns **zero** matches anywhere in `lib/`.
What: `menu_screen.dart`, `reservas_screen.dart`, `cocina_screen.dart`, `clientes_screen.dart`, `reportes_screen.dart`, `configuracion_screen.dart` render the exact same fixed layout regardless of viewport width — no adaptation between a 1280px laptop, a 768px tablet, or a 1920px monitor.
Why unprofessional: an admin panel that only "responds" on 2 of its 8 real screens looks unfinished and inconsistent — some pages feel considered, most don't.
Fix: Extract the `LayoutBuilder` breakpoint pattern from `dashboard_screen.dart:34-44` into a shared `ResponsiveBreakpoints` helper and apply it to the remaining 6 screens.

**[HIGH] Likely RenderFlex overflow in `_ReservaCard` on tablet/narrow-desktop widths**
Where: `panel_admin/lib/features/reservas/reservas_screen.dart:181-227`
What: A single `Row` (no `LayoutBuilder`, no `Wrap`) packs: `Text` hora (fontSize 20, bold) → `SizedBox(16)` → `Expanded` column (mesa + personas) → `_EstadoChip` → conditionally `SizedBox(12)` + `OutlinedButton('No-show')` + `SizedBox(8)` + `ElevatedButton('Marcar ocupada')`. Only the middle column is `Expanded`; the hora text, chip, and BOTH buttons are unconstrained fixed-width siblings. On a 768px tablet (content width ≈ 768 − 70 sidebar − 48 padding ≈ 650px) the combined intrinsic width of hora+chip+"No-show"+"Marcar ocupada" plausibly exceeds available space → classic yellow/black RenderFlex overflow banner.
Why unprofessional: this is precisely the class of bug the user means by "errores visuales."
Fix: Wrap the chip+buttons cluster in a `Wrap(spacing: 8, runSpacing: 8)`, or drop buttons to a second row below `900px` via a `LayoutBuilder`.

**[HIGH] No max-content-width constraint on any list/table screen — content stretches edge-to-edge on wide monitors**
Where: confirmed via grep — `maxWidth` only appears in `login_screen.dart:83` (`ConstrainedBox(maxWidth: 400)`) and inside dialog `SizedBox(width: 380)` (`categoria_form_dialog.dart:127`). It never appears in `reservas_screen.dart`, `cocina_screen.dart`, `clientes_screen.dart`, `reportes_screen.dart`, `configuracion_screen.dart`, or `menu_screen.dart`.
What: On a 1920px monitor, sidebar (250px) leaves ~1650px of content width. `ReservaCard`, `PedidoCard`, `_InfoCard`, and the restaurantes `Card` list all stretch to fill that width via `ListView`/`Column(crossAxisAlignment: stretch)` with no cap.
Why unprofessional: extremely long card/line widths on wide screens read as "sparse and disordered" — exactly the user's complaint — and hurt readability (line length far beyond ~800px readability guidance).
Fix: Wrap each screen's body in `Center(child: ConstrainedBox(constraints: BoxConstraints(maxWidth: 1200), child: ...))`.

**[MEDIUM] `GridView.count` hard-caps at 4 columns regardless of ultrawide viewports**
Where: `dashboard_screen.dart:37-43`, `mesas_screen.dart:41-43`
What: `crossAxisCount` never exceeds 4 no matter how wide the window gets — tiles just get individually huge instead of a 5th/6th column appearing.
Fix: Replace `GridView.count` with `GridView.builder` + `SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 260)` for a truly fluid grid.

**[MEDIUM] Single 750px breakpoint is the ONLY sidebar behavior**
Where: `app_shell.dart:70-73`
What: Sidebar jumps directly from 250px (full labels) to 70px (icon-only) at exactly 750px, with no intermediate tablet treatment. Combined with the lack of any other adaptive screen, the app was clearly not designed responsive-first — this one breakpoint was bolted on.

---

### Pillar 2 — Visual Hierarchy & Spacing (5/10)

**[MEDIUM] No shared spacing scale — outer page padding differs per screen with no rationale**
Where: `dashboard_screen.dart:46` `EdgeInsets.all(30)`, `cocina_screen.dart:37` `EdgeInsets.all(30)`, `reservas_screen.dart:90` / `clientes_screen.dart:33` / `reportes_screen.dart:117` `EdgeInsets.all(24)`, `menu_screen.dart:34` `EdgeInsets.fromLTRB(24,16,24,4)`.
Fix: Add a `GriSpacing` class (e.g. `xs4/sm8/md16/lg24/xl30`) to `core/theme.dart` and standardize page padding to one value.

**[MEDIUM] The exact same card shadow is hand-copied in 4+ places instead of one shared decoration**
Where: `stat_card.dart:38-44`, `dashboard_screen.dart:109-115`, `pedido_card.dart:46-52`, `reportes_screen.dart:350-356` all independently declare `BoxShadow(color: Color(0x0D000000), blurRadius: 12, offset: Offset(0,3))`.
Why it matters: `theme.dart`'s own `cardTheme` (line 93-98) only sets `elevation: 0.5` and radius — it is NOT what these `Container`s actually use, so the "single source of truth" comment at `theme.dart:6-8` is contradicted by 4 independent copies elsewhere.
Fix: Extract a `griCardDecoration` `BoxDecoration` constant in `theme.dart` and reuse.

**[LOW] Typographic hierarchy has no rule — 15 distinct `fontSize` literals in use app-wide**
Where: confirmed via grep: `11,12,13,14,15,16,18,20,22,24,25,26,28,30,32` all appear as literal `fontSize:` values with `griTheme` (`theme.dart:89-99`) defining **no `textTheme` at all**.
Fix: Define named text styles (`griTitleStyle`, `griBodyStyle`, `griCaptionStyle`) in `theme.dart` and route every screen through them.

**[Note — not a finding]** Page-level information hierarchy (title → subtitle → content) is applied consistently at the *structural* level across screens (title bold, subtitle gray, 4-8px gap) — the underlying pattern is sound, it's just re-implemented per screen instead of shared.

---

### Pillar 3 — Design System Consistency (4/10)

**[HIGH] `griTheme` covers colors/cards only — buttons and inputs are re-styled from scratch on every screen**
Where: `core/theme.dart:89-99` — `ThemeData` sets `colorScheme`, `scaffoldBackgroundColor`, `cardTheme`. It sets **no** `elevatedButtonTheme`, `outlinedButtonTheme`, `textButtonTheme`, or `inputDecorationTheme`.
What: The identical primary-button style (`backgroundColor: GriColors.primary, foregroundColor: Colors.white, disabledBackgroundColor: GriColors.primary.withValues(alpha:0.4)...`) is copy-pasted verbatim in at least: `login_screen.dart:156-166`, `dashboard_screen.dart:137-143` and `:231-234`, `mesas_screen.dart` FAB, `cocina_screen.dart:311-315`.
Why unprofessional: any future brand-color or button-radius change requires editing 5+ files by hand — a textbook design-system failure, and the reason small visual inconsistencies (button padding, disabled-state opacity) will keep drifting apart over time.
Fix: Move this into `griTheme.elevatedButtonTheme = ElevatedButtonThemeData(style: ...)` once; delete all per-screen `styleFrom` duplicates.

**[HIGH] 36 raw hex color literals scattered outside `GriColors`**
Where (sample): `app_shell.dart:94` `Color(0xFFEEEEEE)` divider, `app_shell.dart:201` `Color(0xFFAAAAAA)`, `app_shell.dart:253` `Color(0xFFCCCCCC)`, `menu_screen.dart:146/199/202` `Color(0xFFE65100)/Color(0xFFFF8F00)/Color(0xFF9E9E9E)` badge colors, `reportes_screen.dart:382` `Color(0xFFE8F0FE)`.
Why it matters: `theme.dart`'s doc comment explicitly claims to be the "Fuente única de verdad visual para TODO el panel" (line 7) — this claim is false in practice; a third of the palette in active use lives outside that file.
Fix: Move every one-off color into `GriColors` with a named constant, even the "minor" ones (dividers, badge tints).

**[Credit — genuine strength, do not treat as a gap]** Mesa-state colors (disponible/ocupada/reservada/limpieza) ARE correctly centralized in `theme.dart:35-85` via `mesaTileBg/mesaTileFg/mesaDot`, and correctly reused across `mesa_tile.dart`, `mesa_legend.dart`, dashboard stat icons, and `reservas_screen.dart`'s `_EstadoChip`. This is the one part of the design system executed to spec.

---

### Pillar 4 — Forms & Input UX (4/10)

**[CRITICAL] No show/hide toggle on the ONLY password field in the app**
Where: `panel_admin/lib/features/auth/login_screen.dart:139-152`
```dart
TextFormField(
  key: const ValueKey('login-password'),
  controller: _passCtrl,
  obscureText: true,
  ...
)
```
What: `obscureText: true` with no `suffixIcon` toggle, no local `_obscure` state, nothing. Grep confirms this is the **only** `obscureText` occurrence in the entire `panel_admin/lib` tree — there is no other password field anywhere the fix would also need to be applied.
Why unprofessional: this is a direct, verbatim match to the user's complaint — the single credential-entry point in the app gives users zero way to confirm what they typed. Every modern login form (and even most 2015-era ones) has this.
Fix (concrete, ~10 lines):
```dart
bool _obscure = true;
...
TextFormField(
  controller: _passCtrl,
  obscureText: _obscure,
  decoration: InputDecoration(
    labelText: 'Contraseña',
    border: const OutlineInputBorder(),
    prefixIcon: const Icon(Icons.lock_outline),
    suffixIcon: IconButton(
      icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
      onPressed: () => setState(() => _obscure = !_obscure),
    ),
  ),
  ...
)
```

**[MEDIUM] Deactivating a restaurant (destructive, platform-wide effect) has no confirmation dialog**
Where: `configuracion_screen.dart:202-226` (`_toggle`) wired to a bare `Switch` at line 301-304.
What: Flipping the switch to "off" immediately calls `toggleRestauranteActivo(...)`, and the SnackBar copy on line 213-215 itself admits the blast radius: *"Restaurante desactivado — desaparece de la app de clientes"*. Yet there is zero confirm step — one misclick hides a live restaurant from all its customers.
Contrast: mesa deletion (`mesa_form_dialog.dart:155-171`) correctly gates behind an `AlertDialog` confirm. This screen does not follow that same precedent for an arguably more damaging action.
Fix: Wrap the `false`-direction toggle in a confirm `AlertDialog` mirroring the mesa-delete pattern.

**[Note — not a finding, genuine strength]** All CRUD dialogs (`mesa_form_dialog.dart`, `categoria_form_dialog.dart`, `producto_form_dialog.dart`) correctly disable Save while `_saving` is true and while `_sinCambios` (no changes) is true, show inline field validators, and show a `CircularProgressIndicator` inside the button during submit. This part of the form UX is solid and should not be re-litigated.

---

### Pillar 5 — Feedback & States (4/10)

**[CRITICAL] There is no UI anywhere in the app to create a restaurant or a staff user**
Where: exhaustively grepped `panel_admin/` for `crearRestaurante|createRestaurante|crearUsuarioStaff|registrarStaff|setClaims|assignRole|invitar` — **zero matches**. `restaurantes_admin_provider.dart` exposes exactly two functions: `restaurantesAdmin` (read all) and `toggleRestauranteActivo` (update the `activo` field only, rules-enforced `hasOnly(['activo'])`). The super_admin's entire "Restaurantes" tab (`configuracion_screen.dart:199-317`, `_RestaurantesTab`) can only list and toggle EXISTING restaurants.
Why this is critical, not cosmetic: on a genuinely fresh Firestore project (empty `restaurantes` collection — the platform's real day-1 state), a super_admin who logs in has **no path inside the product** to onboard the first restaurant, and no admin/mesero/cocina account can be created from the panel either. The core value proposition documented in `CLAUDE.md` ("Un cliente puede sentarse en una mesa... sin intermediarios") cannot even be bootstrapped without someone hand-editing Firestore documents outside the app.
Fix: Add a `RestauranteFormDialog` (nombre, id/slug, tipoCocina, dirección) → `crearRestaurante()` Firestore write, reachable via a "+ Nuevo restaurante" button on the Restaurantes tab; add a staff-invite flow (Cloud Function setting custom claims + Firebase Auth user creation) reachable from the same area.

**[HIGH] The one screen a super_admin lands on with a fresh database has NO empty state**
Where: `configuracion_screen.dart:251-313` (`_RestaurantesTab` data branch)
What: Every other data-bearing screen in the app (`dashboard_screen.dart:161-171`, `mesas_screen.dart:73-83`, `menu_screen.dart:76-98`, `reservas_screen.dart:133-139`, `cocina_screen.dart:85-107`, `clientes_screen.dart:70-77`, `reportes_screen.dart:233-239`) has an explicit `.isEmpty` branch with a friendly message. `_RestaurantesTab` does not — confirmed no `.isEmpty` check exists in this file. On an empty `restaurantes` collection it silently renders "0 restaurantes en la plataforma" above a blank `ListView` with zero call-to-action.
Fix: Add the same `.isEmpty` → friendly-empty-state pattern used everywhere else, pointing at the "create restaurant" fix above.

**[HIGH] Related dead end: `_RestauranteTab` (singular, non-admin) also has no forward path**
Where: `configuracion_screen.dart:85-101`
What: When `restauranteProvider` resolves to no data (fresh DB / no restaurant selected), the screen shows "No hay restaurante seleccionado" with a "Reintentar" button that just re-invalidates the same empty provider — it can never succeed because there's nothing to create it with (see CRITICAL above). This is a loop, not a fixable error state.

**[MEDIUM] No loading feedback during the mandatory Firebase bootstrap before first paint**
Where: `main.dart:7-11`
```dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await bootstrap();          // Firebase.initializeApp() — network round trip
  runApp(const ProviderScope(child: GriApp()));
}
```
What: `bootstrap()` (`core/firebase_bootstrap.dart`) awaits `Firebase.initializeApp()` before anything is ever painted. On Flutter Web this is a blank white browser tab for as long as that network call + CanvasKit/Wasm bundle takes.
Why it matters: a blank tab reads as "broken" rather than "loading," especially on a slower connection — directly undermines "professional."
Fix: Add a static branded loading shell in `web/index.html` that's replaced once Flutter attaches, or restructure so `runApp` paints a splash screen immediately and `bootstrap()` runs inside a `FutureBuilder`.

**[LOW] `_ErrorBox` is reimplemented as a separate private class in 3 different files**
Where: `dashboard_screen.dart:210-242`, `mesas_screen.dart:115-147`, and the equivalent inline pattern in `cocina_screen.dart:294-323` — same layout, same button style, copy-pasted instead of shared.

---

### Pillar 6 — Accessibility & Polish (3/10)

**[HIGH] The web app manifest and favicon were never customized from the Flutter template**
Where: `panel_admin/web/manifest.json`:
```json
{
  "name": "gri_panel_admin",
  "short_name": "gri_panel_admin",
  "background_color": "#0175C2",
  "theme_color": "#0175C2",
  "description": "A new Flutter project."
}
```
`panel_admin/web/index.html:32`: `<title>gri_panel_admin</title>`.
`panel_admin/web/favicon.png`: visually confirmed to be the stock Flutter logo (blue swoosh), not GRI branding.
Why this is the single most damaging finding for "professional" perception: `#0175C2` is Flutter's own default demo blue — it doesn't even match the app's actual brand color `GriColors.primary = #FF4C05` defined right there in `theme.dart:18`. The browser tab, PWA install prompt, and bookmark icon are the very first thing any user or stakeholder sees, and they currently say, verbatim, "A new Flutter project."
Fix: Set `name`/`short_name` to "GRI Panel", `description` to something real, `theme_color`/`background_color` to `#FF4C05`/`#F5F6F8`, regenerate `favicon.png` + `icons/*.png` from the actual GRI logo (`documentos/` has brand assets per repo root), and set `<title>GRI — Panel Administrativo</title>`.

**[HIGH] Zero `Semantics` widgets and only one `Tooltip` in the entire app**
Where: grep for `Semantics(` across `panel_admin/lib` → 0 matches. Grep for `tooltip:` → 1 match, `menu_screen.dart:156` (category edit icon).
What: every emoji-rendered "icon button" — the QR/edit `ListTile`s in `mesa_actions_sheet.dart:122-132`, the collapsed 70px icon-only sidebar nav (`app_shell.dart:265-276` when `collapsed == true`), the stat-card emoji glyphs — has no accessible label and (for the collapsed sidebar) no tooltip to disambiguate icon-only nav on hover.
Fix: Add `Tooltip(message: label, child: ...)` around each collapsed `_MenuItem`, and `Semantics(label: ...)` on icon-led `ListTile`s.

**[MEDIUM] Emoji glyphs used as icons throughout instead of `Icon`/`IconData`**
Where: `app_shell.dart:136-142` (all 7 sidebar nav items + logo), `dashboard_screen.dart` stat-card emojis, `mesa_actions_sheet.dart:123,129`, `reservas_screen.dart:96`, `cocina_screen.dart` empty-state "🎉".
Why unprofessional: emoji rendering is font/OS-dependent (can render as a fallback tofu box on some Windows/Linux configurations without emoji fonts installed), cannot be recolored/sized consistently the way `Icon(Icons.x, color: ...)` can via `IconTheme`, and gives zero semantic value to assistive tech. Reads as prototype/wireframe rather than shipped product.
Fix: Replace with Material Icons (`Icons.home`, `Icons.table_restaurant`, `Icons.receipt_long`, `Icons.calendar_today`, `Icons.people`, `Icons.bar_chart`, `Icons.settings`) — also unlocks theming via a shared `IconThemeData`.

**[MEDIUM] Secondary text color is borderline WCAG AA contrast failure**
Where: `GriColors.gray = Color(0xFF777777)` (`theme.dart:33`), used at 12-13px for captions/subtitles across nearly every screen (menu product descriptions, timestamps, "Sin X" empty-state text).
What: `#777777` on white computes to ≈4.48:1 contrast — just under the 4.5:1 WCAG AA threshold for normal-weight text at this size.
Fix: Darken to `#666666` (≈5.7:1) or bump usage to ≥14px where 3:1 (large-text AA) would apply.

**[LOW] No `errorBuilder` on GoRouter — unmatched routes fall through to Flutter's default red-screen 404**
Where: `app.dart:27-72` — `GoRouter(...)` declares `routes` but no `errorBuilder`.
Fix: Add a branded "Página no encontrada" screen via `errorBuilder: (context, state) => ...`.

---

## Top 10 Fixes That Would Most Raise Perceived Professionalism

1. **Add show/hide toggle to the login password field** (`login_screen.dart:139-152`) — directly resolves the user's explicit complaint, ~10 lines.
2. **Replace the default Flutter favicon/manifest/browser title with real GRI branding** (`web/manifest.json`, `web/favicon.png`, `web/index.html:32`) — the single most visible "unprofessional" signal, and the cheapest to fix.
3. **Build a "Crear restaurante" flow for super_admin** (`configuracion_screen.dart` Restaurantes tab + new `crearRestaurante()` writer) — removes the CRITICAL onboarding dead-end that blocks the entire platform from bootstrapping.
4. **Fix the `_ReservaCard` Row overflow risk and add `LayoutBuilder` responsiveness to `reservas_screen.dart`**, matching the pattern already proven in `dashboard_screen.dart`.
5. **Add a max-content-width wrapper (`ConstrainedBox(maxWidth: 1200)`) to every list/table screen** so wide monitors don't render sparse, edge-to-edge content.
6. **Centralize button styling into `ThemeData.elevatedButtonTheme`/`outlinedButtonTheme`** — kills 5+ duplicated `styleFrom` blocks and guarantees future consistency.
7. **Replace emoji icons with Material `Icon`s and add `Tooltip`/`Semantics`** across the sidebar and action sheets — fixes both the "looks like a prototype" issue and the accessibility gap in one pass.
8. **Add an empty-state + create-CTA to `_RestaurantesTab`** — the one screen a fresh super_admin actually lands on currently shows nothing actionable.
9. **Add a confirmation dialog before deactivating a restaurant** (`configuracion_screen.dart:202-226`) — parity with the mesa-delete confirm flow for an action with equal or greater blast radius.
10. **Introduce a shared spacing scale and de-duplicate the repeated shadow/`_ErrorBox` code** into `core/theme.dart` / `features/shared/` — stops small visual drift from compounding across screens over time.

---

## Files Audited

- `panel_admin/lib/core/theme.dart`
- `panel_admin/lib/app.dart`, `panel_admin/lib/main.dart`, `panel_admin/lib/core/firebase_bootstrap.dart`
- `panel_admin/lib/features/shared/app_shell.dart`
- `panel_admin/lib/features/auth/login_screen.dart`
- `panel_admin/lib/features/dashboard/dashboard_screen.dart`, `widgets/stat_card.dart`, `widgets/mesa_tile.dart`
- `panel_admin/lib/features/mesas/mesas_screen.dart`, `mesa_actions_sheet.dart`, `mesa_form_dialog.dart` (partial)
- `panel_admin/lib/features/menu/menu_screen.dart`, `categoria_form_dialog.dart`, `producto_form_dialog.dart` (partial)
- `panel_admin/lib/features/reservas/reservas_screen.dart`
- `panel_admin/lib/features/cocina/cocina_screen.dart`, `widgets/pedido_card.dart`
- `panel_admin/lib/features/clientes/clientes_screen.dart`
- `panel_admin/lib/features/reportes/reportes_screen.dart`
- `panel_admin/lib/features/configuracion/configuracion_screen.dart`, `restaurantes_admin_provider.dart`
- `panel_admin/web/manifest.json`, `panel_admin/web/index.html`, `panel_admin/web/favicon.png`

Full-repo greps used as supporting evidence: `obscureText`, `LayoutBuilder`, `MediaQuery`, `maxWidth`, `Semantics(`, `tooltip:`, `IconButton(`, `fontSize:`, `Color(0x`, `crearRestaurante|createRestaurante|...` (staff/restaurant creation).
