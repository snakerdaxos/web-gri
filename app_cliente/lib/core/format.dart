import 'package:intl/intl.dart';

/// Formatea un precio en pesos colombianos — Pitfall 3 lado cliente.
///
/// Acepta `num`: `int` COP (Firestore, Phase 10) y `double` (wire legacy
/// del backend REST hasta su purga). NUNCA concatenar strings
/// manualmente: este helper es la única vía.
/// `formatCOP(32000)` → `"$ 32.000"`.
String formatCOP(num precio) =>
    NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0)
        .format(precio);
