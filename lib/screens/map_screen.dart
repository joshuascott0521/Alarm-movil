import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gm;
import 'package:latlong2/latlong.dart';

import '../config/map_style.dart';
import '../logic/arrival_checker.dart';
import '../services/alarm_service.dart';
import '../services/geocoding_service.dart';
import '../services/location_service.dart';
import '../services/places_store.dart';
import '../widgets/map_markers.dart';
import '../widgets/onboarding_sheet.dart';
import 'alarm_screen.dart';

/// Distancias de aviso que se ofrecen, con un nombre fácil de entender.
const radiusPresets = <(double, String)>[
  (200, 'Justo antes'),
  (500, 'Con calma'),
  (1000, 'Con tiempo'),
  (2000, 'Voy dormido'),
];

class MapScreen extends StatefulWidget {
  const MapScreen({
    super.key,
    required this.alarm,
    required this.location,
    required this.geocoding,
    required this.places,
  });

  final AlarmService alarm;
  final LocationService location;
  final GeocodingService geocoding;
  final PlacesStore places;

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  // Centro inicial mientras se obtiene la ubicación real.
  static const _fallbackCenter = gm.LatLng(4.6097, -74.0817);

  gm.GoogleMapController? _map;
  gm.BitmapDescriptor? _stopIcon;
  Color? _stopIconColor;
  bool _locationAllowed = false;
  double _panelHeight = 0;
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();
  Timer? _debounce;
  List<Place>? _results;
  bool _searching = false;
  bool _searchFailed = false;

  LatLng? _myPosition;
  StreamSubscription<Position>? _watching;

  Place? _destination;
  late double _radius = widget.places.lastRadius ?? 500;

  StreamSubscription<Position>? _tracking;
  ArrivalChecker? _checker;
  double? _tripStartDistance;
  double? _remaining;
  final _speed = SpeedSmoother();

  bool get _isTracking => _tracking != null;

  @override
  void initState() {
    super.initState();
    _searchFocus.addListener(() => setState(() {}));
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // El pin se dibuja como imagen con el color del tema actual.
    final color = Theme.of(context).colorScheme.primary;
    if (color == _stopIconColor) return;
    _stopIconColor = color;
    stopMarkerIcon(color, MediaQuery.devicePixelRatioOf(context)).then((icon) {
      if (mounted) setState(() => _stopIcon = icon);
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _watching?.cancel();
    _tracking?.cancel();
    _searchController.dispose();
    _searchFocus.dispose();
    _map?.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    if (!widget.places.onboardingDone) {
      await OnboardingSheet.show(context);
      await widget.places.completeOnboarding();
    }
    await _locateMe();
  }

  // --- Ubicación -----------------------------------------------------------

  Future<bool> _checkPermission() async {
    final issue = await widget.location.ensurePermission();
    if (issue == null) {
      if (!_locationAllowed && mounted) setState(() => _locationAllowed = true);
      return true;
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(issue.message),
        action: issue == LocationIssue.denied
            ? null
            : SnackBarAction(
                label: 'Abrir ajustes',
                onPressed: () => widget.location.openSettings(issue),
              ),
      ));
    }
    return false;
  }

  Future<void> _locateMe() async {
    if (!await _checkPermission()) return;
    final pos = _myPosition ?? await widget.location.currentPosition();
    if (pos == null || !mounted) return;
    setState(() => _myPosition = pos);
    _moveTo(pos, 16);
    _startWatching();
  }

  void _startWatching() {
    if (_watching != null || _isTracking) return;
    _watching = widget.location.watch().listen(_updateMyPosition);
  }

  Future<void> _stopWatching() async {
    await _watching?.cancel();
    _watching = null;
  }

  void _updateMyPosition(Position p) {
    setState(() => _myPosition = LatLng(p.latitude, p.longitude));
  }

