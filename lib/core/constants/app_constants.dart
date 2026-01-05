class AppConstants {
  static const appName = 'Habit Challenge Tracker';

  /// Enable seed/demo content for quick testing.
  ///
  /// Run with: `flutter run --dart-define=DEMO_DATA=true`
  static const bool enableDemoData =
      bool.fromEnvironment('DEMO_DATA', defaultValue: false);

  static const settingsKeyHasOnboarded = 'has_onboarded';
  static const settingsKeySelectedChallengeId = 'selected_challenge_id';
}

