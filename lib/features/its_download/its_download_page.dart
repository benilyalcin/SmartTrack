import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/bluetooth/vu/its_link.dart';
import '../../core/localization/localization.dart';
import '../../core/providers/app_state.dart';
import '../../core/services/bluetooth_service.dart';
import '../../core/services/its/appendix7.dart';
import '../../core/services/its/download_generation_setting.dart';
import '../../core/services/its/its_download_service.dart';
import '../../core/widgets/app_snackbar.dart';

/// Annex 7 data download over the ITS download service - AvuItsTester's
/// DownloadScreen, section for section.
///
/// One press is one download session and one file. The overview is always
/// part of a vehicle unit session (DDP_054): it carries the certificates a
/// reader needs to check the rest. A card download is a session of its own.
class ItsDownloadPage extends StatefulWidget {
  const ItsDownloadPage({super.key, this.embedded = false});

  final bool embedded;

  @override
  State<ItsDownloadPage> createState() => _ItsDownloadPageState();
}

class _ItsDownloadPageState extends State<ItsDownloadPage> {
  // Kept across visits, as the tester's view model keeps them.
  static Set<VuTransfer> _selected = {VuTransfer.eventsAndFaults};
  static DownloadablePeriod? _downloadable;

  /// The generation [_downloadable] was read with; another generation's
  /// overview has to be downloaded before its period is known.
  static DownloadGeneration? _downloadableFor;

  /// Chosen under ITS > Gelişmiş; Gen 2 v2 unless somebody changed it.
  DownloadGeneration get _generation => DownloadGenerationSetting.value.value;

  DateTime _from = _todayUtc();
  DateTime _to = _todayUtc();
  String? _busy;
  String? _message;
  List<String> _steps = const [];
  int _bytes = 0;
  String? _saved;

  @override
  void initState() {
    super.initState();
    DownloadGenerationSetting.value.addListener(_onGenerationChanged);
  }

  @override
  void dispose() {
    DownloadGenerationSetting.value.removeListener(_onGenerationChanged);
    super.dispose();
  }

  void _onGenerationChanged() => setState(() {});

  static DateTime _todayUtc() {
    final n = DateTime.now().toUtc();
    return DateTime.utc(n.year, n.month, n.day);
  }

  ItsLink? get _link => AppBluetoothService.instance.itsDownload;

  String _t(String key) => AppLocalizations.getText(
    AppStateProvider.of(context).selectedLanguage,
    key,
  );

  bool get _cardOnly => _selected.contains(VuTransfer.cardDownload);
  bool get _wantsActivities => _selected.contains(VuTransfer.activities);

  /// A card download is a session of its own: choosing it clears the
  /// vehicle transfers, and choosing one of those clears it.
  void _toggle(VuTransfer t) {
    if (t == VuTransfer.overview) return;
    setState(() {
      if (_selected.contains(t)) {
        _selected = {..._selected}..remove(t);
      } else if (t == VuTransfer.cardDownload) {
        _selected = {t};
      } else {
        _selected = {..._selected}
          ..remove(VuTransfer.cardDownload)
          ..add(t);
      }
    });
  }

  Future<void> _start(ItsLink link) async {
    final generation = _generation;
    setState(() {
      _busy = _t('its.openingSession');
      _message = null;
      _steps = const [];
      _bytes = 0;
      _saved = null;
    });

    final appState = AppStateProvider.of(context);
    final result = await ItsDownloadService.instance.download(
      link,
      ItsDownloadRequest(
        card: _cardOnly,
        vehicleUnit: !_cardOnly,
        activities: _wantsActivities,
        eventsAndFaults: _selected.contains(VuTransfer.eventsAndFaults),
        detailedSpeed: _selected.contains(VuTransfer.detailedSpeed),
        technicalData: _selected.contains(VuTransfer.technicalData),
        activitiesFrom: _from,
        activitiesTo: _to,
        generation: generation,
      ),
      onProgress: (m) {
        if (mounted) setState(() => _busy = m);
      },
    );

    String? saved;
    final bytes =
        (result.cardBytes?.length ?? 0) + (result.vuBytes?.length ?? 0);
    if (bytes > 0) {
      final files = await appState.saveRealDddBytes(
        cardBytes: result.cardBytes,
        vuBytes: result.vuBytes,
      );
      final f = files.card ?? files.vehicleUnit;
      saved = f == null
          ? null
          : AppLocalizations.getText(
              appState.selectedLanguage,
              'its.savedTo',
            ).replaceAll(
              '{name}',
              f.cardHolderName.isEmpty ? f.id : f.cardHolderName,
            );
    }

    if (!mounted) return;
    setState(() {
      _busy = null;
      _steps = result.steps;
      _bytes = bytes;
      _saved = saved;
      if (result.period != null) {
        _downloadable = result.period;
        _downloadableFor = generation;
      }
      _message = bytes == 0
          ? (result.problem ?? _t('its.noDataSession'))
          : _t('its.resultSummary')
                    .replaceAll('{bytes}', '$bytes')
                    .replaceAll('{count}', '${result.steps.length}') +
                (result.problem == null ? '' : '\n${result.problem}');
    });
    showAppSnackBar(
      context,
      bytes == 0
          ? _t('its.downloadFailed').replaceAll(
              '{problem}',
              result.problem ?? _t('its.unitSentNoData'),
            )
          : result.problem == null
          ? _t('its.downloadedSaved').replaceAll('{bytes}', '$bytes')
          : _t('its.savedPartial')
                .replaceAll('{bytes}', '$bytes')
                .replaceAll('{problem}', result.problem!),
      type: bytes > 0 && result.problem == null
          ? AppSnackBarType.success
          : AppSnackBarType.error,
    );
  }

