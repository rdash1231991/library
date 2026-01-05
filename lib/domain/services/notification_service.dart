import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../../core/utils/date_time_utils.dart';

class NotificationService {
  NotificationService(this._plugin);

  final FlutterLocalNotificationsPlugin _plugin;

  static final FlutterLocalNotificationsPlugin _singletonPlugin =
      FlutterLocalNotificationsPlugin();

  static NotificationService singleton() => NotificationService(_singletonPlugin);

  static Future<void> bootstrap() async {
    tz.initializeTimeZones();
    final tzInfo = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(tzInfo.identifier));

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings();
    const init = InitializationSettings(android: android, iOS: ios);
    await _singletonPlugin.initialize(init);
  }

  Future<bool> requestPermissions() async {
    var ok = true;

    final android =
        _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      // Android 13+ notification permission.
      ok = (await android.requestNotificationsPermission()) ?? ok;
    }

    final ios =
        _plugin.resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();
    if (ios != null) {
      ok = (await ios.requestPermissions(alert: true, badge: true, sound: true)) ??
          ok;
    }

    return ok;
  }

  NotificationDetails _details() {
    const android = AndroidNotificationDetails(
      'habit_reminders',
      'Habit reminders',
      channelDescription: 'Daily habit reminders for your challenges.',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    );

    const ios = DarwinNotificationDetails();

    return const NotificationDetails(android: android, iOS: ios);
  }

  int _notificationId(int habitId, String dateIso) {
    // Stable, deterministic ID per habit/day so we can cancel/reschedule.
    final raw = habitId * 1000003 ^ dateIso.hashCode;
    return raw & 0x7fffffff;
  }

  Future<void> scheduleHabitDailyWithinWindow({
    required int habitId,
    required String habitTitle,
    required String? habitDescription,
    required String startDateIso,
    required int durationDays,
    required String timeIso, // HH:mm
  }) async {
    final start = parseIsoDate(startDateIso);
    final now = DateTime.now();

    for (var i = 0; i < durationDays; i++) {
      final date = start.add(Duration(days: i));
      final scheduledLocal = _combine(date, timeIso);

      // If the scheduled time is in the past, skip.
      if (!scheduledLocal.isAfter(now)) continue;

      final id = _notificationId(habitId, date.toIsoDate());
      final title = habitTitle;
      final body = (habitDescription == null || habitDescription.trim().isEmpty)
          ? 'Time for: $habitTitle'
          : habitDescription.trim();

      await _plugin.zonedSchedule(
        id,
        title,
        body,
        tz.TZDateTime.from(scheduledLocal, tz.local),
        _details(),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: null, // scheduled per-day; no repeating
      );
    }
  }

  Future<void> cancelHabitWithinWindow({
    required int habitId,
    required String startDateIso,
    required int durationDays,
  }) async {
    final start = parseIsoDate(startDateIso);
    for (var i = 0; i < durationDays; i++) {
      final dateIso = start.add(Duration(days: i)).toIsoDate();
      await _plugin.cancel(_notificationId(habitId, dateIso));
    }
  }

  Future<void> cancelAll() => _plugin.cancelAll();

  DateTime _combine(DateTime date, String timeIso) {
    final parts = timeIso.split(':');
    final h = int.parse(parts[0]);
    final m = int.parse(parts[1]);
    return DateTime(date.year, date.month, date.day, h, m);
  }

  // Helpful for debugging in local runs.
  Future<List<PendingNotificationRequest>> pending() => _plugin.pendingNotificationRequests();

  bool get isLinux => Platform.isLinux;
}

