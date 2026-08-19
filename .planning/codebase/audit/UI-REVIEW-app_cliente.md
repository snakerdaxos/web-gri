# UI Review — `app_cliente/` (Flutter mobile client, GRI)

**Audited:** 2026-08-19
**Baseline:** No UI-SPEC.md found for this codebase — audited against abstract 6-pillar standards and the user's own complaint list.
**Mode:** Code-only audit (no dev server / no device attached during this session — findings are static-analysis based, backed by file:line evidence and grep counts, not live screenshots).
**Scope:** `app_cliente/lib/` — 68 Dart files (screens, controllers, models, theme, router).

---

## User complaint validation (spine of this audit)

| Complaint | Verdict | Evidence |
|---|---|---|
| "hay errores visuales" | **CONFIRMED** | Unguarded `Row` in `reserva_wizard_screen.dart` will overflow (RenderFlex, red/black stripes) with any restaurant name that doesn't fit; blank screen bug in `menu_mesa_screen.dart` when menu has zero categories. |
| "no es amigable el interfaz" | **CONFIRMED** | Zero `Semantics()` widgets in 68 files; 5 of 6 `IconButton`s have no tooltip/label; primary QR scan button is 45×45dp (below the 48dp minimum tap target). |
| "no hay responsive, se ve desordenado" | **CONFIRMED** | The entire app body is hard-clamped to `maxWidth: 480` in `app_shell.dart:31-35` — there is no `LayoutBuilder`, no breakpoint, no tablet/landscape adaptation anywhere in the codebase (grep for `LayoutBuilder`/`MediaQuery` returns only 2 hits, both for keyboard-inset padding, not layout). |
| "no permite revisar claves" | **CONFIRMED** | 4 password fields with `obscureText: true` and **zero** visibility-toggle icons, anywhere in the app. |
| "lejos de ser profesional" | **CONFIRMED** | App still ships the unmodified default Flutter launcher icon and a blank white default splash screen — never rebranded. Combined with 38+ raw emoji characters used as UI icons instead of a proper icon set. |

---

## Pillar 1 — Layout & Responsive

**Score: 2/10**

