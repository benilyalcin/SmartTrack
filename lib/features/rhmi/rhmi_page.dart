import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/localization/localization.dart';
import '../../core/providers/app_state.dart';
import '../../core/services/rhmi/manual_entry.dart';
import '../../core/services/rhmi/rhmi.dart';
import '../../core/services/rhmi/rhmi_controller.dart';
import '../../core/widgets/app_snackbar.dart';

/// The page rebuilds with the app language (it depends on AppStateProvider),
/// so every text is read at build time.
String _t(String key, [Map<String, Object?> args = const {}]) =>
    AppLocalizations.text(key, args);

/// Remote HMI for an ATC 8256: what the unit's own keys and menus do,
/// from the phone. One status card on top - the session everything else
/// needs - and the functions below it, folded away until wanted.
class RhmiPage extends StatefulWidget {
  const RhmiPage({super.key, this.embedded = false});

  final bool embedded;

  @override
  State<RhmiPage> createState() => _RhmiPageState();
}

class _RhmiPageState extends State<RhmiPage> {
  final RhmiController _c = RhmiController.instance;
  bool _tokenDialogOpen = false;
  int _slot = 1;

  StreamSubscription<RhmiOutcome>? _outcomes;

  @override
  void initState() {
    super.initState();
    _c.syncDevice();
    _c.addListener(_onChange);
    _outcomes = _c.outcomes.listen(_onOutcome);
  }

  @override
  void dispose() {
    _outcomes?.cancel();
    _c.removeListener(_onChange);
    super.dispose();
  }

  /// Every request's outcome as a notice above the bottom bar, so an entry
  /// made here is seen to land on the unit (or why it did not).
  void _onOutcome(RhmiOutcome o) {
    if (!mounted) return;
    showAppSnackBar(
      context,
      o.text,
      type: switch (o.kind) {
        RhmiOutcomeKind.done => AppSnackBarType.success,
        RhmiOutcomeKind.refused => AppSnackBarType.error,
        RhmiOutcomeKind.notSent => AppSnackBarType.info,
      },
    );
  }

  void _onChange() {
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _askToken() async {
    if (_tokenDialogOpen || _c.awaitingToken == null || !mounted) return;
    _tokenDialogOpen = true;
    final controller = TextEditingController();
    final digits = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(_t('rhmi.ui.tokenTitle')),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          maxLength: 8,
          decoration: InputDecoration(hintText: _t('rhmi.ui.tokenHint')),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(_t('rhmi.ui.cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: Text(_t('rhmi.ui.confirm')),
          ),
        ],
      ),
    );
    _tokenDialogOpen = false;
    if (digits == null) {
      _c.cancelToken();
    } else {
      await _c.confirmToken(digits);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Asked from every build rather than once when the controller changes: a
    // pairing gets a single notification, and if the dialog could not open
    // after that one frame the token had nowhere to go. A wrong code keeps
    // the pairing waiting, so this also brings the dialog back for another
    // try.
    if (_c.awaitingToken != null && !_tokenDialogOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _askToken());
    }

    if (widget.embedded) return _body(context);

