import 'package:flutter/material.dart';

import 'config/brand.dart';
import 'screens/map_screen.dart';
import 'services/alarm_service.dart';
import 'services/geocoding_service.dart';
import 'services/location_service.dart';
import 'services/places_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final alarm = AlarmService();
  await alarm.init();
  runApp(BajateApp(
    alarm: alarm,
    location: LocationService(),
    geocoding: GeocodingService(),
    places: await PlacesStore.open(),
  ));
}

class BajateApp extends StatelessWidget {
  const BajateApp({
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
  Widget build(BuildContext context) {
    return MaterialApp(
      title: Brand.name,
      debugShowCheckedModeBanner: false,
      theme: _theme(Brightness.light),
      darkTheme: _theme(Brightness.dark),
      home: MapScreen(
        alarm: alarm,
        location: location,
        geocoding: geocoding,
        places: places,
      ),
    );
  }

  ThemeData _theme(Brightness brightness) => ThemeData(
        colorSchemeSeed: Brand.seedColor,
        brightness: brightness,
        useMaterial3: true,
        snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
      );
}
