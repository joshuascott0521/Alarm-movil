import 'package:alarm_movil/services/geocoding_service.dart';
import 'package:alarm_movil/services/places_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

Place _place(String name, double lat) =>
    Place(name: name, address: '', point: LatLng(lat, -74.0));

void main() {
  late PlacesStore store;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store = await PlacesStore.open();
  });

  test('guarda y quita favoritos', () async {
    final casa = _place('Casa', 4.6);
    await store.toggleFavorite(casa);
    expect(store.isFavorite(casa), isTrue);
    await store.toggleFavorite(casa);
    expect(store.favorites, isEmpty);
  });

  test('recientes sin duplicados, máximo 5 y sin favoritos', () async {
    for (var i = 0; i < 7; i++) {
      await store.addRecent(_place('P$i', 4.0 + i * 0.01));
    }
    await store.addRecent(_place('P6 otra vez', 4.06));
    expect(store.recents.map((p) => p.name),
        ['P6 otra vez', 'P5', 'P4', 'P3', 'P2']);

    await store.toggleFavorite(_place('P5', 4.05));
    expect(store.recents.map((p) => p.name), isNot(contains('P5')));
  });
}
