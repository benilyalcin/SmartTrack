import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/bluetooth/vu/its_link.dart';
import '../../core/providers/app_state.dart';
import '../../core/services/bluetooth_service.dart';
import '../../core/services/its/appendix7.dart';
import '../../core/services/its/its_download_service.dart';
import '../../core/widgets/app_snackbar.dart';

/// Annex 7 data download over the ITS download service - AvuItsTester's
/// DownloadScreen, section for section.
///
/// One press is one download session and one file. The overview is always
/// part of a vehicle unit session (DDP_054): it carries the certificates a
/// reader needs to check the rest. A card download is a session of its own.
class ItsDownloadPage extends StatefulWidget {
  const ItsDownloadPage({super.key});

  @override
  State<ItsDownloadPage> createState() => _ItsDownloadPageState();
}

class _ItsDownloadPageState extends State<ItsDownloadPage> {
  // Kept across visits, as the tester's view model keeps them.
  static Set<VuTransfer> _selected = {VuTransfer.eventsAndFaults};
  static DownloadGeneration _generation = DownloadGeneration.gen2v2;
  static DownloadablePeriod? _downloadable;

  DateTime _from = _todayUtc();
  DateTime _to = _todayUtc();
  String? _busy;
  String? _message;
  List<String> _steps = const [];
  int _bytes = 0;
  String? _saved;

  static DateTime _todayUtc() {
    final n = DateTime.now().toUtc();
    return DateTime.utc(n.year, n.month, n.day);
  }

