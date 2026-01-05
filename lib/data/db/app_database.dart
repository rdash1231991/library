import 'package:drift/drift.dart';

import 'database_connection.dart';
import 'tables/app_tables.dart';

part 'app_database.g.dart';

LazyDatabase _openConnection() {
  return LazyDatabase(() => openQueryExecutor());
}

@DriftDatabase(
  tables: [
    Challenges,
    Habits,
    DayEntries,
    HabitStatuses,
    Metrics,
    AppSettings,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
        },
        onUpgrade: (m, from, to) async {
          // v1 shipped with initial schema. Future migrations go here.
          // Example:
          // if (from < 2) await m.addColumn(table, column);
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
          await customStatement('PRAGMA journal_mode = WAL');
        },
      );
}

