# GRI — Panel Administrativo

Panel web (Flutter Web) desde el que un restaurante gestiona mesas, reservas,
pedidos, menú, clientes, equipo y reportes; y desde el que el `super_admin` de
la plataforma da de alta restaurantes y su administrador inicial.

Habla **directo a Firebase** (Auth + Firestore + Cloud Functions): no hay backend
propio. Ver `docs/FIREBASE_SETUP.md` en la raíz del repo.

## Arranque

```bash
flutter pub get
flutter run -d chrome            # contra el proyecto Firebase real
flutter run -d chrome --dart-define=USE_EMULATORS=true   # contra emuladores
```

Primera vez en un proyecto vacío: `/bootstrap` crea el primer `super_admin`.
Runbook en `docs/FIREBASE_SETUP.md` §4.1.

## Comandos del proyecto

```bash
flutter analyze                  # debe dar 0 issues
flutter test                     # suite de widgets, providers y router
flutter build web --release
```

## Marca

Naranja GRI `#FF4C05`. Los iconos y el favicon **se generan** desde la app
cliente con `cd ../app_cliente && dart run tool/gen_branding.dart`, que escribe
los assets de LAS DOS apps. El gate `cd scripts && npm run audit:branding` falla
si algo vuelve a los valores por defecto de `flutter create`.
