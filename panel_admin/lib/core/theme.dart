import 'package:flutter/material.dart';

import '../models/mesa.dart';
import '../models/pedido_staff.dart';
import 'design_tokens.dart';

/// Paleta EXACTA del mockup `documentos/index.html` (:root vars).
///
/// Fuente única de verdad visual para TODO el panel — Phase 8 debe reutilizar
/// estas constantes, nunca re-descubrirlas del mockup.
///
/// NOTA: los hex del plan venían como 6 dígitos (`0xff4c05`), que en Dart es
/// alpha=0x00 (transparente). Aquí van con alpha opaco `0xFF…` (desviación
/// Rule 1 documentada en 04-02-SUMMARY.md).
class GriColors {
  GriColors._();

  // ── App chrome ──────────────────────────────────────────────────────────
  /// #ff4c05 — botones, active menu, avatar bg, logo icon bg.
  static const Color primary = Color(0xFFFF4C05);

  /// #d93d00 — hover de botones/acciones primarias.
  static const Color primaryDark = Color(0xFFD93D00);

  /// #f5f6f8 — fondo de página.
  static const Color background = Color(0xFFF5F6F8);

  /// #1f2329 — barra lateral.
  static const Color sidebar = Color(0xFF1F2329);

  /// #252525 — texto principal.
  static const Color text = Color(0xFF252525);

  /// #777777 — token de MARCA del mockup.
  ///
  /// ⚠ NO se usa como color de TEXTO: sobre blanco da 4.478:1 y sobre el
  /// fondo del panel (#F5F6F8) 4.141:1, los dos por debajo del 4.5:1 que
  /// WCAG AA exige para texto normal. Se queda para iconos, bordes y
  /// decoración, donde ese umbral no aplica. Para texto secundario está
  /// [textoSecundarioAccesible]. Hay un gate estático que lo vigila
  /// (`test/a11y/a11y_test.dart`) y un test que afirma que este valor no
  /// cambia: es una decisión BLOQUEADA del usuario.
  static const Color gray = Color(0xFF777777);

  /// #6E6E6E — el gris de TEXTO secundario del panel (5.099:1 sobre blanco,
  /// 4.715:1 sobre #F5F6F8).
  ///
  /// Lo declaró el plan 11-11 como campo de instancia de
  /// [GriSemanticColors]; 11-25 lo añade también aquí porque la mayoría de
  /// los puntos de uso son `const TextStyle`, donde un campo de instancia no
  /// se puede leer. UN SOLO valor con dos caminos de acceso: la extensión
  /// referencia esta constante y un test afirma la igualdad.
  static const Color textoSecundarioAccesible = Color(0xFF6E6E6E);

  // ── Mesa: disponible (verde) ────────────────────────────────────────────
  static const Color mesaDisponibleBg = Color(0xFFE7F8F0);
  static const Color mesaDisponibleFg = Color(0xFF168A52);
  static const Color mesaDisponibleDot = Color(0xFF20B26B);

  // ── Mesa: ocupada (rojo) ────────────────────────────────────────────────
  static const Color mesaOcupadaBg = Color(0xFFFFE9E6);
  static const Color mesaOcupadaFg = Color(0xFFC83C2E);
  static const Color mesaOcupadaDot = Color(0xFFE74C3C);

  // ── Mesa: reservada (amarillo) ──────────────────────────────────────────
  static const Color mesaReservadaBg = Color(0xFFFFF5D8);
  static const Color mesaReservadaFg = Color(0xFFAA7A00);
  static const Color mesaReservadaDot = Color(0xFFF5B82E);

  // ── Mesa: limpieza (azul) ───────────────────────────────────────────────
  static const Color mesaLimpiezaBg = Color(0xFFE9F0FF);
  static const Color mesaLimpiezaFg = Color(0xFF3167C9);
  static const Color mesaLimpiezaDot = Color(0xFF3478F6);

  // ── Stat card icon backgrounds (tint del dot) ───────────────────────────
  static const Color statIconDisponibleBg = Color(0xFFE7F8F0);
  static const Color statIconOcupadaBg = Color(0xFFFFF0E9);
  static const Color statIconReservasBg = Color(0xFFFFF7DF);
  static const Color statIconPedidosBg = Color(0xFFE9F0FF);

