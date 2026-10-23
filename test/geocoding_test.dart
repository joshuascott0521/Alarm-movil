import 'package:alarm_movil/services/geocoding_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  test('interpreta la respuesta de Photon', () {
    const body = '''{"features": [
      {"geometry": {"coordinates": [-74.0631, 4.6486]},
       "properties": {"name": "Estación Calle 72", "street": "Avenida Caracas",
                      "city": "Bogotá", "state": "Bogotá D.C."}},
      {"geometry": {"coordinates": [-74.08, 4.60]},
       "properties": {"street": "Carrera 7", "housenumber": "45-10",
                      "district": "Chapinero", "city": "Bogotá"}}
    ]}''';
    final places = parsePhoton(body);
    expect(places, hasLength(2));
    expect(places[0].name, 'Estación Calle 72');
    expect(places[0].address, 'Avenida Caracas, Bogotá, Bogotá D.C.');
    expect(places[0].point, const LatLng(4.6486, -74.0631));
    expect(places[1].name, 'Carrera 7 # 45-10');
    expect(places[1].address, 'Chapinero, Bogotá');
  });

  test('un lugar se guarda y se recupera igual', () {
    const place = Place(
      name: 'Casa',
      address: 'Chapinero, Bogotá',
      point: LatLng(4.65, -74.06),
    );
    final copy = Place.fromJson(place.toJson());
    expect(copy.name, 'Casa');
    expect(copy.point, place.point);
    expect(copy.isSameAs(place), isTrue);
  });
}