- **CRITICAL** — `app_cliente/lib/features/reservas/reserva_wizard_screen.dart:340-361` (`_ResumenRow`): `Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(label), Text(value)])` — neither `Text` is wrapped in `Expanded`/`Flexible`. `value` is a restaurant name pulled from live data (`nombreRestaurante`). Any name too long for the remaining row width triggers a `RenderFlex overflowed by N pixels` — the literal yellow/black striped visual bug. **Fix:** wrap the `value` Text in `Expanded(child: Text(value, overflow: TextOverflow.ellipsis))`.
- **HIGH** — `app_cliente/lib/features/shared/app_shell.dart:31-35`: the whole app body is wrapped in `Center(child: ConstrainedBox(constraints: BoxConstraints(maxWidth: 480), child: navigationShell))`. This is a permanent phone-sized column with no adaptation — on a tablet or in landscape, ~40%+ of the screen is empty gray space on both sides, and no alternate layout (e.g. 2-column grid, wider cards) is ever used. Grepping the whole `lib/` tree for `LayoutBuilder` and `MediaQuery` returns exactly 2 hits, both `MediaQuery.viewInsets.bottom` for keyboard padding (`menu_mesa_screen.dart:293`, `calificacion_sheet.dart:196`) — **not a single screen adapts to screen size or orientation.**
- **MEDIUM** — `app_cliente/lib/features/restaurantes/restaurante_detalle_screen.dart:27-30`: `AppBar` title is `Text(d.nombre)` with no `overflow`/`maxLines`. A long restaurant name will wrap inside the fixed-height toolbar and get clipped rather than ellipsized.
- **LOW (positive)** — Forms that need it (`login_screen.dart`, `register_screen.dart`, `menu_mesa_screen.dart`'s cart sheet, `calificacion_sheet.dart`) do correctly use `SingleChildScrollView` + keyboard-inset padding, so keyboard-overlap isn't a widespread issue — this is the one place responsive hygiene exists.

## Pillar 2 — Visual Hierarchy & Spacing

**Score: 5/10**

- **MEDIUM** — Spacing values are reasonably consistent (`16`, `18`, `20`, `24` show up repeatedly) but every value is a locally re-typed `EdgeInsets.all(N)`/`SizedBox(height: N)` literal — there is no shared spacing-scale constant anywhere (`grep -r "static const.*space\|spacing" lib` → 0 hits). Any future redesign requires manually editing dozens of files.
- **MEDIUM** — Typographic hierarchy is thin: `grep -rohn "FontWeight\.[a-zA-Z]*"` across all 68 files returns **49 hits, all `FontWeight.bold`** — no `w500`/`w600`/`medium`/`semibold` anywhere. Every screen has exactly two visual weights: bold or default regular. Combined with `fontSize` literals ranging arbitrarily from 12 to 60 (15 distinct values used ad hoc), the hierarchy is achieved by font-size alone, inconsistently, per-screen.
- **LOW (positive)** — Card treatment is centralized via `griTheme.cardTheme` (`core/theme.dart:70-75`, radius 15, elevation 0.5) and is used consistently via the `Card` widget where used (e.g. `mis_reservas_screen.dart:187`, `restaurantes_list_screen.dart:92`). Where a `Container` is used instead of `Card` for a "card-like" surface (`home_screen.dart:180-189` `_SesionBanner`, `home_screen.dart:479-485` `_ProximaReservaCard`), the same `BorderRadius.circular(15)` is at least manually replicated correctly.

## Pillar 3 — Design System Consistency

**Score: 3/10**

- **HIGH** — `core/theme.dart` defines a `GriColors` token class (good instinct), but pedido status colors are defined **separately** in `app_cliente/lib/models/pedido.dart:78-95` as a second, uncoordinated palette (`Color(0xFF2563EB)`, `Color(0xFFD97706)`, `Color(0xFF7C3AED)`, plus their tint backgrounds) that never references `GriColors`. Two different "status chip color" systems exist in the same app (`GriColors.estadoChipBg/Fg` for reservas vs `PedidoEstadoX.estadoColor/estadoBg` for pedidos) with no shared abstraction.
- **HIGH** — Zero usage of `ThemeData.textTheme` anywhere (`grep -r "Theme.of(context).textTheme\|theme.textTheme" lib` → 0 hits). Every single `Text` widget in every screen builds its own inline `const TextStyle(...)`, duplicating `fontWeight: FontWeight.bold, color: GriColors.text` dozens of times independently instead of a shared `titleLarge`/`bodyMedium` etc. This is why size/weight drift (Pillar 2) exists — there is no single source of truth to change.
- **MEDIUM** — Raw hex literals are scattered directly in widget code instead of routed through `GriColors`: `Color(0xFFF5A623)` (star/rating amber) appears **9 times** inline across `home_screen.dart`, `restaurantes_list_screen.dart`, `restaurante_detalle_screen.dart`, `pedido_estado_screen.dart`, `calificacion_sheet.dart` — it is never promoted to a `GriColors.amber` token despite being reused this often. Same for the orange gradient `Color(0xFFFF6B35)`/`Color(0xFFFF9B5A)` (4 uses each, `home_screen.dart`, `restaurantes_list_screen.dart`, `restaurante_detalle_screen.dart`).

## Pillar 4 — Forms & Input UX

**Score: 2/10**

- **CRITICAL** — `app_cliente/lib/features/auth/login_screen.dart:144`: `TextFormField(obscureText: true, ...)` — password field, **no visibility toggle**.
- **CRITICAL** — `app_cliente/lib/features/auth/register_screen.dart:142`: same — `obscureText: true`, no toggle, and also **no `autofillHints`** (login's password field at least has `AutofillHints.password` on line 145; register's does not — inconsistent between the two nearly-identical screens).
- **CRITICAL** — `app_cliente/lib/features/perfil/perfil_screen.dart:131`: "Contraseña actual" field, `obscureText: true`, no toggle.
- **CRITICAL** — `app_cliente/lib/features/perfil/perfil_screen.dart:143`: "Nueva contraseña" field, `obscureText: true`, no toggle.
  - **Fix (all 4):** add a `suffixIcon: IconButton(icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility), onPressed: () => setState(() => _obscure = !_obscure))` bound to a per-field `bool _obscure` state, and pass `obscureText: _obscure`. This is the single most direct fix for the user's explicit complaint.
- **HIGH** — `register_screen.dart` has only one password field — no "confirm password" field. Combined with no visibility toggle, a user has literally zero way to verify what they typed before submitting.
- **LOW (positive)** — What does exist is solid: `login_screen.dart` and `register_screen.dart` both use `Form` + `AutovalidateMode.onUserInteraction`, inline validator error text, disabled-until-valid submit buttons (`_canSubmit`), and in-button loading spinners (`login_screen.dart:170-179`, `register_screen.dart:167-176`, `perfil_screen.dart:166-175`). This part of the form contract is genuinely well built — the missing toggle is the standout gap, not the whole form layer.

## Pillar 5 — Feedback & States

**Score: 6/10**

- **CRITICAL** — `app_cliente/lib/features/pedidos/menu_mesa_screen.dart:116-141`: the `data:` branch renders `ListView(children: [for (categoria in detalle.categorias) ExpansionTile(...)])` with **no `if (detalle.categorias.isEmpty)` guard**. If a restaurant's menu has zero categories (fresh restaurant, empty database, or a category-management bug on the admin side), this screen renders a **completely blank white body** — no message, no icon, no way to tell if it's broken or just empty. Contrast with the near-identical `restaurante_detalle_screen.dart:142-151`, which correctly shows `'Este restaurante aún no tiene menú'` for the exact same empty-categories case. The menu screen is the one place a blank list is most likely to be mistaken for a crash, since it's reached mid-flow (after scanning a table QR) rather than as a landing screen.
- **MEDIUM** — Empty-state polish is inconsistent across screens: `mis_reservas_screen.dart:62-77` and `pedido_estado_screen.dart:120-140` show emoji + heading + helper text + CTA button (good pattern), while `restaurantes_list_screen.dart:32-40` and `restaurante_detalle_screen.dart:142-151` show only a single centered gray `Text` with no icon or next-action guidance — same app, two different empty-state qualities.
- **LOW (positive)** — Loading (`CircularProgressIndicator`) and error states with a "Reintentar" retry button are consistently present across every `AsyncValue.when()` call site checked (`restaurantes_list_screen.dart`, `restaurante_detalle_screen.dart`, `mis_reservas_screen.dart`, `pedido_estado_screen.dart`). Double-submit protection is also handled correctly (`_sending`/`isLoading` guards disable buttons during in-flight requests in `menu_mesa_screen.dart:343`, `scan_screen.dart:219`, `pedido_estado_screen.dart:215`), and destructive actions (cancel reservation, `mis_reservas_screen.dart:241-263`) do get a confirmation dialog.

## Pillar 6 — Accessibility & Polish

**Score: 1/10**

- **HIGH** — `grep -rn "Semantics(" lib` returns **zero matches across all 68 files.** No screen has a single explicit accessibility label. Combined with icon-only controls (below), a screen-reader user cannot use most of this app.
- **HIGH** — Of 6 `IconButton` instances in the codebase, only **1** has a `tooltip` (`menu_mesa_screen.dart:233`, "Agregar {producto}"). The other 5 are unlabeled: quantity decrement/increment in the cart (`menu_mesa_screen.dart:238-256`) and all 5 star-rating buttons in `calificacion_sheet.dart:211-223`.
- **HIGH** — `app_cliente/lib/features/restaurantes/home_screen.dart:295-317` (`_QrButton`): `SizedBox(width: 45, height: 45)` wrapping the InkWell — this is the primary "scan a table" CTA on the home screen and it is **below the 48×48dp minimum recommended touch target**, and also has no `Semantics`/tooltip identifying it as "Scan QR" beyond a 📷 emoji glyph.
- **HIGH (professionalism)** — The app ships the **unmodified default Flutter template branding**: `android/app/src/main/res/mipmap-hdpi/ic_launcher.png` is 544 bytes (the stock Flutter logo asset, unchanged since `flutter create`), and `android/app/src/main/res/drawable/launch_background.xml` is the untouched template (`<item android:drawable="@android:color/white" />`, commented-out placeholder for a custom bitmap never filled in). There is no `flutter_launcher_icons` or `flutter_native_splash` dependency in `pubspec.yaml` at all — despite both being called out as recommended dependencies in this project's own tech-stack doc. First launch shows the generic Flutter logo, not GRI branding.
- **MEDIUM** — The UI leans on raw emoji characters (`🍽️`, `📷`, `📅`, `🪑`, `👥`, `⭐`, `📍`, `🧑‍🍳`, `📡`, `✓`) as its icon system — 38+ occurrences found by grep — instead of `Icon`/`IconData` from a consistent icon set. Emoji glyphs render inconsistently across OS/font versions, are not tinted/sized like `Icon`s, and are invisible to screen readers by default (no semantic meaning attached). This reads as a prototype/mockup aesthetic rather than a shipped product.
- **MEDIUM** — No text-scaling safeguard anywhere (`grep -rn "textScaler\|textScaleFactor" lib` → 0 hits). Fixed-size interactive elements with text/emoji inside them (`_QrButton` 45×45 fixed box with a 22px emoji `Text`, home_screen.dart:308-314; the star `IconButton`s at fixed `iconSize: 36`, calificacion_sheet.dart:221) are not verified against large system font-scale settings (e.g. Android "Largest" accessibility text size), where clipping/overflow is a real risk given the pattern already found in Pillar 1.

---

## Score Card

| Pillar | Score /10 | One-line verdict |
|---|---|---|
| 1. Layout & Responsive | **2/10** | Whole app hard-clamped to a fixed 480px column; zero real breakpoint logic; a live overflow bug exists in the reservation wizard. |
| 2. Visual Hierarchy & Spacing | **5/10** | Spacing is passably consistent but un-tokenized; typography hierarchy relies on font-size alone (only one font-weight, `bold`, used anywhere). |
| 3. Design System Consistency | **3/10** | Two separate, uncoordinated color systems for "status chips"; zero use of `ThemeData.textTheme`; ad hoc hex literals repeated 4-9× each instead of tokens. |
| 4. Forms & Input UX | **2/10** | 4/4 password fields have no show/hide toggle (the user's explicit complaint, fully reproduced); register has no confirm-password field. |
| 5. Feedback & States | **6/10** | Loading/error/retry patterns are solid and consistent, but one screen (`menu_mesa_screen`) renders a silent blank page on an empty menu. |
| 6. Accessibility & Polish | **1/10** | No `Semantics` anywhere in 68 files, 5/6 icon buttons unlabeled, sub-48dp primary CTA, and the app still ships the stock Flutter icon/splash. |

**Overall: 19/60** — well below a shippable bar. Every pillar has at least one CRITICAL or HIGH finding with direct file:line evidence; nothing here was scored on "the component exists."

---

## Top 10 fixes that would most raise perceived professionalism

1. **Add a show/hide toggle to all 4 password fields** (`login_screen.dart:144`, `register_screen.dart:142`, `perfil_screen.dart:131`, `perfil_screen.dart:143`) — directly resolves the user's explicit, named complaint; ~15 minutes per field.
2. **Fix the blank-screen bug in `menu_mesa_screen.dart:116-141`** by adding the same `if (detalle.categorias.isEmpty)` guard `restaurante_detalle_screen.dart` already has — prevents a scanned-table user from hitting a silent dead end.
3. **Wrap `_ResumenRow`'s value `Text` in `Expanded`/ellipsis** (`reserva_wizard_screen.dart:340-361`) to eliminate the live RenderFlex-overflow risk — this is the concrete "visual error" the user is describing.
4. **Replace the default Flutter launcher icon and white splash** with real GRI branding via `flutter_launcher_icons` + `flutter_native_splash` (already recommended in this project's own stack doc, never actually added to `pubspec.yaml`).
5. **Break the app out of the fixed `maxWidth: 480` clamp** (`app_shell.dart:31-35`) with real breakpoint handling (`LayoutBuilder`/`MediaQuery.sizeOf`) so tablets and landscape orientation get an adapted layout instead of a stranded phone-width column.
6. **Centralize color into one token file** — fold `models/pedido.dart:78-95`'s status palette into `GriColors`, and promote the 9×-repeated amber (`0xFFF5A623`) and 4×-repeated gradient colors into named tokens.
7. **Introduce `ThemeData.textTheme`** and replace the dozens of duplicated inline `TextStyle(fontWeight: FontWeight.bold, color: GriColors.text)` literals with theme-driven styles, adding at least one `w600`/medium weight for real hierarchy.
8. **Add tooltips/Semantics to the 5 unlabeled icon buttons** (cart qty +/− in `menu_mesa_screen.dart:238-256`, 5 star buttons in `calificacion_sheet.dart:211-223`) and to the QR scan button.
9. **Grow the QR scan button to ≥48×48dp** (`home_screen.dart:308-310`) — it is the primary "start ordering" action on the home screen.
10. **Add a confirm-password field to registration** and make `register_screen.dart`'s password field consistent with `login_screen.dart` (`autofillHints`).

---

## Files Audited

- `app_cliente/lib/app.dart`, `main.dart`
- `app_cliente/lib/core/theme.dart`
- `app_cliente/lib/features/auth/login_screen.dart`, `register_screen.dart`
- `app_cliente/lib/features/restaurantes/home_screen.dart`, `restaurantes_list_screen.dart`, `restaurante_detalle_screen.dart`
- `app_cliente/lib/features/pedidos/menu_mesa_screen.dart`, `pedido_estado_screen.dart`
- `app_cliente/lib/features/reservas/reserva_wizard_screen.dart`, `mis_reservas_screen.dart`
- `app_cliente/lib/features/perfil/perfil_screen.dart`
- `app_cliente/lib/features/sesion_qr/scan_screen.dart`
- `app_cliente/lib/features/pagos/calificacion_sheet.dart`
- `app_cliente/lib/features/shared/app_shell.dart`
- `app_cliente/lib/models/pedido.dart`
- `app_cliente/pubspec.yaml`
- `app_cliente/android/app/src/main/res/mipmap-*/ic_launcher.png`, `values/styles.xml`, `drawable/launch_background.xml`
- Repository-wide greps across all 68 `.dart` files in `app_cliente/lib` for: `obscureText`, `LayoutBuilder`/`MediaQuery`, `Semantics(`, `tooltip:`, `IconButton(`, `fontSize:`, `FontWeight.`, `Color(0x...)`, `textScaler`/`textScaleFactor`, fixed `width:`/`height:` literals.

No dev server was running during this audit (code-only, no screenshots).
