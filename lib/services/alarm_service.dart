import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';

/// Hace sonar la alarma y muestra la notificación de llegada.
class AlarmService {
  final _notifications = FlutterLocalNotificationsPlugin();
  final _ringtone = FlutterRingtonePlayer();
  bool _ringing = false;

  bool get isRinging => _ringing;

  Future<void> init() async {
    await _notifications.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
    );
    await _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  Future<void> ring(String body) async {
    if (_ringing) return;
    _ringing = true;
    await _ringtone.playAlarm(looping: true, asAlarm: true);
    await _notifications.show(
      id: 1,
      title: '¡Ya casi llegas!',
      body: body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'arrival_alarm',
          'Alarma de llegada',
          channelDescription: 'Avisa cuando estás cerca de tu parada',
          importance: Importance.max,
          priority: Priority.max,
          category: AndroidNotificationCategory.alarm,
          fullScreenIntent: true,
          enableVibration: true,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentSound: true,
          interruptionLevel: InterruptionLevel.timeSensitive,
        ),
      ),
    );
  }

  Future<void> stop() async {
    _ringing = false;
    await _ringtone.stop();
    await _notifications.cancel(id: 1);
  }
}
