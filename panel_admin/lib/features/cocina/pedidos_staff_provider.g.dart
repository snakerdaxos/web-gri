// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pedidos_staff_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Cola de cocina EN VIVO (MIGRA-05): `pedidos where restauranteId == rid
/// where estado in [enviado, aceptado, en_preparacion] orderBy createdAt
/// ASC → snapshots()` (índice compuesto 10-01). Un pedido que pasa a
/// `servido`/`rechazado` desaparece del stream SOLO — sin invalidate ni
/// refetch (el server es la fuente de verdad).
///
/// El rid viene de [ridActivoProvider] (claims/selección — nunca input
/// libre; Pitfall 4). Watches ANTES del primer await (lección 07-03).

@ProviderFor(pedidosStaff)
final pedidosStaffProvider = PedidosStaffProvider._();

/// Cola de cocina EN VIVO (MIGRA-05): `pedidos where restauranteId == rid
/// where estado in [enviado, aceptado, en_preparacion] orderBy createdAt
/// ASC → snapshots()` (índice compuesto 10-01). Un pedido que pasa a
/// `servido`/`rechazado` desaparece del stream SOLO — sin invalidate ni
/// refetch (el server es la fuente de verdad).
///
/// El rid viene de [ridActivoProvider] (claims/selección — nunca input
/// libre; Pitfall 4). Watches ANTES del primer await (lección 07-03).

final class PedidosStaffProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<PedidoStaff>>,
          List<PedidoStaff>,
          Stream<List<PedidoStaff>>
        >
    with
        $FutureModifier<List<PedidoStaff>>,
        $StreamProvider<List<PedidoStaff>> {
  /// Cola de cocina EN VIVO (MIGRA-05): `pedidos where restauranteId == rid
  /// where estado in [enviado, aceptado, en_preparacion] orderBy createdAt
  /// ASC → snapshots()` (índice compuesto 10-01). Un pedido que pasa a
  /// `servido`/`rechazado` desaparece del stream SOLO — sin invalidate ni
  /// refetch (el server es la fuente de verdad).
  ///
  /// El rid viene de [ridActivoProvider] (claims/selección — nunca input
  /// libre; Pitfall 4). Watches ANTES del primer await (lección 07-03).
  PedidosStaffProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'pedidosStaffProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$pedidosStaffHash();

  @$internal
  @override
  $StreamProviderElement<List<PedidoStaff>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<PedidoStaff>> create(Ref ref) {
    return pedidosStaff(ref);
  }
}

String _$pedidosStaffHash() => r'54251b25f744c875c7a2326921362e8edb7b1690';

/// Avisos de cuenta EN VIVO para el badge de cocina: `sesiones where
/// restauranteId == rid where cuentaSolicitada == true where estado ==
/// 'activa' → snapshots()`. Cuando el mesero entrega la cuenta la sesión
/// pasa a `cerrada` y el aviso desaparece solo.

@ProviderFor(avisoCuenta)
final avisoCuentaProvider = AvisoCuentaProvider._();

/// Avisos de cuenta EN VIVO para el badge de cocina: `sesiones where
/// restauranteId == rid where cuentaSolicitada == true where estado ==
/// 'activa' → snapshots()`. Cuando el mesero entrega la cuenta la sesión
/// pasa a `cerrada` y el aviso desaparece solo.

final class AvisoCuentaProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<AvisoCuenta>>,
          List<AvisoCuenta>,
          Stream<List<AvisoCuenta>>
        >
    with
        $FutureModifier<List<AvisoCuenta>>,
        $StreamProvider<List<AvisoCuenta>> {
  /// Avisos de cuenta EN VIVO para el badge de cocina: `sesiones where
  /// restauranteId == rid where cuentaSolicitada == true where estado ==
  /// 'activa' → snapshots()`. Cuando el mesero entrega la cuenta la sesión
  /// pasa a `cerrada` y el aviso desaparece solo.
  AvisoCuentaProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'avisoCuentaProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$avisoCuentaHash();

  @$internal
  @override
  $StreamProviderElement<List<AvisoCuenta>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<AvisoCuenta>> create(Ref ref) {
    return avisoCuenta(ref);
  }
}

String _$avisoCuentaHash() => r'1a29e5641a3029f59dcec1001a94ae177b5aa684';

