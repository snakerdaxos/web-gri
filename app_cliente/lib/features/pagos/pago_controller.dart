import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api_client.dart';
import '../../core/env.dart';
import '../../models/pago.dart';

part 'pago_controller.g.dart';

/// Launcher del checkout — inyectable para tests (patrón backoffBuilder
/// de ws_client). La implementación real abre el navegador/pestaña del
/// sistema y SOLO se invoca desde un user gesture (Pitfall 8: browsers
/// bloquean programmatic launch).
final pagoLauncherProvider =
    Provider<Future<bool> Function(Uri url)>((ref) => (Uri url) => launchUrl(
          url,
          mode: LaunchMode.externalApplication,
        ));

/// Fases del flujo de pago (máquina de estados de la screen).
enum PagoFase {
  /// Sin intención aún (primer frame antes de iniciar()).
  idle,

  /// POSTeando la intención inicial.
  creando,

  /// Intención creada (server dice `pendiente`). [PagoFlowState.lanzado]
  /// distingue "aún no abre el checkout" de "esperando el pago".
  pendiente,

  /// GET /cliente/pagos/{id} dijo `aprobado` — única vía (threat 1).
  aprobado,

  /// GET dijo `rechazado` — reintento crea intención nueva.
  rechazado,

  /// Error creando la intención (p.ej. 409 pedidos en curso).
  error,
}

/// Estado inmutable del flujo de pago (hand-rolled copyWith — no amerita
/// freezed: clase privada de la feature).
class PagoFlowState {
  const PagoFlowState({
    this.fase = PagoFase.idle,
    this.intencion,
    this.ultimoEstado,
    this.lanzado = false,
    this.launchFallido = false,
    this.urlAbsoluta,
    this.errorDetail,
  });

  final PagoFase fase;
  final PagoIntencion? intencion;

  /// Último estado leído por poll() — sus [PagoEstado.pedidoIds] alimentan
  /// el sheet de calificación post-pago (Pitfall 6).
  final PagoEstado? ultimoEstado;

  /// El checkout ya fue abierto al menos una vez.
  final bool lanzado;

  /// launchUrl retornó false → la screen ofrece la URL (fallback).
  final bool launchFallido;

  /// checkout_url resuelta (absoluta) para el launcher y el fallback.
  final String? urlAbsoluta;

  /// `detail` del server cuando fase == error.
  final String? errorDetail;

  PagoFlowState copyWith({
    PagoFase? fase,
    PagoIntencion? intencion,
    PagoEstado? ultimoEstado,
    bool? lanzado,
    bool? launchFallido,
    String? urlAbsoluta,
    String? errorDetail,
  }) {
    return PagoFlowState(
      fase: fase ?? this.fase,
      intencion: intencion ?? this.intencion,
      ultimoEstado: ultimoEstado ?? this.ultimoEstado,
      lanzado: lanzado ?? this.lanzado,
      launchFallido: launchFallido ?? this.launchFallido,
      urlAbsoluta: urlAbsoluta ?? this.urlAbsoluta,
      errorDetail: errorDetail ?? this.errorDetail,
    );
  }
}

/// Orquesta el pago en línea de la cuenta de la sesión:
/// * [iniciar] → `POST /cliente/pagos/intencion` (idempotente server-side)
///   y queda `pendiente` SIN lanzar — el monto se muestra antes del tap.
/// * [pagar] → abre el checkout (launcher inyectable). User action only.
/// * [poll] → `GET /cliente/pagos/{id}`: la ÚNICA fuente de verdad del
///   estado (el retorno del checkout jamás muta nada — threat 1).
///
/// La screen monta el Timer 2.5s (solo poll() mientras `pendiente`) y
/// dispara poll() inmediato al volver del navegador (lifecycle resumed).
@riverpod
class PagoController extends _$PagoController {
  @override
  PagoFlowState build() => const PagoFlowState();

  /// Crea (o reutiliza) la intención de pago. Se llama al abrir la screen
  /// y al reintentar tras error/rechazo (en rechazado el pago anterior es
  /// terminal → el backend crea uno nuevo).
  Future<void> iniciar() async {
    state = state.copyWith(fase: PagoFase.creando);
    try {
      final i = await ref.read(apiClientProvider).crearIntencionPago();
      state = state.copyWith(
        fase: PagoFase.pendiente,
        intencion: i,
        lanzado: false,
        launchFallido: false,
        urlAbsoluta: _absoluta(i.checkoutUrl),
      );
    } on DioException catch (e) {
      state = state.copyWith(fase: PagoFase.error, errorDetail: _detail(e));
    } catch (_) {
      state = state.copyWith(
        fase: PagoFase.error,
        errorDetail: 'Error de conexión. Intenta de nuevo.',
      );
    }
  }

  /// User action (onPressed del botón Pagar): garantiza intención y abre
  /// el checkout externo. Si el launch falla, queda pendiente con
  /// launchFallido=true (la screen muestra la URL + botón reabrir).
  Future<void> pagar() async {
    if (state.fase == PagoFase.aprobado || state.fase == PagoFase.rechazado) {
      return;
    }
    if (state.intencion == null) {
      await iniciar();
      if (state.fase != PagoFase.pendiente || state.intencion == null) return;
    }
    await abrirCheckout();
  }

  /// (Re)abre el checkout — siempre desde un tap (Pitfall 8).
  Future<void> abrirCheckout() async {
    final url = state.urlAbsoluta;
    if (url == null) return;
    final ok = await ref.read(pagoLauncherProvider)(Uri.parse(url));
    state = state.copyWith(lanzado: true, launchFallido: !ok);
  }

  /// Consulta el estado real. Sin cambios de estado en `pendiente`
  /// (evita rebuilds cada tick); transiciones solo con la palabra del
  /// backend. Best-effort: errores de red se ignoran (el Timer reintenta).
  Future<void> poll() async {
    if (state.fase != PagoFase.pendiente) return;
    final id = state.intencion?.pagoId;
    if (id == null) return;
    try {
      final e = await ref.read(apiClientProvider).getPagoEstado(id);
      if (e.estado == 'aprobado' || e.estado == 'rechazado') {
        state = state.copyWith(
          fase: e.estado == 'aprobado' ? PagoFase.aprobado : PagoFase.rechazado,
          ultimoEstado: e,
        );
      }
    } catch (_) {
      // Polling es safety net: el próximo tick reintenta.
    }
  }

  /// checkout_url relativa (sandbox) → absoluta anteponiendo la base.
  String _absoluta(String url) =>
      url.startsWith('http') ? url : '${Env.apiBaseUrl}$url';

  /// Extrae `detail` del server (patrón _pedirCuenta del pedido_estado).
  String _detail(DioException e) {
    final data = e.response?.data;
    final detail = data is Map<String, dynamic> ? data['detail'] : null;
    return detail is String && detail.isNotEmpty
        ? detail
        : 'No pudimos iniciar el pago. Intenta de nuevo.';
  }
}
