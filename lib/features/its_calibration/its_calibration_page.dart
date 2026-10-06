import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/bluetooth/vu/its_link.dart';
import '../../core/services/bluetooth_service.dart';
import '../../core/services/its/diag_decoder.dart';
import '../../core/widgets/app_snackbar.dart';

/// Requests worth a button, named the way the unit's own parameter table
/// (ParameterSearch.cpp) names them - AvuItsTester's ConsoleScreen presets.
const List<(String, String)> _presets = [
  ('StartCommunication', '81'),
  ('Varsayılan oturum', '10 81'),
  ('TimeDate (F90B)', '22 F9 0B'),
  ('DriverCardDriver1 (F907)', '22 F9 07'),
  ('DriverCardDriver2 (F90A)', '22 F9 0A'),
  ('TachographCardSlot1 (F930)', '22 F9 30'),
  ('TachographCardSlot2 (F933)', '22 F9 33'),
  ('Driver1Identification (F916)', '22 F9 16'),
  ('Driver1WorkingState (F903)', '22 F9 03'),
  ('VehiclePosition (F9D7)', '22 F9 D7'),
  ('ByDefaultLoadType (F9D5)', '22 F9 D5'),
  ('KFactor (F918)', '22 F9 18'),
  ('Tanımsız (F9FE)', '22 F9 FE'),
  ('RHMI oturum durumu (F211)', '31 03 F2 11'),
];

/// Annex 8 over the ITS diagnostics channel: a raw KWP2000 request, its
/// answer decoded - AvuItsTester's console. Bytes start at the service
/// identifier; the header, length and checksum are added here.
class ItsCalibrationPage extends StatefulWidget {
  const ItsCalibrationPage({super.key});

  @override
  State<ItsCalibrationPage> createState() => _ItsCalibrationPageState();
}

class _ItsCalibrationPageState extends State<ItsCalibrationPage> {
  final _hex = TextEditingController(text: '22 F9 0B');
  bool _busy = false;
  DiagDecoded? _result;
  String? _message;

  @override
  void dispose() {
    _hex.dispose();
    super.dispose();
  }

  Future<void> _send(ItsLink link) async {
    final text = _hex.text.replaceAll(
      RegExp(r'0x|[\s,:-]', caseSensitive: false),
      '',
    );
    if (text.isEmpty) {
      setState(
        () => _message =
            'Gönderilecek bir şey yok: istek servis tanımlayıcısıyla başlar.',
      );
      return;
    }
    if (text.length.isOdd || !RegExp(r'^[0-9a-fA-F]+$').hasMatch(text)) {
      setState(() => _message = 'Bu bir hex dizisi değil.');
      return;
    }
    final bytes = [
      for (var i = 0; i < text.length; i += 2)
        int.parse(text.substring(i, i + 2), radix: 16),
    ];
    if (bytes.length > 255) {
      setState(() => _message = 'Çok uzun: KWP2000 uzunluğu tek bayt.');
      return;
    }

    setState(() {
      _busy = true;
      _result = null;
      _message = null;
    });
    if (!link.isOpen && !await link.open()) {
      if (mounted) {
        setState(() {
          _busy = false;
          _message = 'Diagnostik kanalı açılamadı.';
        });
        showAppSnackBar(
          context,
          'İstek gönderilmedi: diagnostik kanalı açılamadı.',
          type: AppSnackBarType.error,
        );
      }
      return;
    }
    final answer = await link.request(bytes);
    if (!mounted) return;
    final result = answer == null ? null : DiagDecoder.decode(answer);
    setState(() {
      _busy = false;
      _result = result;
      if (result == null) _message = 'Yanıt yok.';
    });
    showAppSnackBar(
      context,
      result == null
          ? 'Yanıt yok: takograf isteği cevaplamadı.'
          : '${result.positive ? 'Olumlu' : 'Reddedildi'} · '
                '${result.title}: ${result.value}',
      type: result?.positive ?? false
          ? AppSnackBarType.success
          : AppSnackBarType.error,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 48,
        leading: BackButton(onPressed: () => context.go('/vu')),
        title: const Text('Kalibrasyon', style: TextStyle(fontSize: 18)),
      ),
      body: _body(context),
    );
  }

  Widget _body(BuildContext context) {
    final link = AppBluetoothService.instance.itsDiagnostics;
    if (link == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Kalibrasyon için bir ATC 8256\'ya bağlanın.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    final scheme = Theme.of(context).colorScheme;
    final small = Theme.of(context).textTheme.bodySmall;

    return ValueListenableBuilder<ItsChannelStatus>(
      valueListenable: link.status,
      builder: (context, status, _) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(switch (status) {
                      ItsChannelStatus.open =>
                        'Diagnostik: açık (${link.channel.creditsFromVu} credit)',
                      ItsChannelStatus.opening => 'Diagnostik: açılıyor…',
                      ItsChannelStatus.refused =>
                        'Diagnostik: reddedildi (0xFF)',
                      ItsChannelStatus.closed => 'Diagnostik: kapalı',
                    }),
                  ),
                  if (status == ItsChannelStatus.open)
                    OutlinedButton(
                      onPressed: _busy ? null : link.close,
                      child: const Text('Kapat'),
                    )
                  else
                    FilledButton(
                      onPressed: _busy || status == ItsChannelStatus.opening
                          ? null
                          : link.open,
                      child: const Text('Aç'),
                    ),
                ],
              ),
            ),
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Diagnostik kanalında ham istek',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Baytlar servis tanımlayıcısıyla başlar; 80 EE F0, uzunluk '
                    've checksum otomatik eklenir. İmzalı RHMI istekleri '
                    'Uzaktan kumanda ekranındadır.',
                    style: small,
                  ),
                  TextField(
                    controller: _hex,
                    decoration: const InputDecoration(labelText: 'hex'),
                    style: const TextStyle(fontFamily: 'monospace'),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FilledButton(
                      onPressed: _busy ? null : () => _send(link),
                      child: _busy
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Gönder'),
                    ),
                  ),
                  if (_result case final r?) ...[
                    const SizedBox(height: 10),
                    Text(
                      r.positive ? 'Olumlu' : 'Olumsuz',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: r.positive ? scheme.primary : scheme.error,
                      ),
                    ),
                    Text(
                      r.title,
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                    Text(
                      r.value,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                  if (_message != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(_message!, style: small),
                    ),
                ],
              ),
            ),
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Hazır istekler',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      for (final (label, bytes) in _presets)
                        FilterChip(
                          label: Text(label),
                          selected: _hex.text == bytes,
                          onSelected: (_) => setState(() => _hex.text = bytes),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
