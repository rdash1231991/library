import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../db/app_database.dart';
import 'app_settings_repository.dart';
import 'challenge_repository.dart';
import 'checklist_repository.dart';
import 'progress_repository.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final appSettingsRepositoryProvider = Provider<AppSettingsRepository>((ref) {
  return AppSettingsRepository(ref.watch(databaseProvider));
});

final challengeRepositoryProvider = Provider<ChallengeRepository>((ref) {
  return ChallengeRepository(ref.watch(databaseProvider));
});

final checklistRepositoryProvider = Provider<ChecklistRepository>((ref) {
  return ChecklistRepository(ref.watch(databaseProvider));
});

final progressRepositoryProvider = Provider<ProgressRepository>((ref) {
  return ProgressRepository(ref.watch(databaseProvider));
});

