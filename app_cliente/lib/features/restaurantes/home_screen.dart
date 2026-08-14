import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../core/token_provider.dart';
import '../../models/reserva.dart';
import '../reservas/mis_reservas_screen.dart' show EstadoChip;
import '../reservas/reservas_provider.dart';
import 'restaurantes_provider.dart';

/// Tab Inicio — réplica del mockup indexcliente.html:
/// header blanco (logo GRI + botón QR placeholder Phase 6), welcome con el
/// nombre del user, tarjeta del primer restaurante, grid de 2 acciones y
/// card "Próxima reserva" (si hay alguna futura confirmada).
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
    final user = ref.watch(authStateProvider).value;
    final restaurantesAsync = ref.watch(restaurantesListProvider);
    final reservasAsync = ref.watch(reservasProvider);

    final primera = restaurantesAsync.value?.firstOrNull;
    final proxima = _proximaReserva(reservasAsync.value);

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        // ── Header (mockup): logo GRI + botón QR ──────────────────────────
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
              // QR es Phase 6 — placeholder no funcional.
              _QrButton(
                onTap: () => _proximamente(context),
              ),
            ],
          ),
        ),

        Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Welcome ──────────────────────────────────────────────────
              Text(
                '¡Hola, ${user?.nombre ?? ''}! 👋',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: GriColors.text,
                ),
              ),
              const SizedBox(height: 5),
              const Text(
                '¿Dónde quieres comer hoy?',
                style: TextStyle(color: GriColors.gray),
              ),
              const SizedBox(height: 24),

              // ── Tarjeta del primer restaurante ───────────────────────────
              if (primera != null) _RestauranteCard(id: primera.id, nombre: primera.nombre, tipoCocina: primera.tipoCocina, calificacionLabel: primera.calificacionLabel)
              else if (restaurantesAsync.isLoading)
                const Center(child: Padding(
                  padding: EdgeInsets.all(24),
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
                      emoji: '📷',
                      titulo: 'Escanear mesa',
                      subtitulo: 'Ordena desde tu celular',
                      onTap: () => _proximamente(context),
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: _ActionCard(
                      emoji: '📅',
                      titulo: 'Mis reservas',
                      subtitulo: 'Consulta tus reservas',
                      onTap: () => context.go('/reservas'),
                    ),
                  ),
                ],
              ),

              // ── Próxima reserva ──────────────────────────────────────────
              if (proxima != null) ...[
                const SizedBox(height: 24),
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
          '${a.fecha} ${a.horaInicio}'.compareTo('${b.fecha} ${b.horaInicio}'));
    return candidatas.firstOrNull;
  }

  void _proximamente(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Próximamente'), duration: Duration(seconds: 2)),
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
      child: const Center(child: Text('🍽️', style: TextStyle(fontSize: 22))),
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
            child: Text('📷', style: TextStyle(fontSize: 22)),
          ),
        ),
      ),
    );
  }
}

/// Tarjeta restaurante del home (mockup .restaurant): gradiente + info +
/// botón "📅 Reservar una mesa".
class _RestauranteCard extends StatelessWidget {
  const _RestauranteCard({
    required this.id,
    required this.nombre,
    required this.tipoCocina,
    required this.calificacionLabel,
  });

  final int id;
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
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFFF6B35), Color(0xFFFF9B5A)],
              ),
            ),
            child: const Center(
              child: Text('🍽️', style: TextStyle(fontSize: 60)),
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
                    const Text('⭐ ',
                        style: TextStyle(color: Color(0xFFF5A623), fontSize: 14)),
                    Text(
                      calificacionLabel,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFF5A623),
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
                    child: const Text(
                      '📅 Reservar una mesa',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
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
    required this.emoji,
    required this.titulo,
    required this.subtitulo,
    required this.onTap,
  });

  final String emoji;
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
              Text(emoji, style: const TextStyle(fontSize: 30)),
              const SizedBox(height: 10),
              Text(
                titulo,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: GriColors.text,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitulo,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: GriColors.gray),
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
          Text('📅 ${reserva.fecha} · ${reserva.horaLabel}'),
          const SizedBox(height: 6),
          Text('🪑 Mesa ${reserva.mesaNumero} · '
              '👥 ${reserva.numPersonas} personas'),
          const SizedBox(height: 6),
          Text('📍 ${reserva.restauranteNombre}'),
        ],
      ),
    );
  }
}

