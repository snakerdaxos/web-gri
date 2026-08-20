import 'package:flutter/material.dart';

import '../../core/design_tokens.dart';
import '../../core/gri_icons.dart';
import '../../core/imagen_url.dart';
import '../../core/theme.dart';

/// La foto de un plato dentro de la carta (11-30).
///
/// ── POR QUÉ EXISTE ────────────────────────────────────────────────────────
/// Los productos traen `imagenUrl` desde Phase 10 y el cliente NO pintaba
/// ninguna: no había un solo `Image` en las dos pantallas de menú. Este widget
/// es el único punto de la app cliente que convierte esa cadena en píxeles, y
/// concentra las cuatro cosas que hay que hacer bien con una imagen ajena:
///
///  1. SANEAR — la URL viene de un campo de texto del panel. Lo que no sea
///     http(s) con host es "no hay foto" (`urlFotoSegura`).
///  2. PEDIR EL TAMAÑO JUSTO — el ancho sale del LAYOUT
///     (`anchoFotoSolicitado` sobre el `LayoutBuilder`), no de la URL que
///     escribieron. Las de Unsplash llegan con `w=1200`; una tarjeta de móvil
///     ocupa 300 pt. La diferencia son datos móviles del comensal.
///  3. CACHEAR — `Image.network` pasa por el `ImageCache` del framework
///     (1000 imágenes / 100 MB por defecto), cuya CLAVE es la URL + el
///     `cacheWidth`. Por eso el ancho va por buckets: si cambiara con cada
///     píxel del layout, cada frame sería una entrada nueva. Con esto, hacer
///     scroll arriba y abajo o volver a la pantalla NO vuelve a descargar.
///  4. DEGRADAR — sin foto, con una URL inservible o con el host caído se
///     pinta SIEMPRE [PlaceholderPlato], del mismo tamaño exacto que la foto.
///     Nunca un hueco, nunca el icono de imagen rota, nunca una excepción.
///
/// ── POR QUÉ NO `cached_network_image` ─────────────────────────────────────
/// Se evaluó y se descartó (ver 11-30-SUMMARY.md): aportaría caché en DISCO
/// entre arranques, pero arrastra `flutter_cache_manager` -> `sqflite` +
/// `path_provider` + `uuid` + `rxdart` a un binario que hoy no los tiene, y la
/// caché en memoria del framework ya cubre el problema que reportó el usuario
/// (scroll y revisita dentro de la sesión). Una dependencia nueva en el
/// binario de producción es superficie de suministro; esta no se paga sola.
class FotoProducto extends StatelessWidget {
  const FotoProducto({
    super.key,
    required this.url,
    required this.nombre,
    required this.alto,
    this.atenuada = false,
  });

  /// `imagenUrl` del producto, TAL CUAL viene de Firestore (puede ser nula,
  /// estar en blanco o ser basura: de eso se encarga este widget).
  final String? url;

  /// Nombre del plato — es la etiqueta con la que el lector de pantalla
  /// anuncia la foto.
  final String nombre;

  /// Alto de la caja en puntos. Lo decide la tarjeta a partir de su ancho
  /// (16:9 acotado), para que TODAS las fotos de la carta midan igual.
  final double alto;

  /// Plato agotado: la foto se pinta en escala de grises. El plato sigue
  /// enseñándose —el comensal quiere saber qué hay— pero se lee de un vistazo
  /// que hoy no está.
  final bool atenuada;

  /// Escala de grises por luminancia (Rec. 601). No es un color nuevo: es un
  /// filtro sobre los píxeles que ya vienen en la foto.
  static const ColorFilter _grises = ColorFilter.matrix(<double>[
    0.2126, 0.7152, 0.0722, 0, 0, //
    0.2126, 0.7152, 0.0722, 0, 0, //
    0.2126, 0.7152, 0.0722, 0, 0, //
    0, 0, 0, 1, 0, //
  ]);

  @override
  Widget build(BuildContext context) {
    final limpia = urlFotoSegura(url);
    final contenido = limpia == null
        ? PlaceholderPlato(alto: alto)
        : _imagen(context, limpia);

    return SizedBox(
      width: double.infinity,
      height: alto,
      child: atenuada
          ? ColorFiltered(colorFilter: _grises, child: contenido)
          : contenido,
    );
  }

  Widget _imagen(BuildContext context, String limpia) {
    return LayoutBuilder(
      builder: (context, restricciones) {
        // Ancho REAL de la caja. Si llegara sin acotar (nadie la monta así,
        // pero un `Row` sin `Expanded` lo haría), se cae al ancho que tendría
        // en 16:9 en vez de pedir el máximo.
        final anchoLogico = restricciones.maxWidth.isFinite
            ? restricciones.maxWidth
            : alto * 16 / 9;
        final px = anchoFotoSolicitado(
          anchoLogico,
          MediaQuery.devicePixelRatioOf(context),
        );

        return Image.network(
          urlFotoConAncho(limpia, px),
          width: double.infinity,
          height: alto,
          fit: BoxFit.cover,
          // Acota la DECODIFICACIÓN (memoria del móvil). Es la segunda mitad
          // de la mitigación: `w=` acota la descarga cuando el CDN lo
          // entiende; esto acota la RAM aunque no lo entienda.
          cacheWidth: px,
          // Al reconstruirse (scroll, cambio de cantidad en el carrito) no
          // parpadea a blanco: conserva el último fotograma.
          gaplessPlayback: true,
          semanticLabel: 'Foto de $nombre',
          frameBuilder: (context, child, fotograma, yaEstaba) {
            // Cargada de la caché: sin animación (si no, cada scroll haría
            // parpadear toda la carta).
            if (yaEstaba) return child;
            return Stack(
              fit: StackFit.expand,
              children: [
                if (fotograma == null) PlaceholderPlato(alto: alto),
                AnimatedOpacity(
                  opacity: fotograma == null ? 0 : 1,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOut,
                  child: child,
                ),
              ],
            );
          },
          // Un host ajeno puede dar 404, estar caído o estar bloqueado por la
          // red del local. Eso NO puede verse como una imagen rota ni tumbar
          // el menú: se degrada al mismo marcador que un plato sin foto.
          errorBuilder: (context, error, traza) => PlaceholderPlato(alto: alto),
        );
      },
    );
  }
}

/// Marcador de posición de un plato sin foto utilizable.
///
/// Tres situaciones lo pintan y a propósito se ven IGUAL: el producto no tiene
/// `imagenUrl` (los que se creen desde ahora: el seed los escribe en null), la
/// que tiene no sirve, o el host no responde. Para el comensal las tres son lo
/// mismo —"de este plato no hay foto"— y una carta con marcadores idénticos se
/// lee mucho mejor que una con agujeros de tres formas distintas.
///
/// Es DECORATIVO: va dentro de `ExcludeSemantics` para que el lector de
/// pantalla no anuncie un icono que no aporta nada (el nombre y el precio del
/// plato están justo debajo, en texto).
class PlaceholderPlato extends StatelessWidget {
  const PlaceholderPlato({super.key, required this.alto});

  /// El MISMO alto que tendría la foto: la carta no cambia de ritmo.
  final double alto;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        width: double.infinity,
        height: alto,
        color: GriColors.primaryTint,
        alignment: Alignment.center,
        child: Icon(
          GriIcons.menu,
          // Tamaño relativo al hueco para que no se vea diminuto en la
          // tarjeta ancha del escritorio ni gigante en la del móvil.
          size: (alto * 0.3).clamp(GriSpacing.lg, GriSpacing.xxl),
          color: GriColors.primary.withValues(alpha: 0.35),
        ),
      ),
    );
  }
}
