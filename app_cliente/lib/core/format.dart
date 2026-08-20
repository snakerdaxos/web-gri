import 'package:intl/intl.dart';

/// Formatea un precio en pesos colombianos — Pitfall 3 lado cliente.
///
/// Acepta `num`: `int` COP (Firestore, Phase 10) y `double` (wire legacy
/// del backend REST hasta su purga). NUNCA concatenar strings
/// manualmente: este helper es la única vía.
///
/// ── OJO CON EL FORMATO REAL (medido en 11-32, no supuesto) ────────────────
/// El locale `es_CO` pone el símbolo DETRÁS y separa con un ESPACIO DURO
/// (U+00A0). `formatCOP(32000)` devuelve el número, luego `\u00A0`, luego
/// `$` — se LEE «32.000 $». Esta cabecera prometía «$ 32.000» desde la fase
/// 10 y era FALSO en las dos cosas: el orden y el espacio.
///
/// Nadie lo vio en 30 planes porque todos los tests de dinero del repo
/// escribían `expect(find.text(formatCOP(32000)), ...)`: comparaban el helper
/// consigo mismo, así que habrían pasado en verde con CUALQUIER formato. El
/// primer test que afirmó la CADENA literal
/// (`test/pedidos/cuenta_calculo_test.dart`, plan 11-32) lo destapó en dos
/// pasos — primero el orden del símbolo, después el espacio duro.
///
/// Quien afirme una cadena de dinero en un test debe escribir el escape
/// `\u00A0` explícito: un espacio de teclado NO coincide.
///
/// Se corrigió la DOCUMENTACIÓN, no el formato: cambiar la salida movería
/// todos los precios de las dos apps y eso no era una decisión de 11-32.
String formatCOP(num precio) =>
    NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0)
        .format(precio);
