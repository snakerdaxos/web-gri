import 'package:flutter/material.dart';

import '../../core/design_tokens.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../models/producto.dart';
import 'foto_producto.dart';

/// Alto mínimo de la foto de una tarjeta. Por debajo, la foto deja de ser una
/// foto y pasa a ser una franja.
const double altoFotoMin = 120;

/// Alto máximo. Sin este tope, en la columna ancha del escritorio (720 pt) el
/// 16:9 daría 405 pt: un plato por pantalla y a desplazarse.
const double altoFotoMax = 200;

/// Alto de la foto para una tarjeta de [ancho] puntos: 16:9 acotado.
double altoFotoParaAncho(double ancho) {
  if (!ancho.isFinite || ancho <= 0) return altoFotoMin;
  return (ancho * 9 / 16).clamp(altoFotoMin, altoFotoMax);
}

/// Un plato de la carta (11-30).
///
/// ── QUÉ SUSTITUYE Y POR QUÉ ───────────────────────────────────────────────
/// A un `ListTile`: nombre a la izquierda, descripción a una línea debajo y el
/// precio de `trailing`. El usuario, probando la app real, lo describió así:
/// «se ve como lista, no como carta». Y las fotos —que TODOS los productos del
/// proyecto tienen guardadas desde Phase 10— no se pintaban en ningún sitio.
///
/// La tarjeta ordena el plato como una carta de restaurante: foto arriba a
/// todo el ancho, nombre legible, descripción con aire (dos líneas, no una) y
/// el precio grande y en naranja de marca, no gris al final de la fila.
///
/// ── LO QUE NO CAMBIA ──────────────────────────────────────────────────────
/// La identidad visual está BLOQUEADA: aquí no hay ni un color ni un tamaño
/// que no salga de `GriColors` / `GriText` / `GriSpacing` / `GriRadius`. Es
/// una reorganización del layout, no una piel nueva.
class ProductoCard extends StatelessWidget {
  const ProductoCard({
    super.key,
    required this.producto,
    this.accion,
    this.onTap,
    this.etiquetaAccion,
  });

  final Producto producto;

  /// Controles de la derecha del precio (los +/− del carrito en el menú de la
  /// mesa). En la carta de escaparate del detalle del restaurante NO hay: allí
  /// no se pide nada, y un botón que no hace nada es peor que ninguno.
  ///
  /// Si el plato está agotado NO se pinta, aunque lo pasen.
  final Widget? accion;

  /// Pulsar la tarjeta entera. Se ignora si el plato está agotado.
  final VoidCallback? onTap;

  /// Etiqueta con la que el lector de pantalla anuncia esa pulsación. Es
  /// obligatoria de facto cuando hay [onTap]: un objetivo táctil sin nombre lo
  /// caza `labeledTapTargetGuideline` (11-14).
  final String? etiquetaAccion;

  @override
  Widget build(BuildContext context) {
    final agotado = !producto.disponible;
    final pulsable = !agotado && onTap != null;
    final colorTexto =
        agotado ? GriColors.textoSecundarioAccesible : GriColors.text;
    final descripcion = producto.descripcion?.trim();

    final tarjeta = Card(
      // Cero: el aire entre tarjetas lo reparte [ListaProductos]. Con el
      // margen por defecto del tema, la foto no llegaría a los bordes y el
      // hueco entre columnas sería el doble en el escritorio.
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, restricciones) {
          final alto = altoFotoParaAncho(restricciones.maxWidth);
          return InkWell(
            onTap: pulsable ? onTap : null,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                FotoProducto(
                  url: producto.imagenUrl,
                  nombre: producto.nombre,
                  alto: alto,
                  atenuada: agotado,
                ),
                Padding(
                  padding: const EdgeInsets.all(GriSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              producto.nombre,
                              style:
                                  GriText.tituloCard.copyWith(color: colorTexto),
                            ),
                          ),
                          if (agotado) ...[
                            const SizedBox(width: GriSpacing.sm),
                            const _ChipAgotado(),
                          ],
                        ],
                      ),
                      if (descripcion != null && descripcion.isNotEmpty) ...[
                        const SizedBox(height: GriSpacing.xs),
                        Text(
                          descripcion,
                          // Dos líneas, no una: la descripción de un plato es
                          // parte de la carta, no un metadato.
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GriText.cuerpoCompacto.copyWith(
                            color: GriColors.textoSecundarioAccesible,
                          ),
                        ),
                      ],
                      const SizedBox(height: GriSpacing.sm),
                      Row(
                        children: [
                          Text(
                            formatCOP(producto.precio),
                            style: GriText.tituloSeccion.copyWith(
                              color: agotado
                                  ? GriColors.textoSecundarioAccesible
                                  : GriColors.primary,
                            ),
                          ),
                          const Spacer(),
                          if (!agotado && accion != null) accion!,
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    if (!pulsable) return tarjeta;
    return Semantics(
      button: true,
      label: etiquetaAccion,
      child: tarjeta,
    );
  }
}

/// «Agotado» — el tratamiento del plato que hoy no está.
///
/// Va con los tokens del chip de reserva cancelada (mismo significado visual:
/// "esto no va a pasar"), que además cumplen contraste AA sobre su fondo.
class _ChipAgotado extends StatelessWidget {
  const _ChipAgotado();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: GriSpacing.sm,
        vertical: GriSpacing.xs,
      ),
      decoration: const BoxDecoration(
        color: GriColors.chipCanceladaBg,
        borderRadius: GriRadius.chipBorder,
      ),
      child: Text(
        'Agotado',
        style: GriText.chip.copyWith(color: GriColors.chipCanceladaFg),
      ),
    );
  }
}