    // One of the tools under the Tachograph tab; back goes to the list.
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 48,
        leading: BackButton(onPressed: () => context.go('/vu')),
        title: Text(
          _t('its.toolRhmiTitle'),
          style: const TextStyle(fontSize: 18),
        ),
      ),
      body: _body(context),
    );
  }

  Widget _body(BuildContext context) {
    // Shown without a connection too, so the screen can be looked at; the
    // controller answers every action with "not connected" then.
    AppStateProvider.of(context);
    // A new connection may be to another unit.
    _c.syncDevice();

    final enabled = _c.isIdle;
    final open = _c.isSessionOpen && enabled;
    final paired = _c.isPaired(_c.client);

    final children = <Widget>[
      _StatusCard(c: _c),
      const SizedBox(height: 12),
      _Section(
        storageId: 'pairing',
        icon: Icons.link,
        title: _t('rhmi.ui.secPairing'),
        initiallyExpanded: !paired,
        children: [_pairing(enabled)],
      ),
      _Section(
        storageId: 'live',
        icon: Icons.touch_app_outlined,
        title: _t('rhmi.ui.secLive'),
        children: [_liveEntries(open)],
      ),
      _Section(
        storageId: 'warnings',
        icon: Icons.warning_amber_outlined,
        title: _t('rhmi.ui.secWarnings'),
        children: [_warnings(open)],
      ),
      _Section(
        storageId: 'printout',
        icon: Icons.print_outlined,
        title: _t('rhmi.ui.secPrintout'),
        children: [_PrintoutPanel(c: _c, enabled: open)],
      ),
      _Section(
        storageId: 'withdrawal',
        icon: Icons.eject_outlined,
        title: _t('rhmi.ui.secWithdraw'),
        children: [_WithdrawalPanel(c: _c, enabled: open)],
      ),
      _Section(
        storageId: 'manual',
        icon: Icons.edit_calendar_outlined,
        title: _t('rhmi.ui.secManual'),
        children: [_ManualEntryPanel(c: _c, enabled: open)],
      ),
    ];

    if (widget.embedded) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      );
    }

    return ListView(padding: const EdgeInsets.all(16), children: children);
  }

  Widget _pairing(bool enabled) {
    final client = _c.client;
    final paired = _c.isPaired(client);
    final verified = _c.verifiedClients.contains(client);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentedButton<int>(
          segments: [
            ButtonSegment(
              value: Rhmi.clientCardSlot1,
              label: Text(_t('rhmi.ui.slot', {'n': 1})),
            ),
            ButtonSegment(
              value: Rhmi.clientCardSlot2,
              label: Text(_t('rhmi.ui.slot', {'n': 2})),
            ),
            ButtonSegment(
              value: Rhmi.clientInVehicle,
              label: Text(_t('rhmi.client.vehicle')),
            ),
          ],
          selected: {client},
          onSelectionChanged: enabled ? (s) => _c.setClient(s.first) : null,
        ),
        const SizedBox(height: 8),
        Text(
          verified
              ? _t('rhmi.ui.pairedVerified')
              : paired
              ? _t('rhmi.ui.pairedHere')
              : _t('rhmi.ui.notPairedHint'),
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton(
              onPressed: enabled && !verified ? _c.pairClient : null,
              child: Text(_t('rhmi.ui.pair')),
            ),
            // The way back to the code while a pairing waits for it, should
            // the dialog not be on screen.
            if (_c.awaitingToken != null)
              FilledButton.tonal(
                onPressed: () => _askToken(),
                child: Text(_t('rhmi.ui.enterCode')),
              ),
            OutlinedButton(
              onPressed: enabled && paired ? _c.verifySessionId : null,
              child: Text(_t('rhmi.ui.verify')),
            ),
            TextButton(
              onPressed: enabled && paired ? _c.forgetPairing : null,
              child: Text(_t('rhmi.ui.forget')),
            ),
          ],
        ),
      ],
    );
  }

  Widget _slotSelector(bool enabled) => SegmentedButton<int>(
    segments: _slotSegments(),
    selected: {_slot},
    onSelectionChanged: enabled ? (s) => setState(() => _slot = s.first) : null,
  );

  Widget _liveEntries(bool enabled) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _slotSelector(enabled),
        const SizedBox(height: 12),
        _Label(_t('rhmi.whatActivity')),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final (code, label) in [
              (Rhmi.activityRest, _t('rhmi.ui.rest')),
              (Rhmi.activityAvailability, _t('rhmi.activity.available')),
              (Rhmi.activityWork, _t('rhmi.activity.work')),
            ])
              OutlinedButton(
                onPressed: enabled ? () => _c.setActivity(_slot, code) : null,
                child: Text(label),
              ),
          ],
        ),
        const SizedBox(height: 12),
        _Label(_t('rhmi.ui.placeLabel')),
        _PlaceEntry(
          enabled: enabled,
          onSend: (type, country, region) =>
              _c.enterPlace(_slot, type, country, region),
        ),
        const SizedBox(height: 12),
        _Label(_t('rhmi.whatCondition')),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final (code, label) in [
              (Rhmi.ferryTrainBegin, _t('rhmi.ui.ferryBegin')),
              (Rhmi.ferryTrainEnd, _t('rhmi.ui.ferryEnd')),
              (Rhmi.outOfScopeBegin, _t('rhmi.ui.oosBegin')),
              (Rhmi.outOfScopeEnd, _t('rhmi.ui.oosEnd')),
            ])
              OutlinedButton(
                onPressed: enabled
                    ? () => _c.enterSpecificCondition(code)
                    : null,
                child: Text(label),
              ),
          ],
        ),
        const SizedBox(height: 12),
        _Label(_t('rhmi.ui.loadLabel')),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final (code, label) in [
              (Rhmi.operationLoad, _t('rhmi.ui.load')),
              (Rhmi.operationUnload, _t('rhmi.ui.unload')),
              (Rhmi.operationLoadAndUnload, _t('rhmi.ui.loadBoth')),
            ])
              OutlinedButton(
                onPressed: enabled ? () => _c.loadUnload(code) : null,
                child: Text(label),
              ),
          ],
        ),
      ],
    );
  }

  Widget _warnings(bool enabled) {
    final list = _c.warnings;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.tonal(
            onPressed: enabled ? _c.readWarnings : null,
            child: Text(_t('rhmi.ui.readWarnings')),
          ),
        ),
        if (list != null && list.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(_t('rhmi.ui.noWarnings')),
          ),
        for (final w in list ?? const <VuWarning>[])
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.warning_amber),
            title: Text(Rhmi.eventFaultName(w.legalCode)),
            trailing: TextButton(
              onPressed: enabled ? () => _c.acknowledgeWarning(w.index) : null,
              child: Text(_t('rhmi.ui.confirm')),
            ),
          ),
      ],
    );
  }
}

