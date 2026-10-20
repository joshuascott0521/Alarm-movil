import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// Un lugar encontrado por la búsqueda de direcciones.
class Place {
  const Place({required this.name, required this.address, required this.point});

  final String name;
  final String address;
  final LatLng point;
}

/// Busca direcciones con Nominatim (OpenStreetMap), sin API key.
class GeocodingService {
  GeocodingService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  /// Busca [query]. Si se conoce [near], prioriza resultados cercanos.
  Future<List<Place>> search(String query, {LatLng? near}) async {
    final params = {
      'q': query,
      'format': 'jsonv2',
      'limit': '6',
      'accept-language': 'es',
      if (near != null) ...{
        // Caja de ~50 km alrededor del usuario para priorizar su ciudad.
        'viewbox': '${near.longitude - 0.5},${near.latitude + 0.5},'
            '${near.longitude + 0.5},${near.latitude - 0.5}',
        'bounded': '0',
      },
    };
    final uri = Uri.https('nominatim.openstreetmap.org', '/search', params);
    final response = await _client.get(uri, headers: {
      // Nominatim exige identificar la app.
      'User-Agent': 'AlarmaDeParada/1.0 (com.alarmmovil.alarm_movil)',
    });
    if (response.statusCode != 200) {
      throw Exception('Error ${response.statusCode} al buscar la dirección');
    }
    return parsePlaces(utf8.decode(response.bodyBytes));
  }
}

List<Place> parsePlaces(String body) {
  final results = jsonDecode(body) as List<dynamic>;
  return [
    for (final r in results.cast<Map<String, dynamic>>())
      Place(
        name: (r['name'] as String?)?.isNotEmpty == true
            ? r['name'] as String
            : (r['display_name'] as String).split(',').first,
        address: r['display_name'] as String,
        point: LatLng(
          double.parse(r['lat'] as String),
          double.parse(r['lon'] as String),
        ),
      ),
  ];
}
