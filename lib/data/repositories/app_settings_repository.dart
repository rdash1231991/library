import 'package:drift/drift.dart';

import '../../core/constants/app_constants.dart';
import '../db/app_database.dart';

class AppSettingsRepository {
  AppSettingsRepository(this._db);
  final AppDatabase _db;

  Stream<String?> watchValue(String key) {
    final q = _db.select(_db.appSettings)..where((t) => t.key.equals(key));
    return q.watchSingleOrNull().map((row) => row?.value);
  }

  Future<String?> getValue(String key) async {
    final q = _db.select(_db.appSettings)..where((t) => t.key.equals(key));
    final row = await q.getSingleOrNull();
    return row?.value;
  }

  Future<void> setValue(String key, String? value) async {
    await _db.into(_db.appSettings).insertOnConflictUpdate(
          AppSettingsCompanion(
            key: Value(key),
            value: Value(value),
          ),
        );
  }

  Stream<bool> watchHasOnboarded() {
    return watchValue(AppConstants.settingsKeyHasOnboarded)
        .map((v) => v == 'true');
  }

  Future<void> setHasOnboarded(bool value) =>
      setValue(AppConstants.settingsKeyHasOnboarded, value ? 'true' : 'false');

  Stream<int?> watchSelectedChallengeId() {
    return watchValue(AppConstants.settingsKeySelectedChallengeId)
        .map((v) => int.tryParse(v ?? ''));
  }

  Future<int?> getSelectedChallengeId() async {
    final v = await getValue(AppConstants.settingsKeySelectedChallengeId);
    return int.tryParse(v ?? '');
  }

  Future<void> setSelectedChallengeId(int? id) =>
      setValue(AppConstants.settingsKeySelectedChallengeId, id?.toString());
}

