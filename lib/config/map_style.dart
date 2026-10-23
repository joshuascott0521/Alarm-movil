import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

/// Capa de mapa de OpenStreetMap; en modo oscuro se oscurece con un filtro.
///
/// No necesita API key, pero su política de uso es para tráfico moderado.
/// Para publicar la app a muchos usuarios conviene cambiarla por un proveedor
/// con API key (MapTiler, Stadia Maps, Mapbox…), editando solo este archivo.
abstract final class MapStyle {
  static TileLayer tiles(Brightness brightness) => TileLayer(
        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
        maxZoom: 19,
        userAgentPackageName: 'com.alarmmovil.alarm_movil',
        tileBuilder:
            brightness == Brightness.dark ? darkModeTileBuilder : null,
      );

  static const attribution = RichAttributionWidget(
    alignment: AttributionAlignment.bottomLeft,
    attributions: [
      TextSourceAttribution('OpenStreetMap contributors'),
    ],
  );
}
