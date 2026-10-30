import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/bluetooth/vu/its_link.dart';
import '../../core/localization/localization.dart';
import '../../core/providers/app_state.dart';
import '../../core/services/bluetooth_service.dart';
import '../../core/services/its/diag_decoder.dart';
import '../../core/widgets/app_snackbar.dart';

/// Requests worth a button, named the way the unit's own parameter table
/// (ParameterSearch.cpp) names them - AvuItsTester's ConsoleScreen presets.
List<(String, String)> _presets(String Function(String) t) => [
  ('StartCommunication', '81'),
  (t('its.presetDefaultSession'), '10 81'),
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
  (t('its.presetUndefined'), '22 F9 FE'),
  (t('its.presetRhmiSession'), '31 03 F2 11'),
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

  String _t(String key) => AppLocalizations.getText(
    AppStateProvider.of(context).selectedLanguage,
    key,
  );

  Future<void> _send(ItsLink link) async {
    final text = _hex.text.replaceAll(
      RegExp(r'0x|[\s,:-]', caseSensitive: false),
      '',
    );
    if (text.isEmpty) {
      setState(() => _message = _t('its.calibNothingToSend'));
      return;
    }
    if (text.length.isOdd || !RegExp(r'^[0-9a-fA-F]+$').hasMatch(text)) {
      setState(() => _message = _t('its.calibNotHex'));
      return;
    }
    final bytes = [
      for (var i = 0; i < text.length; i += 2)
        int.parse(text.substring(i, i + 2), radix: 16),
    ];
    if (bytes.length > 255) {
      setState(() => _message = _t('its.calibTooLong'));
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
          _message = _t('its.calibChannelFailed');
        });
        showAppSnackBar(
          context,
          _t('its.calibNotSent'),
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
      if (result == null) _message = _t('its.calibNoAnswer');
    });
    showAppSnackBar(
      context,
      result == null
          ? _t('its.calibNoAnswerLong')
          : '${result.positive ? _t('its.calibPositive') : _t('its.calibRefused')} · '
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
        leading: BackButton(onPressed: () => context.go('/vu/advanced')),
        title: Text(
          _t('its.calibrationTitle'),
          style: const TextStyle(fontSize: 18),
        ),
      ),
      body: _body(context),
    );
  }

  /// Stands in for the channel while no ATC is connected, so the screen can
  /// still be looked at; it stays closed.
  static final _noLink = ValueNotifier(ItsChannelStatus.closed);

  Widget _body(BuildContext context) {
    final link = AppBluetoothService.instance.itsDiagnostics;
    final scheme = Theme.of(context).colorScheme;
    final small = Theme.of(context).textTheme.bodySmall;

    return ValueListenableBuilder<ItsChannelStatus>(
      valueListenable: link?.status ?? _noLink,
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
                      ItsChannelStatus.open => _t('its.diagOpen').replaceAll(
                        '{credits}',
                        '${link?.channel.creditsFromVu}',
                      ),
                      ItsChannelStatus.opening => _t('its.diagOpening'),
                      ItsChannelStatus.refused => _t('its.diagRefused'),
                      ItsChannelStatus.closed => _t('its.diagClosed'),
                    }),
                  ),
                  if (status == ItsChannelStatus.open)
                    OutlinedButton(
                      onPressed: _busy ? null : link?.close,
                      child: Text(_t('its.close')),
                    )
                  else
                    FilledButton(
                      onPressed: _busy || status == ItsChannelStatus.opening
                          ? null
                          : link?.open,
                      child: Text(_t('its.open')),
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
                  Text(
                    _t('its.calibRawTitle'),
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  Text(_t('its.calibRawHint'), style: small),
                  TextField(
                    controller: _hex,
                    decoration: const InputDecoration(labelText: 'hex'),
                    style: const TextStyle(fontFamily: 'monospace'),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FilledButton(
                      onPressed: _busy || link == null
                          ? null
                          : () => _send(link),
                      child: _busy
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(_t('its.calibSend')),
                    ),
                  ),
                  if (_result case final r?) ...[
                    const SizedBox(height: 10),
                    Text(
                      r.positive
                          ? _t('its.calibPositive')
                          : _t('its.calibNegative'),
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
                  Text(
                    _t('its.calibPresets'),
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      for (final (label, bytes) in _presets(_t))
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