  // ══ AÑADIDO EN 11-12 ═════════════════════════════════════════════════════
  // Los literales que vivían sueltos en `lib/features/**` y en
  // `lib/models/pedido_staff.dart`. NINGÚN valor cambia: cada constante lleva
  // el MISMO hex que sustituye y el `archivo:línea` de donde salió.
  // El gate `test/core/sin_hex_crudos_test.dart` impide que vuelvan.

  // ── Chrome del shell (sidebar + topbar) ─────────────────────────────────
  /// #EEEEEE — la línea que separa el topbar del contenido
  /// (`features/shared/app_shell.dart:105`).
  ///
  /// Coincide HOY en valor con [imagenPlaceholderBg], pero son dos roles
  /// distintos y se declaran por separado a propósito: cambiar el color de un
  /// separador no debe arrastrar el fondo de una imagen rota.
  static const Color divider = Color(0xFFEEEEEE);

  /// #AAAAAA — subtítulo «Gestión de Restaurante» bajo el logo del sidebar
  /// (`features/shared/app_shell.dart:258`). Sobre [sidebar] (#1F2329).
  static const Color sidebarSubtitulo = Color(0xFFAAAAAA);

  /// #CCCCCC — texto e icono de un ítem del menú lateral NO activo
  /// (`features/shared/app_shell.dart:314`). El activo es blanco sobre
  /// [primary].
  static const Color sidebarItemInactivo = Color(0xFFCCCCCC);

  // ── Badges del menú (categorías y productos) ─────────────────────────────
  /// #E65100 — badge «Inactiva» de una categoría con soft-delete
  /// (`features/menu/menu_screen.dart:152`).
  static const Color badgeCategoriaInactiva = Color(0xFFE65100);

  /// #E65100 — texto e icono de una advertencia destructiva en un formulario
  /// («cambiar el número regenera el QR», `features/mesas/mesa_form_dialog.dart:241,249`).
  ///
  /// Mismo valor que [badgeCategoriaInactiva] y distinto significado: uno
  /// etiqueta un estado del dato, el otro avisa de una consecuencia.
  static const Color advertencia = Color(0xFFE65100);

  /// #FF8F00 — badge «Agotado» (ámbar, estado TRANSITORIO de un producto:
  /// `disponible == false`). `features/menu/menu_screen.dart:205`.
  static const Color badgeAgotado = Color(0xFFFF8F00);

  /// #9E9E9E — badge «Inactivo» (gris, soft-delete de un producto:
  /// `activo == false` — semántica DISTINTA a agotado).
  /// `features/menu/menu_screen.dart:208`.
  static const Color badgeInactivo = Color(0xFF9E9E9E);

  // ── Recuadros y placeholders ────────────────────────────────────────────
  /// #EEEEEE — fondo del placeholder de una imagen de producto que no carga
  /// (`features/menu/producto_form_dialog.dart:238`).
  static const Color imagenPlaceholderBg = Color(0xFFEEEEEE);

  /// #E8F0FE — tinte azul del recuadro del icono de una tarjeta de reporte
  /// (`features/reportes/reportes_screen.dart:385`).
  static const Color reporteIconoBg = Color(0xFFE8F0FE);

  /// #3478F6 — icono dentro de [reporteIconoBg]
  /// (`features/reportes/reportes_screen.dart:391`).
  ///
  /// Mismo valor que [mesaLimpiezaDot] y que [GriSemanticColors.pedidoEnviado];
  /// se declara aparte porque un reporte no es una mesa ni un pedido.
  static const Color reporteIconoFg = Color(0xFF3478F6);

  // ── Dominio: estado de pedido ───────────────────────────────────────────
  /// #8E44AD — morado de `en_preparacion`. Único color de estado de pedido
  /// del panel que no coincide con otro token
  /// (venía suelto en `models/pedido_staff.dart:183`).
  static const Color pedidoEnPreparacion = Color(0xFF8E44AD);
}

