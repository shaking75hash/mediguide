import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

class AppointmentNotificationService {
  AppointmentNotificationService._();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static bool get _isSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  static Future<void> initialize() async {
    if (_initialized) return;
    if (!_isSupported) {
      _initialized = true;
      return;
    }

    tz_data.initializeTimeZones();
    final localTimezone = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(localTimezone.identifier));

    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
    );
    _initialized = true;
  }

  static Future<bool> requestReminderPermissions() async {
    await initialize();
    if (!_isSupported) return false;

    if (defaultTargetPlatform == TargetPlatform.android) {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (android == null) return false;

      final notificationsAllowed =
          await android.requestNotificationsPermission() ?? false;
      if (!notificationsAllowed) return false;

      final canScheduleExactly =
          await android.canScheduleExactNotifications() ?? false;
      if (canScheduleExactly) return true;
      return await android.requestExactAlarmsPermission() ?? false;
    }

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      final ios = _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      return await ios?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          false;
    }

    return true;
  }

  static Future<bool> syncIfPermitted(List<dynamic> appointments) async {
    await initialize();
    if (!_isSupported) return false;

    if (defaultTargetPlatform == TargetPlatform.android) {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (android == null ||
          !(await android.areNotificationsEnabled() ?? false) ||
          !(await android.canScheduleExactNotifications() ?? false)) {
        return false;
      }
    }

    final scheduledIds = <int>{};
    for (final appointment in appointments) {
      if (appointment is! Map) continue;
      final id = int.tryParse(appointment['id']?.toString() ?? '');
      final date = appointment['date']?.toString();
      final time = appointment['time']?.toString();
      if (id == null || date == null || time == null) continue;
      if (appointment['status']?.toString().toLowerCase() != 'scheduled') {
        continue;
      }

      final localStart = DateTime.tryParse('${date}T$time:00');
      if (localStart == null) continue;
      final reminderTime = localStart.subtract(const Duration(minutes: 30));
      if (!reminderTime.isAfter(DateTime.now())) continue;

      final appointmentTime = DateTime.parse('${date}T$time:00');
      await _plugin.zonedSchedule(
        id: id,
        title: 'Appointment reminder',
        body:
            'Your appointment with ${appointment['doctor_name'] ?? 'your doctor'} is in 30 minutes.',
        scheduledDate: tz.TZDateTime.from(
          appointmentTime.subtract(const Duration(minutes: 30)),
          tz.local,
        ),
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'appointment_reminders',
            'Appointment reminders',
            channelDescription:
                'Reminders 30 minutes before scheduled appointments.',
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: 'appointment:$id',
      );
      scheduledIds.add(id);
    }

    final pending = await _plugin.pendingNotificationRequests();
    for (final notification in pending) {
      if (notification.payload?.startsWith('appointment:') == true &&
          !scheduledIds.contains(notification.id)) {
        await _plugin.cancel(id: notification.id);
      }
    }
    return true;
  }

  static Future<void> cancelReminder(int appointmentId) async {
    await initialize();
    if (!_isSupported) return;
    await _plugin.cancel(id: appointmentId);
  }

  static Future<void> cancelAllAppointmentReminders() async {
    await initialize();
    if (!_isSupported) return;
    final pending = await _plugin.pendingNotificationRequests();
    for (final notification in pending) {
      if (notification.payload?.startsWith('appointment:') == true) {
        await _plugin.cancel(id: notification.id);
      }
    }
  }
}
