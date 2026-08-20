import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/reloj.dart';
import '../../core/theme.dart';
import '../../models/restaurante.dart';
import '../../models/reserva_create.dart';
import '../restaurantes/restaurantes_provider.dart';
import '../../core/design_tokens.dart';
import 'reserva_controller.dart';

/// Wizard de reserva (RESV-01) — Stepper fecha → hora → personas → confirmar
/// → `POST /cliente/reservas` vía [ReservaController].
///
/// * Fecha: [showDatePicker] con firstDate = [primeraFechaReservable], que
///   desde 11-31 es HOY siempre que al día le quede algún slot con las 4 h
///   de margen (decisión del usuario 2026-08-20). Antes era siempre mañana.
/// * Hora: dropdown de slots :00 exclusivamente (12:00..21:00) FILTRADO por
///   [horasReservablesEn] — el mismo predicado que valida `crearReserva`,
///   para que el desplegable no pueda ofrecer lo que luego se rechaza — el turno
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

  /// Slots horarios del turno (hourly, :00). Desde 11-31 la lista vive en el
  /// dominio (`horasSlotReserva`) porque el mensaje de error del margen tiene
  /// que nombrar el primer horario válido: la rejilla que se pinta y la que
  /// se cita en el texto TIENEN que ser la misma. Aquí queda el alias.
  static const horasSlot = horasSlotReserva;

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

  // ── EL MARGEN, LEÍDO DE UN SOLO SITIO (11-31) ──────────────────────────
  // Ni el calendario ni el desplegable ni el botón deciden nada por su
  // cuenta: los tres consultan las funciones del dominio, que a su vez
  // llaman a `slotRespetaMargen` — el mismo predicado que aplica
  // `crearReserva`. Por eso el picker no puede ofrecer lo que la validación
  // rechaza.
  DateTime get _ahora => ref.read(relojProvider)();

  /// Las horas que el día elegido todavía admite. Se recalcula en CADA build,
  /// así que si el usuario deja la pantalla abierta y el reloj corre, la
  /// lista se encoge sola.
  List<String> get _horasDisponibles => _fecha == null
      ? const <String>[]
      : horasReservablesEn(_fecha!, _ahora);

  /// La hora elegida sigue siendo válida AHORA (no solo cuando se eligió).
  bool get _horaEsValida =>
      _hora != null && _horasDisponibles.contains(_hora);

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
            padding: const EdgeInsets.only(top: GriSpacing.md),
            // 11-13: `Wrap` en vez de `Row`. Mientras los dos botones quepan
            // se comporta EXACTAMENTE igual que el Row (misma fila, mismos
            // 8px de separación); cuando no caben, baja el segundo a otra
            // línea en vez de desbordar. Un `Row` no puede encoger un botón,
            // así que aquí no bastaba un `Expanded`.
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: details.onStepContinue,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: GriColors.primary,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Continuar'),
                ),
                if (_currentStep > 0)
                  TextButton(
                    onPressed: details.onStepCancel,
                    child: const Text('Atrás'),
                  ),
              ],
            ),
          );
        },
        steps: steps,
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(GriSpacing.md),
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
                textStyle: GriText.botonGrande,
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
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextButton.icon(
                onPressed: _pickFecha,
                icon: const Icon(Icons.calendar_month),
                label: Text(_fecha == null ? 'Elegir fecha' : _fechaString),
              ),
              Text(
                'Puedes reservar para hoy con al menos 4 horas de antelación.',
                style: GriText.auxiliar
                    .copyWith(color: GriColors.textoSecundarioAccesible),
              ),
            ],
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
            child: _horasDisponibles.isEmpty
                ? Text(
                    _fecha == null
                        ? 'Elige primero una fecha.'
                        : 'Ese día ya no queda ningún horario con 4 horas de '
                            'antelación. Vuelve al paso anterior y elige otro '
                            'día.',
                    style: GriText.auxiliar
                        .copyWith(color: GriColors.textoSecundarioAccesible),
                  )
                : DropdownButtonFormField<String>(
              // El `initialValue` cae a null si la hora que había elegida se
              // quedó sin margen mientras la pantalla estaba abierta: un
              // Dropdown con un `value` que no está en `items` revienta.
              initialValue: _horaEsValida ? _hora : null,
              // 11-13: sin `isExpanded` el Row interno del dropdown se maqueta
              // al ancho NATURAL de su contenido y desborda en pantallas
              // estrechas o con el texto ampliado por accesibilidad. El campo
              // ya ocupaba todo el ancho disponible (lo pone el
              // InputDecorator), así que la flecha no se mueve.
              isExpanded: true,
              hint: const Text('Elige una hora'),
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.schedule),
              ),
              items: [
                for (final h in _horasDisponibles)
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
        const SizedBox(height: GriSpacing.sm),
        // El reloj corrió con la pantalla abierta: la hora elegida ya no
        // cumple el margen. Se DICE, en vez de dejar un botón apagado sin
        // explicación.
        if (_hora != null && !_horaEsValida)
          Padding(
            padding: const EdgeInsets.only(bottom: GriSpacing.sm),
            child: Text(
              'Ese horario ya no cumple las 4 horas de antelación. Vuelve al '
              'paso Hora y elige otro.',
              style: GriText.auxiliar
                  .copyWith(color: GriColors.chipCanceladaFg),
            ),
          ),
        Text(
          'Al confirmar, el sistema te asignará una mesa automáticamente.',
          style: GriText.auxiliar.copyWith(color: GriColors.textoSecundarioAccesible),
        ),
      ],
    );
  }

  static String _fmt(DateTime f) =>
      '${f.year.toString().padLeft(4, '0')}-'
      '${f.month.toString().padLeft(2, '0')}-'
      '${f.day.toString().padLeft(2, '0')}';

  Future<void> _pickFecha() async {
    // 11-31: el calendario abre en HOY salvo que a hoy ya no le quede ningún
    // slot con las 4 h de margen (a partir de las 17:01, porque el turno
    // acaba a las 21:00). Antes empezaba SIEMPRE en mañana y el día de hoy
    // era literalmente inseleccionable.
    final primera = primeraFechaReservable(_ahora);
    final inicial =
        (_fecha != null && !_fecha!.isBefore(primera)) ? _fecha! : primera;
    final picked = await showDatePicker(
      context: context,
      firstDate: primera,
      lastDate: DateTime(primera.year, primera.month, primera.day + 365),
      initialDate: inicial,
    );
    if (picked != null) setState(() => _fecha = picked);
  }

  void _onContinue() {
    // Validación pre-avance (threat 5): cada step exige su dato.
    if (_currentStep == _stepFecha && _fecha == null) {
      _hint('Elige una fecha para continuar');
      return;
    }
    if (_currentStep == _stepHora && !_horaEsValida) {
      _hint(_horasDisponibles.isEmpty
          ? 'Ese día ya no queda ningún horario con 4 horas de antelación'
          : 'Elige una hora para continuar');
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
    return tieneRestaurante && _fecha != null && _horaEsValida;
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

  /// Mappea el error del dominio a un mensaje user-friendly (threat 6) —
  /// JAMÁS un stack trace o detail crudo. El controller ya entrega
  /// [ReservaException] con el texto listo (mismos textos de la era REST).
  String _errorMsg(Object e) => e is ReservaException
      ? e.message
      : 'No se pudo crear la reserva. Intenta de nuevo';

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
          Text(label, style: const TextStyle(color: GriColors.textoSecundarioAccesible)),
          // 11-13: el valor va en Expanded + ellipsis. Un `Row` reparte
          // restricciones INFINITAS de ancho a sus hijos, así que el `Text`
          // se maquetaba a su ancho natural y desbordaba en cuanto el nombre
          // del restaurante era largo (medido: 41px a 320 y 616px a 480 con
          // 60 caracteres). El `Expanded` le da el hueco REAL que queda y el
          // `textAlign: end` mantiene el valor pegado a la derecha, que es
          // exactamente donde lo dejaba el `spaceBetween`.
          // Ni tipografía ni espaciado cambian.
          Expanded(
            child: Text(value,
                textAlign: TextAlign.end,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, color: GriColors.text)),
          ),
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
          // 11-14: control de icono sin texto al lado -> necesita etiqueta.
          tooltip: 'Quitar un comensal',
          onPressed: value > 1 ? () => onChanged(value - 1) : null,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: GriSpacing.lg),
          child: Text(
            '$value',
            style: const TextStyle(
                fontSize: 28, fontWeight: FontWeight.bold, color: GriColors.text),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.add_circle_outline, size: 32),
          tooltip: 'Agregar un comensal',
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
          style: TextStyle(color: GriColors.textoSecundarioAccesible)),
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