/// Fondo del tile según [EstadoMesa] — switch exhaustivo sobre los 4 estados
/// (defensa pixel-perfect del ADMN-02). Tile disponible: #e7f8f0.
Color mesaTileBg(EstadoMesa e) => switch (e) {
      EstadoMesa.disponible => GriColors.mesaDisponibleBg,
      EstadoMesa.ocupada => GriColors.mesaOcupadaBg,
      EstadoMesa.reservada => GriColors.mesaReservadaBg,
      EstadoMesa.limpieza => GriColors.mesaLimpiezaBg,
    };

/// Texto del tile según [EstadoMesa].
Color mesaTileFg(EstadoMesa e) => switch (e) {
      EstadoMesa.disponible => GriColors.mesaDisponibleFg,
      EstadoMesa.ocupada => GriColors.mesaOcupadaFg,
      EstadoMesa.reservada => GriColors.mesaReservadaFg,
      EstadoMesa.limpieza => GriColors.mesaLimpiezaFg,
    };

/// Dot/indicador del estado según [EstadoMesa] (leyenda + stat icons).
Color mesaDot(EstadoMesa e) => switch (e) {
      EstadoMesa.disponible => GriColors.mesaDisponibleDot,
      EstadoMesa.ocupada => GriColors.mesaOcupadaDot,
      EstadoMesa.reservada => GriColors.mesaReservadaDot,
      EstadoMesa.limpieza => GriColors.mesaLimpiezaDot,
    };

/// Colores SEMÁNTICOS de dominio del panel — estado de pedido y estado de
/// reserva.
///
/// POR QUÉ EXISTE (11-11). Los colores de dominio estaban repartidos entre
/// `models/pedido_staff.dart:180-187` (los del pedido) y la paleta de mesas
/// de [GriColors] (los del chip de reserva). Esta extensión les da un sitio
/// único en el tema; 11-12 sustituye los puntos de uso.
///
/// NINGÚN valor cambia respecto a lo que había: los hex se copiaron
/// literalmente (la identidad visual es una decisión BLOQUEADA de la fase 11).
///
/// ⚠ HALLAZGO de 11-11 documentado a propósito: el panel y la app cliente
/// pintan el MISMO estado de pedido con colores DISTINTOS (`enviado` #3478F6
/// aquí vs #2563EB en el cliente; `aceptado` #FF4C05 vs #D97706;
/// `en_preparacion` #8E44AD vs #7C3AED). Unificarlos cambiaría píxeles en una
/// de las dos apps, así que queda fuera de este plan — pero ya no está
/// escondido en dos modelos distintos.
@immutable
class GriSemanticColors extends ThemeExtension<GriSemanticColors> {
  const GriSemanticColors({
    required this.pedidoEnviado,
    required this.pedidoAceptado,
    required this.pedidoEnPreparacion,
    required this.pedidoServido,
    required this.pedidoRechazado,
    required this.pedidoPagado,
    required this.reservaConfirmadaFg,
    required this.reservaConfirmadaBg,
    required this.reservaCanceladaFg,
    required this.reservaCanceladaBg,
    required this.reservaPendienteFg,
    required this.reservaPendienteBg,
    required this.peligro,
    required this.textoSecundarioAccesible,
  });

  // ── Estado de pedido (el chip deriva su fondo con alpha 0.12) ───────────
  /// #3478F6 — azul de `enviado` (== [GriColors.mesaLimpiezaDot]).
  final Color pedidoEnviado;

  /// #FF4C05 — naranja de marca para `aceptado` (== [GriColors.primary]).
  final Color pedidoAceptado;

  /// #8E44AD — morado de `en_preparacion` (== [GriColors.pedidoEnPreparacion],
  /// que 11-12 promovió desde el literal suelto de `pedido_staff.dart:183`).
  final Color pedidoEnPreparacion;

  /// #20B26B — verde de `servido` (== [GriColors.mesaDisponibleDot]).
  final Color pedidoServido;

  /// #E74C3C — rojo de `rechazado` (== [GriColors.mesaOcupadaDot]).
  final Color pedidoRechazado;

  /// #20B26B — `pagado` comparte el verde de `servido`, como hoy.
  final Color pedidoPagado;

  // ── Estado de reserva (reutiliza la paleta de mesas, como hoy) ──────────
  final Color reservaConfirmadaFg;
  final Color reservaConfirmadaBg;
  final Color reservaCanceladaFg;
  final Color reservaCanceladaBg;
  final Color reservaPendienteFg;
  final Color reservaPendienteBg;

