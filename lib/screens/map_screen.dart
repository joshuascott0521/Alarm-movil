import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../logic/arrival_checker.dart';
import '../services/alarm_service.dart';
import '../services/geocoding_service.dart';
import '../services/location_service.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({
    super.key,
    required this.alarm,
    required this.location,
    required this.geocoding,
  });

  final AlarmService alarm;
  final LocationService location;
  final GeocodingService geocoding;

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  // Centro inicial mientras se obtiene la ubicación real.
  static const _fallbackCenter = LatLng(4.6097, -74.0817);

  final _mapController = MapController();
  final _searchController = TextEditingController();
  List<Place>? _results;
  bool _searching = false;
  LatLng? _myPosition;
  LatLng? _destination;
  double _radius = 400;
  double? _remaining;
  StreamSubscription<LatLng>? _tracking;

  bool get _isTracking => _tracking != null;

  @override
  void initState() {
    super.initState();
    _locateMe();
  }

  @override
  void dispose() {
    _tracking?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _locateMe() async {
    final error = await widget.location.ensurePermission();
    if (error != null) {
      _showMessage(error);
      return;
    }
    final pos = await widget.location.currentPosition();
    if (pos == null || !mounted) return;
    setState(() => _myPosition = pos);
    _mapController.move(pos, 16);
  }

  void _onMapTap(TapPosition _, LatLng point) {
    if (_isTracking) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _destination = point;
      _results = null;
    });
  }

  Future<void> _search(String query) async {
    query = query.trim();
    if (query.isEmpty) return;
    setState(() => _searching = true);
    try {
      final places = await widget.geocoding.search(query, near: _myPosition);
      if (!mounted) return;
      setState(() => _results = places);
      if (places.isEmpty) _showMessage('No encontramos esa dirección.');
    } catch (_) {
      _showMessage('No se pudo buscar. Revisa tu conexión a internet.');
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  void _selectPlace(Place place) {
    FocusScope.of(context).unfocus();
    setState(() {
      _destination = place.point;
      _results = null;
      _searchController.text = place.name;
    });
    _mapController.move(place.point, 16);
  }

  Future<void> _start() async {
    final destination = _destination;
    if (destination == null) return;
    final error = await widget.location.ensurePermission();
    if (error != null) {
      _showMessage(error);
      return;
    }
    final checker =
        ArrivalChecker(destination: destination, radiusMeters: _radius);
    setState(() {
      _tracking = widget.location.track().listen(
            (pos) => _onPosition(pos, checker),
            onError: (_) => _showMessage('Se perdió la señal del GPS.'),
          );
    });
  }

  void _onPosition(LatLng pos, ArrivalChecker checker) {
    final remaining = checker.distanceTo(pos);
    setState(() {
      _myPosition = pos;
      _remaining = remaining;
    });
    if (checker.isArriving(pos)) _arrive(remaining);
  }

  Future<void> _arrive(double remaining) async {
    await _stopTracking();
    await widget.alarm.ring(
        'Estás a ${formatDistance(remaining)} de tu parada. ¡Prepárate para bajar!');
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.directions_bus, size: 48),
        title: const Text('¡Ya casi llegas!'),
        content: const Text('Prepárate para bajarte del bus.'),
        actions: [
          FilledButton.icon(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.alarm_off),
            label: const Text('Detener alarma'),
          ),
        ],
      ),
    );
    await widget.alarm.stop();
    if (mounted) setState(() => _destination = null);
  }

  Future<void> _stopTracking() async {
    await _tracking?.cancel();
    if (mounted) {
      setState(() {
        _tracking = null;
        _remaining = null;
      });
    }
  }

  void _showMessage(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Alarma de parada')),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _fallbackCenter,
              initialZoom: 12,
              onTap: _onMapTap,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.alarmmovil.alarm_movil',
              ),
              if (_destination != null)
                CircleLayer(circles: [
                  CircleMarker(
                    point: _destination!,
                    radius: _radius,
                    useRadiusInMeter: true,
                    color: scheme.primary.withValues(alpha: 0.2),
                    borderColor: scheme.primary,
                    borderStrokeWidth: 2,
                  ),
                ]),
              MarkerLayer(markers: [
                if (_myPosition != null)
                  Marker(
                    point: _myPosition!,
                    width: 22,
                    height: 22,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                      ),
                    ),
                  ),
                if (_destination != null)
                  Marker(
                    point: _destination!,
                    width: 48,
                    height: 48,
                    alignment: Alignment.topCenter,
                    child: Icon(Icons.location_pin,
                        size: 48, color: scheme.error),
                  ),
              ]),
              const RichAttributionWidget(attributions: [
                TextSourceAttribution('OpenStreetMap contributors'),
              ]),
            ],
          ),
          Positioned(
            left: 16,
            right: 16,
            top: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (!_isTracking) _buildSearch(context),
                const SizedBox(height: 12),
                FloatingActionButton.small(
                  heroTag: 'locate',
                  onPressed: _locateMe,
                  tooltip: 'Mi ubicación',
                  child: const Icon(Icons.my_location),
                ),
              ],
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: SafeArea(child: _buildPanel(context)),
          ),
        ],
      ),
    );
  }

  Widget _buildSearch(BuildContext context) {
    final results = _results;
    return Column(
      children: [
        SearchBar(
          controller: _searchController,
          hintText: 'Buscar parada o dirección',
          leading: const Icon(Icons.search),
          textInputAction: TextInputAction.search,
          onSubmitted: _search,
          trailing: [
            if (_searching)
              const Padding(
                padding: EdgeInsets.all(12),
                child: SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else if (_searchController.text.isNotEmpty || results != null)
              IconButton(
                icon: const Icon(Icons.clear),
                tooltip: 'Borrar',
                onPressed: () => setState(() {
                  _searchController.clear();
                  _results = null;
                }),
              ),
          ],
        ),
        if (results != null && results.isNotEmpty)
          Card(
            margin: const EdgeInsets.only(top: 8),
            clipBehavior: Clip.antiAlias,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 280),
              child: ListView.separated(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: results.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, i) => ListTile(
                  leading: const Icon(Icons.place_outlined),
                  title: Text(results[i].name),
                  subtitle: Text(
                    results[i].address,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () => _selectPlace(results[i]),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPanel(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final Widget content;
    if (_destination == null) {
      content = const Row(children: [
        Icon(Icons.touch_app),
        SizedBox(width: 12),
        Expanded(
          child: Text('Busca tu parada arriba o toca el mapa donde te vas a bajar.'),
        ),
      ]);
    } else if (_isTracking) {
      content = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _remaining == null
                ? 'Buscando señal GPS…'
                : 'Faltan ${formatDistance(_remaining!)}',
            style: textTheme.headlineSmall,
          ),
          const SizedBox(height: 4),
          Text('Sonará a ${formatDistance(_radius)} de tu parada. '
              'Puedes bloquear el teléfono.'),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _stopTracking,
            icon: const Icon(Icons.close),
            label: const Text('Cancelar alarma'),
          ),
        ],
      );
    } else {
      content = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Avisarme a ${formatDistance(_radius)} de la parada',
              style: textTheme.titleMedium),
          Slider(
            value: _radius,
            min: 100,
            max: 2000,
            divisions: 19,
            label: formatDistance(_radius),
            onChanged: (v) => setState(() => _radius = v),
          ),
          FilledButton.icon(
            onPressed: _start,
            icon: const Icon(Icons.alarm_on),
            label: const Text('Activar alarma'),
          ),
        ],
      );
    }
    return Card(
      elevation: 6,
      child: Padding(padding: const EdgeInsets.all(16), child: content),
    );
  }
}
