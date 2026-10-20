import 'package:flutter/material.dart';

import 'screens/map_screen.dart';
import 'services/alarm_service.dart';
import 'services/location_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final alarm = AlarmService();
  await alarm.init();
  runApp(AlarmMovilApp(alarm: alarm, location: LocationService()));
}

class AlarmMovilApp extends StatelessWidget {
  const AlarmMovilApp({super.key, required this.alarm, required this.location});

  final AlarmService alarm;
  final LocationService location;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Alarma de parada',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      darkTheme: ThemeData(
        colorSchemeSeed: Colors.indigo,
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      home: MapScreen(alarm: alarm, location: location),
    );
  }
}
