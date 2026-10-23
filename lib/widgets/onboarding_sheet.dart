import 'package:flutter/material.dart';

import '../config/brand.dart';

/// Explicación breve de la app que se muestra la primera vez.
class OnboardingSheet extends StatelessWidget {
  const OnboardingSheet({super.key});

  static Future<void> show(BuildContext context) => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => const OnboardingSheet(),
      );

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Bienvenido a ${Brand.name}', style: text.headlineSmall),
            const SizedBox(height: 4),
            Text(Brand.tagline, style: text.bodyLarge),
            const SizedBox(height: 24),
            const _Step(
              icon: Icons.search,
              title: 'Elige tu parada',
              body: 'Búscala por dirección o toca el mapa.',
            ),
            const _Step(
              icon: Icons.notifications_active_outlined,
              title: 'Activa la alarma',
              body: 'Elige con cuánta anticipación quieres el aviso.',
            ),
            const _Step(
              icon: Icons.phone_locked_outlined,
              title: 'Guarda el celular',
              body: 'Funciona con la pantalla bloqueada. Sonará cuando '
                  'estés llegando.',
            ),
            const SizedBox(height: 8),
            Text(
              'Te pediremos acceso a tu ubicación y a las notificaciones '
              'para poder avisarte.',
              style: text.bodySmall,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Empezar'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.icon, required this.title, required this.body});

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: scheme.primaryContainer,
            foregroundColor: scheme.onPrimaryContainer,
            child: Icon(icon),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                Text(body),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