/// Los pedidos YA SERVIDOS de la sesión abierta en [mesaId] — la cuenta que
/// el mesero tiene que cobrar (plan 11-32).
///
/// ── POR QUÉ ESTA FORMA DE CONSULTA Y NO OTRA ─────────────────────────
/// Lo natural sería `where('sesionId') + where('estado')`. No se puede, por
/// dos motivos independientes y los dos verificables sin desplegar:
///
///  1. RULES. Firestore evalúa las rules contra la CONSULTA, no contra los
///     documentos devueltos. La rama de staff de `/pedidos` es
///     `staffOf(resource.data.restauranteId)`, así que la query DEBE llevar
///     `where('restauranteId', isEqualTo: rid)` o se deniega ENTERA — el
///     mismo modo de fallo del menú (11-03) y del listener del cliente
///     (11-28). Lo vigila `scripts/audit_indexes.mjs` (AUDIT 2/4).
///  2. ÍNDICES. `pedidos(restauranteId, estado, createdAt ASC)` YA existe en
///     `firestore.indexes.json` (lo usa la cola de cocina). Con igualdad en
///     los dos primeros campos y RANGO en `createdAt`, ese mismo índice sirve
///     a esta consulta: 11-32 no necesita índice nuevo ni despliegue.
///
/// ── LA VENTANA `createdAt >= inicioAt` NO ES UNA OPTIMIZACIÓN ──────────
/// `sesiones/{mesaId}` tiene doc ID DETERMINISTA y `abrirSesion()` hace
/// `tx.set()` sobre el MISMO documento en cada visita. Los pedidos de la
/// visita anterior conservan su `sesionId`, así que sin acotar por el
/// `inicioAt` de la sesión VIGENTE el mesero le cobraría a este comensal la
/// cena del anterior. Además acota lo que se lee: sin ella la consulta
/// crecería con todo el histórico de pedidos servidos del restaurante.
///
/// Si no hay doc de sesión (o no trae `inicioAt`) se cae a una ventana de 24
/// horas: la FORMA de la consulta no cambia nunca — el audit estático la
/// parsea siempre igual y el índice sirve en los dos casos.
///
/// El filtro final por `sesionId` es client-side a propósito: añadirlo a la
/// query obligaría a un índice nuevo y el conjunto que llega ya está acotado
/// al restaurante y a la ventana de la sesión.

@ProviderFor(pedidosServidosMesa)
final pedidosServidosMesaProvider = PedidosServidosMesaFamily._();

/// Los pedidos YA SERVIDOS de la sesión abierta en [mesaId] — la cuenta que
/// el mesero tiene que cobrar (plan 11-32).
///
/// ── POR QUÉ ESTA FORMA DE CONSULTA Y NO OTRA ─────────────────────────
/// Lo natural sería `where('sesionId') + where('estado')`. No se puede, por
/// dos motivos independientes y los dos verificables sin desplegar:
///
///  1. RULES. Firestore evalúa las rules contra la CONSULTA, no contra los
///     documentos devueltos. La rama de staff de `/pedidos` es
///     `staffOf(resource.data.restauranteId)`, así que la query DEBE llevar
///     `where('restauranteId', isEqualTo: rid)` o se deniega ENTERA — el
///     mismo modo de fallo del menú (11-03) y del listener del cliente
///     (11-28). Lo vigila `scripts/audit_indexes.mjs` (AUDIT 2/4).
///  2. ÍNDICES. `pedidos(restauranteId, estado, createdAt ASC)` YA existe en
///     `firestore.indexes.json` (lo usa la cola de cocina). Con igualdad en
///     los dos primeros campos y RANGO en `createdAt`, ese mismo índice sirve
///     a esta consulta: 11-32 no necesita índice nuevo ni despliegue.
///
/// ── LA VENTANA `createdAt >= inicioAt` NO ES UNA OPTIMIZACIÓN ──────────
/// `sesiones/{mesaId}` tiene doc ID DETERMINISTA y `abrirSesion()` hace
/// `tx.set()` sobre el MISMO documento en cada visita. Los pedidos de la
/// visita anterior conservan su `sesionId`, así que sin acotar por el
/// `inicioAt` de la sesión VIGENTE el mesero le cobraría a este comensal la
/// cena del anterior. Además acota lo que se lee: sin ella la consulta
/// crecería con todo el histórico de pedidos servidos del restaurante.
///
/// Si no hay doc de sesión (o no trae `inicioAt`) se cae a una ventana de 24
/// horas: la FORMA de la consulta no cambia nunca — el audit estático la
/// parsea siempre igual y el índice sirve en los dos casos.
///
/// El filtro final por `sesionId` es client-side a propósito: añadirlo a la
/// query obligaría a un índice nuevo y el conjunto que llega ya está acotado
/// al restaurante y a la ventana de la sesión.