/// The session everything signed needs, and the outcome of the last action
/// - pinned at the top so a button pressed further down never seems to do
/// nothing.
class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.c});
  final RhmiController c;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final status = c.sessionStatus;
    final open = c.isSessionOpen;
    final idle = c.isIdle;
    final offset = c.clockOffsetSeconds;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  open ? Icons.lock_open : Icons.lock_outline,
                  color: open ? scheme.primary : scheme.outline,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _t('rhmi.ui.session', {
                      'status': status?.label ?? _t('rhmi.ui.sessionUnknown'),
                    }),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            if (offset != null && offset.abs() > 60)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  _t('rhmi.ui.clockOffset', {
                    'offset': '${offset > 0 ? '+' : ''}$offset',
                  }),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            const SizedBox(height: 8),
            if (c.busy != null)
              Row(
                children: [
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text('${c.busy}…')),
                ],
              )
            else if (c.message != null)
              Text(c.message!),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (!open)
                  FilledButton(
                    onPressed: idle ? c.openSession : null,
                    child: Text(_t('rhmi.ui.openSession')),
                  )
                else
                  OutlinedButton(
                    onPressed: idle ? c.closeSession : null,
                    child: Text(_t('rhmi.ui.closeSession')),
                  ),
                TextButton(
                  onPressed: idle ? c.refreshSessionStatus : null,
                  child: Text(_t('rhmi.ui.refresh')),
                ),
                TextButton(
                  onPressed: idle ? c.checkClocks : null,
                  child: Text(_t('rhmi.ui.checkClock')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Yuva 1 and Yuva 2, in the app language.
List<ButtonSegment<int>> _slotSegments() => [
  for (final n in const [1, 2])
    ButtonSegment(value: n, label: Text(_t('rhmi.ui.slot', {'n': n}))),
];

class _Section extends StatelessWidget {
  const _Section({
    required this.storageId,
    required this.icon,
    required this.title,
    required this.children,
    this.initiallyExpanded = false,
  });
  final String storageId;
  final IconData icon;
  final String title;
  final List<Widget> children;
  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: ExpansionTile(
      // Expansion booleans must not share the ancestor scroll offset entry.
      key: PageStorageKey('rhmi-section-$storageId'),
      leading: Icon(icon),
      title: Text(title),
      initiallyExpanded: initiallyExpanded,
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    ),
  );
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(text, style: const TextStyle(fontWeight: FontWeight.w600)),
  );
}

/// A country, and a region when the country is Spain - the only one the
/// region field applies to.
class _CountryPicker extends StatelessWidget {
  const _CountryPicker({
    required this.country,
    required this.region,
    required this.onChanged,
    required this.enabled,
  });
  final int country;
  final int region;
  final void Function(int country, int region) onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      DropdownButtonFormField<int>(
        initialValue: country,
        isExpanded: true,
        decoration: InputDecoration(labelText: _t('rhmi.ui.country')),
        items: [
          for (final (code, label) in Rhmi.countries)
            DropdownMenuItem(value: code, child: Text(label)),
        ],
        onChanged: enabled
            ? (v) => onChanged(v ?? country, v == Rhmi.spain ? region : 0)
            : null,
      ),
      if (country == Rhmi.spain)
        DropdownButtonFormField<int>(
          initialValue: region == 0 ? null : region,
          isExpanded: true,
          decoration: InputDecoration(labelText: _t('rhmi.ui.region')),
          items: [
            for (final (code, label) in Rhmi.regions)
              DropdownMenuItem(value: code, child: Text(label)),
          ],
          onChanged: enabled ? (v) => onChanged(country, v ?? 0) : null,
        ),
    ],
  );
}