/// Ancho al que se aspira para una tarjeta de la carta.
///
/// No es un breakpoint de pantalla: es el ancho al que una tarjeta con foto
/// 16:9, nombre, descripción y precio se lee bien. La rejilla mete tantas
/// columnas como quepan a ESE ancho, así que la tarjeta mide casi lo mismo en
/// un móvil de 320 que en una ventana de 1600 — lo que cambia es cuántas hay.
const double anchoObjetivoTarjeta = 300;

/// Tope de columnas. Sin él, un monitor ancho daría una cuadrícula de sellos.
const int columnasMax = 4;

/// La rejilla de la carta: tantas columnas como quepan a
/// [anchoObjetivoTarjeta], entre 1 y [columnasMax].
///
/// POR QUÉ NO UN `GridView`: esto vive DENTRO de un `ListView` (los hijos de
/// un `ExpansionTile` de categoría). Un viewport dentro de otro viewport en el
/// mismo eje obliga a `shrinkWrap` + `NeverScrollableScrollPhysics` y a fijar
/// una relación de aspecto para TODAS las celdas — que es justo lo que aquí no
/// se puede: cada tarjeta mide lo que midan su nombre y su descripción. Un
/// `Wrap` de anchos calculados hace lo mismo sin ninguna de las dos ataduras.
///
/// POR QUÉ NO UN BREAKPOINT FIJO (1 columna / 2 columnas): estas dos pantallas
/// viven FUERA del `AppShell` (`app.dart`: `/mesa` y `/restaurantes/:id` son
/// rutas hermanas del shell), así que NO heredan el techo de 720 pt de
/// `GriBreakpoints.contenidoMaxAmplio`. En un navegador maximizado reciben el
/// ancho entero: con dos columnas fijas saldrían dos tarjetas de 800 pt con
/// una foto de 200 de alto, una tira aplastada. Contando columnas, la tarjeta
/// conserva su proporción a cualquier ancho.
///
/// | viewport | columnas | ancho de tarjeta |
/// |----------|----------|------------------|
/// | 320      | 1        | 320              |
/// | 700      | 2        | 342              |
/// | 1000     | 3        | 322              |
/// | 1600     | 4        | 388              |
class ListaProductos extends StatelessWidget {
  const ListaProductos({
    super.key,
    required this.productos,
    required this.tarjeta,
  });

  final List<Producto> productos;

  /// Fábrica de la tarjeta. La inyecta la pantalla porque cada una monta la
  /// suya: el menú de la mesa con los controles del carrito, el detalle del
  /// restaurante sin ellos.
  final Widget Function(Producto) tarjeta;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, restricciones) {
        final ancho = restricciones.maxWidth.isFinite
            ? restricciones.maxWidth
            : GriBreakpoints.contenidoMax;
        final columnas =
            (ancho / anchoObjetivoTarjeta).floor().clamp(1, columnasMax);
        // `floor`: con la división exacta, un error de coma flotante de 10^-13
        // basta para que el `Wrap` decida que la segunda tarjeta no cabe y la
        // baje de fila.
        final anchoTarjeta =
            ((ancho - GriSpacing.md * (columnas - 1)) / columnas)
                .floorToDouble();

        return Wrap(
          spacing: GriSpacing.md,
          runSpacing: GriSpacing.md,
          children: [
            for (final producto in productos)
              SizedBox(
                width: anchoTarjeta > 0 ? anchoTarjeta : null,
                child: tarjeta(producto),
              ),
          ],
        );
      },
    );
  }
}
