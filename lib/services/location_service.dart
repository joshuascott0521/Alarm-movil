import 'dart:io';

import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

/// Acceso al GPS, incluyendo seguimiento con la pantalla apagada.
class LocationService {
  /// Pide permisos de ubicación. Devuelve un mensaje de error o `null` si
  /// todo está bien.
  Future<String?> ensurePermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return 'Activa el GPS del teléfono para usar la alarma.';
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      return 'Necesitamos tu ubicación para saber cuándo llegas.';
    }
    if (permission == LocationPermission.deniedForever) {
      return 'El permiso de ubicación está bloqueado. Actívalo en Ajustes.';
    }
    return null;
  }

  Future<LatLng?> currentPosition() async {
    try {
      final p = await Geolocator.getCurrentPosition();
      return LatLng(p.latitude, p.longitude);
    } catch (_) {
      return null;
    }
  }

  /// Posiciones continuas que siguen llegando con la app en segundo plano.
  Stream<LatLng> track() {
    final LocationSettings settings;
    if (Platform.isAndroid) {
      settings = AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 15,
        intervalDuration: const Duration(seconds: 5),
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: 'Alarma de parada activa',
          notificationText: 'Te avisaremos cuando estés cerca de tu destino.',
          notificationChannelName: 'Seguimiento del viaje',
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
    return Geolocator.getPositionStream(locationSettings: settings)
        .map((p) => LatLng(p.latitude, p.longitude));
  }
}
