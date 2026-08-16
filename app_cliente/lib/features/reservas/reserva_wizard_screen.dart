import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../models/restaurante.dart';
import '../../models/reserva_create.dart';
import '../restaurantes/restaurantes_provider.dart';
import 'reserva_controller.dart';

/// Wizard de reserva (RESV-01) — Stepper fecha → hora → personas → confirmar
/// → `POST /cliente/reservas` vía [ReservaController].
///
/// * Fecha: [showDatePicker] con firstDate = mañana (no fechas pasadas).
/// * Hora: dropdown de slots :00 exclusivamente (12:00..21:00) — el turno
///   es de 60 min y el backend rechaza non-:00 con 400; el wizard NUNCA
///   ofrece TimeOfDay libre (threat 5).
/// * Personas: 1..20 (match del Field(ge=1, le=20) del backend).
/// * Si [restauranteId] es 0/null (FAB "sin preselect"), se antepone un
///   step "Restaurante" con dropdown de `/public/restaurantes`.
class ReservaWizardScreen extends ConsumerStatefulWidget {
  const ReservaWizardScreen({
    super.key,
    required this.restauranteId,
    required this.restauranteNombre,
  });

  /// Slug del doc `restaurantes/{slug}` — String end-to-end (Phase 10).
  /// Vacío (`''`) cuando el FAB abre el wizard "sin preselect".
  final String restauranteId;
  final String restauranteNombre;

  /// Slots horarios del turno (hourly, :00) — la fuente única que renderiza
  /// el dropdown. 12:00 a 21:00.
  static const horasSlot = <String>[
    '12:00', '13:00', '14:00', '15:00', '16:00', '17:00',
    '18:00', '19:00', '20:00', '21:00',
  ];

  @override
  ConsumerState<ReservaWizardScreen> createState() =>
      _ReservaWizardScreenState();
}

class _ReservaWizardScreenState extends ConsumerState<ReservaWizardScreen> {
  int _currentStep = 0;

  Restaurante? _restaurante;
  DateTime? _fecha;
  String? _hora;
  int _personas = 2;

  bool get _needsRestauranteStep => widget.restauranteId.isEmpty;

