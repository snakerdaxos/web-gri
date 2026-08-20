// test/core/firebase_error_mapper_test.dart — el clasificador de fallos y sus
// mensajes (11-23).
//
// ── POR QUÉ EXISTE ESTE ARCHIVO ────────────────────────────────────────────
// El usuario escaneó el QR de una mesa y la app le dijo *"No pudimos abrir la
// mesa. Verifica el código e intenta de nuevo."*. Estuvo revisando el QR, que
// era CORRECTO. La causa real fue, primero, un `permission-denied` (su cuenta
// tenía rol `super_admin` y la regla de crear sesión exige `isCliente()`), y
// después que la app apuntaba a unos emuladores apagados. Dos causas sin nada
// en común entre sí, y ninguna de las dos tenía que ver con el código.
//
// La regresión que este archivo impide es EXACTAMENTE esa: que el mensaje de
// un `permission-denied` vuelva a hablar del código, del QR o de "verificar".
// El caso se llama «NO CONFUSIÓN» y afirma la ausencia de esas tres palabras.
import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gri_cliente/core/firebase_error_mapper.dart';

FirebaseException _fb(String code) =>
    FirebaseException(plugin: 'cloud_firestore', code: code);

void main() {
  group('clasificarFallo — de la excepción cruda a la causa de dominio', () {
    test('permission-denied → permisoDenegado', () {
      expect(clasificarFallo(_fb('permission-denied')),
          CausaFallo.permisoDenegado);
    });

    test('unauthenticated → permisoDenegado (es quién eres, no qué pediste)',
        () {
      expect(
          clasificarFallo(_fb('unauthenticated')), CausaFallo.permisoDenegado);
    });

    test('unavailable → sinConexion', () {
      expect(clasificarFallo(_fb('unavailable')), CausaFallo.sinConexion);
    });

    test('deadline-exceeded → sinConexion', () {
      expect(clasificarFallo(_fb('deadline-exceeded')), CausaFallo.sinConexion);
    });

    test('cancelled → sinConexion', () {
      expect(clasificarFallo(_fb('cancelled')), CausaFallo.sinConexion);
    });

    test('internal → sinConexion', () {
      expect(clasificarFallo(_fb('internal')), CausaFallo.sinConexion);
    });

    test('not-found → noEncontrado', () {
      expect(clasificarFallo(_fb('not-found')), CausaFallo.noEncontrado);
    });

    test('SocketException → sinConexion', () {
      expect(clasificarFallo(const SocketException('conexión rechazada')),
          CausaFallo.sinConexion);
    });

    test('TimeoutException → sinConexion', () {
      expect(clasificarFallo(TimeoutException('sin respuesta')),
          CausaFallo.sinConexion);
    });

    test(
        'cualquier otra excepción → desconocido (jamás se confunde con las anteriores)',
        () {
      // Ninguna de estas es de red ni de permisos, y el mapeador NO debe
      // fingir que sabe qué pasó.
      for (final e in <Object>[
        StateError('bad state'),
        ArgumentError('nope'),
        const FormatException('json roto'),
        _fb('aborted'),
        _fb('failed-precondition'),
        Exception('vete a saber'),
      ]) {
        final causa = clasificarFallo(e);
        expect(causa, CausaFallo.desconocido,
            reason: '$e no debe colarse en una causa concreta');
        expect(causa, isNot(CausaFallo.permisoDenegado));
        expect(causa, isNot(CausaFallo.sinConexion));
        expect(causa, isNot(CausaFallo.noEncontrado));
      }
    });

    test('un FirebaseException sin code reconocido NO se toma por fallo de red',
        () {
      // El bug original nace justo aquí: meterlo todo en el mismo saco.
      expect(clasificarFallo(_fb('unknown')), CausaFallo.desconocido);
    });
  });

  group('mensajeDe — un texto honesto por causa', () {
    test(
        'NO CONFUSIÓN: permisoDenegado no habla del código, del QR ni de verificar',
        () {
      // ESTA es la regresión del incidente real. Si algún día alguien vuelve a
      // redactar «verifica el código» para una denegación de permisos, este
      // caso se pone rojo.
      for (final contexto in Contexto.values) {
        final texto = mensajeDe(CausaFallo.permisoDenegado, contexto: contexto)
            .toLowerCase();
        expect(texto, isNot(contains('código')), reason: 'contexto $contexto');
        expect(texto, isNot(contains('codigo')), reason: 'contexto $contexto');
        expect(texto, isNot(contains('qr')), reason: 'contexto $contexto');
        expect(texto, isNot(contains('verifica')),
            reason: 'contexto $contexto');
        expect(texto, contains('cuenta'),
            reason: 'debe señalar la CUENTA como causa (contexto $contexto)');
      }
    });

    test('sinConexion habla de la conexión, en los cuatro contextos', () {
      for (final contexto in Contexto.values) {
        final texto =
            mensajeDe(CausaFallo.sinConexion, contexto: contexto).toLowerCase();
        expect(texto, contains('conex'), reason: 'contexto $contexto');
      }
    });

    test('sinConexion tampoco culpa al código ni al QR', () {
      for (final contexto in Contexto.values) {
        final texto =
            mensajeDe(CausaFallo.sinConexion, contexto: contexto).toLowerCase();
        expect(texto, isNot(contains('código')));
        expect(texto, isNot(contains('qr')));
        expect(texto, isNot(contains('verifica')));
      }
    });

    test('abrirMesa: las CINCO causas dan CINCO mensajes distintos', () {
      const causas = [
        CausaFallo.formatoInvalido,
        CausaFallo.noEncontrado,
        CausaFallo.noDisponible,
        CausaFallo.permisoDenegado,
        CausaFallo.sinConexion,
      ];
      final mensajes = [
        for (final c in causas) mensajeDe(c, contexto: Contexto.abrirMesa),
      ];
      // Comparación DOS A DOS: un `toSet().length` diría lo mismo pero sin
      // señalar qué par colisiona.
      for (var i = 0; i < mensajes.length; i++) {
        for (var j = i + 1; j < mensajes.length; j++) {
          expect(mensajes[i], isNot(mensajes[j]),
              reason: '${causas[i]} y ${causas[j]} comparten mensaje');
        }
        expect(mensajes[i].trim(), isNotEmpty);
      }
    });

    test(
        'formatoInvalido habla del formato del código; noEncontrado, de que la mesa no existe',
        () {
      final formato =
          mensajeDe(CausaFallo.formatoInvalido, contexto: Contexto.abrirMesa)
              .toLowerCase();
      final inexistente =
          mensajeDe(CausaFallo.noEncontrado, contexto: Contexto.abrirMesa)
              .toLowerCase();
      expect(formato, contains('código'));
      expect(inexistente, contains('no existe'));
      expect(formato, isNot(inexistente));
    });

    test('noDisponible conserva EXACTAMENTE el mensaje que ya era correcto',
        () {
      // Contrato con scan_test.dart y con el usuario: este texto ya acertaba y
      // el plan no lo cambia.
      expect(mensajeDe(CausaFallo.noDisponible, contexto: Contexto.abrirMesa),
          'La mesa no está disponible en este momento');
    });

    test('desconocido no atribuye la causa a nada que el usuario haya hecho',
        () {
      for (final contexto in Contexto.values) {
        final texto =
            mensajeDe(CausaFallo.desconocido, contexto: contexto).toLowerCase();
        expect(texto, isNot(contains('verifica')), reason: '$contexto');
        expect(texto, isNot(contains('código')), reason: '$contexto');
        expect(texto, isNot(contains('conexión')),
            reason: 'no sabemos que sea la red: $contexto');
        expect(texto.trim(), isNotEmpty);
      }
    });

    test('cada contexto redacta lo suyo: los mensajes de desconocido difieren',
        () {
      final textos = <String>{
        for (final c in Contexto.values)
          mensajeDe(CausaFallo.desconocido, contexto: c),
      };
      expect(textos.length, Contexto.values.length,
          reason: 'un mensaje por contexto, sin copiar y pegar');
    });
  });

  group('pista de emuladores — solo en builds de desarrollo', () {
    // OJO CON EL VERDE FÁCIL: la tentación es escribir
    //   expect(texto.contains(pistaEmuladores), usandoEmuladores)
    // pero eso compara la implementación consigo misma. Si alguien escribiera
    // `bool.fromEnvironment('USE_EMULATORS', defaultValue: true)`, la pista
    // aparecería en el binario de PRODUCCIÓN y ese caso seguiría verde,
    // porque los dos lados de la igualdad se moverían a la vez.
    //
    // Por eso la expectativa entra por un define INDEPENDIENTE, que solo
    // conoce el runner:
    //   flutter test                                   → sin pista (defecto)
    //   flutter test --dart-define=USE_EMULATORS=true \
    //               --dart-define=ESPERA_PISTA_EMULADORES=true → con pista
    // Ambas ejecuciones quedan registradas en 11-23-SUMMARY.md. No se pueden
    // observar a la vez: `bool.fromEnvironment` es constante de compilación.
    const esperaPista =
        bool.fromEnvironment('ESPERA_PISTA_EMULADORES', defaultValue: false);

    test('el define USE_EMULATORS gobierna la pista, y por defecto NO está',
        () {
      expect(usandoEmuladores, esperaPista,
          reason: 'sin --dart-define=USE_EMULATORS=true el flag debe ser false:'
              ' el defaultValue de bool.fromEnvironment es parte del contrato');
      for (final contexto in Contexto.values) {
        final texto = mensajeDe(CausaFallo.sinConexion, contexto: contexto);
        expect(texto.contains(pistaEmuladores), esperaPista,
            reason: 'la pista debe aparecer si y solo si el define está activo'
                ' (contexto $contexto)');
      }
    });

    test('la pista NUNCA se cuela en una causa que no sea sinConexion', () {
      for (final causa in CausaFallo.values) {
        if (causa == CausaFallo.sinConexion) continue;
        for (final contexto in Contexto.values) {
          expect(mensajeDe(causa, contexto: contexto),
              isNot(contains(pistaEmuladores)),
              reason: '$causa / $contexto');
        }
      }
    });

    test('la pista menciona los emuladores (es lo único que la hace útil)', () {
      expect(pistaEmuladores.toLowerCase(), contains('emulador'));
    });
  });
}
