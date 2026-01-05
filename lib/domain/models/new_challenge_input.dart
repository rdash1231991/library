class NewMetricInput {
  NewMetricInput({
    required this.name,
    required this.unit,
    required this.startValue,
    this.targetValue,
  });

  final String name;
  final String unit;
  final double startValue;
  final double? targetValue;
}

class NewHabitInput {
  NewHabitInput({
    required this.title,
    this.description,
    this.reminderTimeIso,
    required this.reminderEnabled,
  });

  final String title;
  final String? description;
  final String? reminderTimeIso; // HH:mm
  final bool reminderEnabled;
}

class NewChallengeInput {
  NewChallengeInput({
    required this.name,
    required this.startDateIso,
    required this.durationDays,
    this.notes,
    required this.habits,
    required this.metrics,
  });

  final String name;
  final String startDateIso; // yyyy-MM-dd
  final int durationDays;
  final String? notes;
  final List<NewHabitInput> habits;
  final List<NewMetricInput> metrics;
}