  String get _fechaString {
    final f = _fecha!;
    return '${f.year.toString().padLeft(4, '0')}-'
        '${f.month.toString().padLeft(2, '0')}-'
        '${f.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final saving = ref.watch(reservaControllerProvider).isLoading;
    final steps = _buildSteps();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: GriColors.text,
        elevation: 0,
        title: Text('Reservar$_restauranteNombreSuffix'),
      ),
      body: Stepper(
        currentStep: _currentStep,
        onStepTapped: (i) => setState(() => _currentStep = i),
        onStepCancel: _currentStep > 0
            ? () => setState(() => _currentStep--)
            : null,
        onStepContinue: _onContinue,
        controlsBuilder: (context, details) {
          // El Stepper llama controlsBuilder por CADA step; solo el activo
          // muestra controles (un único "Continuar" en el árbol).
          if (_currentStep != details.stepIndex ||
              _currentStep == steps.length - 1) {
            return const SizedBox.shrink(); // el último step tiene su botón.
          }
          return Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Row(
              children: [
                ElevatedButton(
                  onPressed: details.onStepContinue,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: GriColors.primary,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Continuar'),
                ),
                if (_currentStep > 0) ...[
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: details.onStepCancel,
                    child: const Text('Atrás'),
                  ),
                ],
              ],
            ),
          );
        },
        steps: steps,
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: (saving || !_puedeConfirmar) ? null : _confirmar,
              style: ElevatedButton.styleFrom(
                backgroundColor: GriColors.primary,
                foregroundColor: Colors.white,
                disabledBackgroundColor:
                    GriColors.primary.withValues(alpha: 0.4),
                disabledForegroundColor: Colors.white70,
                padding: const EdgeInsets.symmetric(vertical: 14),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              child: saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Confirmar reserva'),
            ),
          ),
        ),
      ),
    );
  }

  String get _restauranteNombreSuffix => _needsRestauranteStep
      ? (_restaurante != null ? ' · ${_restaurante!.nombre}' : '')
      : (widget.restauranteNombre.isNotEmpty
          ? ' · ${widget.restauranteNombre}'
          : '');

  List<Step> _buildSteps() => [
        if (_needsRestauranteStep)
          Step(
            title: const Text('Restaurante'),
            isActive: _currentStep >= 0,
            state: _currentStep > 0 ? StepState.complete : StepState.indexed,
            content: _RestaurantePicker(
              selected: _restaurante,
              onChanged: (r) => setState(() => _restaurante = r),
            ),
          ),
        Step(
          title: const Text('Fecha'),
          isActive: _currentStep >= _stepFecha,
          state: _fecha != null && _currentStep > _stepFecha
              ? StepState.complete
              : StepState.indexed,
          content: Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _pickFecha,
              icon: const Icon(Icons.calendar_month),
              label: Text(_fecha == null ? 'Elegir fecha' : _fechaString),
            ),
          ),
        ),
        Step(
          title: const Text('Hora'),
          isActive: _currentStep >= _stepHora,
          state: _hora != null && _currentStep > _stepHora
              ? StepState.complete
              : StepState.indexed,
          content: Align(
            alignment: Alignment.centerLeft,
            child: DropdownButtonFormField<String>(
              initialValue: _hora,
              hint: const Text('Elige una hora'),
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.schedule),
              ),
              items: [
                for (final h in ReservaWizardScreen.horasSlot)
                  DropdownMenuItem(value: h, child: Text(h)),
              ],
              onChanged: (v) => setState(() => _hora = v),
            ),
          ),
        ),
        Step(
          title: const Text('Personas'),
          isActive: _currentStep >= _stepPersonas,
          state: _currentStep > _stepPersonas
              ? StepState.complete
              : StepState.indexed,
          content: _PersonasSelector(
            value: _personas,
            onChanged: (v) => setState(() => _personas = v),
          ),
        ),
        Step(
          title: const Text('Confirmar'),
          isActive: _currentStep >= _stepConfirmar,
          content: Align(
            alignment: Alignment.centerLeft,
            child: _resumen(),
          ),
        ),
      ];

  // Índices reales según si hay step de restaurante o no.
  int get _stepFecha => _needsRestauranteStep ? 1 : 0;
  int get _stepHora => _stepFecha + 1;
  int get _stepPersonas => _stepHora + 1;
  int get _stepConfirmar => _stepPersonas + 1;

  Widget _resumen() {
    final nombreRestaurante = _needsRestauranteStep
        ? _restaurante?.nombre ?? '—'
        : widget.restauranteNombre;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ResumenRow(label: 'Restaurante', value: nombreRestaurante),
        _ResumenRow(label: 'Fecha', value: _fecha?.let(_fmt) ?? '—'),
        _ResumenRow(label: 'Hora', value: _hora ?? '—'),
        _ResumenRow(label: 'Personas', value: '$_personas'),
        const SizedBox(height: 8),
        const Text(
          'Al confirmar, el sistema te asignará una mesa automáticamente.',
          style: TextStyle(color: GriColors.gray, fontSize: 12),
        ),
      ],
    );
  }

  static String _fmt(DateTime f) =>
      '${f.year.toString().padLeft(4, '0')}-'
      '${f.month.toString().padLeft(2, '0')}-'
      '${f.day.toString().padLeft(2, '0')}';

  Future<void> _pickFecha() async {
    final ahora = DateTime.now();
    final manana = DateTime(ahora.year, ahora.month, ahora.day)
        .add(const Duration(days: 1));
    final picked = await showDatePicker(
      context: context,
      firstDate: manana,
      lastDate: manana.add(const Duration(days: 365)),
      initialDate: _fecha ?? manana,
    );
    if (picked != null) setState(() => _fecha = picked);
  }

  void _onContinue() {
    // Validación pre-avance (threat 5): cada step exige su dato.
    if (_currentStep == _stepFecha && _fecha == null) {
      _hint('Elige una fecha para continuar');
      return;
    }
    if (_currentStep == _stepHora && _hora == null) {
      _hint('Elige una hora para continuar');
      return;
    }
    if (_needsRestauranteStep && _currentStep == 0 && _restaurante == null) {
      _hint('Elige un restaurante para continuar');
      return;
    }
    if (_currentStep < _stepConfirmar) {
      setState(() => _currentStep++);
    }
  }

  bool get _puedeConfirmar {
    final tieneRestaurante = _needsRestauranteStep
        ? _restaurante != null
        : widget.restauranteId.isNotEmpty;
    return tieneRestaurante && _fecha != null && _hora != null;
  }

  Future<void> _confirmar() async {
    final rid = _needsRestauranteStep ? _restaurante!.id : widget.restauranteId;
    try {
      final reserva = await ref
          .read(reservaControllerProvider.notifier)
          .create(ReservaCreate(
            restauranteId: rid,
            fecha: _fechaString,
            hora: int.parse(_hora!.split(':').first), // '19:00' → 19 (slot :00)
            numPersonas: _personas,
          ));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('¡Reserva confirmada! Mesa ${reserva.mesaNumero}'),
          backgroundColor: GriColors.green,
        ),
      );
      Navigator.of(context).pop(true);
    } on Exception catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_errorMsg(e)),
          backgroundColor: GriColors.chipCanceladaFg,
        ),
      );
    }
  }

  /// Mappea el error del POST a un mensaje user-friendly (threat 6) —
  /// JAMÁS un stack trace o detail crudo.
  String _errorMsg(Object e) {
    final statusCode = _statusCodeOf(e);
    return switch (statusCode) {
      409 => 'Ese horario acaba de ser reservado, elige otro',
      400 => 'Revisa los datos: la fecha debe ser futura y la hora en punto',
      _ => 'No se pudo crear la reserva. Intenta de nuevo',
    };
  }

  int? _statusCodeOf(Object e) {
    try {
      final dynamic dyn = e;
      return dyn.response?.statusCode as int?;
    } catch (_) {
      return null;
    }
  }

  void _hint(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}

