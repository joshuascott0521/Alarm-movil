import 'package:latlong2/latlong.dart';

/// Decide si el usuario ya está llegando a su parada.
class ArrivalChecker {
  ArrivalChecker({required this.destination, required this.radiusMeters});

  final LatLng destination;

  /// Distancia (en metros) a la que debe sonar la alarma.
  final double radiusMeters;

  static const _distance = Distance();

  double distanceTo(LatLng position) =>
      _distance.as(LengthUnit.Meter, position, destination);

  bool isArriving(LatLng position) => distanceTo(position) <= radiusMeters;
}

/// Suaviza la velocidad del GPS, que en un bus sube y baja a cada parada.
class SpeedSmoother {
  SpeedSmoother({this.weight = 0.3});

  final double weight;
  double? _value;

  double? get value => _value;

  void add(double metersPerSecond) {
    if (metersPerSecond.isNaN || metersPerSecond < 0) return;
    _value = _value == null
        ? metersPerSecond
        : _value! * (1 - weight) + metersPerSecond * weight;
  }
}

/// Minutos estimados hasta que suene la alarma, o `null` si el bus va
/// demasiado lento (parado, en un trancón) para estimarlo.
int? minutesUntilAlarm({
  required double remainingMeters,
  required double radiusMeters,
  required double? speedMps,
}) {
  if (speedMps == null || speedMps < 1.5) return null;
  final meters = remainingMeters - radiusMeters;
  if (meters <= 0) return 0;
  return (meters / speedMps / 60).ceil();
}

/// Texto legible para una distancia en metros ("850 m", "2,4 km").
String formatDistance(double meters) {
  if (meters < 1000) return '${meters.round()} m';
  return '${(meters / 1000).toStringAsFixed(1).replaceAll('.', ',')} km';
}
