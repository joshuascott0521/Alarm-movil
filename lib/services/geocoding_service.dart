import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// Un lugar: resultado de búsqueda, parada guardada o punto del mapa.
class Place {
  const Place({required this.name, required this.address, required this.point});

  final String name;
  final String address;
  final LatLng point;

  Place copyWith({String? name, String? address}) => Place(
        name: name ?? this.name,
        address: address ?? this.address,
        point: point,
      );

  /// Dos lugares a menos de 30 m se consideran el mismo.
  bool isSameAs(Place other) =>
      const Distance().as(LengthUnit.Meter, point, other.point) < 30;

  Map<String, Object> toJson() => {
        'name': name,
        'address': address,
        'lat': point.latitude,
        'lon': point.longitude,
      };

  factory Place.fromJson(Map<String, dynamic> json) => Place(
        name: json['name'] as String,
        address: json['address'] as String,
        point: LatLng(
          (json['lat'] as num).toDouble(),
          (json['lon'] as num).toDouble(),
        ),
      );
}

/// Busca direcciones con Photon (OpenStreetMap), sin API key.
///
/// Photon permite sugerencias mientras se escribe y búsqueda inversa
/// (de coordenadas a dirección).
class GeocodingService {
  GeocodingService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  static const _host = 'photon.komoot.io';

  /// Busca [query]. Si se conoce [near], prioriza resultados cercanos.
  Future<List<Place>> search(String query, {LatLng? near}) async {
    final body = await _get('/api/', {
      'q': query,
      'limit': '6',
      if (near != null) ...{
        'lat': '${near.latitude}',
        'lon': '${near.longitude}',
      },
    });
    return parsePhoton(body);
  }

  /// Nombre de la calle o lugar más cercano a [point], o `null`.
  Future<Place?> reverse(LatLng point) async {
    final body = await _get('/reverse', {
      'lat': '${point.latitude}',
      'lon': '${point.longitude}',
      'limit': '1',
    });
    final places = parsePhoton(body);
    if (places.isEmpty) return null;
    // Conservamos el punto exacto que tocó el usuario.
    return Place(name: places.first.name, address: places.first.address, point: point);
  }

  Future<String> _get(String path, Map<String, String> params) async {
    final response = await _client.get(
      Uri.https(_host, path, params),
      headers: {'User-Agent': 'Bajate/1.0 (com.alarmmovil.alarm_movil)'},
    );
    if (response.statusCode != 200) {
      throw Exception('Error ${response.statusCode} al buscar la dirección');
    }
    return utf8.decode(response.bodyBytes);
  }
}

/// Convierte la respuesta GeoJSON de Photon en lugares.
List<Place> parsePhoton(String body) {
  final features = (jsonDecode(body) as Map<String, dynamic>)['features']
      as List<dynamic>;
  final places = <Place>[];
  for (final f in features.cast<Map<String, dynamic>>()) {
    final props = f['properties'] as Map<String, dynamic>;
    final coords = (f['geometry'] as Map<String, dynamic>)['coordinates']
        as List<dynamic>;
    String? field(String key) {
      final v = props[key];
      return v is String && v.trim().isNotEmpty ? v.trim() : null;
    }

    final street = [field('street'), field('housenumber')]
        .whereType<String>()
        .join(' # ');
    final name = field('name') ??
        (street.isNotEmpty ? street : null) ??
        field('district') ??
        field('city') ??
        'Punto en el mapa';
    final address = <String>{
      if (street.isNotEmpty && street != name) street,
      ?field('district'),
      ?field('city'),
      ?field('state'),
    }.where((part) => part != name).join(', ');

    places.add(Place(
      name: name,
      address: address,
      point: LatLng(
        (coords[1] as num).toDouble(),
        (coords[0] as num).toDouble(),
      ),
    ));
  }
  return places;
}