  // ── Comunes ─────────────────────────────────────────────────────────────
  /// #F44336 — rojo de acción destructiva. Es EXACTAMENTE el valor de
  /// `Colors.red`, que es lo que hoy usan los "Eliminar"/"Desactivar" de los
  /// diálogos.
  ///
  /// Se declara como `Color` plano y NO como `Colors.red`: `Colors.red` es un
  /// `MaterialColor`, y `Color.lerp` devuelve siempre un `Color` plano, así
  /// que con el `MaterialColor` dentro `lerp(otro, 0)` dejaba de ser igual a
  /// `this` — `Color.==` compara también el `runtimeType`. El contrato de
  /// `ThemeExtension` se rompía por eso. (Descubierto por el test de `lerp`
  /// en 11-11.) El render es idéntico: mismo ARGB.
  final Color peligro;

  /// #6E6E6E — gris de texto secundario que SÍ alcanza 4.5:1 sobre los dos
  /// fondos del panel (5.099:1 sobre blanco, 4.715:1 sobre #F5F6F8).
  ///
  /// APLICADO desde 11-25 en todo el texto secundario del panel. Existe para
  /// que ese arreglo NO tenga que tocar [GriColors.gray] (#777777), que es un
  /// token de MARCA y no puede cambiar de valor. El valor vive en
  /// [GriColors.textoSecundarioAccesible]; este campo lo referencia.
  final Color textoSecundarioAccesible;

  /// La instancia canónica de GRI. Es la que registra [griTheme] y la que
  /// devuelve [of] cuando el tema no trae ninguna.
  static const GriSemanticColors gri = GriSemanticColors(
    pedidoEnviado: GriColors.mesaLimpiezaDot,
    pedidoAceptado: GriColors.primary,
    pedidoEnPreparacion: GriColors.pedidoEnPreparacion,
    pedidoServido: GriColors.mesaDisponibleDot,
    pedidoRechazado: GriColors.mesaOcupadaDot,
    pedidoPagado: GriColors.mesaDisponibleDot,
    reservaConfirmadaFg: GriColors.mesaDisponibleFg,
    reservaConfirmadaBg: GriColors.mesaDisponibleBg,
    reservaCanceladaFg: GriColors.mesaOcupadaFg,
    reservaCanceladaBg: GriColors.mesaOcupadaBg,
    reservaPendienteFg: GriColors.mesaReservadaFg,
    reservaPendienteBg: GriColors.mesaReservadaBg,
    peligro: Color(0xFFF44336),
    textoSecundarioAccesible: GriColors.textoSecundarioAccesible,
  );

  /// Lee la extensión del tema. Cae a [gri] si no está registrada.
  static GriSemanticColors of(BuildContext context) =>
      Theme.of(context).extension<GriSemanticColors>() ?? gri;

  /// Color del chip según el estado del pedido.
  Color pedido(EstadoPedido e) => switch (e) {
        EstadoPedido.enviado => pedidoEnviado,
        EstadoPedido.aceptado => pedidoAceptado,
        EstadoPedido.enPreparacion => pedidoEnPreparacion,
        EstadoPedido.servido => pedidoServido,
        EstadoPedido.rechazado => pedidoRechazado,
        EstadoPedido.pagado => pedidoPagado,
      };

  /// Color del TEXTO del chip según el estado de la reserva. El comodín es
  /// `pendiente`, igual que hoy en `reservas_screen.dart:249`.
  Color reservaFg(String estado) => switch (estado) {
        'confirmada' => reservaConfirmadaFg,
        'cancelada' => reservaCanceladaFg,
        _ => reservaPendienteFg,
      };

  /// Fondo del chip según el estado de la reserva.
  Color reservaBg(String estado) => switch (estado) {
        'confirmada' => reservaConfirmadaBg,
        'cancelada' => reservaCanceladaBg,
        _ => reservaPendienteBg,
      };

