import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Punto azul de "estás aquí", con un pulso suave y la dirección de avance.
class LocationDot extends StatefulWidget {
  const LocationDot({super.key, this.heading});

  /// Rumbo en grados (0 = norte), si el GPS lo conoce.
  final double? heading;

  @override
  State<LocationDot> createState() => _LocationDotState();
}

class _LocationDotState extends State<LocationDot>
    with SingleTickerProviderStateMixin {
  late final _pulse = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 2),
  )..repeat();

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const color = Color(0xFF1E88E5);
    final heading = widget.heading;
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, _) => Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 20 + 40 * _pulse.value,
            height: 20 + 40 * _pulse.value,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.35 * (1 - _pulse.value)),
            ),
          ),
          if (heading != null && heading >= 0)
            Transform.rotate(
              angle: heading * math.pi / 180,
              child: const Icon(Icons.navigation, size: 34, color: color),
            ),
          Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: const [BoxShadow(blurRadius: 4, color: Colors.black26)],
            ),
          ),
        ],
      ),
    );
  }
}

/// Pin de la parada, que "cae" al aparecer.
class StopPin extends StatelessWidget {
  const StopPin({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: -30, end: 0),
      duration: const Duration(milliseconds: 450),
      curve: Curves.bounceOut,
      builder: (context, dy, child) =>
          Transform.translate(offset: Offset(0, dy), child: child),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: scheme.primary,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: const [BoxShadow(blurRadius: 6, color: Colors.black38)],
            ),
            child: Icon(Icons.directions_bus, color: scheme.onPrimary, size: 22),
          ),
          Container(width: 3, height: 14, color: scheme.primary),
        ],
      ),
    );
  }
}
