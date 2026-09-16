import 'package:flutter/material.dart';

import '../localization/localization.dart';
import '../providers/app_state.dart';
import '../services/driving_time_calculator.dart';
import '../services/violation_analyzer.dart';

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

  bool _submitting = false;

  String _t(String key) => AppLocalizations.getText(
    AppStateProvider.of(context).selectedLanguage,
    key,
  );

  String _fmtHm(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

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

  Future<void> _select(AppState appState, ActivityType type) async {
    if (_submitting) return;
    setState(() => _submitting = true);
    await appState.resolveRealGap(type);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final appState = AppStateProvider.of(context);
    final gap = widget.gap;

    return PopScope(
      canPop: false,
      child: AlertDialog(
        title: Text(_t('gap.title')),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${_t('gap.message')} (${_fmtHm(gap.start)} - ${_fmtHm(gap.end)})',
              ),
              const SizedBox(height: 16),
              Text(
                _t('gap.selectActivity'),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              if (_submitting)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator()),
                )
              else
                Column(
                  children: _selectableTypes.map((type) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () => _select(appState, type),
                          icon: Icon(_activityIcon(type)),
                          label: Text(_activityLabel(type)),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            alignment: Alignment.centerLeft,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
