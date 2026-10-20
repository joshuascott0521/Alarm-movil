import 'package:alarm_movil/services/geocoding_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('interpreta la respuesta de Nominatim', () {
    const body = '''[
      {"lat": "4.6486", "lon": "-74.0631", "name": "Estación Calle 72",
       "display_name": "Estación Calle 72, Avenida Caracas, Bogotá, Colombia"},
      {"lat": "4.60", "lon": "-74.08", "name": "",
       "display_name": "Carrera 7, Bogotá, Colombia"}
    ]''';
    final places = parsePlaces(body);
    expect(places, hasLength(2));
    expect(places[0].name, 'Estación Calle 72');
    expect(places[0].point.latitude, 4.6486);
    expect(places[0].point.longitude, -74.0631);
    expect(places[1].name, 'Carrera 7');
  });
}