  // --- Búsqueda ------------------------------------------------------------

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    setState(() {});
    if (query.trim().length < 3) {
      setState(() => _results = null);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), () => _search(query));
  }

  Future<void> _search(String query) async {
    query = query.trim();
    if (query.isEmpty) return;
    setState(() {
      _searching = true;
      _searchFailed = false;
    });
    try {
      final places = await widget.geocoding.search(query, near: _myPosition);
      // Ignora respuestas de búsquedas que el usuario ya cambió.
      if (!mounted || _searchController.text.trim() != query) return;
      setState(() => _results = places);
    } catch (_) {
      if (mounted) setState(() => _searchFailed = true);
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  void _clearSearch() {
    _debounce?.cancel();
    _searchController.clear();
    setState(() {
      _results = null;
      _searchFailed = false;
    });
  }

  // --- Destino -------------------------------------------------------------

  void _selectPlace(Place place) {
    _searchFocus.unfocus();
    _clearSearch();
    HapticFeedback.selectionClick();
    setState(() => _destination = place);
    _moveTo(place.point, 16);
  }

  Future<void> _onMapTap(gm.LatLng tapped) async {
    final point = _fromGm(tapped);
    if (_searchFocus.hasFocus) {
      _searchFocus.unfocus();
      return;
    }
    if (_isTracking) return;
    HapticFeedback.selectionClick();
    final place = Place(
      name: 'Punto en el mapa',
      address: 'Buscando dirección…',
      point: point,
    );
    setState(() => _destination = place);
    Place? named;
    try {
      named = await widget.geocoding.reverse(point);
    } catch (_) {}
    // El usuario pudo haber elegido otro punto mientras tanto.
    if (!mounted || _destination?.point != point) return;
    setState(() => _destination = named ?? place.copyWith(address: ''));
  }

  Future<void> _toggleFavorite() async {
    final destination = _destination;
    if (destination == null) return;
    await widget.places.toggleFavorite(destination);
    final saved = widget.places.isFavorite(destination);
    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(saved
          ? 'Guardada en tus paradas'
          : 'Quitada de tus paradas'),
      duration: const Duration(seconds: 2),
    ));
  }

  void _setRadius(double meters) {
    HapticFeedback.selectionClick();
    setState(() => _radius = meters);
    widget.places.saveRadius(meters);
  }

  // --- Viaje ---------------------------------------------------------------

  Future<void> _startTrip() async {
    final destination = _destination;
    if (destination == null) return;
    if (!await _checkPermission()) return;
    final checker =
        ArrivalChecker(destination: destination.point, radiusMeters: _radius);
    final me = _myPosition;
    if (me != null && checker.isArriving(me)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Ya estás dentro de la zona de aviso. '
            'Elige una distancia menor o una parada más lejana.'),
      ));
      return;
    }
    await widget.places.addRecent(destination);
    await _stopWatching();
    HapticFeedback.mediumImpact();
    setState(() {
      _checker = checker;
      _tripStartDistance = me == null ? null : checker.distanceTo(me);
      _remaining = _tripStartDistance;
      _tracking = widget.location.track().listen(
            _onTripPosition,
            onError: (_) => _showMessage('Se perdió la señal del GPS.'),
          );
    });
    _fitTrip();
  }

  void _fitTrip() {
    final me = _myPosition;
    final destination = _destination;
    if (me == null || destination == null) return;
    final bounds = gm.LatLngBounds(
      southwest: gm.LatLng(
        math.min(me.latitude, destination.point.latitude),
        math.min(me.longitude, destination.point.longitude),
      ),
      northeast: gm.LatLng(
        math.max(me.latitude, destination.point.latitude),
        math.max(me.longitude, destination.point.longitude),
      ),
    );
    _map?.animateCamera(gm.CameraUpdate.newLatLngBounds(bounds, 80));
  }

  void _onTripPosition(Position p) {
    final checker = _checker;
    if (checker == null) return;
    final pos = LatLng(p.latitude, p.longitude);
    _speed.add(p.speed);
    final remaining = checker.distanceTo(pos);
    _updateMyPosition(p);
    setState(() {
      _remaining = remaining;
      _tripStartDistance ??= remaining;
    });
    if (checker.isArriving(pos)) {
      // Evita que otra posición en cola dispare la alarma dos veces.
      _checker = null;
      _arrive(remaining);
    }
  }

  Future<void> _arrive(double remaining) async {
    final destination = _destination!;
    await _stopTrip();
    await widget.alarm.ring(
        'Estás a ${formatDistance(remaining)} de ${destination.name}. '
        '¡Prepárate para bajar!');
    if (!mounted) return;
    await Navigator.of(context).push(MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => AlarmScreen(
        place: destination,
        distance: formatDistance(remaining),
      ),
    ));
    await widget.alarm.stop();
    if (mounted) setState(() => _destination = null);
  }

  Future<void> _confirmCancel() async {
    final cancel = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Cancelar la alarma?'),
        content: const Text('Ya no te avisaremos al llegar a tu parada.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Seguir vigilando'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Cancelar alarma'),
          ),
        ],
      ),
    );
    if (cancel == true) await _stopTrip();
  }

  Future<void> _stopTrip() async {
    await _tracking?.cancel();
    if (!mounted) return;
    setState(() {
      _tracking = null;
      _checker = null;
      _remaining = null;
      _tripStartDistance = null;
    });
    _startWatching();
  }

  gm.LatLng _toGm(LatLng p) => gm.LatLng(p.latitude, p.longitude);
  LatLng _fromGm(gm.LatLng p) => LatLng(p.latitude, p.longitude);

  void _moveTo(LatLng point, double zoom) =>
      _map?.animateCamera(gm.CameraUpdate.newLatLngZoom(_toGm(point), zoom));

  void _showMessage(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  // --- Interfaz ------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final destination = _destination;
    final me = _myPosition;
    return Scaffold(
      body: Stack(
        children: [
          gm.GoogleMap(
            initialCameraPosition: const gm.CameraPosition(
              target: _fallbackCenter,
              zoom: 12,
            ),
            onMapCreated: (controller) {
              _map = controller;
              final me = _myPosition;
              if (me != null) _moveTo(me, 16);
            },
            onTap: _onMapTap,
            style: Theme.of(context).brightness == Brightness.dark
                ? MapStyle.dark
                : null,
            // Deja libre la zona bajo el panel para el logo y los encuadres.
            padding: EdgeInsets.only(
              top: MediaQuery.paddingOf(context).top + 72,
              bottom: _panelHeight,
            ),
            myLocationEnabled: _locationAllowed,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            compassEnabled: true,
            circles: {
              if (destination != null)
                gm.Circle(
                  circleId: const gm.CircleId('zona'),
                  center: _toGm(destination.point),
                  radius: _radius,
                  fillColor: scheme.primary.withValues(alpha: 0.15),
                  strokeColor: scheme.primary,
                  strokeWidth: 2,
                ),
            },
            polylines: {
              if (_isTracking && me != null && destination != null)
                gm.Polyline(
                  polylineId: const gm.PolylineId('restante'),
                  points: [_toGm(me), _toGm(destination.point)],
                  color: scheme.primary,
                  width: 4,
                  patterns: [gm.PatternItem.dash(20), gm.PatternItem.gap(12)],
                ),
            },
            markers: {
              if (destination != null)
                gm.Marker(
                  markerId: const gm.MarkerId('parada'),
                  position: _toGm(destination.point),
                  icon: _stopIcon ?? gm.BitmapDescriptor.defaultMarker,
                  infoWindow: gm.InfoWindow(title: destination.name),
                ),
            },
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (!_isTracking) _buildSearch(context),
                  const SizedBox(height: 12),
                  if (!_searchFocus.hasFocus)
                    FloatingActionButton.small(
                      heroTag: 'locate',
                      onPressed: _isTracking ? _fitTrip : _locateMe,
                      tooltip: _isTracking ? 'Ver el viaje' : 'Mi ubicación',
                      child: Icon(
                          _isTracking ? Icons.zoom_out_map : Icons.my_location),
                    ),
                ],
              ),
            ),
          ),
          if (!_searchFocus.hasFocus)
            Align(
              alignment: Alignment.bottomCenter,
              child: _BottomPanel(
                onHeightChanged: (h) {
                  if (h != _panelHeight) setState(() => _panelHeight = h);
                },
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: _isTracking
                      ? _buildTripPanel(context)
                      : destination != null
                          ? _buildDestinationPanel(context, destination)
                          : _buildIdlePanel(context),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSearch(BuildContext context) {
    final hasText = _searchController.text.isNotEmpty;
    return Column(
      children: [
        SearchBar(
          controller: _searchController,
          focusNode: _searchFocus,
          hintText: '¿En qué parada te bajas?',
          elevation: const WidgetStatePropertyAll(4),
          leading: _searchFocus.hasFocus
              ? IconButton(
                  icon: const Icon(Icons.arrow_back),
                  tooltip: 'Volver al mapa',
                  onPressed: () {
                    _clearSearch();
                    _searchFocus.unfocus();
                  },
                )
              : const Icon(Icons.search),
          textInputAction: TextInputAction.search,
          onChanged: _onSearchChanged,
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
            else if (hasText)
              IconButton(
                icon: const Icon(Icons.close),
                tooltip: 'Borrar',
                onPressed: _clearSearch,
              )
            else
              IconButton(
                icon: const Icon(Icons.help_outline),
                tooltip: 'Cómo funciona',
                onPressed: () => OnboardingSheet.show(context),
              ),
          ],
        ),
        if (_searchFocus.hasFocus) _buildSuggestions(context),
      ],
    );
  }

  Widget _buildSuggestions(BuildContext context) {
    final query = _searchController.text.trim();
    final List<Widget> children;
    if (query.length < 3) {
      final favorites = widget.places.favorites;
      final recents = widget.places.recents;
      children = [
        if (favorites.isEmpty && recents.isEmpty)
          const _Hint(
            icon: Icons.star_outline,
            text: 'Escribe una dirección, barrio o estación. '
                'Las paradas que guardes aparecerán aquí.',
          ),
        if (favorites.isNotEmpty) const _SectionTitle('Tus paradas'),
        for (final p in favorites)
          _PlaceTile(place: p, icon: Icons.star, onTap: () => _selectPlace(p)),
        if (recents.isNotEmpty) const _SectionTitle('Recientes'),
        for (final p in recents)
          _PlaceTile(
              place: p, icon: Icons.history, onTap: () => _selectPlace(p)),
      ];
    } else if (_searchFailed) {
      children = const [
        _Hint(
          icon: Icons.wifi_off,
          text: 'No se pudo buscar. Revisa tu conexión a internet.',
        ),
      ];
    } else if (_results == null) {
      children = const [_Hint(icon: Icons.search, text: 'Buscando…')];
    } else if (_results!.isEmpty) {
      children = const [
        _Hint(
          icon: Icons.search_off,
          text: 'Sin resultados. Prueba con otra dirección o toca el mapa.',
        ),
      ];
    } else {
      children = [
        for (final p in _results!)
          _PlaceTile(
              place: p,
              icon: Icons.place_outlined,
              onTap: () => _selectPlace(p)),
      ];
    }
    return Card(
      margin: const EdgeInsets.only(top: 8),
      clipBehavior: Clip.antiAlias,
      elevation: 4,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.5,
        ),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: children,
        ),
      ),
    );
  }

  Widget _buildIdlePanel(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final saved = [...widget.places.favorites, ...widget.places.recents];
    return Column(
      key: const ValueKey('idle'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('¿Dónde te bajas?', style: text.titleLarge),
        const SizedBox(height: 4),
        const Text('Busca la dirección arriba o toca el mapa.'),
        if (saved.isNotEmpty) ...[
          const SizedBox(height: 12),
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: saved.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, i) => ActionChip(
                avatar: Icon(widget.places.isFavorite(saved[i])
                    ? Icons.star
                    : Icons.history),
                label: Text(saved[i].name),
                onPressed: () => _selectPlace(saved[i]),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildDestinationPanel(BuildContext context, Place destination) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final me = _myPosition;
    final distance = me == null
        ? null
        : const Distance().as(LengthUnit.Meter, me, destination.point);
    final isFavorite = widget.places.isFavorite(destination);
    return Column(
      key: const ValueKey('destination'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: scheme.primaryContainer,
              foregroundColor: scheme.onPrimaryContainer,
              child: const Icon(Icons.directions_bus),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(destination.name,
                      style: text.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  Text(
                    [
                      if (distance != null) 'A ${formatDistance(distance)}',
                      if (destination.address.isNotEmpty) destination.address,
                    ].join(' · '),
                    style: text.bodySmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(isFavorite ? Icons.star : Icons.star_outline),
              color: isFavorite ? Colors.amber.shade700 : null,
              tooltip: isFavorite ? 'Quitar de tus paradas' : 'Guardar parada',
              onPressed: _toggleFavorite,
            ),
            IconButton(
              icon: const Icon(Icons.close),
              tooltip: 'Elegir otra parada',
              onPressed: () => setState(() => _destination = null),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text('¿Cuándo te aviso?', style: text.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final (meters, label) in radiusPresets)
              ChoiceChip(
                label: Text('$label · ${formatDistance(meters)}'),
                selected: _radius == meters,
                onSelected: (_) => _setRadius(meters),
              ),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 52,
          child: FilledButton.icon(
            onPressed: _startTrip,
            icon: const Icon(Icons.notifications_active),
            label: const Text('Activar alarma'),
          ),
        ),
      ],
    );
  }

  Widget _buildTripPanel(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final remaining = _remaining;
    final start = _tripStartDistance;
    final progress = remaining == null || start == null || start <= _radius
        ? null
        : ((start - remaining) / (start - _radius)).clamp(0.0, 1.0);
    final minutes = remaining == null
        ? null
        : minutesUntilAlarm(
            remainingMeters: remaining,
            radiusMeters: _radius,
            speedMps: _speed.value,
          );
    return Column(
      key: const ValueKey('trip'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(Icons.notifications_active, color: scheme.primary, size: 18),
            const SizedBox(width: 6),
            Text('Alarma activa',
                style: text.labelLarge?.copyWith(color: scheme.primary)),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          _destination?.name ?? '',
          style: text.titleMedium,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        Text(
          remaining == null
              ? 'Buscando señal GPS…'
              : 'Faltan ${formatDistance(remaining)}',
          style: text.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(value: progress, minHeight: 8),
        ),
        const SizedBox(height: 8),
        Text(
          minutes == null
              ? 'Sonará a ${formatDistance(_radius)} de tu parada.'
              : 'Sonará en unos $minutes min, '
                  'a ${formatDistance(_radius)} de tu parada.',
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Icon(Icons.lock_outline, size: 16, color: scheme.outline),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'Puedes bloquear el celular y descansar.',
                style: text.bodySmall?.copyWith(color: scheme.outline),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: _confirmCancel,
          icon: const Icon(Icons.close),
          label: const Text('Cancelar alarma'),
        ),
      ],
    );
  }
}

/// Hoja inferior con esquinas redondeadas que aloja los paneles.
class _BottomPanel extends StatelessWidget {
  const _BottomPanel({required this.child, required this.onHeightChanged});

  final Widget child;
  final ValueChanged<double> onHeightChanged;

  @override
  Widget build(BuildContext context) {
    return NotificationListener<SizeChangedLayoutNotification>(
      onNotification: (_) {
        _report(context);
        return true;
      },
      child: SizeChangedLayoutNotifier(child: _buildPanel(context)),
    );
  }

  void _report(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final box = context.findRenderObject() as RenderBox?;
      if (box != null && box.hasSize) onHeightChanged(box.size.height);
    });
  }

  Widget _buildPanel(BuildContext context) {
    _report(context);
    return Material(
      elevation: 12,
      color: Theme.of(context).colorScheme.surface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: SafeArea(
        top: false,
        child: AnimatedSize(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
          alignment: Alignment.topCenter,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _PlaceTile extends StatelessWidget {
  const _PlaceTile({
    required this.place,
    required this.icon,
    required this.onTap,
  });

  final Place place;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(place.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: place.address.isEmpty
          ? null
          : Text(place.address, maxLines: 1, overflow: TextOverflow.ellipsis),
      onTap: onTap,
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(text, style: Theme.of(context).textTheme.bodyMedium),
    );
  }
}
