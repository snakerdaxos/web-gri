// lib/features/shared/icono_inline.dart — un icono DENTRO de una línea de
// texto, en el mismo sitio donde estaba el emoji (11-13).
//
// ── POR QUÉ NO UN `Row` ───────────────────────────────────────────────────
// Varias pantallas tenían el emoji EN MEDIO de la cadena:
//
//     Text('🪑 Mesa ${r.mesaNumero} · 👥 ${r.numPersonas} personas')
//
// Sacarlo a un `Row(children: [Icon, Text])` cambia el comportamiento del
// salto de línea: el `Text` original hacía wrap como un párrafo normal y el
// glifo fluía con él, mientras que en un `Row` el texto queda en una caja
// aparte y hay que decidir a mano qué pasa cuando no cabe (y con dos iconos
// en la misma frase, además, harían falta dos `Row` anidados).
//
// `WidgetSpan` es la traducción FIEL: el icono sigue siendo parte del flujo
// del párrafo, exactamente como el emoji. El wrap, el alto de la línea y el
// espaciado no cambian.
//
// El `size` por defecto (14) es el `fontSize` efectivo de esos `Text` sin
// estilo (`bodyMedium` de `griTextTheme`), que es el tamaño al que se pintaba
// el emoji. Regla del plan 11-13: el `size` del icono IGUALA el `fontSize`
// del texto que lo rodeaba.
import 'package:flutter/material.dart';

/// Icono como parte del flujo de un párrafo, alineado al centro de la línea.
InlineSpan iconoInline(IconData icono, {double size = 14, Color? color}) =>
    WidgetSpan(
      alignment: PlaceholderAlignment.middle,
      child: Icon(icono, size: size, color: color),
    );
