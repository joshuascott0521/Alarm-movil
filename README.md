# Alarma de parada 🚌⏰

¿Te pasas de tu parada cuando vas dormido o distraído en el bus?
Marca en el mapa dónde te vas a bajar y la app hará sonar una alarma
cuando estés llegando.

## Cómo funciona

1. Abre la app: el mapa se centra en tu ubicación.
2. Toca el mapa en el punto donde te vas a bajar.
3. Elige a qué distancia quieres que te avise (100 m – 2 km).
4. Pulsa **Activar alarma**. Puedes bloquear el teléfono.
5. Al entrar en ese radio suena la alarma del sistema y aparece una
   notificación. Pulsa **Detener alarma**.

## Tecnología

- [Flutter](https://flutter.dev) (Android e iOS)
- `flutter_map` + OpenStreetMap para el mapa (no requiere API key)
- `geolocator` para el GPS, con servicio en primer plano en Android para
  seguir funcionando con la pantalla apagada
- `flutter_ringtone_player` + `flutter_local_notifications` para la alarma

## Estructura

- `lib/main.dart` — punto de entrada
- `lib/screens/map_screen.dart` — pantalla principal con el mapa
- `lib/logic/arrival_checker.dart` — cálculo de distancia y llegada
- `lib/services/location_service.dart` — permisos y seguimiento GPS
- `lib/services/alarm_service.dart` — sonido y notificación de la alarma

## Desarrollo

```bash
flutter pub get
flutter run       # con un teléfono o emulador conectado
flutter analyze   # análisis estático
flutter test      # pruebas
```

> Para probar en emulador, simula la ruta desde *Extended controls →
> Location* (Android) o *Features → Location* (simulador iOS).