final class PedidosServidosMesaProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<PedidoStaff>>,
          List<PedidoStaff>,
          Stream<List<PedidoStaff>>
        >
    with
        $FutureModifier<List<PedidoStaff>>,
        $StreamProvider<List<PedidoStaff>> {
  /// Los pedidos YA SERVIDOS de la sesión abierta en [mesaId] — la cuenta que
  /// el mesero tiene que cobrar (plan 11-32).
  ///
  /// ── POR QUÉ ESTA FORMA DE CONSULTA Y NO OTRA ─────────────────────────
  /// Lo natural sería `where('sesionId') + where('estado')`. No se puede, por
  /// dos motivos independientes y los dos verificables sin desplegar:
  ///
  ///  1. RULES. Firestore evalúa las rules contra la CONSULTA, no contra los
  ///     documentos devueltos. La rama de staff de `/pedidos` es
  ///     `staffOf(resource.data.restauranteId)`, así que la query DEBE llevar
  ///     `where('restauranteId', isEqualTo: rid)` o se deniega ENTERA — el
  ///     mismo modo de fallo del menú (11-03) y del listener del cliente
  ///     (11-28). Lo vigila `scripts/audit_indexes.mjs` (AUDIT 2/4).
  ///  2. ÍNDICES. `pedidos(restauranteId, estado, createdAt ASC)` YA existe en
  ///     `firestore.indexes.json` (lo usa la cola de cocina). Con igualdad en
  ///     los dos primeros campos y RANGO en `createdAt`, ese mismo índice sirve
  ///     a esta consulta: 11-32 no necesita índice nuevo ni despliegue.
  ///
  /// ── LA VENTANA `createdAt >= inicioAt` NO ES UNA OPTIMIZACIÓN ──────────
  /// `sesiones/{mesaId}` tiene doc ID DETERMINISTA y `abrirSesion()` hace
  /// `tx.set()` sobre el MISMO documento en cada visita. Los pedidos de la
  /// visita anterior conservan su `sesionId`, así que sin acotar por el
  /// `inicioAt` de la sesión VIGENTE el mesero le cobraría a este comensal la
  /// cena del anterior. Además acota lo que se lee: sin ella la consulta
  /// crecería con todo el histórico de pedidos servidos del restaurante.
  ///
  /// Si no hay doc de sesión (o no trae `inicioAt`) se cae a una ventana de 24
  /// horas: la FORMA de la consulta no cambia nunca — el audit estático la
  /// parsea siempre igual y el índice sirve en los dos casos.
  ///
  /// El filtro final por `sesionId` es client-side a propósito: añadirlo a la
  /// query obligaría a un índice nuevo y el conjunto que llega ya está acotado
  /// al restaurante y a la ventana de la sesión.
  PedidosServidosMesaProvider._({
    required PedidosServidosMesaFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'pedidosServidosMesaProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$pedidosServidosMesaHash();

  @override
  String toString() {
    return r'pedidosServidosMesaProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<List<PedidoStaff>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<PedidoStaff>> create(Ref ref) {
    final argument = this.argument as String;
    return pedidosServidosMesa(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is PedidosServidosMesaProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$pedidosServidosMesaHash() =>
    r'9595eaa952e729e395c968ebd3016e2e4842238c';

/// Los pedidos YA SERVIDOS de la sesión abierta en [mesaId] — la cuenta que
/// el mesero tiene que cobrar (plan 11-32).
///
/// ── POR QUÉ ESTA FORMA DE CONSULTA Y NO OTRA ─────────────────────────
/// Lo natural sería `where('sesionId') + where('estado')`. No se puede, por
/// dos motivos independientes y los dos verificables sin desplegar:
///
///  1. RULES. Firestore evalúa las rules contra la CONSULTA, no contra los
///     documentos devueltos. La rama de staff de `/pedidos` es
///     `staffOf(resource.data.restauranteId)`, así que la query DEBE llevar
///     `where('restauranteId', isEqualTo: rid)` o se deniega ENTERA — el
///     mismo modo de fallo del menú (11-03) y del listener del cliente
///     (11-28). Lo vigila `scripts/audit_indexes.mjs` (AUDIT 2/4).
///  2. ÍNDICES. `pedidos(restauranteId, estado, createdAt ASC)` YA existe en
///     `firestore.indexes.json` (lo usa la cola de cocina). Con igualdad en
///     los dos primeros campos y RANGO en `createdAt`, ese mismo índice sirve
///     a esta consulta: 11-32 no necesita índice nuevo ni despliegue.
///
/// ── LA VENTANA `createdAt >= inicioAt` NO ES UNA OPTIMIZACIÓN ──────────
/// `sesiones/{mesaId}` tiene doc ID DETERMINISTA y `abrirSesion()` hace
/// `tx.set()` sobre el MISMO documento en cada visita. Los pedidos de la
/// visita anterior conservan su `sesionId`, así que sin acotar por el
/// `inicioAt` de la sesión VIGENTE el mesero le cobraría a este comensal la
/// cena del anterior. Además acota lo que se lee: sin ella la consulta
/// crecería con todo el histórico de pedidos servidos del restaurante.
///
/// Si no hay doc de sesión (o no trae `inicioAt`) se cae a una ventana de 24
/// horas: la FORMA de la consulta no cambia nunca — el audit estático la
/// parsea siempre igual y el índice sirve en los dos casos.
///
/// El filtro final por `sesionId` es client-side a propósito: añadirlo a la
/// query obligaría a un índice nuevo y el conjunto que llega ya está acotado
/// al restaurante y a la ventana de la sesión.

final class PedidosServidosMesaFamily extends $Family
    with $FunctionalFamilyOverride<Stream<List<PedidoStaff>>, String> {
  PedidosServidosMesaFamily._()
    : super(
        retry: null,
        name: r'pedidosServidosMesaProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Los pedidos YA SERVIDOS de la sesión abierta en [mesaId] — la cuenta que
  /// el mesero tiene que cobrar (plan 11-32).
  ///
  /// ── POR QUÉ ESTA FORMA DE CONSULTA Y NO OTRA ─────────────────────────
  /// Lo natural sería `where('sesionId') + where('estado')`. No se puede, por
  /// dos motivos independientes y los dos verificables sin desplegar:
  ///
  ///  1. RULES. Firestore evalúa las rules contra la CONSULTA, no contra los
  ///     documentos devueltos. La rama de staff de `/pedidos` es
  ///     `staffOf(resource.data.restauranteId)`, así que la query DEBE llevar
  ///     `where('restauranteId', isEqualTo: rid)` o se deniega ENTERA — el
  ///     mismo modo de fallo del menú (11-03) y del listener del cliente
  ///     (11-28). Lo vigila `scripts/audit_indexes.mjs` (AUDIT 2/4).
  ///  2. ÍNDICES. `pedidos(restauranteId, estado, createdAt ASC)` YA existe en
  ///     `firestore.indexes.json` (lo usa la cola de cocina). Con igualdad en
  ///     los dos primeros campos y RANGO en `createdAt`, ese mismo índice sirve
  ///     a esta consulta: 11-32 no necesita índice nuevo ni despliegue.
  ///
  /// ── LA VENTANA `createdAt >= inicioAt` NO ES UNA OPTIMIZACIÓN ──────────
  /// `sesiones/{mesaId}` tiene doc ID DETERMINISTA y `abrirSesion()` hace
  /// `tx.set()` sobre el MISMO documento en cada visita. Los pedidos de la
  /// visita anterior conservan su `sesionId`, así que sin acotar por el
  /// `inicioAt` de la sesión VIGENTE el mesero le cobraría a este comensal la
  /// cena del anterior. Además acota lo que se lee: sin ella la consulta
  /// crecería con todo el histórico de pedidos servidos del restaurante.
  ///
  /// Si no hay doc de sesión (o no trae `inicioAt`) se cae a una ventana de 24
  /// horas: la FORMA de la consulta no cambia nunca — el audit estático la
  /// parsea siempre igual y el índice sirve en los dos casos.
  ///
  /// El filtro final por `sesionId` es client-side a propósito: añadirlo a la
  /// query obligaría a un índice nuevo y el conjunto que llega ya está acotado
  /// al restaurante y a la ventana de la sesión.

  PedidosServidosMesaProvider call(String mesaId) =>
      PedidosServidosMesaProvider._(argument: mesaId, from: this);

  @override
  String toString() => r'pedidosServidosMesaProvider';
}
