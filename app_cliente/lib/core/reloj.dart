// core/reloj.dart — el "ahora" de la app, en un solo sitio y sustituible.
//
// POR QUÉ EXISTE (11-31): al permitir reservar para HOY con un margen mínimo
// de 4 horas, la decisión "¿este slot se puede reservar?" pasa a depender del
// reloj. Con `DateTime.now()` esparcido por la pantalla y por el servicio:
//
//   · el selector y el validador podrían leer instantes distintos y
//     contradecirse (el picker ofrece las 18:00 y el validador la rechaza);
//   · los tests que fijan un slot de HOY solo pasan a ciertas horas del día
//     —a las 20:05 un caso con el slot de las 23:00 se pondría rojo—, que es
//     exactamente la clase de test que está verde por la razón equivocada.
//
// Un único `relojProvider` resuelve las dos cosas: producción devuelve
// `DateTime.now`, y los tests inyectan un INSTANTE FIJO y explícito
// («son las 14:30») en vez de recalcular la respuesta con la misma
// aritmética que el código bajo prueba.
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Fuente única del instante actual. Override point de tests:
/// `relojProvider.overrideWithValue(() => DateTime(2026, 8, 20, 14, 30))`.
final relojProvider = Provider<DateTime Function()>((ref) => DateTime.now);
