import 'package:drift/drift.dart';

import '../../core/utils/date_time_utils.dart';
import '../../domain/models/progress_models.dart';
import '../db/app_database.dart';

class ProgressRepository {
  ProgressRepository(this._db);
  final AppDatabase _db;

  Stream<List<DaySummary>> watchDaySummariesInRange({
    required int challengeId,
    required String fromIso,
    required String toIso,
  }) {
    return _daySummariesQuery(
      challengeId: challengeId,
      fromIso: fromIso,
      toIso: toIso,
    ).watch().map(_mapDaySummaryRows);
  }

  Future<List<DaySummary>> getDaySummariesInRange({
    required int challengeId,
    required String fromIso,
    required String toIso,
  }) async {
    final rows = await _daySummariesQuery(
      challengeId: challengeId,
      fromIso: fromIso,
      toIso: toIso,
    ).get();
    return _mapDaySummaryRows(rows);
  }

  Future<DaySummary?> getDaySummary({
    required int challengeId,
    required String dateIso,
  }) async {
    final list = await getDaySummariesInRange(
      challengeId: challengeId,
      fromIso: dateIso,
      toIso: dateIso,
    );
    return list.isEmpty ? null : list.first;
  }

  Future<ProgressStats> computeStats({
    required int challengeId,
    required DateTime today,
  }) async {
    final challenge = await (_db.select(_db.challenges)
          ..where((t) => t.id.equals(challengeId)))
        .getSingleOrNull();
    if (challenge == null) {
      return ProgressStats(
        greenDays: 0,
        totalDays: 0,
        completionPercent: 0,
        currentStreak: 0,
      );
    }

    final start = parseIsoDate(challenge.startDate);
    final end = start.add(Duration(days: challenge.durationDays - 1));
    final todayOnly = today.toDateOnly();
    if (todayOnly.isBefore(start)) {
      return ProgressStats(
        greenDays: 0,
        totalDays: 0,
        completionPercent: 0,
        currentStreak: 0,
      );
    }

    final upTo = todayOnly.isAfter(end) ? end : todayOnly;

    final totalDays = upTo.difference(start).inDays + 1;

    if (totalDays <= 0) {
      return ProgressStats(
        greenDays: 0,
        totalDays: 0,
        completionPercent: 0,
        currentStreak: 0,
      );
    }

    final summaries = await getDaySummariesInRange(
      challengeId: challengeId,
      fromIso: start.toIsoDate(),
      toIso: upTo.toIsoDate(),
    );

    final greenDays = summaries.where((s) => s.color == DayColor.green).length;
    final completionPercent = greenDays / totalDays;

    var streak = 0;
    for (final s in summaries.reversed) {
      if (s.color == DayColor.green) {
        streak++;
      } else {
        break;
      }
    }

    return ProgressStats(
      greenDays: greenDays,
      totalDays: totalDays,
      completionPercent: completionPercent,
      currentStreak: streak,
    );
  }

  Selectable<QueryRow> _daySummariesQuery({
    required int challengeId,
    required String fromIso,
    required String toIso,
  }) {
    // Use a custom query for stable aggregation + performance.
    return _db.customSelect(
      '''
SELECT
  de.date AS date,
  SUM(CASE WHEN hs.status = 'done' THEN 1 ELSE 0 END) AS done_count,
  SUM(CASE WHEN hs.status = 'not_done' THEN 1 ELSE 0 END) AS not_done_count,
  COUNT(hs.id) AS total_count
FROM day_entries de
JOIN habit_statuses hs ON hs.day_entry_id = de.id
WHERE de.challenge_id = ?1
  AND de.date >= ?2
  AND de.date <= ?3
GROUP BY de.id
ORDER BY de.date ASC
''',
      variables: [
        Variable.withInt(challengeId),
        Variable.withString(fromIso),
        Variable.withString(toIso),
      ],
      readsFrom: {
        _db.dayEntries,
        _db.habitStatuses,
      },
    );
  }

  List<DaySummary> _mapDaySummaryRows(List<QueryRow> rows) {
    return rows.map((r) {
      final date = r.read<String>('date');
      final done = r.read<int>('done_count');
      final notDone = r.read<int>('not_done_count');
      final total = r.read<int>('total_count');

      final color = notDone > 0
          ? DayColor.red
          : (total > 0 && done == total ? DayColor.green : DayColor.gray);

      return DaySummary(
        dateIso: date,
        color: color,
        doneCount: done,
        notDoneCount: notDone,
        totalCount: total,
      );
    }).toList();
  }
}