  Future<void> _pick(bool from) async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDate: from ? _from : _to,
      helpText: from ? _t('its.pickFrom') : _t('its.pickTo'),
    );
    if (picked == null) return;
    final day = DateTime.utc(picked.year, picked.month, picked.day);
    setState(() => from ? _from = day : _to = day);
  }

  static DateTime _utcDay(int seconds) {
    final d = DateTime.fromMillisecondsSinceEpoch(seconds * 1000, isUtc: true);
    return DateTime.utc(d.year, d.month, d.day);
  }

  static String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _transferName(VuTransfer t) => _t(switch (t) {
    VuTransfer.overview => 'its.transferOverview',
    VuTransfer.activities => 'its.transferActivities',
    VuTransfer.eventsAndFaults => 'its.transferEvents',
    VuTransfer.detailedSpeed => 'its.transferSpeed',
    VuTransfer.technicalData => 'its.transferTechnical',
    VuTransfer.cardDownload => 'its.transferCard',
  });

  @override
  Widget build(BuildContext context) {
    if (widget.embedded) return _body(context);

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 48,
        leading: BackButton(onPressed: () => context.go('/vu')),
        title: Text(
          _t('its.toolDownloadTitle'),
          style: const TextStyle(fontSize: 18),
        ),
      ),
      body: _body(context),
    );
  }

  /// Stands in for the channel while no ATC is connected, so the screen can
  /// still be looked at; it stays closed, so nothing can be started.
  static final _noLink = ValueNotifier(ItsChannelStatus.closed);

  Widget _body(BuildContext context) {
    final link = _link;
    final small = Theme.of(context).textTheme.bodySmall;
    final datesUsable = !_wantsActivities || !_to.isBefore(_from);
    final idle = _busy == null;

    return ValueListenableBuilder<ItsChannelStatus>(
      valueListenable: link?.status ?? _noLink,
      builder: (context, status, _) {
        final open = status == ItsChannelStatus.open;
        final children = <Widget>[
          _Card(
            title: _t('its.channelCard'),
            children: [
              Text(_t('its.channelHint'), style: small),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(switch (status) {
                      ItsChannelStatus.open =>
                        _t('its.downloadOpen').replaceAll(
                          '{credits}',
                          '${link?.channel.creditsFromVu}',
                        ),
                      ItsChannelStatus.opening => _t('its.downloadOpening'),
                      ItsChannelStatus.refused => _t('its.downloadRefused'),
                      ItsChannelStatus.closed => _t('its.downloadClosed'),
                    }),
                  ),
                  if (open)
                    OutlinedButton(
                      onPressed: idle ? link?.close : null,
                      child: Text(_t('its.close')),
                    )
                  else
                    FilledButton(
                      onPressed: idle && status != ItsChannelStatus.opening
                          ? link?.open
                          : null,
                      child: Text(_t('its.open')),
                    ),
                ],
              ),
            ],
          ),
          _Card(
            title: _t('its.sessionCard'),
            children: [
              Text(_t('its.sessionHint'), style: small),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final t in VuTransfer.values)
                    FilterChip(
                      label: Text(
                        t == VuTransfer.overview
                            ? '${_transferName(t)} (${_cardOnly ? _t('its.overviewNotWithCard') : _t('its.overviewAlways')})'
                            : _transferName(t),
                      ),
                      selected: t == VuTransfer.overview
                          ? !_cardOnly
                          : _selected.contains(t),
                      onSelected: t == VuTransfer.overview || !idle
                          ? null
                          : (_) => _toggle(t),
                    ),
                ],
              ),
              if (_cardOnly)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(_t('its.cardOwnSession'), style: small),
                ),
            ],
          ),
          if (_wantsActivities)
            _Card(
              title: _t('its.activitiesCard'),
              children: [
                Text(_t('its.activitiesHint'), style: small),
                if (_downloadableFor == _generation ? _downloadable : null
                    case final p?) ...[
                  const SizedBox(height: 8),
                  Text(
                    _t('its.unitHolds')
                        .replaceAll('{from}', _fmt(_utcDay(p.minSeconds)))
                        .replaceAll('{to}', _fmt(_utcDay(p.maxSeconds))),
                  ),
                  TextButton(
                    onPressed: idle
                        ? () => setState(() {
                            _from = _utcDay(p.minSeconds);
                            _to = _utcDay(p.maxSeconds);
                          })
                        : null,
                    child: Text(_t('its.wholePeriod')),
                  ),
                ] else
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(_t('its.periodUnknown'), style: small),
                  ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: idle ? () => _pick(true) : null,
                        child: Text(
                          _t('its.fromDate').replaceAll('{date}', _fmt(_from)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: idle ? () => _pick(false) : null,
                        child: Text(
                          _t('its.toDate').replaceAll('{date}', _fmt(_to)),
                        ),
                      ),
                    ),
                  ],
                ),
                if (!datesUsable)
                  Text(
                    _t('its.endBeforeStart'),
                    style: small?.copyWith(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                Text(
                  _t('its.daysUtc').replaceAll(
                    '{days}',
                    '${ItsDownloadService.maxActivityDays}',
                  ),
                  style: small,
                ),
              ],
            ),
          _Card(
            title: _t('its.runCard'),
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.icon(
                  onPressed: link != null && open && idle && datesUsable
                      ? () => _start(link)
                      : null,
                  icon: const Icon(Icons.download),
                  label: Text(_t('its.download')),
                ),
              ),
              if (!open)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    _t('its.channelClosedHint'),
                    style: small?.copyWith(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              if (_busy != null)
                Row(
                  children: [
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_busy!)),
                  ],
                )
              else
                Text(_t('its.idleStatus').replaceAll('{bytes}', '$_bytes')),
              if (_saved != null)
                Text(_t('its.saved').replaceAll('{name}', _saved!)),
              if (_message != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(_message!),
                ),
            ],
          ),
          if (_steps.isNotEmpty)
            _Card(
              title: _t('its.transfersCard'),
              children: [for (final s in _steps) Text(s, style: small)],
            ),
          _Card(
            title: _t('its.filesCard'),
            children: [
              // The two things a download gives: the unit's data and the
              // card's, newest first; a tap opens the file.
              for (final (title, kind) in const [
                ('VU download', 'vehicleUnit'),
                ('Card download', 'card'),
              ]) ...[
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                ..._filesOf(context, kind),
                const SizedBox(height: 8),
              ],
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => context.go('/ddd-files'),
                  icon: const Icon(Icons.folder_outlined),
                  label: Text(_t('its.allFiles')),
                ),
              ),
            ],
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
      },
    );
  }
}

