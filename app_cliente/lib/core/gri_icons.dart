// lib/core/gri_icons.dart — mapa único de iconos semánticos de la APP CLIENTE
// (11-13).
//
// ╔══════════════════════════════════════════════════════════════════════════╗
// ║ GEMELO: `panel_admin/lib/core/gri_icons.dart` (plan 11-21).              ║
// ║ NO se sincronizan: las dos apps tienen vocabularios distintos (el panel  ║
// ║ habla de cocina, reportes y equipo; ésta de descubrimiento y reservas).  ║
// ║ Los nombres que coinciden deben significar lo mismo, eso sí.             ║
// ╚══════════════════════════════════════════════════════════════════════════╝
//
// ── POR QUÉ EXISTE ────────────────────────────────────────────────────────
// Hasta 11-13 la iconografía de esta app eran EMOJIS pintados como `Text`
// (`🏠 🔍 📅 👤` en la barra inferior, `🍽️` como marca, `⭐` en la
// calificación…). Un emoji no es un icono: su forma la decide la fuente del
// sistema, así que cambia entre Android, iOS y cada navegador, y puede
// faltar. El usuario pidió expresamente sustituirlos (11-CONTEXT, «Emojis
// como iconos», 2026-08-19).
//
// ── CÓMO SE NOMBRAN ───────────────────────────────────────────────────────
// Por SIGNIFICADO, nunca por forma. `GriIcons.mesa`, no `GriIcons.silla`.
// Así, cambiar mañana el set de iconos (o pasar a uno propio) toca UN archivo
// y no las 15 pantallas.
//
// ── CÓMO SE AÑADE UNO NUEVO ───────────────────────────────────────────────
// 1. Se declara aquí, con su significado en el doc comment.
// 2. En la pantalla se usa SIEMPRE `Icon(GriIcons.x, ...)`, nunca un
//    `Icons.x` suelto.
// 3. Con `semanticLabel` cuando el icono NO va acompañado de texto visible
//    (es lo que consume el plan 11-14 de accesibilidad).
// 4. Se añade su fila a `docs/ICONOS-app_cliente.md`.
//
// ── LO QUE ESTE ARCHIVO NO DECIDE ─────────────────────────────────────────
// Ni el tamaño ni el color. El `size` lo pone el punto de uso y debe IGUALAR
// el `fontSize` del `Text` que sustituyó (regla del plan 11-13, mitigación de
// T-11-13-05); el color sale de `GriColors` o del `IconTheme`, jamás de un
// literal nuevo.
import 'package:flutter/material.dart';

abstract final class GriIcons {
  // ── Navegación principal (los 4 tabs) ───────────────────────────────────
  /// Tab «Inicio». Antes `🏠`.
  static const IconData inicio = Icons.home_outlined;

  /// Tab «Restaurantes» — descubrir/buscar. Antes `🔍`.
  static const IconData buscar = Icons.search;

  /// Tab «Reservas» y todo lo que sea una fecha. Antes `📅`.
  static const IconData reservas = Icons.calendar_today_outlined;

  /// Tab «Perfil». Antes `👤`.
  static const IconData perfil = Icons.person_outline;

  // ── Dominio ─────────────────────────────────────────────────────────────
  /// Marca GRI, restaurante, plato, «no hay restaurantes». Antes `🍽️`.
  static const IconData menu = Icons.restaurant;

  /// Mesa física del local. Antes `🪑`.
  static const IconData mesa = Icons.table_restaurant_outlined;

  /// Comensales de una reserva. Antes `👥`.
  static const IconData personas = Icons.people_outline;

  /// Calificación del restaurante. Antes `⭐`.
  static const IconData calificacion = Icons.star;

  /// Escanear el QR de la mesa. Antes `📷` — y `qr_code_scanner` dice lo que
  /// el botón HACE, que no es «hacer una foto».
  static const IconData escanearQr = Icons.qr_code_scanner;

  /// Dirección / ubicación del restaurante. Antes `📍`.
  static const IconData direccion = Icons.place_outlined;

  /// Resumen del pedido / cuenta. Antes `📋`.
  static const IconData resumenPedido = Icons.receipt_long_outlined;

  // ── Estados ─────────────────────────────────────────────────────────────
  /// Confirmación de una acción ya hecha («Cuenta solicitada»). Antes `✓`.
  static const IconData confirmado = Icons.check;

  /// Aviso EN LA INTERFAZ (no el `⚠️` de los comentarios, que se queda).
  static const IconData aviso = Icons.warning_amber_outlined;

  /// La cocina está preparando el pedido. Antes `🧑‍🍳`.
  static const IconData cocinando = Icons.soup_kitchen_outlined;

  /// Seguimiento en vivo (stream abierto). Antes `📡`.
  static const IconData enVivo = Icons.sensors;
}
