import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/firebase_providers.dart';
import '../../core/gri_icons.dart';
import '../../core/theme.dart';
import '../../models/reserva.dart';
import '../../models/sesion_mesa.dart';
import '../auth/auth_controller.dart';
import '../reservas/mis_reservas_screen.dart' show EstadoChip;
import '../reservas/reservas_provider.dart';
import '../sesion_qr/sesion_provider.dart';
import '../shared/icono_inline.dart';
import '../../core/design_tokens.dart';
import 'restaurantes_provider.dart';

/// Tab Inicio — réplica del mockup indexcliente.html:
/// header blanco (logo GRI + botón QR → scanner real, Phase 6), welcome
/// con el nombre del user, banner "Estás en la Mesa X" si hay sesión
/// activa, tarjeta del primer restaurante, grid de 2 acciones y card
/// "Próxima reserva" (si hay alguna futura confirmada).
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  String get _hoy {
    final now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // authStateProvider NUEVO (FirebaseAuth, 10-02) — displayName para el
    // greeting; ya no la capa de sesión legacy de la era REST.
    final user = ref.watch(authStateProvider).value;
    final restaurantesAsync = ref.watch(restaurantesListProvider);

    // Mis reservas como stream Firestore (REALTIME) — sin uid no hay
    // sesión: AsyncLoading (el router igual redirige a /login).
    final uid = ref.watch(firebaseAuthProvider).currentUser?.uid;
    final reservasAsync = uid == null
        ? const AsyncValue<List<Reserva>>.loading()
        : ref.watch(misReservasProvider(uid));
    final sesion = ref.watch(sesionActualProvider).value;

    final primera = restaurantesAsync.value?.firstOrNull;
    final proxima = _proximaReserva(reservasAsync.value);

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        // ── Header (mockup): logo GRI + botón QR ──────────────────────────
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: GriSpacing.md),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  _LogoIcon(),
                  SizedBox(width: 10),
                  Text(
                    'GRI',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: GriColors.text,
                    ),
                  ),
                ],
              ),
              _QrButton(
                onTap: () => context.push('/sesion/scan'),
              ),
            ],
          ),
        ),

        Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Banner de sesión activa (MESA-06 UI) ────────────────────
              // El stream emite la sesión MÁS RECIENTE aunque esté cerrada
              // (para la calificación post-cierre) — el banner exige activa.
              if (sesion != null && sesion.estado == 'activa') ...[
                _SesionBanner(sesion: sesion),
                const SizedBox(height: 20),
              ],

              // ── Welcome ──────────────────────────────────────────────────
              Text(
                // ignore: lines_longer_than_80_chars
                '¡Hola, ${user?.displayName ?? ''}! 👋', // EMOJI-OK: saludo
                style: GriText.tituloPantalla.copyWith(color: GriColors.text),
              ),
              const SizedBox(height: 5),
              const Text(
                '¿Dónde quieres comer hoy?',
                style: TextStyle(color: GriColors.gray),
              ),
              const SizedBox(height: GriSpacing.lg),

              // ── Tarjeta del primer restaurante ───────────────────────────
              if (primera != null) _RestauranteCard(id: primera.id, nombre: primera.nombre, tipoCocina: primera.tipoCocina, calificacionLabel: primera.ratingLabel)
              else if (restaurantesAsync.isLoading)
                const Center(child: Padding(
                  padding: EdgeInsets.all(GriSpacing.lg),
                  child: CircularProgressIndicator(),
                ))
              else
                const Text(
                  'No hay restaurantes disponibles todavía',
                  style: TextStyle(color: GriColors.gray),
                ),

              const SizedBox(height: 20),

              // ── Grid de 2 acciones ──────────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: _ActionCard(
                      icono: GriIcons.escanearQr,
                      titulo: 'Escanear mesa',
                      subtitulo: 'Ordena desde tu celular',
                      onTap: () => context.push('/sesion/scan'),
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: _ActionCard(
                      icono: GriIcons.reservas,
                      titulo: 'Mis reservas',
                      subtitulo: 'Consulta tus reservas',
                      onTap: () => context.go('/reservas'),
                    ),
                  ),
                ],
              ),

              // ── Próxima reserva ──────────────────────────────────────────
              if (proxima != null) ...[
                const SizedBox(height: GriSpacing.lg),
                _ProximaReservaCard(reserva: proxima),
              ],
            ],
          ),
        ),
      ],
    );
  }

  /// La reserva futura confirmada más próxima (fecha, luego hora).
  Reserva? _proximaReserva(List<Reserva>? reservas) {
    if (reservas == null) return null;
    final candidatas = reservas
        .where((r) => r.estadoReserva == EstadoReserva.confirmada)
        .where((r) => r.esProxima(_hoy))
        .toList()
      ..sort((a, b) =>
          '${a.fechaStr} ${a.horaLabel}'.compareTo('${b.fechaStr} ${b.horaLabel}'));
    return candidatas.firstOrNull;
  }
}

/// Banner "Estás en la Mesa X" (sesión QR activa) — acceso directo al menú
/// de la mesa, a los pedidos y reflejo de la cuenta solicitada.
class _SesionBanner extends StatelessWidget {
  const _SesionBanner({required this.sesion});