  @override
  GriSemanticColors copyWith({
    Color? pedidoEnviado,
    Color? pedidoAceptado,
    Color? pedidoEnPreparacion,
    Color? pedidoServido,
    Color? pedidoRechazado,
    Color? pedidoPagado,
    Color? reservaConfirmadaFg,
    Color? reservaConfirmadaBg,
    Color? reservaCanceladaFg,
    Color? reservaCanceladaBg,
    Color? reservaPendienteFg,
    Color? reservaPendienteBg,
    Color? peligro,
    Color? textoSecundarioAccesible,
  }) {
    return GriSemanticColors(
      pedidoEnviado: pedidoEnviado ?? this.pedidoEnviado,
      pedidoAceptado: pedidoAceptado ?? this.pedidoAceptado,
      pedidoEnPreparacion: pedidoEnPreparacion ?? this.pedidoEnPreparacion,
      pedidoServido: pedidoServido ?? this.pedidoServido,
      pedidoRechazado: pedidoRechazado ?? this.pedidoRechazado,
      pedidoPagado: pedidoPagado ?? this.pedidoPagado,
      reservaConfirmadaFg: reservaConfirmadaFg ?? this.reservaConfirmadaFg,
      reservaConfirmadaBg: reservaConfirmadaBg ?? this.reservaConfirmadaBg,
      reservaCanceladaFg: reservaCanceladaFg ?? this.reservaCanceladaFg,
      reservaCanceladaBg: reservaCanceladaBg ?? this.reservaCanceladaBg,
      reservaPendienteFg: reservaPendienteFg ?? this.reservaPendienteFg,
      reservaPendienteBg: reservaPendienteBg ?? this.reservaPendienteBg,
      peligro: peligro ?? this.peligro,
      textoSecundarioAccesible:
          textoSecundarioAccesible ?? this.textoSecundarioAccesible,
    );
  }

  @override
  GriSemanticColors lerp(ThemeExtension<GriSemanticColors>? other, double t) {
    if (other is! GriSemanticColors) return this;
    return GriSemanticColors(
      pedidoEnviado: Color.lerp(pedidoEnviado, other.pedidoEnviado, t)!,
      pedidoAceptado: Color.lerp(pedidoAceptado, other.pedidoAceptado, t)!,
      pedidoEnPreparacion:
          Color.lerp(pedidoEnPreparacion, other.pedidoEnPreparacion, t)!,
      pedidoServido: Color.lerp(pedidoServido, other.pedidoServido, t)!,
      pedidoRechazado: Color.lerp(pedidoRechazado, other.pedidoRechazado, t)!,
      pedidoPagado: Color.lerp(pedidoPagado, other.pedidoPagado, t)!,
      reservaConfirmadaFg:
          Color.lerp(reservaConfirmadaFg, other.reservaConfirmadaFg, t)!,
      reservaConfirmadaBg:
          Color.lerp(reservaConfirmadaBg, other.reservaConfirmadaBg, t)!,
      reservaCanceladaFg:
          Color.lerp(reservaCanceladaFg, other.reservaCanceladaFg, t)!,
      reservaCanceladaBg:
          Color.lerp(reservaCanceladaBg, other.reservaCanceladaBg, t)!,
      reservaPendienteFg:
          Color.lerp(reservaPendienteFg, other.reservaPendienteFg, t)!,
      reservaPendienteBg:
          Color.lerp(reservaPendienteBg, other.reservaPendienteBg, t)!,
      peligro: Color.lerp(peligro, other.peligro, t)!,
      textoSecundarioAccesible: Color.lerp(
          textoSecundarioAccesible, other.textoSecundarioAccesible, t)!,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GriSemanticColors &&
          other.pedidoEnviado == pedidoEnviado &&
          other.pedidoAceptado == pedidoAceptado &&
          other.pedidoEnPreparacion == pedidoEnPreparacion &&
          other.pedidoServido == pedidoServido &&
          other.pedidoRechazado == pedidoRechazado &&
          other.pedidoPagado == pedidoPagado &&
          other.reservaConfirmadaFg == reservaConfirmadaFg &&
          other.reservaConfirmadaBg == reservaConfirmadaBg &&
          other.reservaCanceladaFg == reservaCanceladaFg &&
          other.reservaCanceladaBg == reservaCanceladaBg &&
          other.reservaPendienteFg == reservaPendienteFg &&
          other.reservaPendienteBg == reservaPendienteBg &&
          other.peligro == peligro &&
          other.textoSecundarioAccesible == textoSecundarioAccesible;

  @override
  int get hashCode => Object.hashAll(<Object>[
        pedidoEnviado,
        pedidoAceptado,
        pedidoEnPreparacion,
        pedidoServido,
        pedidoRechazado,
        pedidoPagado,
        reservaConfirmadaFg,
        reservaConfirmadaBg,
        reservaCanceladaFg,
        reservaCanceladaBg,
        reservaPendienteFg,
        reservaPendienteBg,
        peligro,
        textoSecundarioAccesible,
      ]);
}

/// Escala tipográfica DECLARADA del tema.
///
/// ── Por qué lleva los valores de Material 3 y no los 24-bold de GRI ───────
/// Estos slots NO son un catálogo libre: los consume el chrome del framework.
/// Medido con una sonda contra el tema anterior a 11-11: `headlineSmall` es el
/// título de los 8 `AlertDialog` del panel, `bodyLarge` el título de los
/// `ListTile`, `bodyMedium` el `Text` sin estilo y el contenido de los
/// diálogos, `labelLarge` la etiqueta de TODOS los botones, `titleMedium` el
/// del `DropdownButton` del shell. Meter aquí los 24-bold / 18-bold que GRI
/// usa inline cambiaría el tamaño y el peso de ese chrome — un cambio visual,
/// prohibido por la decisión BLOQUEADA de la fase.
///
/// Declararlos explícitamente sí aporta: dejan de ser un default implícito
/// del framework, así que una actualización de Flutter que cambie la
/// tipografía de M3 ya no puede reflotar el panel en silencio, y 11-12 tiene
/// un objetivo estable al que migrar los `fontSize: 16/14/13/12` inline.
///
/// La escala PROPIA de GRI vive en `GriText`, en `core/design_tokens.dart`.
const TextTheme griTextTheme = TextTheme(
  displayLarge: TextStyle(fontSize: 57, fontWeight: FontWeight.w400),
  displayMedium: TextStyle(fontSize: 45, fontWeight: FontWeight.w400),
  displaySmall: TextStyle(fontSize: 36, fontWeight: FontWeight.w400),
  headlineLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.w400),
  headlineMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.w400),
  headlineSmall: TextStyle(fontSize: 24, fontWeight: FontWeight.w400),
  titleLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.w400),
  titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
  titleSmall: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
  bodyLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w400),
  bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w400),
  bodySmall: TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
  labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
  labelMedium: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
  labelSmall: TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
);

