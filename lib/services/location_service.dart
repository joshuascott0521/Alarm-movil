import 'dart:io';

import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

/// Problemas que impiden usar el GPS.
enum LocationIssue {
  serviceDisabled('Activa el GPS del teléfono para usar la alarma.'),
  denied('Necesitamos tu ubicación para saber cuándo llegas.'),
  deniedForever('El permiso de ubicación está bloqueado. Actívalo en Ajustes.');

  const LocationIssue(this.message);
  final String message;
}

/// Acceso al GPS, incluyendo seguimiento con la pantalla apagada.
class LocationService {
  /// Pide permisos de ubicación. Devuelve el problema encontrado o `null` si
  /// todo está bien.
  Future<LocationIssue?> ensurePermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return LocationIssue.serviceDisabled;
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) return LocationIssue.denied;
    if (permission == LocationPermission.deniedForever) {
      return LocationIssue.deniedForever;
    }
    return null;
  }

  /// Abre la pantalla de Ajustes adecuada para resolver [issue].
  Future<void> openSettings(LocationIssue issue) =>
      issue == LocationIssue.serviceDisabled
          ? Geolocator.openLocationSettings()
          : Geolocator.openAppSettings();

  Future<LatLng?> currentPosition() async {
    try {
      final last = await Geolocator.getLastKnownPosition();
      final p = last ?? await Geolocator.getCurrentPosition();
      return LatLng(p.latitude, p.longitude);
    } catch (_) {
      return null;
    }
  }

  /// Posiciones mientras la app está abierta y no hay viaje activo.
  Stream<Position> watch() => Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10,
        ),
      );

  /// Posiciones del viaje, que siguen llegando con la app en segundo plano.
  Stream<Position> track() {
    final LocationSettings settings;
    if (Platform.isAndroid) {
      settings = AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 15,
        intervalDuration: const Duration(seconds: 5),
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: 'Bájate está vigilando tu viaje',
          notificationText: 'Te avisaremos cuando estés cerca de tu parada.',
          notificationChannelName: 'Viaje en curso',
          notificationIcon:
              AndroidResource(name: 'ic_stat_bajate', defType: 'drawable'),
          enableWakeLock: true,
          setOngoing: true,
        ),
      );
    } else if (Platform.isIOS) {
      settings = AppleSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 15,
        activityType: ActivityType.automotiveNavigation,
        pauseLocationUpdatesAutomatically: false,
        showBackgroundLocationIndicator: true,
        allowBackgroundLocationUpdates: true,
      );
    } else {
      settings = const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 15,
      );
    }
    return Geolocator.getPositionStream(locationSettings: settings);
  }
}