class _PlaceEntry extends StatefulWidget {
  const _PlaceEntry({required this.enabled, required this.onSend});
  final bool enabled;
  final void Function(int type, int country, int region) onSend;

  @override
  State<_PlaceEntry> createState() => _PlaceEntryState();
}

class _PlaceEntryState extends State<_PlaceEntry> {
  int _country = 0x30;
  int _region = 0;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _CountryPicker(
        country: _country,
        region: _region,
        enabled: widget.enabled,
        onChanged: (c, r) => setState(() {
          _country = c;
          _region = r;
        }),
      ),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        children: [
          OutlinedButton(
            onPressed: widget.enabled
                ? () => widget.onSend(Rhmi.placeBegin, _country, _region)
                : null,
            child: Text(_t('rhmi.ui.begin')),
          ),
          OutlinedButton(
            onPressed: widget.enabled
                ? () => widget.onSend(Rhmi.placeEnd, _country, _region)
                : null,
            child: Text(_t('rhmi.ui.end')),
          ),
        ],
      ),
    ],
  );
}

class _PrintoutPanel extends StatefulWidget {
  const _PrintoutPanel({required this.c, required this.enabled});
  final RhmiController c;
  final bool enabled;

  @override
  State<_PrintoutPanel> createState() => _PrintoutPanelState();
}

class _PrintoutPanelState extends State<_PrintoutPanel> {
  int _type = 0x01;
  DateTime? _day;

  Future<void> _pickDay() async {
    final p = widget.c.printoutPeriod;
    if (p == null || p.type != _type || p.newest == 0) {
      await widget.c.getPrintoutPeriod(_type);
      return;
    }
    DateTime utc(int s) =>
        DateTime.fromMillisecondsSinceEpoch(s * 1000, isUtc: true);
    final first = utc(p.oldest), last = utc(p.newest);
    if (!mounted) return;
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(first.year, first.month, first.day),
      lastDate: DateTime(last.year, last.month, last.day),
      initialDate: DateTime(last.year, last.month, last.day),
    );
    if (picked != null && mounted) setState(() => _day = picked);
  }

  @override
  Widget build(BuildContext context) {
    final needsDate = Rhmi.printoutNeedsDate(_type);
    final dayLabel = _day == null
        ? _t('rhmi.ui.pickDay')
        : '${_day!.day.toString().padLeft(2, '0')}.'
              '${_day!.month.toString().padLeft(2, '0')}.${_day!.year}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<int>(
          initialValue: _type,
          isExpanded: true,
          decoration: InputDecoration(labelText: _t('rhmi.ui.printType')),
          items: [
            for (final (code, label) in Rhmi.printoutTypes)
              DropdownMenuItem(value: code, child: Text(label)),
          ],
          onChanged: widget.enabled
              ? (v) => setState(() {
                  _type = v ?? _type;
                  _day = null;
                })
              : null,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (needsDate)
              OutlinedButton.icon(
                onPressed: widget.enabled ? _pickDay : null,
                icon: const Icon(Icons.event),
                label: Text(dayLabel),
              ),
            FilledButton(
              onPressed: widget.enabled && (!needsDate || _day != null)
                  ? () => widget.c.startPrintout(
                      _type,
                      _day == null
                          ? null
                          : DateTime.utc(
                                  _day!.year,
                                  _day!.month,
                                  _day!.day,
                                ).millisecondsSinceEpoch ~/
                                1000,
                    )
                  : null,
              child: Text(_t('rhmi.ui.print')),
            ),
            TextButton(
              onPressed: widget.enabled ? widget.c.printoutStatus : null,
              child: Text(_t('rhmi.ui.status')),
            ),
          ],
        ),
      ],
    );
  }
}

class _WithdrawalPanel extends StatefulWidget {
  const _WithdrawalPanel({required this.c, required this.enabled});
  final RhmiController c;
  final bool enabled;

  @override
  State<_WithdrawalPanel> createState() => _WithdrawalPanelState();
}

