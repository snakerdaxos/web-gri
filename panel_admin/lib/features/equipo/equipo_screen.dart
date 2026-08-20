import 'package:data_table_2/data_table_2.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/async_fallo.dart';
import '../../core/firebase_error_mapper.dart';
import '../../core/theme.dart';
import 'equipo_controller.dart';
import 'equipo_provider.dart';
import 'staff_form_dialog.dart';
import '../shared/responsive_page.dart';
import '../../core/gri_icons.dart';

import '../../core/design_tokens.dart';
/// Gestión de equipo del restaurante (BOOT-04) — la pieza que hace al
/// restaurante autosuficiente: hasta aquí, dar de alta a un mesero exigía
/// `scripts/seed_firebase.mjs` con la clave de servicio del proyecto.
///
/// UNA SOLA PANTALLA ADAPTATIVA, no dos. Los dos llamadores autorizados
/// (`super_admin` y `admin_restaurante`) hacen exactamente lo mismo y solo
/// difieren en un campo del formulario —el selector de restaurante—; dos
/// pantallas duplicarían formulario, validación, tabla y manejo de errores
/// para ahorrarse un `if`.
///
/// ⚠️ ESTA PANTALLA NO ES UNA FRONTERA DE SEGURIDAD. El ítem del sidebar y el
/// `redirect` del router evitan que un mesero se tropiece con ella, pero quien
/// decide de verdad es (a) `firestore.rules` para el listado —solo el
/// `admin_restaurante` de ese rid puede leer `usuarios` de su tenant—, (b) la
/// callable `crearUsuarioStaff` para el alta y (c) `cambiarEstadoStaff` para la
/// baja. Las tres tienen suite propia contra emuladores.
///
/// Nota sobre "eliminar": no existe y no es un olvido. `firestore.rules`
/// prohíbe `delete` en `usuarios` (`allow delete: if false`) y la decisión
/// BLOQUEADA del usuario es DESACTIVAR, nunca borrar: borrar dejaría pedidos
/// huérfanos apuntando a un uid inexistente y rompería los reportes de ventas
/// por mesero. La baja reversible (11-24) vive en la columna de acciones.
class EquipoScreen extends ConsumerWidget {
  const EquipoScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final equipoAsync = ref.watch(equipoProvider);

    // Material ancestor: en producción lo provee el Scaffold del AppShell;
    // standalone (tests) sin esto Flutter inyecta estilos fallback
    // (patrón clientes_screen).
    return Material(
      color: GriColors.background,
      child: ResponsivePage(
        padding: const EdgeInsets.all(GriSpacing.lg),
        builder: (context, ancho) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Equipo del restaurante',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: GriColors.text,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Personal con acceso al panel — administradores, '
                        'meseros y cocina',
                        style: TextStyle(color: GriColors.textoSecundarioAccesible, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  key: const Key('equipo-nuevo'),
                  onPressed: () => _abrirFormulario(context),
                  icon: const Icon(Icons.person_add_alt_1, size: 18),
                  label: const Text('Nuevo usuario'),
                ),
              ],
            ),
            const _AvisoSinFunciones(),
            const SizedBox(height: 16),
            Expanded(
              child: equipoAsync.cuandoConFallo(
                cargando: () => const Center(child: CircularProgressIndicator()),
                fallo: (e) => Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        mensajeDeFallo(e, contexto: Contexto.equipo),
                        textAlign: TextAlign.center,
                        style: TextStyle(color: GriColors.textoSecundarioAccesible),
                      ),
                      TextButton(
                        onPressed: () => ref.invalidate(equipoProvider),
                        child: const Text('Reintentar'),
                      ),
                    ],
                  ),
                ),
                datos: (equipo) => equipo.isEmpty
                    ? const _EquipoVacio()
                    : _TablaEquipo(equipo: equipo),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Aviso permanente de que el alta y la baja NO se ejecutan desde el panel
