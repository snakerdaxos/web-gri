// lib/core/gri_icons.dart — mapa único de iconos semánticos del PANEL ADMIN
// (11-21).
//
// ╔══════════════════════════════════════════════════════════════════════════╗
// ║ GEMELO: `app_cliente/lib/core/gri_icons.dart` (plan 11-13).              ║
// ║ NO se sincronizan: las dos apps tienen vocabularios distintos (el panel  ║
// ║ habla de cocina, reportes y equipo; la del cliente, de descubrimiento y  ║
// ║ reservas). Los nombres que coinciden deben significar lo mismo, eso sí:  ║
// ║ `mesas`, `reservas`, `clientes` y `marca` valen aquí lo mismo que allí.  ║
// ╚══════════════════════════════════════════════════════════════════════════╝
//
// ── POR QUÉ EXISTE ────────────────────────────────────────────────────────
// Hasta 11-21 la iconografía del panel eran EMOJIS pintados como `Text`: los
// 8 ítems del sidebar, las 4 stat cards, las acciones de mesa, el botón de
// imprimir el QR, los estados vacíos… Un emoji no es un icono: su forma la
// decide la fuente del sistema operativo, así que el mismo panel se ve
// distinto en Windows, en macOS y en cada navegador, y algunos glifos
// modernos (`🪑`, `🪪`) ni siquiera existen en fuentes antiguas — donde
// salen como un rectángulo vacío. El usuario pidió expresamente sustituirlos
// (11-CONTEXT.md, «Emojis como iconos», 2026-08-19).
//
// ── CÓMO SE NOMBRAN ───────────────────────────────────────────────────────
// Por SIGNIFICADO, nunca por forma: `GriIcons.mesas`, no `GriIcons.silla`.
// Cambiar mañana de set de iconos toca UN archivo, no 12 pantallas.
//
// ── CÓMO SE AÑADE UNO NUEVO ───────────────────────────────────────────────
// 1. Se declara aquí, con su significado en el doc comment.
// 2. En la pantalla se usa SIEMPRE `Icon(GriIcons.x, ...)`, nunca un
//    `Icons.x` suelto.
// 3. Con `semanticLabel` cuando el icono NO va acompañado de texto visible
//    (es lo que consume el plan 11-14 de accesibilidad).
// 4. Se añade su fila a `docs/ICONOS-panel_admin.md`.
//
// ── LO QUE ESTE ARCHIVO NO DECIDE ─────────────────────────────────────────
// Ni el tamaño ni el color. El `size` lo pone el punto de uso y debe IGUALAR
// el `fontSize` del `Text` que sustituyó (mitigación de T-11-21-05); el color
// sale de `GriColors` o del `IconTheme`, jamás de un literal nuevo.
import 'package:flutter/material.dart';

abstract final class GriIcons {
  // ── Los 8 ítems del sidebar ─────────────────────────────────────────────
  /// Dashboard. Antes `🏠`.
  static const IconData dashboard = Icons.home_outlined;

  /// Mesas del local (sidebar, mapa de mesas, acciones). Antes `🪑`.
  static const IconData mesas = Icons.table_restaurant_outlined;

  /// Pedidos / cola de cocina. Antes `📋`.
  static const IconData pedidos = Icons.receipt_long_outlined;

  /// Reservas y, en general, cualquier fecha. Antes `📅`.
  static const IconData reservas = Icons.calendar_today_outlined;

  /// Clientes y, en general, un grupo de personas (comensales de una mesa).
  /// Antes `👥`.
  static const IconData clientes = Icons.people_outline;

  /// Reportes de ventas. Antes `📊`.
  static const IconData reportes = Icons.bar_chart;

  /// Equipo / personal con acceso al panel. Antes `🪪`.
  static const IconData equipo = Icons.badge_outlined;

  /// Configuración. Antes `⚙️`.
  static const IconData configuracion = Icons.settings_outlined;

  // ── Dominio ─────────────────────────────────────────────────────────────
  /// Marca GRI y, por extensión, «un plato»: badge del logo, pedido de una
  /// mesa, aviso de cuenta. Antes `🍽️`.
  static const IconData marca = Icons.restaurant;

  /// Un restaurante como entidad de la plataforma. Antes `🏪`.
  static const IconData restaurante = Icons.storefront_outlined;

  /// Ver el código QR de una mesa. Antes `📷` (que era la CÁMARA, no el QR —
  /// el panel GENERA el QR, no lo escanea: la sustitución corrige además el
  /// significado).
  static const IconData verQr = Icons.qr_code_2;

  /// Imprimir. Antes `🖨️`.
  static const IconData imprimir = Icons.print_outlined;

  /// Editar. Antes `✏️`.
  static const IconData editar = Icons.edit_outlined;

  /// Notas que el cliente dejó en un pedido. Antes `📝`.
  static const IconData notas = Icons.edit_note;

  /// Dinero vendido en el rango consultado. Antes `💵`.
  static const IconData ventas = Icons.payments_outlined;

  /// Ticket / número de pedidos. Antes `🧾`.
  static const IconData ticket = Icons.receipt_outlined;

  /// Aviso EN LA INTERFAZ (nunca en un comentario). Antes `⚠️`.
  static const IconData aviso = Icons.warning_amber_outlined;

  /// Ruta que no existe (pantalla 404). Antes `🧭`, escrito como
  /// `'\u{1F9ED}'` — un emoji camuflado de secuencia de escape, que ningún
  /// `grep` de glifos encontraba.
  static const IconData rutaDesconocida = Icons.explore_outlined;

  /// «El control está arriba»: la guía que manda usar el selector de
  /// restaurante del topbar. Antes `👇`, que apuntaba hacia ABAJO a un
  /// control que está ARRIBA.
  static const IconData selectorArriba = Icons.arrow_upward;

  /// Nada que hacer / bandeja vacía en cocina. Antes `🎉`.
  static const IconData todoAlDia = Icons.celebration_outlined;
}