class _WithdrawalPanelState extends State<_WithdrawalPanel> {
  int _slot = 1;
  int _country = 0x30;
  int _region = 0;
  int _shift = Rhmi.shiftPrintoutNone;
  bool _technical = false;

  Future<void> _withdraw() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_t('rhmi.ui.withdrawTitle')),
        content: Text(_t('rhmi.ui.withdrawBody', {'slot': _slot})),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(_t('rhmi.ui.withdrawCancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(_t('rhmi.ui.withdrawDo')),
          ),
        ],
      ),
    );
    if (ok == true) {
      await widget.c.withdrawCard(_slot, _country, _region, _shift, _technical);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      SegmentedButton<int>(
        segments: _slotSegments(),
        selected: {_slot},
        onSelectionChanged: widget.enabled
            ? (s) => setState(() => _slot = s.first)
            : null,
      ),
      const SizedBox(height: 8),
      _Label(_t('rhmi.whatPlaceEnd')),
      _CountryPicker(
        country: _country,
        region: _region,
        enabled: widget.enabled,
        onChanged: (c, r) => setState(() {
          _country = c;
          _region = r;
        }),
      ),
      const SizedBox(height: 8),
      DropdownButtonFormField<int>(
        initialValue: _shift,
        decoration: InputDecoration(labelText: _t('rhmi.ui.shiftPrintout')),
        items: [
          DropdownMenuItem(
            value: Rhmi.shiftPrintoutNone,
            child: Text(_t('rhmi.ui.none')),
          ),
          const DropdownMenuItem(
            value: Rhmi.shiftPrintoutUtc,
            child: Text('UTC'),
          ),
          DropdownMenuItem(
            value: Rhmi.shiftPrintoutLocal,
            child: Text(_t('rhmi.ui.localTime')),
          ),
        ],
        onChanged: widget.enabled
            ? (v) => setState(() => _shift = v ?? _shift)
            : null,
      ),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(_t('rhmi.ui.technical')),
        value: _technical,
        onChanged: widget.enabled
            ? (v) => setState(() => _technical = v)
            : null,
      ),
      Align(
        alignment: Alignment.centerLeft,
        child: FilledButton.icon(
          onPressed: widget.enabled ? _withdraw : null,
          icon: const Icon(Icons.eject),
          label: Text(_t('rhmi.ui.withdrawButton')),
        ),
      ),
    ],
  );
}

/// F200: the gap between the last withdrawal and this insertion. The unit
/// takes an entry only for about a minute after the card goes in, so the
/// entry is prepared once - durations and minute offsets, not clock times -
/// and "Gönder" reads the period afresh and sends in the same turn.
class _ManualEntryPanel extends StatefulWidget {
  const _ManualEntryPanel({required this.c, required this.enabled});
  final RhmiController c;
  final bool enabled;

  @override
  State<_ManualEntryPanel> createState() => _ManualEntryPanelState();
}

class _ManualEntryPanelState extends State<_ManualEntryPanel> {
  int _slot = 1;
  ManualActivityType _activity = ManualActivityType.rest;
  final _minutes = TextEditingController();
  final _placeMinute = TextEditingController(text: '0');
  int _placeType = Rhmi.placeBegin;
  int _country = 0x30;
  int _region = 0;

  /// What was typed: each activity's length, in order.
  final List<(ManualActivityType, int)> _segments = [];

  /// Places as minutes from the start of the period.
  final List<(int, int, int, int)> _places = [];

  @override
  void dispose() {
    _minutes.dispose();
    _placeMinute.dispose();
    super.dispose();
  }

  /// Each activity begins where the durations before it end.
  List<ManualActivity> _activitiesFor(ManualEntryPeriod p) {
    final begin = ManualEntry.truncateToMinute(p.periodBegin);
    final out = <ManualActivity>[];
    var offset = 0;
    for (final (activity, minutes) in _segments) {
      out.add(ManualActivity(begin + offset * 60, activity));
      offset += minutes;
    }
    return out;
  }

