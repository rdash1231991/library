import 'package:flutter/material.dart';

import '../../core/utils/date_time_utils.dart';
import '../../domain/models/progress_models.dart';

class ProgressCard extends StatelessWidget {
  const ProgressCard({
    super.key,
    required this.challengeName,
    required this.rangeLabel,
    required this.days,
    required this.colorByIso,
    required this.completionPercent,
    required this.streakDays,
    required this.isStory,
  });

  final String challengeName;
  final String rangeLabel;
  final List<DateTime?> days; // includes null placeholders for alignment
  final Map<String, DayColor> colorByIso; // yyyy-MM-dd -> color
  final double completionPercent; // 0..1
  final int streakDays;
  final bool isStory;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bg = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        cs.primaryContainer,
        cs.surface,
        cs.secondaryContainer,
      ],
    );

    final width = isStory ? 360.0 : 360.0;
    final height = isStory ? 640.0 : 360.0;

    return SizedBox(
      width: width,
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: bg,
          borderRadius: BorderRadius.circular(28),
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                challengeName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 6),
              Text(
                rangeLabel,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 14),
              Expanded(
                child: Center(
                  child: _Heatmap(days: days, colorByIso: colorByIso),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _StatPill(
                      label: 'Completion',
                      value: '${(completionPercent * 100).toStringAsFixed(0)}%',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _StatPill(
                      label: 'Streak',
                      value: '$streakDays days',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'Habit Challenge Tracker',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.2,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Heatmap extends StatelessWidget {
  const _Heatmap({required this.days, required this.colorByIso});

  final List<DateTime?> days;
  final Map<String, DayColor> colorByIso;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        const cols = 7;
        final cell = (constraints.maxWidth / cols).floorToDouble();
        final size = cell.clamp(10.0, 26.0).toDouble();

        return Wrap(
          spacing: 4,
          runSpacing: 4,
          children: [
            for (final d in days)
              Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  color: d == null
                      ? Colors.transparent
                      : switch (colorByIso[d.toIsoDate()] ?? DayColor.gray) {
                          DayColor.green => Colors.green.shade600,
                          DayColor.red => Colors.red.shade600,
                          DayColor.gray => cs.surfaceContainerHighest,
                        },
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: cs.surface.withAlpha((0.75 * 255).round()),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

