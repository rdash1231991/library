import 'package:drift/drift.dart';

enum HabitStatusValue { notMarked, done, notDone }

class HabitStatusConverter extends TypeConverter<HabitStatusValue, String> {
  const HabitStatusConverter();

  @override
  HabitStatusValue fromSql(String fromDb) {
    return switch (fromDb) {
      'not_marked' => HabitStatusValue.notMarked,
      'done' => HabitStatusValue.done,
      'not_done' => HabitStatusValue.notDone,
      _ => HabitStatusValue.notMarked,
    };
  }

  @override
  String toSql(HabitStatusValue value) {
    return switch (value) {
      HabitStatusValue.notMarked => 'not_marked',
      HabitStatusValue.done => 'done',
      HabitStatusValue.notDone => 'not_done',
    };
  }
}

class Challenges extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 120)();
  TextColumn get startDate => text().withLength(min: 10, max: 10)(); // yyyy-MM-dd
  IntColumn get durationDays => integer()();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();
}

class Habits extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get challengeId =>
      integer().references(Challenges, #id, onDelete: KeyAction.cascade)();
  TextColumn get title => text().withLength(min: 1, max: 120)();
  TextColumn get description => text().nullable()();
  TextColumn get reminderTime =>
      text().nullable().withLength(min: 5, max: 5)(); // HH:mm
  BoolColumn get reminderEnabled =>
      boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();
}

class DayEntries extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get challengeId =>
      integer().references(Challenges, #id, onDelete: KeyAction.cascade)();
  TextColumn get date => text().withLength(min: 10, max: 10)(); // yyyy-MM-dd
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();

  @override
  List<Set<Column>> get uniqueKeys => [
        {challengeId, date},
      ];
}

class HabitStatuses extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get dayEntryId =>
      integer().references(DayEntries, #id, onDelete: KeyAction.cascade)();
  IntColumn get habitId =>
      integer().references(Habits, #id, onDelete: KeyAction.cascade)();
  TextColumn get status =>
      text().map(const HabitStatusConverter()).withDefault(
            Constant(const HabitStatusConverter()
                .toSql(HabitStatusValue.notMarked)),
          )();
  DateTimeColumn get updatedAt =>
      dateTime().withDefault(currentDateAndTime)();

  @override
  List<Set<Column>> get uniqueKeys => [
        {dayEntryId, habitId},
      ];
}

class Metrics extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get challengeId =>
      integer().references(Challenges, #id, onDelete: KeyAction.cascade)();
  TextColumn get name => text().withLength(min: 1, max: 80)();
  TextColumn get unit => text().withLength(min: 0, max: 24)();
  RealColumn get startValue => real()();
  RealColumn get targetValue => real().nullable()();
}

/// Simple key/value storage for local-only settings.
class AppSettings extends Table {
  TextColumn get key => text().withLength(min: 1, max: 64)();
  TextColumn get value => text().nullable()();

  @override
  Set<Column> get primaryKey => {key};
}

