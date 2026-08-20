import 'package:intl/intl.dart';

/// Formatea un precio en pesos colombianos — Pitfall 3 lado panel.
///
/// NUNCA concatenar strings manualmente: este helper es la única vía. Acepta
/// `num` porque Firestore guarda precios `int` COP (research 10) mientras la
/// era REST enviaba doubles.
///
/// ── OJO CON EL FORMATO REAL (medido en 11-32, no supuesto) ────────────────
/// El locale `es_CO` pone el símbolo DETRÁS y separa con un ESPACIO DURO
/// (U+00A0) — se LEE «32.000 $». Esta cabecera prometía «$ 32.000» desde la
/// fase 10 y era FALSO en las dos cosas: el orden y el espacio.
///
/// Ver la explicación completa (y por qué ningún test lo detectó en 30
/// planes) en la cabecera gemela de `app_cliente/lib/core/format.dart`.
///
/// Se corrigió la DOCUMENTACIÓN, no el formato: cambiar la salida movería
/// todos los precios de las dos apps y eso no era una decisión de 11-32.
String formatCOP(num precio) =>
    NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0)
        .format(precio);
