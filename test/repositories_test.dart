import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_challenge_tracker/core/utils/date_time_utils.dart';
import 'package:habit_challenge_tracker/data/db/app_database.dart';
import 'package:habit_challenge_tracker/data/db/tables/app_tables.dart';
import 'package:habit_challenge_tracker/data/repositories/challenge_repository.dart';
import 'package:habit_challenge_tracker/data/repositories/progress_repository.dart';
import 'package:habit_challenge_tracker/domain/models/new_challenge_input.dart';
import 'package:habit_challenge_tracker/domain/models/progress_models.dart';

void main() {
  group('Repositories', () {
    late AppDatabase db;
    late ChallengeRepository challenges;
    late ProgressRepository progress;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      challenges = ChallengeRepository(db);
      progress = ProgressRepository(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('createChallengeWithPlan generates day entries and habit statuses', () async {
      final id = await challenges.createChallengeWithPlan(
        NewChallengeInput(
          name: 'Test',
          startDateIso: DateTime(2026, 1, 1).toIsoDate(),
          durationDays: 3,
          notes: null,
          metrics: const [],
          habits: [
            NewHabitInput(
              title: 'Habit A',
              description: null,
              reminderEnabled: false,
              reminderTimeIso: null,
            ),
            NewHabitInput(
              title: 'Habit B',
              description: null,
              reminderEnabled: false,
              reminderTimeIso: null,
            ),
          ],
        ),
      );

      final dayEntries = await (db.select(db.dayEntries)
            ..where((t) => t.challengeId.equals(id)))
          .get();
      expect(dayEntries, hasLength(3));

      final habits = await (db.select(db.habits)
            ..where((t) => t.challengeId.equals(id)))
          .get();
      expect(habits, hasLength(2));

      final statuses = await db.select(db.habitStatuses).get();
      expect(statuses, hasLength(3 * 2));
    });

    test('day color rules (green/red/gray) work', () async {
      final id = await challenges.createChallengeWithPlan(
        NewChallengeInput(
          name: 'Test',
          startDateIso: DateTime(2026, 1, 1).toIsoDate(),
          durationDays: 3,
          notes: null,
          metrics: const [],
          habits: [
            NewHabitInput(
              title: 'A',
              description: null,
              reminderEnabled: false,
              reminderTimeIso: null,
            ),
            NewHabitInput(
              title: 'B',
              description: null,
              reminderEnabled: false,
              reminderTimeIso: null,
            ),
          ],
        ),
      );

      final habits = await challenges.getHabitsForChallenge(id);
      final days = await (db.select(db.dayEntries)
            ..where((t) => t.challengeId.equals(id))
            ..orderBy([(t) => OrderingTerm.asc(t.date)]))
          .get();

      Future<void> setStatus(int dayEntryId, int habitId, HabitStatusValue v) {
        return (db.update(db.habitStatuses)
              ..where((t) => t.dayEntryId.equals(dayEntryId))
              ..where((t) => t.habitId.equals(habitId)))
            .write(
          HabitStatusesCompanion(
            status: Value(v),
            updatedAt: Value(DateTime.now()),
          ),
        );
      }

      // Day 1: all done => green
      for (final h in habits) {
        await setStatus(days[0].id, h.id, HabitStatusValue.done);
      }

      // Day 2: one not_done => red
      await setStatus(days[1].id, habits[0].id, HabitStatusValue.notDone);
      await setStatus(days[1].id, habits[1].id, HabitStatusValue.done);

      // Day 3: all not_marked => gray (default)

      final summaries = await progress.getDaySummariesInRange(
        challengeId: id,
        fromIso: days.first.date,
        toIso: days.last.date,
      );

      expect(summaries.map((s) => s.color).toList(), [
        DayColor.green,
        DayColor.red,
        DayColor.gray,
      ]);
    });
  });
}

