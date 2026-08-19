# GRI — App Cliente

App móvil (Flutter, Android + web) con la que un comensal descubre restaurantes,
reserva mesa, escanea el QR de su mesa, pide del menú, sigue su pedido en tiempo
real y solicita la cuenta.

Habla **directo a Firebase** (Auth + Firestore + Cloud Functions): no hay backend
propio. Ver `docs/FIREBASE_SETUP.md` en la raíz del repo.

## Arranque

```bash
flutter pub get
flutter run -d chrome            # contra el proyecto Firebase real
flutter run -d chrome --dart-define=USE_EMULATORS=true   # contra emuladores
```

## Comandos del proyecto

```bash
flutter analyze                  # debe dar 0 issues
flutter test                     # suite de widgets y providers
dart run tool/gen_branding.dart  # regenera los assets de marca de LAS DOS apps
```

## Marca

Naranja GRI `#FF4C05`. Los iconos, el favicon y los assets de la PWA **se
generan** con `tool/gen_branding.dart` — no hay ningún binario aportado a mano.
El gate `cd scripts && npm run audit:branding` falla si algo vuelve a los
valores por defecto de `flutter create`.
