import 'package:drift/drift.dart';

import '../db/tables/app_tables.dart';
import '../../domain/models/checklist_models.dart';
import '../db/app_database.dart';

class ChecklistRepository {
  ChecklistRepository(this._db);
  final AppDatabase _db;

  Future<ChecklistDay?> getChecklistDay({
    required int challengeId,
    required String dateIso,
  }) async {
    final rows = await _db.customSelect(
      '''
SELECT
  de.id AS day_entry_id,
  de.date AS date,
  de.notes AS day_notes,
  h.id AS habit_id,
  h.title AS habit_title,
  h.description AS habit_description,
  h.reminder_enabled AS reminder_enabled,
  h.reminder_time AS reminder_time,
  hs.status AS status
FROM day_entries de
JOIN habit_statuses hs ON hs.day_entry_id = de.id
JOIN habits h ON h.id = hs.habit_id
WHERE de.challenge_id = ?1 AND de.date = ?2
ORDER BY h.created_at ASC
''',
      variables: [
        Variable.withInt(challengeId),
        Variable.withString(dateIso),
      ],
      readsFrom: {
        _db.dayEntries,
        _db.habitStatuses,
        _db.habits,
      },
    ).get();

    if (rows.isEmpty) return null;

    final first = rows.first;
    final dayEntryId = first.read<int>('day_entry_id');
    final notes = first.readNullable<String>('day_notes');

    final items = rows.map((r) {
      final statusString = r.read<String>('status');
      final status = const HabitStatusConverter().fromSql(statusString);
      return ChecklistHabitItem(
        habitId: r.read<int>('habit_id'),
        title: r.read<String>('habit_title'),
        description: r.readNullable<String>('habit_description'),
        reminderEnabled: (r.read<int>('reminder_enabled')) == 1,
        reminderTimeIso: r.readNullable<String>('reminder_time'),
        status: status,
      );
    }).toList();

    return ChecklistDay(
      dayEntryId: dayEntryId,
      dateIso: dateIso,
      notes: notes,
      habits: items,
    );
  }

  Future<void> saveChecklistDay({
    required int dayEntryId,
    required String? notes,
    required Map<int, HabitStatusValue> statusByHabitId,
  }) async {
    await _db.transaction(() async {
      await (_db.update(_db.dayEntries)..where((t) => t.id.equals(dayEntryId)))
          .write(DayEntriesCompanion(notes: Value(notes?.trim().isEmpty == true ? null : notes?.trim())));

      final now = DateTime.now();
      for (final e in statusByHabitId.entries) {
        await (_db.update(_db.habitStatuses)
              ..where((t) => t.dayEntryId.equals(dayEntryId))
              ..where((t) => t.habitId.equals(e.key)))
            .write(
          HabitStatusesCompanion(
            status: Value(e.value),
            updatedAt: Value(now),
          ),
        );
      }
    });
  }
}