  ItsLink? get _link => AppBluetoothService.instance.itsDownload;

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
    setState(() {
      _busy = 'Oturum açılıyor';
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
        generation: _generation,
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
          : 'Dosyalar · ${f.cardHolderName.isEmpty ? f.id : f.cardHolderName}';
    }

    if (!mounted) return;
    setState(() {
      _busy = null;
      _steps = result.steps;
      _bytes = bytes;
      _saved = saved;
      if (result.period != null) _downloadable = result.period;
      _message = bytes == 0
          ? (result.problem ??
                'Oturum çalıştı ama takograf hiç veri göndermedi.')
          : '$bytes bayt, ${result.steps.length} transfer'
                '${result.problem == null ? '' : '\n${result.problem}'}';
    });
    showAppSnackBar(
      context,
      bytes == 0
          ? 'İndirme başarısız: ${result.problem ?? 'takograf veri göndermedi.'}'
          : result.problem == null
          ? '$bytes bayt indirildi ve kaydedildi.'
          : '$bytes bayt kaydedildi, eksik: ${result.problem}',
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
      helpText: from ? 'Başlangıç (UTC)' : 'Bitiş (UTC)',
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

  static String _transferName(VuTransfer t) => switch (t) {
    VuTransfer.overview => 'Genel bakış',
    VuTransfer.activities => 'Aktiviteler',
    VuTransfer.eventsAndFaults => 'Olaylar ve arızalar',
    VuTransfer.detailedSpeed => 'Detaylı hız',
    VuTransfer.technicalData => 'Teknik veri',
    VuTransfer.cardDownload => 'Kart indirme',
  };

  static String _hex(int v) =>
      '0x${v.toRadixString(16).padLeft(2, '0').toUpperCase()}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 48,
        leading: BackButton(onPressed: () => context.go('/vu')),
        title: const Text('Veri indirme', style: TextStyle(fontSize: 18)),
      ),
      body: _body(context),
    );
  }

  Widget _body(BuildContext context) {
    final link = _link;
    if (link == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'ITS indirme için bir ATC 8256\'ya bağlanın.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final small = Theme.of(context).textTheme.bodySmall;
    final datesUsable = !_wantsActivities || !_to.isBefore(_from);
    final idle = _busy == null;

    return ValueListenableBuilder<ItsChannelStatus>(
      valueListenable: link.status,
      builder: (context, status, _) {
        final open = status == ItsChannelStatus.open;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _Card(
              title: 'Kanal',
              children: [
                Text(
                  'Kanalı açmak takografa 16 credit verir. 0xFF reddi ön '
                  'konektörün bu arayüzü kullandığı ya da takılı kartların '
                  'ITS\'e izin vermediği anlamına gelir.',
                  style: small,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(switch (status) {
                        ItsChannelStatus.open =>
                          'İndirme: açık (${link.channel.creditsFromVu} credit)',
                        ItsChannelStatus.opening => 'İndirme: açılıyor…',
                        ItsChannelStatus.refused =>
                          'İndirme: reddedildi (0xFF)',
                        ItsChannelStatus.closed => 'İndirme: kapalı',
                      }),
                    ),
                    if (open)
                      OutlinedButton(
                        onPressed: idle ? link.close : null,
                        child: const Text('Kapat'),
                      )
                    else
                      FilledButton(
                        onPressed: idle && status != ItsChannelStatus.opening
                            ? link.open
                            : null,
                        child: const Text('Aç'),
                      ),
                  ],
                ),
              ],
            ),
            _Card(
              title: 'Oturum',
              children: [
                Text(
                  'Bir basış bir indirme oturumudur: StartCommunication, '
                  'transferler, TransferExit ve StopCommunication, hepsi tek '
                  'dosyada. Genel bakış her zaman ilk gider ve çıkarılamaz: '
                  'takograf sertifikalarını taşır.',
                  style: small,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    for (final t in VuTransfer.values)
                      FilterChip(
                        label: Text(
                          t == VuTransfer.overview
                              ? '${_transferName(t)} (${_cardOnly ? 'kartla değil' : 'her zaman'})'
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
                    child: Text(
                      'Kart indirme kendi oturumu ve kendi dosyasıdır: kartın '
                      'verisi, kartın sertifikalarıyla.',
                      style: small,
                    ),
                  ),
              ],
            ),
            _Card(
              title: 'Nesil',
              children: [
                Text(
                  'Nesil, transfer istek parametresinin (TRTP) içinde gider. '
                  'Kart indirmenin her nesilde tek değeri vardır. Uygulama '
                  'Gen 1 dosyasını kendisi okur; Gen 2 dosyası saklanır ve '
                  'paylaşılır.',
                  style: small,
                ),
                const SizedBox(height: 8),
                SegmentedButton<DownloadGeneration>(
                  segments: [
                    for (final g in DownloadGeneration.values)
                      ButtonSegment(value: g, label: Text(g.label)),
                  ],
                  selected: {_generation},
                  onSelectionChanged: idle
                      ? (s) => setState(() {
                          _generation = s.first;
                          // Read out of the other generation's overview.
                          _downloadable = null;
                        })
                      : null,
                ),
                const SizedBox(height: 4),
                Text(
                  'Genel bakış TRTP ${_hex(Appendix7.trtpFor(VuTransfer.overview, _generation))}, '
                  'aktiviteler ${_hex(Appendix7.trtpFor(VuTransfer.activities, _generation))} '
                  'olarak gider.',
                  style: small,
                ),
              ],
            ),
            if (_wantsActivities)
              _Card(
                title: 'Aktiviteler, gün gün',
                children: [
                  Text(
                    'Her istek tek bir takvim gününü adlandırır; bir dönem aynı '
                    'oturumda gün gün istenir, en eskiden başlayarak. İki uç '
                    'da dahil.',
                    style: small,
                  ),
                  if (_downloadable case final p?) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Takograf ${_fmt(_utcDay(p.minSeconds))} – '
                      '${_fmt(_utcDay(p.maxSeconds))} arasını tutuyor.',
                    ),
                    TextButton(
                      onPressed: idle
                          ? () => setState(() {
                              _from = _utcDay(p.minSeconds);
                              _to = _utcDay(p.maxSeconds);
                            })
                          : null,
                      child: const Text('İndirilebilir dönemin tamamı'),
                    ),
                  ] else
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'Takografın indirilebilir dönemi ilk Gen 2 '
                        'oturumundan sonra burada görünür.',
                        style: small,
                      ),
                    ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: idle ? () => _pick(true) : null,
                          child: Text('Başlangıç ${_fmt(_from)}'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: idle ? () => _pick(false) : null,
                          child: Text('Bitiş ${_fmt(_to)}'),
                        ),
                      ),
                    ],
                  ),
                  if (!datesUsable)
                    Text(
                      'Bitiş başlangıçtan önce olamaz.',
                      style: small?.copyWith(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  Text(
                    'Günler UTC\'dir; bir oturum en fazla '
                    '${ItsDownloadService.maxActivityDays} gün ister.',
                    style: small,
                  ),
                ],
              ),
            _Card(
              title: 'Çalıştır',
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton.icon(
                    onPressed: open && idle && datesUsable
                        ? () => _start(link)
                        : null,
                    icon: const Icon(Icons.download),
                    label: const Text('İndir'),
                  ),
                ),
                if (!open)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'İndirme kanalı açık değil: yukarıdan açın.',
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
                  Text('Durum: boşta · $_bytes bayt'),
                if (_saved != null) Text('Kaydedildi: $_saved'),
                if (_message != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(_message!),
                  ),
              ],
            ),
            if (_steps.isNotEmpty)
              _Card(
                title: 'Transferler',
                children: [for (final s in _steps) Text(s, style: small)],
              ),
            _Card(
              title: 'Dosyalar',
              children: [
                Text(
                  'İndirilen dosyalar uygulamanın dosya listesine kaydedilir; '
                  'oradan açılır, paylaşılır.',
                  style: small,
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => context.go('/ddd-files'),
                    icon: const Icon(Icons.folder_outlined),
                    label: const Text('İndirilen dosyalar'),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
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
