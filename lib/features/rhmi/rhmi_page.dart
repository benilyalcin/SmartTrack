import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/app_state.dart';
import '../../core/services/rhmi/manual_entry.dart';
import '../../core/services/rhmi/rhmi.dart';
import '../../core/services/rhmi/rhmi_controller.dart';
import '../../core/widgets/app_snackbar.dart';

/// Remote HMI for an ATC 8256: what the unit's own keys and menus do,
/// from the phone. One status card on top - the session everything else
/// needs - and the functions below it, folded away until wanted.
class RhmiPage extends StatefulWidget {
  const RhmiPage({super.key});

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
    if (_c.awaitingToken != null && !_tokenDialogOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _askToken());
    }
  }

  Future<void> _askToken() async {
    if (_tokenDialogOpen || _c.awaitingToken == null || !mounted) return;
    _tokenDialogOpen = true;
    final controller = TextEditingController();
    final digits = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Eşleştirme kodu'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          maxLength: 8,
          decoration: const InputDecoration(
            hintText: 'Takograf ekranındaki 8 hane',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('İptal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Onayla'),
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
    // One of the tools under the Tachograph tab; back goes to the list.
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 48,
        leading: BackButton(onPressed: () => context.go('/vu')),
        title: const Text('Uzaktan kumanda', style: TextStyle(fontSize: 18)),
      ),
      body: _body(context),
    );
  }

  Widget _body(BuildContext context) {
    final appState = AppStateProvider.of(context);
    if (!appState.isBluetoothConnected || !_c.isConnected) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Uzaktan kumanda için bir ATC 8256\'ya bağlanın.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    // A new connection may be to another unit.
    _c.syncDevice();

    final enabled = _c.isIdle;
    final open = _c.isSessionOpen && enabled;
    final paired = _c.isPaired(_c.client);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _StatusCard(c: _c, paired: paired),
        const SizedBox(height: 12),
        _Section(
          icon: Icons.link,
          title: 'Eşleştirme',
          initiallyExpanded: !paired,
          children: [_pairing(enabled)],
        ),
        _Section(
          icon: Icons.touch_app_outlined,
          title: 'Live Entries',
          children: [_liveEntries(open)],
        ),
        _Section(
          icon: Icons.warning_amber_outlined,
          title: 'Uyarılar',
          children: [_warnings(open)],
        ),
        _Section(
          icon: Icons.print_outlined,
          title: 'Çıktı',
          children: [_PrintoutPanel(c: _c, enabled: open)],
        ),
        _Section(
          icon: Icons.eject_outlined,
          title: 'Kart çıkarma',
          children: [_WithdrawalPanel(c: _c, enabled: open)],
        ),
        _Section(
          icon: Icons.edit_calendar_outlined,
          title: 'Manuel giriş',
          children: [_ManualEntryPanel(c: _c, enabled: open)],
        ),
      ],
    );
  }

  Widget _pairing(bool enabled) {
    final client = _c.client;
    final paired = _c.isPaired(client);
    final verified = _c.verifiedClients.contains(client);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentedButton<int>(
          segments: const [
            ButtonSegment(value: Rhmi.clientCardSlot1, label: Text('Yuva 1')),
            ButtonSegment(value: Rhmi.clientCardSlot2, label: Text('Yuva 2')),
            ButtonSegment(value: Rhmi.clientInVehicle, label: Text('Araç içi')),
          ],
          selected: {client},
          onSelectionChanged: enabled ? (s) => _c.setClient(s.first) : null,
        ),
        const SizedBox(height: 8),
        Text(
          verified
              ? 'Eşleşmiş ve doğrulanmış.'
              : paired
              ? 'Bu telefonda eşleşmiş.'
              : 'Eşleşmemiş. Yuva istemcisi için o yuvada kart olmalı; araç '
                    'içi istemci yalnız kalibrasyon modunda eşleşir.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton(
              onPressed: enabled && !verified ? _c.pairClient : null,
              child: const Text('Eşleştir'),
            ),
            OutlinedButton(
              onPressed: enabled && paired ? _c.verifySessionId : null,
              child: const Text('Doğrula'),
            ),
            TextButton(
              onPressed: enabled && paired ? _c.forgetPairing : null,
              child: const Text('Unut'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _slotSelector(bool enabled) => SegmentedButton<int>(
    segments: const [
      ButtonSegment(value: 1, label: Text('Yuva 1')),
      ButtonSegment(value: 2, label: Text('Yuva 2')),
    ],
    selected: {_slot},
    onSelectionChanged: enabled ? (s) => setState(() => _slot = s.first) : null,
  );

  Widget _liveEntries(bool enabled) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _slotSelector(enabled),
        const SizedBox(height: 12),
        const _Label('Aktivite'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final (code, label) in const [
              (Rhmi.activityRest, 'Dinlenme'),
              (Rhmi.activityAvailability, 'Hazır bulunma'),
              (Rhmi.activityWork, 'Diğer iş'),
            ])
              OutlinedButton(
                onPressed: enabled ? () => _c.setActivity(_slot, code) : null,
                child: Text(label),
              ),
          ],
        ),
        const SizedBox(height: 12),
        const _Label('Yer (günlük çalışma dönemi)'),
        _PlaceEntry(
          enabled: enabled,
          onSend: (type, country, region) =>
              _c.enterPlace(_slot, type, country, region),
        ),
        const SizedBox(height: 12),
        const _Label('Özel durum'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final (code, label) in const [
              (Rhmi.ferryTrainBegin, 'Feribot/tren başla'),
              (Rhmi.ferryTrainEnd, 'Feribot/tren bitir'),
              (Rhmi.outOfScopeBegin, 'Kapsam dışı başla'),
              (Rhmi.outOfScopeEnd, 'Kapsam dışı bitir'),
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
        const _Label('Yükleme / boşaltma'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final (code, label) in const [
              (Rhmi.operationLoad, 'Yükleme'),
              (Rhmi.operationUnload, 'Boşaltma'),
              (Rhmi.operationLoadAndUnload, 'İkisi'),
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
            child: const Text('Uyarıları oku'),
          ),
        ),
        if (list != null && list.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text('Bekleyen uyarı yok.'),
          ),
        for (final w in list ?? const <VuWarning>[])
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.warning_amber),
            title: Text(Rhmi.eventFaultName(w.legalCode)),
            trailing: TextButton(
              onPressed: enabled ? () => _c.acknowledgeWarning(w.index) : null,
              child: const Text('Onayla'),
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
  const _StatusCard({required this.c, required this.paired});
  final RhmiController c;
  final bool paired;

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
                    'Oturum: ${status?.label ?? 'bilinmiyor'}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            if (offset != null && offset.abs() > 60)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Takograf saati ${offset > 0 ? '+' : ''}$offset sn; istekler '
                  'takograf saatiyle imzalanıyor.',
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
                    onPressed: idle && paired ? c.openSession : null,
                    child: const Text('Oturumu aç'),
                  )
                else
                  OutlinedButton(
                    onPressed: idle ? c.closeSession : null,
                    child: const Text('Oturumu kapat'),
                  ),
                TextButton(
                  onPressed: idle ? c.refreshSessionStatus : null,
                  child: const Text('Durumu yenile'),
                ),
                TextButton(
                  onPressed: idle ? c.checkClocks : null,
                  child: const Text('Saati kontrol et'),
                ),
              ],
            ),
            if (!paired)
              Text(
                'Oturum açmak için önce eşleştirin.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.icon,
    required this.title,
    required this.children,
    this.initiallyExpanded = false,
  });
  final IconData icon;
  final String title;
  final List<Widget> children;
  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: ExpansionTile(
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
        decoration: const InputDecoration(labelText: 'Ülke'),
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
          decoration: const InputDecoration(labelText: 'Bölge'),
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
            child: const Text('Başlangıç'),
          ),
          OutlinedButton(
            onPressed: widget.enabled
                ? () => widget.onSend(Rhmi.placeEnd, _country, _region)
                : null,
            child: const Text('Bitiş'),
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
        ? 'Gün seç'
        : '${_day!.day.toString().padLeft(2, '0')}.'
              '${_day!.month.toString().padLeft(2, '0')}.${_day!.year}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<int>(
          initialValue: _type,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Çıktı türü'),
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
              child: const Text('Yazdır'),
            ),
            TextButton(
              onPressed: widget.enabled ? widget.c.printoutStatus : null,
              child: const Text('Durum'),
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
        title: const Text('Kart çıkarılsın mı?'),
        content: Text(
          'Yuva $_slot\'taki kart, bitiş yeri kaydedilip çıkarılacak. Oturum '
          'kartla birlikte kapanır.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Çıkar'),
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
        segments: const [
          ButtonSegment(value: 1, label: Text('Yuva 1')),
          ButtonSegment(value: 2, label: Text('Yuva 2')),
        ],
        selected: {_slot},
        onSelectionChanged: widget.enabled
            ? (s) => setState(() => _slot = s.first)
            : null,
      ),
      const SizedBox(height: 8),
      const _Label('Bitiş yeri'),
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
        decoration: const InputDecoration(labelText: 'Günün kart çıktısı'),
        items: const [
          DropdownMenuItem(value: Rhmi.shiftPrintoutNone, child: Text('Yok')),
          DropdownMenuItem(value: Rhmi.shiftPrintoutUtc, child: Text('UTC')),
          DropdownMenuItem(
            value: Rhmi.shiftPrintoutLocal,
            child: Text('Yerel saat'),
          ),
        ],
        onChanged: widget.enabled
            ? (v) => setState(() => _shift = v ?? _shift)
            : null,
      ),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Teknik veri çıktısı'),
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
          label: const Text('Kartı çıkar'),
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
          'Kartın takılı olmadığı süreyi doldurur. Kart takıldıktan sonra '
          'yaklaşık bir dakika içinde gönderilmelidir.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        SegmentedButton<int>(
          segments: const [
            ButtonSegment(value: 1, label: Text('Yuva 1')),
            ButtonSegment(value: 2, label: Text('Yuva 2')),
          ],
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
              child: const Text('Kart tipi'),
            ),
            FilledButton.tonal(
              onPressed: widget.enabled ? () => c.getPeriod(_slot) : null,
              child: const Text('Dönemi oku'),
            ),
          ],
        ),
        if (period != null) ...[
          const SizedBox(height: 8),
          Text('Dönem: $usable dakika, doldurulan: $filled dakika'),
          const SizedBox(height: 12),
          const _Label('Aktiviteler (sırayla, süreleriyle)'),
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
                  decoration: const InputDecoration(labelText: 'Dakika'),
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
              title: Text('${_segments[i].$1.label} · ${_segments[i].$2} dk'),
              trailing: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => setState(() => _segments.removeAt(i)),
              ),
            ),
          const SizedBox(height: 12),
          const _Label('Yerler (isteğe bağlı)'),
          Row(
            children: [
              SizedBox(
                width: 90,
                child: TextField(
                  controller: _placeMinute,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Dakika'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(
                      value: Rhmi.placeBegin,
                      label: Text('Başlangıç'),
                    ),
                    ButtonSegment(value: Rhmi.placeEnd, label: Text('Bitiş')),
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
              label: const Text('Yer ekle'),
            ),
          ),
          for (var i = 0; i < _places.length; i++)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(
                '${_places[i].$1}. dk · '
                '${_places[i].$2 == Rhmi.placeBegin ? 'Başlangıç' : 'Bitiş'} · '
                '${Rhmi.countries.where((c) => c.$1 == _places[i].$3).firstOrNull?.$2 ?? _places[i].$3}',
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
                child: const Text('Gönder'),
              ),
              OutlinedButton(
                onPressed: widget.enabled
                    ? () => c.stopManualEntry(_slot)
                    : null,
                child: const Text('Girişi bitir'),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
