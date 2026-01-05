import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/utils/date_time_utils.dart';
import '../../data/repositories/repository_providers.dart';
import '../../domain/models/new_challenge_input.dart';
import '../../domain/services/service_providers.dart';

class CreateChallengeScreen extends ConsumerStatefulWidget {
  const CreateChallengeScreen({super.key});

  @override
  ConsumerState<CreateChallengeScreen> createState() =>
      _CreateChallengeScreenState();
}

class _CreateChallengeScreenState extends ConsumerState<CreateChallengeScreen> {
  final _name = TextEditingController();
  final _notes = TextEditingController();

  var _step = 0;
  var _durationPreset = _DurationPreset.thirty;
  final _customDuration = TextEditingController(text: '21');
  DateTime _startDate = DateTime.now().toDateOnly();

  final List<_MetricDraft> _metrics = [];
  final List<_HabitDraft> _habits = [];

  var _saving = false;

  @override
  void initState() {
    super.initState();
    _metrics.add(_MetricDraft());
  }

  @override
  void dispose() {
    _name.dispose();
    _notes.dispose();
    _customDuration.dispose();
    for (final m in _metrics) {
      m.dispose();
    }
    super.dispose();
  }

  int? _durationDays() {
    return switch (_durationPreset) {
      _DurationPreset.thirty => 30,
      _DurationPreset.sixty => 60,
      _DurationPreset.custom => int.tryParse(_customDuration.text.trim()),
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Challenge')),
      body: Stepper(
        currentStep: _step,
        onStepContinue: () async {
          if (_step < 2) {
            setState(() => _step++);
            return;
          }
          await _save();
        },
        onStepCancel: () {
          if (_step == 0) {
            context.pop();
          } else {
            setState(() => _step--);
          }
        },
        controlsBuilder: (context, details) {
          return Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: _saving ? null : details.onStepContinue,
                    child: Text(_step < 2 ? 'Next' : (_saving ? 'Saving…' : 'Save')),
                  ),
                ),
                const SizedBox(width: 10),
                TextButton(
                  onPressed: _saving ? null : details.onStepCancel,
                  child: Text(_step == 0 ? 'Close' : 'Back'),
                ),
              ],
            ),
          );
        },
        steps: [
          Step(
            title: const Text('Basics'),
            isActive: _step >= 0,
            content: _stepBasics(context),
          ),
          Step(
            title: const Text('Habits'),
            isActive: _step >= 1,
            content: _stepHabits(context),
          ),
          Step(
            title: const Text('Review'),
            isActive: _step >= 2,
            content: _stepReview(context),
          ),
        ],
      ),
    );
  }

  Widget _stepBasics(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _name,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(
            labelText: 'Challenge name',
            hintText: 'e.g., 30-Day Mind + Body',
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Duration',
          style: Theme.of(context)
              .textTheme
              .titleSmall
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        SegmentedButton<_DurationPreset>(
          segments: const [
            ButtonSegment(value: _DurationPreset.thirty, label: Text('30')),
            ButtonSegment(value: _DurationPreset.sixty, label: Text('60')),
            ButtonSegment(value: _DurationPreset.custom, label: Text('Custom')),
          ],
          selected: {_durationPreset},
          onSelectionChanged: (s) => setState(() => _durationPreset = s.first),
        ),
        if (_durationPreset == _DurationPreset.custom) ...[
          const SizedBox(height: 10),
          TextField(
            controller: _customDuration,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Custom duration (days)',
            ),
          ),
        ],
        const SizedBox(height: 12),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Start date'),
          subtitle: Text(formatFriendlyDate(_startDate)),
          trailing: const Icon(Icons.date_range),
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              firstDate: DateTime.now().subtract(const Duration(days: 365 * 5)),
              lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
              initialDate: _startDate,
            );
            if (picked != null) setState(() => _startDate = picked.toDateOnly());
          },
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _notes,
          minLines: 2,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: 'Notes (optional)',
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Metrics / Baseline (optional)',
          style: Theme.of(context)
              .textTheme
              .titleSmall
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        ..._metrics.map((m) => _MetricEditor(
              draft: m,
              onDelete: _metrics.length <= 1
                  ? null
                  : () => setState(() {
                        m.dispose();
                        _metrics.remove(m);
                      }),
            )),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => setState(() => _metrics.add(_MetricDraft())),
            icon: const Icon(Icons.add),
            label: const Text('Add metric'),
          ),
        ),
      ],
    );
  }

  Widget _stepHabits(BuildContext context) {
    return Column(
      children: [
        if (_habits.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              'Add at least one habit. This is your daily checklist.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
        ..._habits.map((h) {
          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: ListTile(
              title: Text(h.title),
              subtitle: Text(
                [
                  if (h.description?.trim().isNotEmpty == true)
                    h.description!.trim(),
                  if (h.reminderEnabled && h.reminderTime != null)
                    'Reminder: ${timeOfDayToIso(h.reminderTime)}',
                ].join(' • '),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Edit',
                    onPressed: () async {
                      final edited = await showModalBottomSheet<_HabitDraft>(
                        context: context,
                        isScrollControlled: true,
                        builder: (ctx) => _EditHabitSheet(initial: h),
                      );
                      if (edited != null) {
                        setState(() {
                          final idx = _habits.indexOf(h);
                          _habits[idx] = edited;
                        });
                      }
                    },
                    icon: const Icon(Icons.edit),
                  ),
                  IconButton(
                    tooltip: 'Delete',
                    onPressed: () => setState(() => _habits.remove(h)),
                    icon: const Icon(Icons.delete_outline),
                  ),
                ],
              ),
            ),
          );
        }),
        const SizedBox(height: 6),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () async {
              final created = await showModalBottomSheet<_HabitDraft>(
                context: context,
                isScrollControlled: true,
                builder: (ctx) => const _EditHabitSheet(),
              );
              if (created != null) setState(() => _habits.add(created));
            },
            icon: const Icon(Icons.add),
            label: const Text('Add habit'),
          ),
        ),
      ],
    );
  }

  Widget _stepReview(BuildContext context) {
    final duration = _durationDays();
    final durationText = duration == null ? '—' : '$duration days';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _name.text.trim().isEmpty ? 'Untitled challenge' : _name.text.trim(),
          style: Theme.of(context)
              .textTheme
              .titleLarge
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Text('Starts: ${formatFriendlyDate(_startDate)}'),
        Text('Duration: $durationText'),
        const SizedBox(height: 12),
        Text(
          'Habits (${_habits.length})',
          style: Theme.of(context)
              .textTheme
              .titleSmall
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        ..._habits.map((h) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text('• ${h.title}'),
            )),
        const SizedBox(height: 10),
        Text(
          'Metrics (${_metrics.where((m) => m.hasAnyInput).length})',
          style: Theme.of(context)
              .textTheme
              .titleSmall
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        ..._metrics.where((m) => m.hasAnyInput).map((m) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text('• ${m.name.text.trim()} (${m.unit.text.trim()})'),
            )),
        const SizedBox(height: 10),
        Text(
          'Tip: you can tap a habit once (Done), double tap (Not Done), or long press (Reset).',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      ],
    );
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    final duration = _durationDays();

    if (name.isEmpty) {
      _toast('Please enter a challenge name.');
      setState(() => _step = 0);
      return;
    }
    if (duration == null || duration <= 0 || duration > 3650) {
      _toast('Please enter a valid duration in days.');
      setState(() => _step = 0);
      return;
    }
    if (_habits.isEmpty) {
      _toast('Please add at least one habit.');
      setState(() => _step = 1);
      return;
    }

    final metrics = _metrics
        .where((m) => m.hasAnyInput)
        .map((m) {
          final start = double.tryParse(m.startValue.text.trim());
          if (m.name.text.trim().isEmpty ||
              m.unit.text.trim().isEmpty ||
              start == null) {
            return null;
          }
          final target = double.tryParse(m.targetValue.text.trim());
          return NewMetricInput(
            name: m.name.text.trim(),
            unit: m.unit.text.trim(),
            startValue: start,
            targetValue: target,
          );
        })
        .whereType<NewMetricInput>()
        .toList();

    final habits = _habits.map((h) {
      return NewHabitInput(
        title: h.title.trim(),
        description: h.description?.trim(),
        reminderEnabled: h.reminderEnabled,
        reminderTimeIso:
            h.reminderEnabled ? timeOfDayToIso(h.reminderTime) : null,
      );
    }).toList();

    setState(() => _saving = true);
    try {
      final repo = ref.read(challengeRepositoryProvider);
      final id = await repo.createChallengeWithPlan(
        NewChallengeInput(
          name: name,
          startDateIso: _startDate.toIsoDate(),
          durationDays: duration,
          notes: _notes.text,
          habits: habits,
          metrics: metrics,
        ),
      );

      await ref.read(appSettingsRepositoryProvider).setSelectedChallengeId(id);

      // Notifications: schedule only when reminders exist.
      final needsNotifs = habits.any((h) => h.reminderEnabled && h.reminderTimeIso != null);
      if (needsNotifs) {
        final ok = await ref.read(notificationServiceProvider).requestPermissions();
        if (ok) {
          final challenge = await repo.getChallenge(id);
          final savedHabits = await repo.getHabitsForChallenge(id);
          if (challenge != null) {
            for (final h in savedHabits) {
              if (h.reminderEnabled && h.reminderTime != null) {
                await ref.read(notificationServiceProvider).scheduleHabitDailyWithinWindow(
                      habitId: h.id,
                      habitTitle: h.title,
                      habitDescription: h.description,
                      startDateIso: challenge.startDate,
                      durationDays: challenge.durationDays,
                      timeIso: h.reminderTime!,
                    );
              }
            }
          }
        }
      }

      if (!mounted) return;
      context.go('/checklist/$id');
    } catch (e) {
      _toast('Failed to save: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}

enum _DurationPreset { thirty, sixty, custom }

class _MetricDraft {
  final name = TextEditingController();
  final unit = TextEditingController();
  final startValue = TextEditingController();
  final targetValue = TextEditingController();

  bool get hasAnyInput =>
      name.text.trim().isNotEmpty ||
      unit.text.trim().isNotEmpty ||
      startValue.text.trim().isNotEmpty ||
      targetValue.text.trim().isNotEmpty;

  void dispose() {
    name.dispose();
    unit.dispose();
    startValue.dispose();
    targetValue.dispose();
  }
}

class _MetricEditor extends StatelessWidget {
  const _MetricEditor({required this.draft, this.onDelete});

  final _MetricDraft draft;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: draft.name,
                    decoration: const InputDecoration(labelText: 'Metric name'),
                  ),
                ),
                if (onDelete != null) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'Remove metric',
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: draft.unit,
                    decoration: const InputDecoration(labelText: 'Unit'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: draft.startValue,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Starting value'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: draft.targetValue,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Target value (optional)',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HabitDraft {
  _HabitDraft({
    required this.title,
    this.description,
    required this.reminderEnabled,
    this.reminderTime,
  });

  final String title;
  final String? description;
  final bool reminderEnabled;
  final TimeOfDay? reminderTime;
}

class _EditHabitSheet extends StatefulWidget {
  const _EditHabitSheet({this.initial});

  final _HabitDraft? initial;

  @override
  State<_EditHabitSheet> createState() => _EditHabitSheetState();
}

class _EditHabitSheetState extends State<_EditHabitSheet> {
  late final TextEditingController _title;
  late final TextEditingController _desc;
  var _reminderEnabled = false;
  TimeOfDay? _reminderTime;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.initial?.title ?? '');
    _desc = TextEditingController(text: widget.initial?.description ?? '');
    _reminderEnabled = widget.initial?.reminderEnabled ?? false;
    _reminderTime = widget.initial?.reminderTime;
  }

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
            widget.initial == null ? 'Add habit' : 'Edit habit',
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _title,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(labelText: 'Title'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _desc,
            minLines: 1,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Description (optional)',
              hintText: 'e.g., 30 mins run',
            ),
          ),
          const SizedBox(height: 10),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Reminder'),
            value: _reminderEnabled,
            onChanged: (v) => setState(() => _reminderEnabled = v),
          ),
          if (_reminderEnabled) ...[
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Reminder time'),
              subtitle:
                  Text(_reminderTime == null ? 'Not set' : timeOfDayToIso(_reminderTime)!),
              trailing: const Icon(Icons.access_time),
              onTap: () async {
                final picked = await showTimePicker(
                  context: context,
                  initialTime: _reminderTime ?? const TimeOfDay(hour: 8, minute: 0),
                );
                if (picked != null) setState(() => _reminderTime = picked);
              },
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () {
                final title = _title.text.trim();
                if (title.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter a habit title.')),
                  );
                  return;
                }
                Navigator.of(context).pop(
                  _HabitDraft(
                    title: title,
                    description: _desc.text.trim().isEmpty ? null : _desc.text.trim(),
                    reminderEnabled: _reminderEnabled,
                    reminderTime: _reminderEnabled ? _reminderTime : null,
                  ),
                );
              },
              child: const Text('Save habit'),
            ),
          ),
        ],
      ),
    );
  }
}

