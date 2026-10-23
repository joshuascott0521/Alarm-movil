import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'geocoding_service.dart';

/// Paradas favoritas y recientes, guardadas en el teléfono.
class PlacesStore {
  PlacesStore(this._prefs);

  static Future<PlacesStore> open() async =>
      PlacesStore(await SharedPreferences.getInstance());

  final SharedPreferences _prefs;
  static const _favoritesKey = 'favorites';
  static const _recentsKey = 'recents';
  static const _onboardingKey = 'onboarding_done';
  static const _radiusKey = 'radius';
  static const maxRecents = 5;

  List<Place> get favorites => _read(_favoritesKey);

  /// Recientes que no están ya en favoritos.
  List<Place> get recents => _read(_recentsKey)
      .where((r) => !favorites.any(r.isSameAs))
      .toList();

  bool isFavorite(Place place) => favorites.any(place.isSameAs);

  Future<void> toggleFavorite(Place place) {
    final list = favorites;
    if (list.any(place.isSameAs)) {
      list.removeWhere(place.isSameAs);
    } else {
      list.insert(0, place);
    }
    return _write(_favoritesKey, list);
  }

  Future<void> addRecent(Place place) {
    final list = _read(_recentsKey)
      ..removeWhere(place.isSameAs)
      ..insert(0, place);
    return _write(_recentsKey, list.take(maxRecents).toList());
  }

  bool get onboardingDone => _prefs.getBool(_onboardingKey) ?? false;
  Future<void> completeOnboarding() => _prefs.setBool(_onboardingKey, true);

  double? get lastRadius => _prefs.getDouble(_radiusKey);
  Future<void> saveRadius(double meters) => _prefs.setDouble(_radiusKey, meters);

  List<Place> _read(String key) {
    final raw = _prefs.getString(key);
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List<dynamic>)
          .map((e) => Place.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _write(String key, List<Place> places) => _prefs.setString(
      key, jsonEncode(places.map((p) => p.toJson()).toList()));
}
