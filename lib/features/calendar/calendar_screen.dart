import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../core/utils/date_time_utils.dart';
import '../../data/db/app_database.dart';
import '../../data/repositories/repository_providers.dart';
import '../../domain/models/progress_models.dart';

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key, required this.challengeId});

  final int challengeId;

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  DateTime _focusedDay = DateTime.now().toDateOnly();
  DateTime? _selectedDay;

  @override
  Widget build(BuildContext context) {
    final challengeAsync = ref.watch(_challengeProvider(widget.challengeId));

    return Scaffold(
      appBar: AppBar(title: const Text('Calendar')),
      body: challengeAsync.when(
        data: (challenge) {
          if (challenge == null) {
            return const Center(child: Text('Challenge not found.'));
          }

          final start = parseIsoDate(challenge.startDate);
          final end = start.add(Duration(days: challenge.durationDays - 1));

          final monthStart = DateTime(_focusedDay.year, _focusedDay.month, 1);
          final monthEnd = DateTime(_focusedDay.year, _focusedDay.month + 1, 0);
          final from = (monthStart.isBefore(start) ? start : monthStart).toIsoDate();
          final to = (monthEnd.isAfter(end) ? end : monthEnd).toIsoDate();

          final summariesAsync = ref.watch(
            _monthSummariesProvider((widget.challengeId, from, to)),
          );
          final statsAsync = ref.watch(_statsProvider(widget.challengeId));

          return SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                Text(
                  challenge.name,
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 10),
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
                      label: statsAsync.when(
                        data: (s) => 'Streak ${s.currentStreak}d',
                        loading: () => 'Streak…',
                        error: (_, _) => 'Streak —',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                summariesAsync.when(
                  data: (summaries) {
                    final map = {
                      for (final s in summaries) s.dateIso: s.color,
                    };

                    return Card(
                      margin: EdgeInsets.zero,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: TableCalendar(
                          firstDay: start,
                          lastDay: end,
                          focusedDay: _focusedDay,
                          currentDay: DateTime.now().toDateOnly(),
                          selectedDayPredicate: (d) =>
                              _selectedDay != null &&
                              isSameDay(_selectedDay, d),
                          onDaySelected: (selectedDay, focusedDay) {
                            setState(() {
                              _selectedDay = selectedDay.toDateOnly();
                              _focusedDay = focusedDay.toDateOnly();
                            });
                            final iso = selectedDay.toDateOnly().toIsoDate();
                            context.push('/checklist/${widget.challengeId}?date=$iso');
                          },
                          onPageChanged: (focusedDay) {
                            setState(() => _focusedDay = focusedDay.toDateOnly());
                          },
                          headerStyle: const HeaderStyle(
                            titleCentered: true,
                            formatButtonVisible: false,
                          ),
                          calendarBuilders: CalendarBuilders(
                            defaultBuilder: (context, day, focusedDay) {
                              final iso = day.toDateOnly().toIsoDate();
                              final color = map[iso];
                              if (color == null) return null;
                              return _DayCell(day: day, color: color);
                            },
                            todayBuilder: (context, day, focusedDay) {
                              final iso = day.toDateOnly().toIsoDate();
                              final color = map[iso] ?? DayColor.gray;
                              return _DayCell(day: day, color: color, isToday: true);
                            },
                            selectedBuilder: (context, day, focusedDay) {
                              final iso = day.toDateOnly().toIsoDate();
                              final color = map[iso] ?? DayColor.gray;
                              return _DayCell(day: day, color: color, isSelected: true);
                            },
                          ),
                        ),
                      ),
                    );
                  },
                  loading: () => const Padding(
                    padding: EdgeInsets.only(top: 24),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (e, _) => Text('Failed to load month: $e'),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: const [
                    _Legend(color: DayColor.green, label: 'All habits done'),
                    _Legend(color: DayColor.red, label: 'Any not done'),
                    _Legend(color: DayColor.gray, label: 'In progress'),
                  ],
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Failed to load challenge: $e')),
      ),
    );
  }
}

final _challengeProvider = StreamProvider.family<Challenge?, int>((ref, id) {
  return ref.watch(challengeRepositoryProvider).watchChallenge(id);
});

typedef _MonthKey = (int challengeId, String fromIso, String toIso);

final _monthSummariesProvider =
    StreamProvider.family<List<DaySummary>, _MonthKey>((ref, key) {
  return ref.watch(progressRepositoryProvider).watchDaySummariesInRange(
        challengeId: key.$1,
        fromIso: key.$2,
        toIso: key.$3,
      );
});

final _statsProvider = FutureProvider.family<ProgressStats, int>((ref, id) {
  return ref
      .read(progressRepositoryProvider)
      .computeStats(challengeId: id, today: DateTime.now());
});

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.color,
    this.isSelected = false,
    this.isToday = false,
  });

  final DateTime day;
  final DayColor color;
  final bool isSelected;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bg = switch (color) {
      DayColor.green => Colors.green.shade600,
      DayColor.red => Colors.red.shade600,
      DayColor.gray => cs.surfaceContainerHighest,
    };
    final fg = color == DayColor.gray ? cs.onSurface : Colors.white;

    return Container(
      margin: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isSelected
              ? cs.primary
              : (isToday
                  ? cs.primary.withAlpha((0.5 * 255).round())
                  : Colors.transparent),
          width: isSelected ? 2 : 1,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        '${day.day}',
        style: Theme.of(context)
            .textTheme
            .labelLarge
            ?.copyWith(color: fg, fontWeight: FontWeight.w800),
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

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});
  final DayColor color;
  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bg = switch (color) {
      DayColor.green => Colors.green.shade600,
      DayColor.red => Colors.red.shade600,
      DayColor.gray => cs.surfaceContainerHighest,
    };
    final fg = color == DayColor.gray ? cs.onSurface : Colors.white;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context)
            .textTheme
            .labelMedium
            ?.copyWith(color: fg, fontWeight: FontWeight.w700),
      ),
    );
  }
}

