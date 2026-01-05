import '../../data/db/tables/app_tables.dart';

class ChecklistHabitItem {
  ChecklistHabitItem({
    required this.habitId,
    required this.title,
    this.description,
    required this.reminderEnabled,
    this.reminderTimeIso,
    required this.status,
  });

  final int habitId;
  final String title;
  final String? description;
  final bool reminderEnabled;
  final String? reminderTimeIso; // HH:mm
  final HabitStatusValue status;

  ChecklistHabitItem copyWith({HabitStatusValue? status}) => ChecklistHabitItem(
        habitId: habitId,
        title: title,
        description: description,
        reminderEnabled: reminderEnabled,
        reminderTimeIso: reminderTimeIso,
        status: status ?? this.status,
      );
}

class ChecklistDay {
  ChecklistDay({
    required this.dayEntryId,
    required this.dateIso,
    this.notes,
    required this.habits,
  });

  final int dayEntryId;
  final String dateIso;
  final String? notes;
  final List<ChecklistHabitItem> habits;
}

