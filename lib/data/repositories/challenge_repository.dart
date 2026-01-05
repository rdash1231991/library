import 'package:drift/drift.dart';

import '../../core/utils/date_time_utils.dart';
import '../../domain/models/new_challenge_input.dart';
import '../db/app_database.dart';
import '../db/tables/app_tables.dart';

class ChallengeRepository {
  ChallengeRepository(this._db);
  final AppDatabase _db;

  Stream<List<Challenge>> watchChallenges() {
    final q = _db.select(_db.challenges)
      ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]);
    return q.watch();
  }

  Future<Challenge?> getChallenge(int id) {
    final q = _db.select(_db.challenges)..where((t) => t.id.equals(id));
    return q.getSingleOrNull();
  }

  Stream<Challenge?> watchChallenge(int id) {
    final q = _db.select(_db.challenges)..where((t) => t.id.equals(id));
    return q.watchSingleOrNull();
  }

  Stream<List<Habit>> watchHabitsForChallenge(int challengeId) {
    final q = _db.select(_db.habits)
      ..where((t) => t.challengeId.equals(challengeId))
      ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]);
    return q.watch();
  }

  Future<List<Habit>> getHabitsForChallenge(int challengeId) {
    final q = _db.select(_db.habits)
      ..where((t) => t.challengeId.equals(challengeId))
      ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]);
    return q.get();
  }

  Future<int> createChallengeWithPlan(NewChallengeInput input) {
    if (input.habits.isEmpty) {
      throw ArgumentError('Challenge must include at least one habit.');
    }

    return _db.transaction(() async {
      final challengeId = await _db.into(_db.challenges).insert(
            ChallengesCompanion.insert(
              name: input.name.trim(),
              startDate: input.startDateIso,
              durationDays: input.durationDays,
              notes: Value(input.notes?.trim().isEmpty == true ? null : input.notes),
            ),
          );

      if (input.metrics.isNotEmpty) {
        await _db.batch((b) {
          b.insertAll(
            _db.metrics,
            input.metrics
                .where((m) => m.name.trim().isNotEmpty)
                .map(
                  (m) => MetricsCompanion.insert(
                    challengeId: challengeId,
                    name: m.name.trim(),
                    unit: m.unit.trim(),
                    startValue: m.startValue,
                    targetValue: Value(m.targetValue),
                  ),
                )
                .toList(),
          );
        });
      }

      final habitIds = <int>[];
      for (final h in input.habits) {
        final id = await _db.into(_db.habits).insert(
              HabitsCompanion.insert(
                challengeId: challengeId,
                title: h.title.trim(),
                description: Value(h.description?.trim().isEmpty == true
                    ? null
                    : h.description?.trim()),
                reminderTime: Value(h.reminderTimeIso),
                reminderEnabled: Value(h.reminderEnabled),
              ),
            );
        habitIds.add(id);
      }

      final start = parseIsoDate(input.startDateIso);
      final days = input.durationDays;

      // Create one DayEntry per day and one HabitStatus per habit/day.
      await _db.batch((b) async {
        for (var i = 0; i < days; i++) {
          final date = start.add(Duration(days: i)).toIsoDate();
          final dayEntry = DayEntriesCompanion.insert(
            challengeId: challengeId,
            date: date,
            notes: const Value(null),
          );
          b.insert(_db.dayEntries, dayEntry);
        }
      });

      // Now fetch day entries ids to create status rows. (We keep this simple and
      // stable for v1; performance is fine for <= 365 days.)
      final dayEntries = await (_db.select(_db.dayEntries)
            ..where((t) => t.challengeId.equals(challengeId))
            ..orderBy([(t) => OrderingTerm.asc(t.date)]))
          .get();

      await _db.batch((b) {
        for (final de in dayEntries) {
          for (final hid in habitIds) {
            b.insert(
              _db.habitStatuses,
              HabitStatusesCompanion.insert(
                dayEntryId: de.id,
                habitId: hid,
                status: Value(HabitStatusValue.notMarked),
                updatedAt: Value(DateTime.now()),
              ),
            );
          }
        }
      });

      return challengeId;
    });
  }

  Future<void> updateHabitReminder({
    required int habitId,
    required bool enabled,
    required String? reminderTimeIso,
  }) async {
    await (_db.update(_db.habits)..where((t) => t.id.equals(habitId))).write(
      HabitsCompanion(
        reminderEnabled: Value(enabled),
        reminderTime: Value(reminderTimeIso),
      ),
    );
  }

  Future<void> deleteChallenge(int challengeId) async {
    await (_db.delete(_db.challenges)..where((t) => t.id.equals(challengeId)))
        .go();
  }

  Future<int> seedDemoData() async {
    final today = DateTime.now().toDateOnly();
    final start = today.subtract(const Duration(days: 6)).toIsoDate();

    final id = await createChallengeWithPlan(
      NewChallengeInput(
        name: '30-Day Reset',
        startDateIso: start,
        durationDays: 30,
        notes: 'Demo challenge (local only).',
        metrics: [
          NewMetricInput(
            name: 'Minutes meditated',
            unit: 'min',
            startValue: 5,
            targetValue: 15,
          ),
        ],
        habits: [
          NewHabitInput(
            title: 'Meditate',
            description: '10 minutes',
            reminderEnabled: false,
            reminderTimeIso: null,
          ),
          NewHabitInput(
            title: 'Drink water',
            description: '2 liters',
            reminderEnabled: false,
            reminderTimeIso: null,
          ),
          NewHabitInput(
            title: 'Walk',
            description: '30 minutes',
            reminderEnabled: false,
            reminderTimeIso: null,
          ),
        ],
      ),
    );

    // Paint the last 7 days with a mix of green/red/gray.
    await _db.transaction(() async {
      final habits = await getHabitsForChallenge(id);
      final dayEntries = await (_db.select(_db.dayEntries)
            ..where((t) => t.challengeId.equals(id))
            ..where((t) => t.date.isSmallerOrEqualValue(today.toIsoDate()))
            ..orderBy([(t) => OrderingTerm.asc(t.date)]))
          .get();

      for (var idx = 0; idx < dayEntries.length; idx++) {
        final de = dayEntries[idx];
        final mode = idx % 3; // 0 green, 1 red, 2 gray
        for (var h = 0; h < habits.length; h++) {
          final status = switch (mode) {
            0 => HabitStatusValue.done,
            1 => (h == 0 ? HabitStatusValue.notDone : HabitStatusValue.done),
            _ => HabitStatusValue.notMarked,
          };

          await (_db.update(_db.habitStatuses)
                ..where((t) => t.dayEntryId.equals(de.id))
                ..where((t) => t.habitId.equals(habits[h].id)))
              .write(
            HabitStatusesCompanion(
              status: Value(status),
              updatedAt: Value(DateTime.now()),
            ),
          );
        }
      }
    });

    return id;
  }
}

