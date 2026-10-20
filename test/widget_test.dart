import 'package:alarm_movil/logic/arrival_checker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  // ~0.001° de latitud equivale a ~111 m.
  const stop = LatLng(4.6097, -74.0817);
  final checker = ArrivalChecker(destination: stop, radiusMeters: 400);

  test('no suena cuando el bus está lejos', () {
    const far = LatLng(4.6197, -74.0817); // ~1,1 km
    expect(checker.isArriving(far), isFalse);
    expect(checker.distanceTo(far), closeTo(1106, 15));
  });

  test('suena al entrar en el radio', () {
    const near = LatLng(4.6127, -74.0817); // ~330 m
    expect(checker.isArriving(near), isTrue);
  });

  test('formatea distancias', () {
    expect(formatDistance(850.4), '850 m');
    expect(formatDistance(2400), '2,4 km');
  });
}
