import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/utils/date_time_utils.dart';
import '../../data/db/app_database.dart';
import '../../data/repositories/repository_providers.dart';
import '../../domain/models/progress_models.dart';
import '../../domain/services/service_providers.dart';
import 'progress_card.dart';

class ShareScreen extends ConsumerStatefulWidget {
  const ShareScreen({super.key, required this.challengeId});

  final int challengeId;

  @override
  ConsumerState<ShareScreen> createState() => _ShareScreenState();
}

class _ShareScreenState extends ConsumerState<ShareScreen> {
  final GlobalKey _cardKey = GlobalKey();

  var _range = _ShareRange.currentMonth;
  var _format = _ShareFormat.story;
  var _sharing = false;

  @override
  Widget build(BuildContext context) {
    final challengeAsync = ref.watch(_challengeProvider(widget.challengeId));
    final statsAsync = ref.watch(_statsProvider(widget.challengeId));

    return Scaffold(
      appBar: AppBar(title: const Text('Share progress')),
      body: challengeAsync.when(
        data: (challenge) {
          if (challenge == null) {
            return const Center(child: Text('Challenge not found.'));
          }

          final now = DateTime.now().toDateOnly();
          final start = parseIsoDate(challenge.startDate);
          final end = start.add(Duration(days: challenge.durationDays - 1));
          final effectiveEnd = now.isAfter(end) ? end : now;

          if (effectiveEnd.isBefore(start)) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('This challenge hasn’t started yet.'),
              ),
            );
          }

          final (from, to, label) = _computeRange(
            range: _range,
            now: now,
            start: start,
            effectiveEnd: effectiveEnd,
          );

          final summariesAsync = ref.watch(
            _summariesProvider((widget.challengeId, from.toIsoDate(), to.toIsoDate())),
          );

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
                const SizedBox(height: 14),
                Text(
                  'Range',
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                SegmentedButton<_ShareRange>(
                  segments: const [
                    ButtonSegment(
                      value: _ShareRange.currentMonth,
                      label: Text('Month'),
                    ),
                    ButtonSegment(
                      value: _ShareRange.last30,
                      label: Text('Last 30'),
                    ),
                  ],
                  selected: {_range},
                  onSelectionChanged: (s) => setState(() => _range = s.first),
                ),
                const SizedBox(height: 12),
                Text(
                  'Format',
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                SegmentedButton<_ShareFormat>(
                  segments: const [
                    ButtonSegment(value: _ShareFormat.story, label: Text('Story')),
                    ButtonSegment(
                        value: _ShareFormat.square, label: Text('Square')),
                  ],
                  selected: {_format},
                  onSelectionChanged: (s) => setState(() => _format = s.first),
                ),
                const SizedBox(height: 16),
                summariesAsync.when(
                  data: (summaries) {
                    final colorByIso = {
                      for (final s in summaries) s.dateIso: s.color,
                    };
                    final days = _buildDaysForHeatmap(
                      range: _range,
                      from: from,
                      to: to,
                    );

                    final completion =
                        statsAsync.asData?.value.completionPercent ?? 0;
                    final streak = statsAsync.asData?.value.currentStreak ?? 0;

                    return Center(
                      child: RepaintBoundary(
                        key: _cardKey,
                        child: ProgressCard(
                          challengeName: challenge.name,
                          rangeLabel: label,
                          days: days,
                          colorByIso: colorByIso,
                          completionPercent: completion,
                          streakDays: streak,
                          isStory: _format == _ShareFormat.story,
                        ),
                      ),
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) =>
                      Center(child: Text('Failed to load progress: $e')),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _sharing
                        ? null
                        : () async {
                            setState(() => _sharing = true);
                            try {
                              final (w, h) = switch (_format) {
                                _ShareFormat.story => (1080, 1920),
                                _ShareFormat.square => (1080, 1080),
                              };

                              final file = await ref
                                  .read(shareImageServiceProvider)
                                  .capturePng(
                                    repaintBoundaryKey: _cardKey,
                                    targetWidthPx: w,
                                    targetHeightPx: h,
                                    fileBaseName:
                                        'habit_challenge_${widget.challengeId}_${_range.name}_${_format.name}_${DateTime.now().millisecondsSinceEpoch}',
                                  );

                              await SharePlus.instance.share(
                                ShareParams(
                                  files: [file],
                                  text: '${challenge.name} • $label',
                                ),
                              );
                            } finally {
                              if (mounted) setState(() => _sharing = false);
                            }
                          },
                    icon: const Icon(Icons.ios_share),
                    label: Text(_sharing ? 'Preparing…' : 'Share'),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Tip: use Instagram “Add to story” from the share sheet.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
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

enum _ShareRange { currentMonth, last30 }
enum _ShareFormat { story, square }

final _challengeProvider = StreamProvider.family<Challenge?, int>((ref, id) {
  return ref.watch(challengeRepositoryProvider).watchChallenge(id);
});

typedef _SummariesKey = (int challengeId, String fromIso, String toIso);

final _summariesProvider =
    FutureProvider.family<List<DaySummary>, _SummariesKey>((ref, key) {
  return ref.read(progressRepositoryProvider).getDaySummariesInRange(
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

(DateTime from, DateTime to, String label) _computeRange({
  required _ShareRange range,
  required DateTime now,
  required DateTime start,
  required DateTime effectiveEnd,
}) {
  return switch (range) {
    _ShareRange.currentMonth => () {
        final from = DateTime(now.year, now.month, 1).toDateOnly();
        final to = DateTime(now.year, now.month + 1, 0).toDateOnly();
        final clampedFrom = from.isBefore(start) ? start : from;
        final clampedTo = to.isAfter(effectiveEnd) ? effectiveEnd : to;
        return (
          clampedFrom,
          clampedTo,
          '${DateFormat.yMMM().format(clampedFrom)} • ${clampedFrom.toIsoDate()} → ${clampedTo.toIsoDate()}',
        );
      }(),
    _ShareRange.last30 => () {
        final from = now.subtract(const Duration(days: 29));
        final clampedFrom = from.isBefore(start) ? start : from;
        return (clampedFrom, effectiveEnd, '${clampedFrom.toIsoDate()} → ${effectiveEnd.toIsoDate()}');
      }(),
  };
}

List<DateTime?> _buildDaysForHeatmap({
  required _ShareRange range,
  required DateTime from,
  required DateTime to,
}) {
  final days = <DateTime?>[];

  if (range == _ShareRange.currentMonth) {
    // Align to Monday=1.
    final leading = (from.weekday - DateTime.monday) % 7;
    for (var i = 0; i < leading; i++) {
      days.add(null);
    }
  }

  for (var d = from; !d.isAfter(to); d = d.add(const Duration(days: 1))) {
    days.add(d.toDateOnly());
  }

  return days;
}

