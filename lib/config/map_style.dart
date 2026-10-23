import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

/// Capas de mapa claras y oscuras de CARTO, basadas en OpenStreetMap.
///
/// Son gratuitas para uso no comercial. Para publicar la app con fines
/// comerciales conviene cambiarlas por un proveedor con API key (MapTiler,
/// Stadia Maps, Mapbox…), editando solo este archivo.
abstract final class MapStyle {
  static const _light =
      'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png';
  static const _dark =
      'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png';

  static TileLayer tiles(Brightness brightness) => TileLayer(
        urlTemplate: brightness == Brightness.dark ? _dark : _light,
        subdomains: const ['a', 'b', 'c', 'd'],
        retinaMode: true,
        maxZoom: 20,
        userAgentPackageName: 'com.alarmmovil.alarm_movil',
      );

  static const attribution = RichAttributionWidget(
    alignment: AttributionAlignment.bottomLeft,
    attributions: [
      TextSourceAttribution('OpenStreetMap contributors'),
      TextSourceAttribution('CARTO'),
    ],
  );
}
