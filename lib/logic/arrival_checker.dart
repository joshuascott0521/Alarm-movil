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

/// Texto legible para una distancia en metros ("850 m", "2,4 km").
String formatDistance(double meters) {
  if (meters < 1000) return '${meters.round()} m';
  return '${(meters / 1000).toStringAsFixed(1).replaceAll('.', ',')} km';
}
