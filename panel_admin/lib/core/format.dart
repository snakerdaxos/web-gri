import 'package:intl/intl.dart';

/// Formatea un precio en pesos colombianos — Pitfall 3 lado panel.
///
/// `precio` llega como JSON number (el backend coercea Decimal→float vía
/// @field_serializer); NUNCA concatenar strings manualmente: este helper es
/// la única vía. `formatCOP(32000.0)` → `"$ 32.000"`.
String formatCOP(double precio) =>
    NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0)
        .format(precio);
