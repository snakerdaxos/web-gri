@echo off
cd /d C:\Users\valle\Documents\cel\app_cliente
set PATH=C:\src\flutter\bin;%PATH%
flutter run -d emulator-5554 --dart-define=USE_EMULATORS=true > C:\Users\valle\Documents\cel\flutter_run.log 2>&1