  List<ManualPlace> _placesFor(ManualEntryPeriod p) {
    final begin = ManualEntry.truncateToMinute(p.periodBegin);
    return [
      for (final (minute, type, country, region) in _places)
        ManualPlace(begin + minute * 60, type, country, region),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    final period = c.period;
    final usable = period == null
        ? 0
        : (ManualEntry.truncateToMinute(period.periodEnd) -
                  ManualEntry.truncateToMinute(period.periodBegin)) ~/
              60;
    final filled = _segments.fold<int>(0, (s, e) => s + e.$2);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          _t('rhmi.ui.manualHint'),
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        SegmentedButton<int>(
          segments: _slotSegments(),
          selected: {_slot},
          onSelectionChanged: widget.enabled
              ? (s) => setState(() => _slot = s.first)
              : null,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton(
              onPressed: widget.enabled
                  ? () => c.getInsertedCardType(_slot)
                  : null,
              child: Text(_t('rhmi.ui.cardType')),
            ),
            FilledButton.tonal(
              onPressed: widget.enabled ? () => c.getPeriod(_slot) : null,
              child: Text(_t('rhmi.ui.readPeriod')),
            ),
          ],
        ),
        if (period != null) ...[
          const SizedBox(height: 8),
          Text(
            _t('rhmi.ui.periodFilled', {'usable': usable, 'filled': filled}),
          ),
          const SizedBox(height: 12),
          _Label(_t('rhmi.ui.activitiesLabel')),
          Wrap(
            spacing: 8,
            children: [
              for (final a in ManualActivityType.values)
                ChoiceChip(
                  label: Text(a.label),
                  selected: _activity == a,
                  onSelected: (_) => setState(() => _activity = a),
                ),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _minutes,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: _t('rhmi.ui.minutes')),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                onPressed: () {
                  final m = int.tryParse(_minutes.text);
                  if (m == null || m <= 0) return;
                  setState(() {
                    _segments.add((_activity, m));
                    _minutes.clear();
                  });
                },
                icon: const Icon(Icons.add),
              ),
            ],
          ),
          for (var i = 0; i < _segments.length; i++)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(
                _t('rhmi.ui.segment', {
                  'activity': _segments[i].$1.label,
                  'minutes': _segments[i].$2,
                }),
              ),
              trailing: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => setState(() => _segments.removeAt(i)),
              ),
            ),
          const SizedBox(height: 12),
          _Label(_t('rhmi.ui.placesLabel')),
          Row(
            children: [
              SizedBox(
                width: 90,
                child: TextField(
                  controller: _placeMinute,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: _t('rhmi.ui.minutes')),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SegmentedButton<int>(
                  segments: [
                    ButtonSegment(
                      value: Rhmi.placeBegin,
                      label: Text(_t('rhmi.ui.begin')),
                    ),
                    ButtonSegment(
                      value: Rhmi.placeEnd,
                      label: Text(_t('rhmi.ui.end')),
                    ),
                  ],
                  selected: {_placeType},
                  onSelectionChanged: (s) =>
                      setState(() => _placeType = s.first),
                ),
              ),
            ],
          ),
          _CountryPicker(
            country: _country,
            region: _region,
            enabled: true,
            onChanged: (c, r) => setState(() {
              _country = c;
              _region = r;
            }),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () {
                final m = int.tryParse(_placeMinute.text);
                if (m == null || m < 0) return;
                setState(() => _places.add((m, _placeType, _country, _region)));
              },
              icon: const Icon(Icons.add_location_alt_outlined),
              label: Text(_t('rhmi.ui.addPlace')),
            ),
          ),
          for (var i = 0; i < _places.length; i++)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(
                _t('rhmi.ui.placeRow', {
                  'minute': _places[i].$1,
                  'type': _t(
                    _places[i].$2 == Rhmi.placeBegin
                        ? 'rhmi.ui.begin'
                        : 'rhmi.ui.end',
                  ),
                  'country':
                      Rhmi.countries
                          .where((c) => c.$1 == _places[i].$3)
                          .firstOrNull
                          ?.$2 ??
                      _places[i].$3,
                }),
              ),
              trailing: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => setState(() => _places.removeAt(i)),
              ),
            ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton(
                onPressed: widget.enabled && _segments.isNotEmpty
                    ? () => c.sendManualEntry(
                        _slot,
                        _activitiesFor(period),
                        _placesFor(period),
                        // Durations and minute offsets survive a fresh
                        // period as they are; absolute times are rebuilt
                        // from it the next time.
                        onRebased: (_, _) {},
                      )
                    : null,
                child: Text(_t('rhmi.ui.send')),
              ),
              OutlinedButton(
                onPressed: widget.enabled
                    ? () => c.stopManualEntry(_slot)
                    : null,
                child: Text(_t('rhmi.ui.stopEntry')),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
