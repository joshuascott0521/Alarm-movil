import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/geocoding_service.dart';

/// Pantalla completa que aparece cuando suena la alarma.
class AlarmScreen extends StatefulWidget {
  const AlarmScreen({super.key, required this.place, required this.distance});

  final Place place;

  /// Distancia restante ya formateada ("350 m").
  final String distance;

  @override
  State<AlarmScreen> createState() => _AlarmScreenState();
}

class _AlarmScreenState extends State<AlarmScreen>
    with SingleTickerProviderStateMixin {
  late final _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
    lowerBound: 0.9,
    upperBound: 1.1,
  )..repeat(reverse: true);

  @override
  void initState() {
    super.initState();
    HapticFeedback.heavyImpact();
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: scheme.primary,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const Spacer(),
                ScaleTransition(
                  scale: _pulse,
                  child: CircleAvatar(
                    radius: 72,
                    backgroundColor: scheme.onPrimary,
                    child: Icon(Icons.directions_bus,
                        size: 80, color: scheme.primary),
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  '¡Bájate!',
                  style: text.displayMedium?.copyWith(
                    color: scheme.onPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Estás a ${widget.distance} de',
                  style: text.titleMedium?.copyWith(color: scheme.onPrimary),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.place.name,
                  textAlign: TextAlign.center,
                  style: text.headlineSmall?.copyWith(
                    color: scheme.onPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  height: 64,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: scheme.onPrimary,
                      foregroundColor: scheme.primary,
                      textStyle: text.titleLarge,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.alarm_off, size: 28),
                    label: const Text('Detener alarma'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
