import 'package:flutter/material.dart';

import '../../core/localization/localization.dart';

/// What to download from an STC 8255 through its K-line dongle.
typedef StcDownloadOptions = ({
  bool includeCard,
  bool includeVehicleUnit,
  DateTimeRange? activityRange,
  bool includeEventsFaults,
  bool includeDetailedSpeed,
  bool includeTechnicalData,
});

String _t(String key, [Map<String, Object?> args = const {}]) =>
    AppLocalizations.text(key, args);

/// The download chooser the files screen had before the ATC got its own
/// download screen: the vehicle unit with each of its blocks (activities
/// over a date range, events and faults, detailed speed, technical data)
/// and the driver card, each switched on or off.
Future<StcDownloadOptions?> showStcDownloadSheet(BuildContext context) {
  final scheme = Theme.of(context).colorScheme;
  return showModalBottomSheet<StcDownloadOptions>(
    context: context,
    backgroundColor: scheme.surface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) => const _StcDownloadSheet(),
  );
}

/// The first day [everything] stands for: earlier than any unit holds, so
/// the download keeps to the unit's own downloadable period.
final DateTime _everythingStart = DateTime(2000);

bool _isEverything(DateTimeRange r) => !r.start.isAfter(_everythingStart);

/// Today and the 6, 29 or 89 days before it, everything the unit holds, a
/// range of one's own, or no activity data at all (null). Today is in: the
/// unit has today's activities so far, and the vendor's download has them.
Future<DateTimeRange?> _pickActivityRange(BuildContext context) async {
  final choice = await showDialog<String>(
    context: context,
    builder: (context) => SimpleDialog(
      title: Text(_t('stcdl.rangeTitle')),
      children: [
        for (final days in const [7, 30, 90])
          SimpleDialogOption(
            onPressed: () => Navigator.of(context).pop('$days'),
            child: Text(_t('stcdl.rangeDays', {'days': days})),
          ),
        SimpleDialogOption(
          onPressed: () => Navigator.of(context).pop('all'),
          child: Text(_t('stcdl.rangeEverything')),
        ),
        SimpleDialogOption(
          onPressed: () => Navigator.of(context).pop('custom'),
          child: Text(_t('stcdl.rangeCustom')),
        ),
        const Divider(height: 1),
        SimpleDialogOption(
          onPressed: () => Navigator.of(context).pop('skip'),
          child: Text(_t('stcdl.rangeSkip')),
        ),
      ],
    ),
  );
  if (choice == null || choice == 'skip') return null;

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  if (choice == 'all') {
    return DateTimeRange(start: _everythingStart, end: today);
  }
  if (choice == 'custom') {
    if (!context.mounted) return null;
    return showDateRangePicker(
      context: context,
      firstDate: DateTime(today.year, today.month, today.day - 365),
      lastDate: today,
      initialDateRange: DateTimeRange(
        start: DateTime(today.year, today.month, today.day - 6),
        end: today,
      ),
      helpText: _t('stcdl.rangeHelp'),
    );
  }
  return _lastDays(int.parse(choice));
}

/// The last [days] calendar days, today included.
DateTimeRange _lastDays(int days) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  return DateTimeRange(
    start: DateTime(today.year, today.month, today.day - (days - 1)),
    end: today,
  );
}

class _StcDownloadSheet extends StatefulWidget {
  const _StcDownloadSheet();

  @override
  State<_StcDownloadSheet> createState() => _StcDownloadSheetState();
}

class _StcDownloadSheetState extends State<_StcDownloadSheet> {
  bool _includeVehicleUnit = true;
  bool _includeCard = true;
  DateTimeRange? _activityRange = _lastDays(30);
  bool _includeEventsFaults = true;
  bool _includeDetailedSpeed = true;
  bool _includeTechnicalData = true;

  Future<void> _pickRange() async {
    final range = await _pickActivityRange(context);
    if (!mounted) return;
    setState(() => _activityRange = range);
  }

  String get _rangeLabel {
    final range = _activityRange;
    if (range == null) return _t('stcdl.rangeNone');
    if (_isEverything(range)) return _t('stcdl.rangeEverythingShort');
    final days = range.end.difference(range.start).inDays + 1;
    return _t('stcdl.rangeDays', {'days': days});
  }

  bool get _canDownload => _includeCard || _includeVehicleUnit;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: scheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _t('stcdl.title'),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _t('stcdl.subtitle'),
                style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 16),
              _BlockToggle(
                icon: Icons.directions_car_filled_outlined,
                title: _t('stcdl.vehicleUnit'),
                value: _includeVehicleUnit,
                onChanged: (v) => setState(() => _includeVehicleUnit = v),
              ),
              if (_includeVehicleUnit) _vuSubPanel(scheme),
              const SizedBox(height: 8),
              _BlockToggle(
                icon: Icons.badge_outlined,
                title: _t('stcdl.card'),
                value: _includeCard,
                onChanged: (v) => setState(() => _includeCard = v),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _canDownload
                    ? () => Navigator.of(context).pop((
                        includeCard: _includeCard,
                        includeVehicleUnit: _includeVehicleUnit,
                        activityRange: _includeVehicleUnit
                            ? _activityRange
                            : null,
                        includeEventsFaults: _includeEventsFaults,
                        includeDetailedSpeed: _includeDetailedSpeed,
                        includeTechnicalData: _includeTechnicalData,
                      ))
                    : null,
                icon: const Icon(Icons.download_rounded),
                label: Text(_t('stcdl.download')),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _vuSubPanel(ColorScheme scheme) {
    return Container(
      margin: const EdgeInsets.only(left: 20, top: 4, bottom: 4),
      padding: const EdgeInsets.only(left: 12, top: 2, bottom: 2),
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(color: scheme.outlineVariant, width: 2),
        ),
      ),
      child: Column(
        children: [
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text(
              _t('stcdl.activities'),
              style: TextStyle(fontSize: 14, color: scheme.onSurface),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _rangeLabel,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: scheme.primary,
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: scheme.onSurfaceVariant,
                ),
              ],
            ),
            onTap: _pickRange,
          ),
          _MiniSwitch(
            label: _t('stcdl.eventsFaults'),
            value: _includeEventsFaults,
            onChanged: (v) => setState(() => _includeEventsFaults = v),
          ),
          _MiniSwitch(
            label: _t('stcdl.detailedSpeed'),
            value: _includeDetailedSpeed,
            onChanged: (v) => setState(() => _includeDetailedSpeed = v),
          ),
          _MiniSwitch(
            label: _t('stcdl.technical'),
            value: _includeTechnicalData,
            onChanged: (v) => setState(() => _includeTechnicalData = v),
          ),
        ],
      ),
    );
  }
}

class _BlockToggle extends StatelessWidget {
  const _BlockToggle({
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // A Material, not a coloured Container: the tile draws its ink on the
    // nearest Material, and a coloured box in between would hide it.
    return Material(
      color: scheme.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: value ? scheme.primary : scheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: CheckboxListTile(
        value: value,
        onChanged: (v) => onChanged(v ?? false),
        controlAffinity: ListTileControlAffinity.leading,
        secondary: Icon(icon, color: scheme.onSurfaceVariant),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: scheme.onSurface,
          ),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

class _MiniSwitch extends StatelessWidget {
  const _MiniSwitch({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontSize: 14, color: scheme.onSurface),
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: scheme.primary,
          ),
        ],
      ),
    );
  }
}
