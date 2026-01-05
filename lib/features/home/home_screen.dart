import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_constants.dart';
import '../../core/utils/date_time_utils.dart';
import '../../data/db/app_database.dart';
import '../../data/repositories/repository_providers.dart';
import '../../domain/models/progress_models.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final challengesAsync = ref.watch(_challengesProvider);
    final selectedIdAsync = ref.watch(_selectedChallengeIdProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Challenges'),
        actions: [
          IconButton(
            tooltip: 'Create New Challenge',
            onPressed: () => context.push('/create'),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: challengesAsync.when(
        data: (challenges) {
          if (challenges.isEmpty) {
            return _EmptyState(
              onCreate: () => context.push('/create'),
              onSeedDemo: AppConstants.enableDemoData
                  ? () async {
                      final repo = ref.read(challengeRepositoryProvider);
                      final id = await repo.seedDemoData();
                      await ref
                          .read(appSettingsRepositoryProvider)
                          .setSelectedChallengeId(id);
                    }
                  : null,
            );
          }

          final selectedId = selectedIdAsync.asData?.value ?? challenges.first.id;
          final selected =
              challenges.firstWhere((c) => c.id == selectedId, orElse: () => challenges.first);

          return ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: _TodayHeader(
                  challenge: selected,
                  onOpen: () => context.push('/checklist/${selected.id}'),
                ),
              ),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
                child: Text(
                  'All challenges',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              ...challenges.map(
                (c) => _ChallengeCard(
                  challenge: c,
                  isSelected: c.id == selectedId,
                  onSelect: () async {
                    await ref
                        .read(appSettingsRepositoryProvider)
                        .setSelectedChallengeId(c.id);
                  },
                  onToday: () => context.push('/checklist/${c.id}'),
                  onCalendar: () => context.push('/calendar/${c.id}'),
                  onShare: () => context.push('/share/${c.id}'),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Failed to load challenges: $e')),
      ),
      floatingActionButton: challengesAsync.maybeWhen(
        data: (list) => list.isEmpty
            ? null
            : FloatingActionButton.extended(
                onPressed: () => context.push('/create'),
                icon: const Icon(Icons.add),
                label: const Text('Create New Challenge'),
              ),
        orElse: () => null,
      ),
    );
  }
}

final _challengesProvider = StreamProvider<List<Challenge>>((ref) {
  return ref.watch(challengeRepositoryProvider).watchChallenges();
});

final _selectedChallengeIdProvider = StreamProvider<int?>((ref) {
  return ref.watch(appSettingsRepositoryProvider).watchSelectedChallengeId();
});

final _statsProvider = FutureProvider.family<ProgressStats, int>((ref, id) async {
  return ref
      .read(progressRepositoryProvider)
      .computeStats(challengeId: id, today: DateTime.now());
});

typedef _TodayKey = (int challengeId, String dateIso);

final _todayProvider = FutureProvider.family<DaySummary?, _TodayKey>((ref, key) {
  return ref.read(progressRepositoryProvider).getDaySummary(
        challengeId: key.$1,
        dateIso: key.$2,
      );
});

class _TodayHeader extends ConsumerWidget {
  const _TodayHeader({required this.challenge, required this.onOpen});

  final Challenge challenge;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final todayIso = DateTime.now().toDateOnly().toIsoDate();
    final todayAsync = ref.watch(_todayProvider((challenge.id, todayIso)));
    final statsAsync = ref.watch(_statsProvider(challenge.id));

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Today',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            Text(
              challenge.name,
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                _Chip(
                  label: todayAsync.when(
                    data: (d) => d == null
                        ? 'No entry'
                        : switch (d.color) {
                            DayColor.green => 'All done',
                            DayColor.red => 'Needs attention',
                            DayColor.gray => 'In progress',
                          },
                    loading: () => 'Loading…',
                    error: (_, _) => '—',
                  ),
                ),
                _Chip(
                  label: statsAsync.when(
                    data: (s) =>
                        'Completion ${(s.completionPercent * 100).toStringAsFixed(0)}%',
                    loading: () => 'Stats…',
                    error: (_, _) => 'Stats —',
                  ),
                ),
                _Chip(
                  label: statsAsync.when(
                    data: (s) => 'Streak ${s.currentStreak}d',
                    loading: () => 'Streak…',
                    error: (_, _) => 'Streak —',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onOpen,
                icon: const Icon(Icons.checklist),
                label: const Text("Open today's checklist"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChallengeCard extends ConsumerWidget {
  const _ChallengeCard({
    required this.challenge,
    required this.isSelected,
    required this.onSelect,
    required this.onToday,
    required this.onCalendar,
    required this.onShare,
  });

  final Challenge challenge;
  final bool isSelected;
  final VoidCallback onSelect;
  final VoidCallback onToday;
  final VoidCallback onCalendar;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(_statsProvider(challenge.id));
    final todayIso = DateTime.now().toDateOnly().toIsoDate();
    final todayAsync = ref.watch(_todayProvider((challenge.id, todayIso)));
    final cs = Theme.of(context).colorScheme;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onSelect,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      challenge.name,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                  if (isSelected)
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: cs.primary.withAlpha((0.12 * 255).round()),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        'Selected',
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                              color: cs.primary,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Starts ${formatFriendlyDate(parseIsoDate(challenge.startDate))} • ${challenge.durationDays} days',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 8,
                children: [
                  _Chip(
                    label: statsAsync.when(
                      data: (s) =>
                          'Completion ${(s.completionPercent * 100).toStringAsFixed(0)}%',
                      loading: () => 'Completion…',
                      error: (_, _) => 'Completion —',
                    ),
                  ),
                  _Chip(
                    label: todayAsync.when(
                      data: (d) => d == null
                          ? 'Today —'
                          : switch (d.color) {
                              DayColor.green => 'Today: green',
                              DayColor.red => 'Today: red',
                              DayColor.gray => 'Today: gray',
                            },
                      loading: () => 'Today…',
                      error: (_, _) => 'Today —',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: onToday,
                      child: const Text('Today'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  IconButton(
                    tooltip: 'Calendar',
                    onPressed: onCalendar,
                    icon: const Icon(Icons.calendar_month),
                  ),
                  IconButton(
                    tooltip: 'Share',
                    onPressed: onShare,
                    icon: const Icon(Icons.ios_share),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context)
            .textTheme
            .labelMedium
            ?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onCreate, this.onSeedDemo});

  final VoidCallback onCreate;
  final Future<void> Function()? onSeedDemo;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.checklist_rounded, size: 56, color: cs.primary),
            const SizedBox(height: 14),
            Text(
              'Start your first challenge',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Create a duration + habits. Then you’ll get a simple daily checklist and a color-coded calendar.',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: cs.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onCreate,
                icon: const Icon(Icons.add),
                label: const Text('Create New Challenge'),
              ),
            ),
            if (onSeedDemo != null) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () async => onSeedDemo!.call(),
                  child: const Text('Seed demo data'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

