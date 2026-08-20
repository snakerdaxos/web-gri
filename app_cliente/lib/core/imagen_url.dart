// lib/core/imagen_url.dart — saneado y dimensionado de las URLs de foto de
// plato de la app cliente (11-30).
//
// ── DE DÓNDE VIENEN ESTAS URLs ────────────────────────────────────────────
// De un campo de TEXTO del panel. Cloud Storage no está habilitado en el
// proyecto (exige plan Blaze, descartado por el usuario), así que la foto de
// un plato es siempre una URL a un host ajeno que alguien escribió a mano.
// Hoy las 16 del proyecto son de `images.unsplash.com`; mañana pueden ser
// cualquier cosa, o nada.
//
// Consecuencias, y lo que este archivo hace con cada una:
//   · Puede estar vacía, en blanco o mal formada  -> [urlFotoSegura] da null
//     y la tarjeta pinta el marcador de posición, nunca un hueco.
//   · Puede traer un esquema que no es http(s)    -> también null. Lo que
//     llega de un campo de texto ajeno no se abre a ciegas.
//   · Puede pesar megas. Las de Unsplash aceptan `?w=` y devuelven la imagen
//     ya redimensionada; pedir la original en un móvil son datos del comensal
//     tirados a la basura -> [urlFotoConAncho] reescribe ese `w` con el ancho
//     que de verdad ocupa la tarjeta ([anchoFotoSolicitado]).
//
// LO QUE NO HACE: inventarle un `w` a una URL que no lo trae. Una URL ajena
// puede venir firmada (Storage, S3, CloudFront) y un parámetro de más invalida
// la firma: la foto pasaría de verse a no verse. Sin `w` previo, el servidor
// no ha declarado que sepa redimensionar y la URL se deja EXACTAMENTE igual;
// el tamaño lo acota entonces el `cacheWidth` del `Image` (que ahorra memoria
// de decodificación, no descarga — ver `features/shared/foto_producto.dart`).
library;

/// Paso del redondeo del ancho pedido, en píxeles físicos.
///
/// La URL es la CLAVE del `ImageCache` de Flutter. Si el ancho se calculase al
/// píxel exacto, redimensionar la ventana o girar el teléfono generaría una
/// URL distinta en cada frame y la foto se volvería a descargar sin parar.
/// Con el paso, todo un rango de anchos comparte una sola URL.
const int pasoAnchoFoto = 128;

/// Suelo del ancho pedido: por debajo, la foto se ve blanda en pantalla densa.
const int anchoFotoMin = 128;

/// Techo del ancho pedido. 1024 cubre la tarjeta más ancha posible (la
/// columna de contenido se topa en `GriBreakpoints.contenidoMaxAmplio` = 720)
/// en una pantalla 2x sin pedir un póster.
const int anchoFotoMax = 1024;

/// Tope del `devicePixelRatio` que se le pasa al CDN.
///
/// Un móvil moderno declara 3x o más. A 3x una tarjeta de 360 pt pediría 1080
/// px de foto: el triple de datos para una diferencia que en una FOTO (no en
/// un texto ni en un trazo fino) es imperceptible.
const double dprMaxFoto = 2.0;

/// Devuelve la URL utilizable de una foto, o `null` si no hay ninguna.
///
/// `null` es la respuesta a TODO lo que no sea una dirección http(s) con host:
/// campo vacío, espacios, cadena suelta, `javascript:`, `data:`, `file:`…
/// Quien la llama pinta el marcador de posición en ese caso.
String? urlFotoSegura(String? crudo) {
  if (crudo == null) return null;
  final texto = crudo.trim();
  if (texto.isEmpty) return null;

  final uri = Uri.tryParse(texto);
  if (uri == null) return null;
  if (uri.scheme != 'http' && uri.scheme != 'https') return null;
  if (uri.host.isEmpty) return null;

  return texto;
}

/// Ancho en píxeles FÍSICOS que se le pide al CDN para una foto que ocupa
/// [anchoLogico] puntos en una pantalla de densidad [dpr].
///
/// Redondea hacia arriba al [pasoAnchoFoto] (estabilidad de caché), acota el
/// [dpr] a [dprMaxFoto] y el resultado a `[anchoFotoMin, anchoFotoMax]`.
/// Un [anchoLogico] no finito o absurdo no revienta: cae en los extremos.
int anchoFotoSolicitado(double anchoLogico, double dpr) {
  if (anchoLogico.isNaN) return anchoFotoMin;
  if (anchoLogico.isInfinite) return anchoFotoMax;

  final densidad = dpr.isFinite ? dpr.clamp(1.0, dprMaxFoto) : 1.0;
  final fisicos = anchoLogico * densidad;
  if (!fisicos.isFinite || fisicos <= 0) return anchoFotoMin;

  final bucket = (fisicos / pasoAnchoFoto).ceil() * pasoAnchoFoto;
  return bucket.clamp(anchoFotoMin, anchoFotoMax);
}

/// Reescribe el parámetro de ancho de [url] a [anchoPx] px.
///
/// Solo actúa si la URL YA trae un `w` numérico — ver el encabezado del
/// archivo. Si además trae `h`, lo escala en la misma proporción para no
/// deformar el recorte. En cualquier otro caso (sin `w`, `w` no numérico, URL
/// no parseable) devuelve [url] tal cual.
String urlFotoConAncho(String url, int anchoPx) {
  final uri = Uri.tryParse(url);
  if (uri == null) return url;

  final params = Map<String, List<String>>.from(uri.queryParametersAll);
  final wActual = int.tryParse(params['w']?.firstOrNull ?? '');
  if (wActual == null || wActual <= 0) return url;

  params['w'] = <String>['$anchoPx'];

  final hActual = int.tryParse(params['h']?.firstOrNull ?? '');
  if (hActual != null && hActual > 0) {
    params['h'] = <String>['${(hActual * anchoPx / wActual).round()}'];
  }

  return uri.replace(queryParameters: params).toString();
}