/// La decoración de tarjeta del panel — blanco, radio 15 y la sombra sutil
/// del mockup.
///
/// El `BoxShadow(Color(0x0D000000), blurRadius: 12, offset: Offset(0, 3))`
/// estaba copiado en SIETE sitios (`stat_card.dart:39`,
/// `dashboard_screen.dart:134` y `:310`, `reportes_screen.dart:351`,
/// `cocina/widgets/pedido_card.dart:47`, y en `login_screen.dart:92` /
/// `bootstrap_screen.dart:130` bajo la forma equivalente
/// `Colors.black.withValues(alpha: 0.05)` — 0.05×255 = 12.75 → 13 = 0x0D).
/// Este plan lo DECLARA una vez; el plan 11-12 borra las copias.
const BoxDecoration griCardDecoration = BoxDecoration(
  color: Colors.white,
  borderRadius: GriRadius.cardBorder,
  boxShadow: <BoxShadow>[
    BoxShadow(
      color: Color(0x0D000000), // rgba(0,0,0,0.05)
      blurRadius: 12,
      offset: Offset(0, 3),
    ),
  ],
);

/// El estilo COMPLETO del botón primario a ancho completo, tal como está hoy
/// copiado en `login_screen.dart:153` y `bootstrap_screen.dart:245`
/// (colores + el par de deshabilitado; el padding y el `textStyle` siguen en
/// cada pantalla porque solo los usan esas dos).
///
/// El par de colores DESHABILITADOS no va en `elevatedButtonTheme` a
/// propósito: solo lo declaran 4 de los 12 `ElevatedButton` del panel, y
/// meterlo en el tema cambiaría el aspecto deshabilitado de los botones de
/// acción de cocina, que hoy usan el gris por defecto de Material.
final ButtonStyle griBotonPrimario = ElevatedButton.styleFrom(
  backgroundColor: GriColors.primary,
  foregroundColor: Colors.white,
  disabledBackgroundColor: GriColors.primary.withValues(alpha: 0.4),
  disabledForegroundColor: Colors.white70,
);