/// The last few saved files of one kind ('vehicleUnit' or 'card'; a
/// combined download counts as both), as rows that open the file.
List<Widget> _filesOf(BuildContext context, String kind) {
  final files = AppStateProvider.of(context).dddFiles
      .where((f) => f.downloadKind == kind || f.downloadKind == 'both')
      .take(3)
      .toList();
  final small = Theme.of(context).textTheme.bodySmall;
  if (files.isEmpty) {
    final lang = AppStateProvider.of(context).selectedLanguage;
    return [Text(AppLocalizations.getText(lang, 'its.noneYet'), style: small)];
  }

  String two(int v) => v.toString().padLeft(2, '0');
  return [
    for (final f in files)
      ListTile(
        dense: true,
        contentPadding: EdgeInsets.zero,
        leading: Icon(
          kind == 'card' ? Icons.badge_outlined : Icons.local_shipping_outlined,
        ),
        title: Text(
          f.cardHolderName.isEmpty ? f.cardType : f.cardHolderName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '${two(f.downloadedAt.day)}.${two(f.downloadedAt.month)}.'
          '${f.downloadedAt.year} ${two(f.downloadedAt.hour)}:'
          '${two(f.downloadedAt.minute)} · '
          '${(f.fileSizeBytes / 1024).toStringAsFixed(1)} KB',
          style: small,
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.push('/ddd-files/${f.id}'),
      ),
  ];
}

class _Card extends StatelessWidget {
  const _Card({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    ),
  );
}
