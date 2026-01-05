class NotificationService {
  static NotificationService singleton() => NotificationService();

  static Future<void> bootstrap() async {
    // No-op on web.
  }

  Future<bool> requestPermissions() async => false;

  Future<void> scheduleHabitDailyWithinWindow({
    required int habitId,
    required String habitTitle,
    required String? habitDescription,
    required String startDateIso,
    required int durationDays,
    required String timeIso,
  }) async {
    // No-op on web.
  }

  Future<void> cancelHabitWithinWindow({
    required int habitId,
    required String startDateIso,
    required int durationDays,
  }) async {
    // No-op on web.
  }

  Future<void> cancelAll() async {
    // No-op on web.
  }
}