/// Variante DESTRUCTIVA de `TextButton` — el `foregroundColor: Colors.red` de
/// los "Eliminar"/"Desactivar" de `configuracion_screen.dart:245` y
/// `mesa_form_dialog.dart:168` y `:247`.
final ButtonStyle griBotonPeligroTexto =
    TextButton.styleFrom(foregroundColor: GriSemanticColors.gri.peligro);

/// Variante DESTRUCTIVA de `OutlinedButton` — el "Rechazar" de
/// `cocina/widgets/pedido_card.dart:171`.
final ButtonStyle griBotonPeligroContorno = OutlinedButton.styleFrom(
  foregroundColor: GriColors.mesaOcupadaFg,
  side: const BorderSide(color: GriColors.mesaOcupadaDot),
);

/// El `InputDecoration` de borde perfilado que hoy declaran 4 pantallas
/// (`login_screen.dart:132`, `bootstrap_screen.dart:178` y `:193`,
/// `shared/password_field.dart:70`).
///
/// ⚠ NO se registra como `inputDecorationTheme` en [griTheme], y es
/// deliberado: los otros 12 campos del panel (todos los diálogos de menú,
/// mesas y restaurantes) NO declaran `border`, así que hoy pintan el
/// subrayado por defecto de Material 3. Registrarlo les cambiaría la
/// GEOMETRÍA — borde y `contentPadding` —, que es un cambio visual prohibido
/// por la decisión BLOQUEADA de la fase. Se nombra aquí para que 11-12 pueda
/// referenciarlo sin decidir por los otros 12.
const InputDecorationTheme griInputOutline = InputDecorationTheme(
  border: OutlineInputBorder(),
);

/// [ThemeData] del panel — card radius 15 + shadow sutil, fondo #f5f6f8,
/// seed naranja #ff4c05 (Material 3).
///
/// ── Qué se centraliza aquí y qué NO (11-11) ──────────────────────────────
/// SÍ `elevatedButtonTheme`: 10 de los 12 `ElevatedButton` del panel ya
/// declaran inline exactamente `backgroundColor: primary` +
/// `foregroundColor: white`. Es una convención real, así que el tema la
/// asume. Efecto medido: los 2 que NO lo declaraban
/// (`reportes_screen.dart:140` "Consultar" y `reservas_screen.dart:221`
/// "Marcar ocupada") pasan de #FFF1ED sobre #8F4C37 —el derivado del seed,
/// que NO es la marca— al naranja de GRI, igual que los otros 10.
///
/// NO `textButtonTheme`, `outlinedButtonTheme` ni `inputDecorationTheme`: no
/// hay convención que centralizar (0 de 26 `TextButton` declaran estilo base;
/// los 2 que llevan `style` son la variante destructiva) y registrarlos
/// cambiaría color o geometría en decenas de sitios. Los estilos con nombre
/// de arriba cubren esos casos sin tocar el render. Hay un test que afirma
/// esta ausencia, para que nadie los añada por descuido.
final ThemeData griTheme = ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.fromSeed(seedColor: GriColors.primary),
  scaffoldBackgroundColor: GriColors.background,
  textTheme: griTextTheme,
  extensions: const <ThemeExtension<dynamic>>[GriSemanticColors.gri],
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: GriColors.primary,
      foregroundColor: Colors.white,
    ),
  ),
  // SÍ `floatingActionButtonTheme` (11-12): el panel tiene UN solo FAB
  // (`features/mesas/mesas_screen.dart:30`) y declara exactamente este par
  // inline. Es 1 de 1: registrarlo no puede cambiar ningún píxel hoy, y
  // convierte la última declaración suelta del naranja de marca en una
  // lectura del tema. Un test afirma que sigue registrado con estos valores.
  floatingActionButtonTheme: const FloatingActionButtonThemeData(
    backgroundColor: GriColors.primary,
    foregroundColor: Colors.white,
  ),
  cardTheme: const CardThemeData(
    elevation: 0.5,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(GriRadius.card)),
    ),
  ),
);
