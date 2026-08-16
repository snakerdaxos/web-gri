import 'package:intl/intl.dart';

/// Formatea un precio en pesos colombianos — Pitfall 3 lado panel.
///
/// NUNCA concatenar strings manualmente: este helper es la única vía.
/// `formatCOP(32000)` / `formatCOP(32000.0)` → `"$ 32.000"` — acepta num
/// porque Firestore guarda precios `int` COP (research 10) mientras la
/// era REST enviaba doubles.
String formatCOP(num precio) =>
    NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0)
        .format(precio);