extension<T extends Object> on T {
  R let<R>(R Function(T) f) => f(this);
}

class _ResumenRow extends StatelessWidget {
  const _ResumenRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: GriColors.gray)),
          Text(value,
              style: const TextStyle(
                  fontWeight: FontWeight.bold, color: GriColors.text)),
        ],
      ),
    );
  }
}

class _PersonasSelector extends StatelessWidget {
  const _PersonasSelector({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.remove_circle_outline, size: 32),
          onPressed: value > 1 ? () => onChanged(value - 1) : null,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            '$value',
            style: const TextStyle(
                fontSize: 28, fontWeight: FontWeight.bold, color: GriColors.text),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.add_circle_outline, size: 32),
          onPressed: value < 20 ? () => onChanged(value + 1) : null,
        ),
      ],
    );
  }
}

/// Dropdown de restaurantes para el wizard sin preselect (FAB "+").
class _RestaurantePicker extends ConsumerWidget {
  const _RestaurantePicker({required this.selected, required this.onChanged});

  final Restaurante? selected;
  final ValueChanged<Restaurante> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(restaurantesListProvider);
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => const Text('No se pudieron cargar los restaurantes',
          style: TextStyle(color: GriColors.gray)),
      data: (list) => DropdownButtonFormField<Restaurante>(
        initialValue: selected,
        hint: const Text('Elige un restaurante'),
        decoration: const InputDecoration(
          border: OutlineInputBorder(),
          prefixIcon: Icon(Icons.restaurant),
        ),
        items: [
          for (final r in list) DropdownMenuItem(value: r, child: Text(r.nombre)),
        ],
        onChanged: (r) {
          if (r != null) onChanged(r);
        },
      ),
    );
  }
}