  final SesionMesa sesion;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: griGradienteRestaurante,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(GriIcons.mesa, size: 20, color: Colors.white),
              const SizedBox(width: GriSpacing.sm),
              Expanded(
                child: Text(
                  'Estás en la Mesa ${sesion.mesaNumero}',
                  style: GriText.tituloSeccion.copyWith(color: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(height: GriSpacing.xs),
          Text.rich(
            TextSpan(children: [
              iconoInline(GriIcons.direccion),
              TextSpan(text: ' ${sesion.restauranteNombre}'),
            ]),
            style: const TextStyle(color: Colors.white70),
          ),
          if (sesion.cuentaSolicitada) ...[
            const SizedBox(height: GriSpacing.sm),
            const Text.rich(
              TextSpan(children: [
                TextSpan(text: 'Cuenta solicitada '),
                WidgetSpan(
                  alignment: PlaceholderAlignment.middle,
                  child: Icon(GriIcons.confirmado,
                      size: 14, color: Colors.white),
                ),
              ]),
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    onTap: () => context.push('/mesa'),
                    borderRadius: BorderRadius.circular(10),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 10),
                      child: Text(
                        'Ver menú',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: GriColors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Material(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    onTap: () => context.push('/mesa/pedidos'),
                    borderRadius: BorderRadius.circular(10),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 10),
                      child: Text(
                        'Mis pedidos',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LogoIcon extends StatelessWidget {
  const _LogoIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: GriColors.primary,
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Center(
        child: Icon(GriIcons.menu,
            size: 22, color: Colors.white, semanticLabel: 'GRI'),
      ),
    );
  }
}

class _QrButton extends StatelessWidget {
  const _QrButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: GriColors.primaryTint,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: const SizedBox(
          width: 45,
          height: 45,
          child: Center(
            child: Icon(GriIcons.escanearQr,
                size: 22,
                color: GriColors.primary,
                semanticLabel: 'Escanear QR de la mesa'),
          ),
        ),
      ),
    );
  }
}

/// Tarjeta restaurante del home (mockup .restaurant): gradiente + info +
/// botón "Reservar una mesa" con el icono de calendario.
class _RestauranteCard extends StatelessWidget {
  const _RestauranteCard({
    required this.id,
    required this.nombre,
    required this.tipoCocina,
    required this.calificacionLabel,
  });

  /// Slug del doc Firestore (String end-to-end, Phase 10).
  final String id;
  final String nombre;
  final String? tipoCocina;
  final String calificacionLabel;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 150,
            decoration: const BoxDecoration(
              gradient: griGradienteRestaurante,
            ),
            child: const Center(
              child: Icon(GriIcons.menu, size: 60, color: Colors.white),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nombre,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: GriColors.text,
                  ),
                ),
                if (tipoCocina != null) ...[
                  const SizedBox(height: 6),
                  Text(tipoCocina!, style: const TextStyle(color: GriColors.gray)),
                ],
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(GriIcons.calificacion,
                        color: GriColors.calificacionEstrella, size: 14),
                    const SizedBox(width: GriSpacing.xs),
                    Text(
                      calificacionLabel,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: GriColors.calificacionEstrella,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 15),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => context.push(
                      '/reservas/wizard'
                      '?restauranteId=$id'
                      '&restauranteNombre=${Uri.encodeComponent(nombre)}',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: GriColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text.rich(
                      TextSpan(children: [
                        WidgetSpan(
                          alignment: PlaceholderAlignment.middle,
                          child: Icon(GriIcons.reservas, size: 16),
                        ),
                        TextSpan(text: ' Reservar una mesa'),
                      ]),
                      style: GriText.botonGrande,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icono,
    required this.titulo,
    required this.subtitulo,
    required this.onTap,
  });

  final IconData icono;
  final String titulo;
  final String subtitulo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(15),
      shadowColor: Colors.black.withValues(alpha: 0.05),
      elevation: 1,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // size 30 = el fontSize que tenia el Text del emoji.
              Icon(icono, size: 30, color: GriColors.primary),
              const SizedBox(height: 10),
              Text(
                titulo,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: GriColors.text,
                ),
              ),
              const SizedBox(height: GriSpacing.xs),
              Text(
                subtitulo,
                textAlign: TextAlign.center,
                style: GriText.auxiliar.copyWith(color: GriColors.gray),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Card "Próxima reserva" del mockup (.reservation): fondo tint naranja con
/// borde y status chip.
class _ProximaReservaCard extends StatelessWidget {
  const _ProximaReservaCard({required this.reserva});

  final Reserva reserva;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: GriColors.primaryTint,
        border: Border.all(color: GriColors.primaryTintBorder),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Próxima reserva',
                style: TextStyle(
                  color: GriColors.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              EstadoChip(estado: reserva.estado),
            ],
          ),
          const SizedBox(height: 12),
          Text.rich(TextSpan(children: [
            iconoInline(GriIcons.reservas),
            TextSpan(text: ' ${reserva.fechaStr} · ${reserva.horaLabel}'),
          ])),
          const SizedBox(height: 6),
          Text.rich(TextSpan(children: [
            iconoInline(GriIcons.mesa),
            TextSpan(text: ' Mesa ${reserva.mesaNumero} · '),
            iconoInline(GriIcons.personas),
            TextSpan(text: ' ${reserva.numPersonas} personas'),
          ])),
          const SizedBox(height: 6),
          Text.rich(TextSpan(children: [
            iconoInline(GriIcons.direccion),
            TextSpan(text: ' ${reserva.restauranteNombre}'),
          ])),
        ],
      ),
    );
  }
}

