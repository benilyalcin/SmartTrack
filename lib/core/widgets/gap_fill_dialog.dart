import 'package:flutter/material.dart';

import '../localization/localization.dart';
import '../providers/app_state.dart';
import '../services/driving_time_calculator.dart';
import '../services/violation_analyzer.dart';

/// Asks the driver what they did during a stretch the card file has no
/// record for. The stretch can be split into parts, each with its own
/// activity, at any date and time inside it.
class GapFillDialog extends StatefulWidget {
  final ActivityGap gap;
  const GapFillDialog({super.key, required this.gap});

  @override
  State<GapFillDialog> createState() => _GapFillDialogState();
}

class _GapFillDialogState extends State<GapFillDialog> {
  static const _selectableTypes = [
    ActivityType.driving,
    ActivityType.work,
    ActivityType.available,
    ActivityType.rest,
  ];

  /// The shortest part a split or a moved boundary may leave.
  static const _minPart = Duration(minutes: 1);

  late ActivityGap _gap;

  /// Where one part ends and the next begins, in order, inside [_gap].
  final List<DateTime> _cuts = [];

  /// The activity chosen for each part; always one more than [_cuts].
  final List<ActivityType?> _types = [null];

  /// Stretches already answered in this dialog, for the "1 / 2" label.
  int _answered = 0;

  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _gap = widget.gap;
  }

  String _t(String key) => AppLocalizations.getText(
    AppStateProvider.of(context).selectedLanguage,
    key,
  );

  List<DateTime> get _bounds => [_gap.start, ..._cuts, _gap.end];

  String _fmt(DateTime dt) {
    final local = dt.toLocal();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(local.day)}.${two(local.month)} '
        '${two(local.hour)}:${two(local.minute)}';
  }

  String _fmtDuration(Duration d) => _t(
    'gap.duration',
  ).replaceAll('{h}', '${d.inHours}').replaceAll('{m}', '${d.inMinutes % 60}');

  String _activityLabel(ActivityType type) {
    switch (type) {
      case ActivityType.driving:
        return _t('logs.driving');
      case ActivityType.rest:
        return _t('logs.break_');
      case ActivityType.work:
        return _t('timeline.work');
      case ActivityType.available:
        return _t('timeline.available');
      case ActivityType.unknown:
        return _t('violation.missingRecord');
    }
  }

  IconData _activityIcon(ActivityType type) {
    switch (type) {
      case ActivityType.driving:
        return Icons.directions_car;
      case ActivityType.rest:
        return Icons.hotel;
      case ActivityType.work:
        return Icons.engineering;
      case ActivityType.available:
        return Icons.event_available;
      case ActivityType.unknown:
        return Icons.help_outline;
    }
  }

  /// Halfway through the last part, on the minute; null when that part is
  /// too short to split.
  DateTime? _splitPoint() {
    final bounds = _bounds;
    final start = bounds[bounds.length - 2];
    final end = bounds.last;
    final middle = start.add(end.difference(start) ~/ 2).toLocal();
    final cut = DateTime(
      middle.year,
      middle.month,
      middle.day,
      middle.hour,
      middle.minute,
    );
    if (cut.difference(start) < _minPart || end.difference(cut) < _minPart) {
      return null;
    }
    return cut;
  }

  void _split() {
    final cut = _splitPoint();
    if (cut == null) return;
    setState(() {
      _cuts.add(cut);
      _types.add(null);
      _error = null;
    });
  }

  /// The removed part's time goes to the part before it, or to the one after
  /// it when it is the first.
  void _remove(int part) {
    setState(() {
      _cuts.removeAt(part == 0 ? 0 : part - 1);
      _types.removeAt(part);
      _error = null;
    });
  }

  Future<void> _editCut(int index) async {
    final bounds = _bounds;
    final earliest = bounds[index];
    final latest = bounds[index + 2];
    final current = _cuts[index].toLocal();

    var day = DateUtils.dateOnly(current);
    final firstDay = DateUtils.dateOnly(earliest.toLocal());
    final lastDay = DateUtils.dateOnly(latest.toLocal());
    if (firstDay != lastDay) {
      final picked = await showDatePicker(
        context: context,
        initialDate: day,
        firstDate: firstDay,
        lastDate: lastDay,
      );
      if (picked == null || !mounted) return;
      day = picked;
    }

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current),
    );
    if (time == null || !mounted) return;

    final cut = DateTime(day.year, day.month, day.day, time.hour, time.minute);
    if (cut.difference(earliest) < _minPart ||
        latest.difference(cut) < _minPart) {
      setState(() {
        _error = _t(
          'gap.outOfRange',
        ).replaceAll('{from}', _fmt(earliest)).replaceAll('{to}', _fmt(latest));
      });
      return;
    }
    setState(() {
      _cuts[index] = cut;
      _error = null;
    });
  }

  Future<void> _save(AppState appState) async {
    if (_submitting) return;
    if (_types.contains(null)) {
      setState(() => _error = _t('gap.chooseEach'));
      return;
    }
    final bounds = _bounds;
    final segments = [
      for (var i = 0; i < _types.length; i++)
        TachographActivity(
          type: _types[i]!,
          startTime: bounds[i],
          endTime: bounds[i + 1],
        ),
    ];

    setState(() => _submitting = true);
    await appState.resolveRealGap(segments);
    if (!mounted) return;

    final next = appState.pendingRealGap;
    if (next == null) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _gap = next;
      _cuts.clear();
      _types
        ..clear()
        ..add(null);
      _answered++;
      _submitting = false;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final appState = AppStateProvider.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final bounds = _bounds;
    final total = _answered + appState.pendingRealGapCount;

    return PopScope(
      canPop: false,
      child: AlertDialog(
        title: Text(_t('gap.title')),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (total > 1) ...[
                Text(
                  _t('gap.progress')
                      .replaceAll('{n}', '${_answered + 1}')
                      .replaceAll('{total}', '$total'),
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: scheme.primary,
                  ),
                ),
                const SizedBox(height: 8),
              ],
              Text(_t('gap.message')),
              const SizedBox(height: 8),
              Text(
                '${_fmt(_gap.start)} → ${_fmt(_gap.end)} '
                '(${_fmtDuration(_gap.duration)})',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(
                _t('gap.splitHint'),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _t('gap.selectActivity'),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              for (var i = 0; i < _types.length; i++)
                _buildPart(i, bounds[i], bounds[i + 1]),
              TextButton.icon(
                onPressed: _submitting || _splitPoint() == null ? null : _split,
                icon: const Icon(Icons.call_split),
                label: Text(_t('gap.split')),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(_error!, style: TextStyle(color: scheme.error)),
                ),
            ],
          ),
        ),
        actions: [
          if (_submitting)
            const Padding(
              padding: EdgeInsets.all(8),
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
            )
          else
            FilledButton(
              onPressed: () => _save(appState),
              child: Text(_t('gap.save')),
            ),
        ],
      ),
    );
  }

  Widget _buildPart(int part, DateTime start, DateTime end) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isLast = part == _types.length - 1;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 4, 4, 12),
      decoration: BoxDecoration(
        border: Border.all(color: scheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _boundary(start, part == 0 ? null : part - 1),
                    const Text(' → '),
                    _boundary(end, isLast ? null : part),
                    Text(
                      '  ${_fmtDuration(end.difference(start))}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (_types.length > 1)
                IconButton(
                  tooltip: _t('gap.removePart'),
                  icon: const Icon(Icons.close),
                  onPressed: _submitting ? null : () => _remove(part),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final type in _selectableTypes)
                ChoiceChip(
                  avatar: Icon(_activityIcon(type), size: 18),
                  label: Text(_activityLabel(type)),
                  selected: _types[part] == type,
                  showCheckmark: false,
                  onSelected: _submitting
                      ? null
                      : (_) => setState(() {
                          _types[part] = type;
                          _error = null;
                        }),
                ),
            ],
          ),
        ],
      ),
    );
  }

  /// A part's start or end. The two ends of the whole stretch are fixed; a
  /// boundary between two parts opens a date and time picker.
  Widget _boundary(DateTime at, int? cutIndex) {
    final scheme = Theme.of(context).colorScheme;
    if (cutIndex == null || _submitting) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(_fmt(at)),
      );
    }
    return InkWell(
      onTap: () => _editCut(cutIndex),
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _fmt(at),
              style: TextStyle(
                color: scheme.primary,
                fontWeight: FontWeight.w600,
                decoration: TextDecoration.underline,
                decorationColor: scheme.primary,
              ),
            ),
            const SizedBox(width: 2),
            Icon(Icons.edit_calendar, size: 16, color: scheme.primary),
          ],
        ),
      ),
    );
  }
}