/// (11-26).
///
/// **Va ANTES de pulsar, no después.** Un mensaje que solo aparece al fallar
/// deja al operador rellenar un formulario entero para nada; y si además ese
/// mensaje miente sobre la causa —«El restaurante no existe», que es lo que
/// decía hasta este plan— lo manda a investigar lo que no es. El texto es la
/// MISMA constante que muestra el error, así que no pueden divergir.
///
/// **Los botones se quedan.** No se ocultan ni se deshabilitan: el día que las
/// callables se desplieguen, la rama de error se apaga sola y no hay que tocar
/// nada aquí. Ver `docs/ESTADO-DESPLIEGUE.md`.
///
/// El estilo es el aviso que YA usa el panel (`mesa_form_dialog.dart:232`):
/// `Row` + `Icon(GriIcons.aviso)` ámbar del tamaño del texto, sin recuadro. Lo
/// único que cambia es el color del TEXTO: `GriColors.advertencia` no llega a
/// AA sobre el fondo de página (3.5:1) y este aviso es permanente, así que usa
/// el token secundario accesible, que 11-25 mide sobre los dos fondos.
class _AvisoSinFunciones extends StatelessWidget {
  const _AvisoSinFunciones();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      key: Key('equipo-aviso-sin-funciones'),
      padding: EdgeInsets.only(top: GriSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(GriIcons.aviso, size: 13, color: GriColors.advertencia),
          SizedBox(width: 6),
          Expanded(
            child: Text(
              mensajeGestionPersonalNoDisponible,
              style: TextStyle(
                color: GriColors.textoSecundarioAccesible,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> _abrirFormulario(BuildContext context) {
  return showDialog<bool>(
    context: context,
    builder: (_) => const StaffFormDialog(),
  );
}

/// Estado vacío GUIADO (patrón `EmptyState` de 11-09, que vive en la app
/// cliente y no se puede importar desde aquí: son dos proyectos Flutter
/// independientes). Lo que se conserva es el contrato que allí se fijó:
/// la guía es OBLIGATORIA — constatar el vacío sin explicar qué hacer deja al
/// operador sin saber si la pantalla falló.
class _EquipoVacio extends StatelessWidget {
  const _EquipoVacio();

  @override
  Widget build(BuildContext context) {
    return Center(
      key: const Key('equipo-vacio'),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(GriIcons.equipo, size: 40, color: GriColors.gray),
            const SizedBox(height: 12),
            const Text(
              'Todavía no hay nadie en el equipo',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: GriColors.text,
              ),
            ),
            const SizedBox(height: 8),
            const SizedBox(
              width: 420,
              child: Text(
                key: Key('equipo-vacio-guia'),
                'Da de alta a tu personal con "Nuevo usuario": cada persona '
                'entra al panel con su propio correo y contraseña, y solo ve '
                'lo que su rol le permite.',
                textAlign: TextAlign.center,
                style: TextStyle(color: GriColors.textoSecundarioAccesible, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tabla del equipo. `DataTable2` con `minWidth` y dentro de bounds finitos
/// (Expanded), igual que `clientes_screen` — el README del paquete prohíbe
/// montarlo en un scroll sin límite.
///
/// Es `Stateful` por una sola razón: [_TablaEquipoState._enVuelo] guarda el uid
/// de la operación en curso para que un doble toque no dispare dos llamadas.
/// Con un `ConsumerWidget` no habría dónde guardarlo y el segundo toque saldría
/// antes de que el primero volviera.
class _TablaEquipo extends ConsumerStatefulWidget {
  const _TablaEquipo({required this.equipo});

  final List<MiembroEquipo> equipo;

  @override
  ConsumerState<_TablaEquipo> createState() => _TablaEquipoState();
}

class _TablaEquipoState extends ConsumerState<_TablaEquipo> {
  /// uid de la operación en vuelo, o `null`. Mientras no sea `null`, NINGUNA
  /// fila acepta pulsaciones.
  String? _enVuelo;

  /// Confirmación SOLO en el sentido destructivo, mismo criterio que el toggle
  /// de restaurantes (11-05) y el borrado de mesa: desactivar echa a alguien
  /// del sistema; reactivar es inocuo y pedir confirmación solo estorbaría.
  Future<bool> _confirmarBaja(MiembroEquipo m) async {
    final confirmo = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        key: const Key('equipo-confirmar-baja'),
        // El diálogo NOMBRA a la persona: con varias filas parecidas, un
        // "¿Desactivar usuario?" genérico no deja comprobar que se pulsó la
        // fila correcta.
        title: Text('¿Desactivar a ${m.nombre}?'),
        content: Text(
          'Dejará de poder entrar al panel y perderá sus permisos. No se '
          'borra nada: sus pedidos y su historial siguen intactos, y puedes '
          'reactivarlo cuando quieras — recuperará su rol de '
          '${etiquetaRol(m.rol)}.',
        ),
        actions: [
          TextButton(
            key: const Key('equipo-baja-cancelar'),
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            key: const Key('equipo-baja-confirmar'),
            style: griBotonPeligroTexto,
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Desactivar'),
          ),
        ],
      ),
    );
    return confirmo == true;
  }

  Future<void> _cambiarEstado(MiembroEquipo m, {required bool activo}) async {
    if (_enVuelo != null) return;

    if (!activo && !await _confirmarBaja(m)) return;
    if (!mounted) return;

    final messenger = ScaffoldMessenger.maybeOf(context);
    final accion = ref.read(cambiarEstadoAccionProvider);

    setState(() => _enVuelo = m.uid);
    try {
      await accion(uid: m.uid, activo: activo);
      messenger?.showSnackBar(
        SnackBar(
          content: Text(
            activo
                // El aviso NO es cortesía: un ID token ya emitido vive hasta
                // ~1 h, así que ni la baja expulsa al instante una sesión
                // abierta ni la readmisión devuelve los permisos a una sesión
                // que siguiera viva. En los dos sentidos, volver a entrar es
                // lo que hace efectivo el cambio.
                ? '${m.nombre} vuelve a tener acceso. Tiene que volver a '
                    'iniciar sesión para recuperar sus permisos.'
                : '${m.nombre} ya no puede entrar. Si tenía la sesión '
                    'abierta, se cerrará en cuanto caduque su token.',
          ),
        ),
      );
    } on EquipoException catch (e) {
      messenger?.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      messenger?.showSnackBar(
        const SnackBar(
          content: Text('No se pudo cambiar el estado del usuario.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _enVuelo = null);
      // Se refresca SIEMPRE, también tras un error: la operación no es atómica
      // entre Auth y Firestore, así que un fallo no garantiza que nada haya
      // cambiado. Dejar la lista con el estado anterior sería mentir.
      ref.invalidate(equipoProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final yo = ref.watch(uidSesionProvider);

    return DataTable2(
      columnSpacing: 12,
      minWidth: 720,
      columns: const [
        DataColumn2(label: Text('Nombre'), size: ColumnSize.L),
        DataColumn2(label: Text('Correo'), size: ColumnSize.L),
        DataColumn(label: Text('Rol')),
        DataColumn(label: Text('Estado')),
        DataColumn2(label: Text('Acción'), size: ColumnSize.S),
      ],
      rows: [
        for (final m in widget.equipo)
          DataRow2(
            cells: [
              DataCell(
                Text(
                  m.nombre,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    // La marca visual no puede ser SOLO la insignia: en una
                    // tabla larga hay que distinguir la fila de un golpe.
                    color: m.activo ? GriColors.text : GriColors.badgeInactivo,
                  ),
                ),
              ),
              DataCell(Text(m.email)),
              DataCell(Text(etiquetaRol(m.rol))),
              DataCell(_EstadoBadge(activo: m.activo)),
              DataCell(_accion(m, yo)),
            ],
          ),
      ],
    );
  }

  /// La acción de una fila, o un hueco.
  ///
  /// ⚠️ OCULTAR NO ES IMPEDIR. Los dos casos sin acción —uno mismo y un
  /// `super_admin`— son las dos PROHIBICIONES que la callable aplica en el
  /// servidor, cada una con test unitario, test de propiedad y caso e2e con
  /// token real. Aquí se ocultan para no ofrecer un botón que va a fallar; si
  /// alguien llamara la función a mano, la decisión sigue siendo del servidor.
  /// Mismo criterio que el gating de `/equipo` en el router (11-10).
  Widget _accion(MiembroEquipo m, String? yo) {
    if (m.uid == yo) {
      return const Text(
        'Eres tú',
        key: Key('equipo-accion-propia'),
        style: TextStyle(color: GriColors.textoSecundarioAccesible, fontSize: 12),
      );
    }
    if (m.rol == 'super_admin') return const SizedBox.shrink();

    final bloqueado = _enVuelo != null;
    final verbo = m.activo ? 'Desactivar' : 'Reactivar';
    return TextButton(
      key: Key('equipo-accion-${m.uid}'),
      style: m.activo ? griBotonPeligroTexto : null,
      onPressed: bloqueado ? null : () => _cambiarEstado(m, activo: !m.activo),
      // El botón NOMBRA a la persona para un lector de pantalla (11-25). En
      // pantalla basta con el verbo —el nombre está en la primera celda de la
      // misma fila—, pero una tabla no transmite esa relación: un lector
      // anunciaría diez botones «Desactivar» idénticos. El `Semantics` va
      // DENTRO del botón y sin `container`, así que se funde en el nodo del
      // propio botón; `excludeSemantics` evita que el texto visible añada un
      // segundo «Desactivar» al anuncio. El texto en pantalla NO cambia.
      child: Semantics(
        label: '$verbo a ${m.nombre}',
        excludeSemantics: true,
        child: Text(verbo),
      ),
    );
  }
}

/// Insignia de estado. Se pinta también para los activos: una marca que solo
/// aparece en el caso raro se lee como un adorno, no como un dato de la fila.
class _EstadoBadge extends StatelessWidget {
  const _EstadoBadge({required this.activo});

  final bool activo;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: GriSpacing.sm,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color:
            activo ? GriColors.mesaDisponibleBg : GriColors.imagenPlaceholderBg,
        borderRadius: BorderRadius.circular(GriRadius.chip),
      ),
      child: Text(
        activo ? 'Activo' : 'Desactivado',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: activo ? GriColors.mesaDisponibleFg : GriColors.badgeInactivo,
        ),
      ),
    );
  }
}
