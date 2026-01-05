import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/utils/date_time_utils.dart';
import '../../data/db/tables/app_tables.dart';
import '../../data/repositories/repository_providers.dart';
import '../../domain/models/checklist_models.dart';
import '../../domain/services/service_providers.dart';

class ChecklistScreen extends ConsumerStatefulWidget {
  const ChecklistScreen({
    super.key,
    required this.challengeId,
    this.dateIso,
  });

  final int challengeId;
  final String? dateIso;

  @override
  ConsumerState<ChecklistScreen> createState() => _ChecklistScreenState();
}

class _ChecklistScreenState extends ConsumerState<ChecklistScreen> {
  final _notes = TextEditingController();
  final _status = <int, HabitStatusValue>{};
  var _didInit = false;

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dateIso = widget.dateIso ?? DateTime.now().toDateOnly().toIsoDate();
    final challengeAsync = ref.watch(_challengeProvider(widget.challengeId));
    final allChallengesAsync = ref.watch(_allChallengesProvider);
    final dayAsync = ref.watch(_checklistProvider((widget.challengeId, dateIso)));

    return Scaffold(
      appBar: AppBar(
        title: challengeAsync.when(
          data: (c) => Text(c?.name ?? 'Checklist'),
          loading: () => const Text('Checklist'),
          error: (_, _) => const Text('Checklist'),
        ),
        actions: [
          allChallengesAsync.maybeWhen(
            data: (list) => list.length <= 1
                ? const SizedBox.shrink()
                : PopupMenuButton<int>(
                    tooltip: 'Switch challenge',
                    icon: const Icon(Icons.swap_horiz),
                    onSelected: (id) async {
                      await ref
                          .read(appSettingsRepositoryProvider)
                          .setSelectedChallengeId(id);
                      if (!context.mounted) return;
                      context.go('/checklist/$id?date=$dateIso');
                    },
                    itemBuilder: (context) => [
                      for (final c in list)
                        PopupMenuItem(
                          value: c.id,
                          child: Text(
                            c.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                  ),
            orElse: () => const SizedBox.shrink(),
          ),
          IconButton(
            tooltip: 'Reminders',
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              builder: (_) => _RemindersSheet(challengeId: widget.challengeId),
            ),
            icon: const Icon(Icons.notifications_active),
          ),
          IconButton(
            tooltip: 'Calendar',
            onPressed: () => context.push('/calendar/${widget.challengeId}'),
            icon: const Icon(Icons.calendar_month),
          ),
          IconButton(
            tooltip: 'Share',
            onPressed: () => context.push('/share/${widget.challengeId}'),
            icon: const Icon(Icons.ios_share),
          ),
        ],
      ),
      body: dayAsync.when(
        data: (day) {
          if (day == null) {
            return const Center(child: Text('No checklist for this date.'));
          }

          if (!_didInit) {
            _didInit = true;
            _notes.text = day.notes ?? '';
            _status
              ..clear()
              ..addEntries(day.habits.map((h) => MapEntry(h.habitId, h.status)));
          }

          return SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                Text(
                  formatFriendlyDate(parseIsoDate(dateIso)),
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Text(
                  'Tap: Done • Double tap: Not Done • Long press: Reset',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 14),
                ...day.habits.map((h) => _HabitRow(
                      habit: h,
                      status: _status[h.habitId] ?? HabitStatusValue.notMarked,
                      onTap: () => setState(() {
                        final current =
                            _status[h.habitId] ?? HabitStatusValue.notMarked;
                        _status[h.habitId] = current == HabitStatusValue.done
                            ? HabitStatusValue.notMarked
                            : HabitStatusValue.done;
                      }),
                      onDoubleTap: () => setState(() {
                        final current =
                            _status[h.habitId] ?? HabitStatusValue.notMarked;
                        _status[h.habitId] = current == HabitStatusValue.notDone
                            ? HabitStatusValue.notMarked
                            : HabitStatusValue.notDone;
                      }),
                      onLongPress: () => setState(() {
                        _status[h.habitId] = HabitStatusValue.notMarked;
                      }),
                    )),
                const SizedBox(height: 18),
                TextField(
                  controller: _notes,
                  minLines: 2,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    labelText: 'Notes for today (optional)',
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () async {
                      await ref.read(checklistRepositoryProvider).saveChecklistDay(
                            dayEntryId: day.dayEntryId,
                            notes: _notes.text,
                            statusByHabitId: Map<int, HabitStatusValue>.from(_status),
                          );
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Progress saved')),
                      );
                    },
                    icon: const Icon(Icons.check_circle),
                    label: const Text('Save progress'),
                  ),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Failed to load checklist: $e')),
      ),
    );
  }
}

final _challengeProvider = StreamProvider.family((ref, int challengeId) {
  return ref.watch(challengeRepositoryProvider).watchChallenge(challengeId);
});

final _allChallengesProvider = StreamProvider((ref) {
  return ref.watch(challengeRepositoryProvider).watchChallenges();
});

typedef _ChecklistKey = (int challengeId, String dateIso);

final _checklistProvider = FutureProvider.family<ChecklistDay?, _ChecklistKey>(
  (ref, key) async {
    return ref.read(checklistRepositoryProvider).getChecklistDay(
          challengeId: key.$1,
          dateIso: key.$2,
        );
  },
);

class _HabitRow extends StatelessWidget {
  const _HabitRow({
    required this.habit,
    required this.status,
    required this.onTap,
    required this.onDoubleTap,
    required this.onLongPress,
  });

  final ChecklistHabitItem habit;
  final HabitStatusValue status;
  final VoidCallback onTap;
  final VoidCallback onDoubleTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final (bg, fg, icon) = switch (status) {
      HabitStatusValue.done => (Colors.green.shade600, Colors.white, Icons.check),
      HabitStatusValue.notDone =>
        (Colors.red.shade600, Colors.white, Icons.close),
      HabitStatusValue.notMarked => (cs.surfaceContainerHighest, cs.onSurface, Icons.remove),
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          onDoubleTap: onDoubleTap,
          onLongPress: onLongPress,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  height: 40,
                  width: 40,
                  decoration: BoxDecoration(
                    color: fg.withAlpha(
                      ((status == HabitStatusValue.notMarked ? 0.12 : 0.2) * 255)
                          .round(),
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: fg),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        habit.title,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(
                              color: fg,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      if (habit.description != null &&
                          habit.description!.trim().isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          habit.description!.trim(),
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(color: fg.withAlpha((0.9 * 255).round())),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Icon(Icons.touch_app, color: fg.withAlpha((0.85 * 255).round())),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RemindersSheet extends ConsumerWidget {
  const _RemindersSheet({required this.challengeId});

  final int challengeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final challengeAsync = ref.watch(_challengeProvider(challengeId));
    final habitsAsync = ref.watch(_habitsProvider(challengeId));

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Habit reminders',
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          Text(
            'Enable/disable and change reminder times. Changes reschedule notifications.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 12),
          habitsAsync.when(
            data: (habits) {
              if (habits.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: Text('No habits found.'),
                );
              }

              return challengeAsync.when(
                data: (challenge) {
                  if (challenge == null) {
                    return const Padding(
                      padding: EdgeInsets.only(top: 12),
                      child: Text('Challenge not found.'),
                    );
                  }

                  return ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemBuilder: (context, idx) {
                      final h = habits[idx];
                      final tod = isoToTimeOfDay(h.reminderTime);

                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(h.title),
                        subtitle: Text(
                          h.reminderEnabled && h.reminderTime != null
                              ? 'Daily at ${h.reminderTime}'
                              : 'Off',
                        ),
                        trailing: Switch(
                          value: h.reminderEnabled,
                          onChanged: (v) async {
                            final notif = ref.read(notificationServiceProvider);
                            if (v) {
                              final ok = await notif.requestPermissions();
                              if (!ok) {
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Notification permission not granted.'),
                                  ),
                                );
                                return;
                              }
                            }

                            final repo = ref.read(challengeRepositoryProvider);
                            final nextTimeIso = v
                                ? (h.reminderTime ?? '08:00')
                                : null;

                            await repo.updateHabitReminder(
                              habitId: h.id,
                              enabled: v,
                              reminderTimeIso: nextTimeIso,
                            );

                            await notif.cancelHabitWithinWindow(
                              habitId: h.id,
                              startDateIso: challenge.startDate,
                              durationDays: challenge.durationDays,
                            );

                            if (v && nextTimeIso != null) {
                              await notif.scheduleHabitDailyWithinWindow(
                                habitId: h.id,
                                habitTitle: h.title,
                                habitDescription: h.description,
                                startDateIso: challenge.startDate,
                                durationDays: challenge.durationDays,
                                timeIso: nextTimeIso,
                              );
                            }
                          },
                        ),
                        onTap: h.reminderEnabled
                            ? () async {
                                final picked = await showTimePicker(
                                  context: context,
                                  initialTime:
                                      tod ?? const TimeOfDay(hour: 8, minute: 0),
                                );
                                if (picked == null) return;
                                final nextTimeIso = timeOfDayToIso(picked)!;

                                final notif =
                                    ref.read(notificationServiceProvider);
                                final ok = await notif.requestPermissions();
                                if (!ok) {
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content:
                                          Text('Notification permission not granted.'),
                                    ),
                                  );
                                  return;
                                }

                                final repo = ref.read(challengeRepositoryProvider);
                                await repo.updateHabitReminder(
                                  habitId: h.id,
                                  enabled: true,
                                  reminderTimeIso: nextTimeIso,
                                );

                                await notif.cancelHabitWithinWindow(
                                  habitId: h.id,
                                  startDateIso: challenge.startDate,
                                  durationDays: challenge.durationDays,
                                );
                                await notif.scheduleHabitDailyWithinWindow(
                                  habitId: h.id,
                                  habitTitle: h.title,
                                  habitDescription: h.description,
                                  startDateIso: challenge.startDate,
                                  durationDays: challenge.durationDays,
                                  timeIso: nextTimeIso,
                                );
                              }
                            : null,
                      );
                    },
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemCount: habits.length,
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text('Failed to load challenge: $e'),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('Failed to load habits: $e'),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Done'),
            ),
          ),
        ],
      ),
    );
  }
}

final _habitsProvider = StreamProvider.family((ref, int challengeId) {
  return ref.watch(challengeRepositoryProvider).watchHabitsForChallenge(challengeId);
});

