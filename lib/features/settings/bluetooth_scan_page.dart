import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart'
    show openAppSettings;

import '../../core/bluetooth/services/vu_app_connection_service.dart';
import '../../core/exceptions/ble_exception.dart';
import '../../core/exceptions/vu_profile_mismatch_exception.dart';
import '../../core/models/tachograph_type.dart';
import '../../core/localization/localization.dart';
import '../../core/providers/app_state.dart';
import '../../core/services/bluetooth_service.dart';
import '../../core/widgets/app_snackbar.dart';
import '../../core/widgets/bouncing_dots_loader.dart';

class BluetoothScanPage extends StatefulWidget {
  /// Shown as the step after choosing a tachograph (/connect) rather than
  /// pushed over the app: it leads on to the dashboard, back goes to the
  /// choice, and the user may go on without connecting.
  final bool standalone;

  const BluetoothScanPage({super.key, this.standalone = false});

  @override
  State<BluetoothScanPage> createState() => _BluetoothScanPageState();
}

class _BluetoothScanPageState extends State<BluetoothScanPage>
    with TickerProviderStateMixin {
  List<AppBluetoothDevice> _devices = [];
  bool _isScanning = false;
  bool _permissionDenied = false;
  bool _filterNearOnly = false;
  String? _connectingDeviceId;
  StreamSubscription? _scanSub;

  late final AnimationController _ringController;
  late final AnimationController _dotController;

  bool _looksLikeTachograph(AppBluetoothDevice d) =>
      AppBluetoothService.isVehicleUnit(id: d.id, name: d.name);

  /// Everything the scan lists that is not a tachograph: the Classic
  /// K-line dongle the phone is paired with, and BLE devices that name
  /// themselves, among them a BLE dongle.
  bool _looksLikeDongle(AppBluetoothDevice d) => !_looksLikeTachograph(d);

  List<AppBluetoothDevice> get _tachographs =>
      _devices.where(_looksLikeTachograph).toList();

  List<AppBluetoothDevice> get _dongles {
    final dongles = _devices.where(_looksLikeDongle);
    if (!_filterNearOnly) return dongles.toList();

    return dongles.where((d) => d.rssi >= -70).toList();
  }

  List<AppBluetoothDevice> get _visibleDevices => [
    ..._tachographs,
    ..._dongles,
  ];

  @override
  void initState() {
    super.initState();
    _ringController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    _dotController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _startScan();
  }

  void _startScan() async {
    setState(() {
      _isScanning = true;
      _permissionDenied = false;
      _devices.clear();
    });
    _ringController.repeat();
    _dotController.repeat(reverse: true);

    final granted = await AppBluetoothService.instance.startUnifiedScan();
    if (!mounted) return;
    if (!granted) {
      setState(() {
        _isScanning = false;
        _permissionDenied = true;
      });
      _stopPulse();
      return;
    }

    _scanSub?.cancel();
    _scanSub = AppBluetoothService.instance.unifiedScanResults.listen(
      (results) {
        if (mounted) {
          setState(() {
            _devices = results;
          });
        }
      },
      onDone: () {
        if (mounted) {
          setState(() => _isScanning = false);
          _stopPulse();
        }
      },
    );

    Future.delayed(const Duration(seconds: 15), () {
      if (mounted && _isScanning) {
        setState(() => _isScanning = false);
        _stopPulse();
      }
    });
  }

  void _stopPulse() {
    _ringController.stop();
    _dotController.stop();
  }

  @override
  void dispose() {
    _scanSub?.cancel();
    AppBluetoothService.instance.stopScan();
    _ringController.dispose();
    _dotController.dispose();
    super.dispose();
  }

  static const bool _legalOnlyDemoEnabled = false;

  Future<bool?> _confirmLegalOnlyDemo() {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_t('scan.demoTitle')),
        content: Text(_t('scan.demoBody')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(_t('scan.demoNo')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(_t('scan.demoYes')),
          ),
        ],
      ),
    );
  }

  Future<void> _runLegalOnlyDemo(AppBluetoothDevice device) async {
    setState(() {
      _isScanning = true;
      _connectingDeviceId = device.id;
    });
    try {
      await AppBluetoothService.instance.performLegalOnlyDemo(device);
      if (mounted) {
        showAppSnackBar(
          context,
          _t('scan.demoDone'),
          type: AppSnackBarType.success,
        );
        context.push('/kline-log');
      }
    } catch (e) {
      if (mounted) {
        showAppSnackBar(
          context,
          '${device.displayName}: ${_friendlyConnectError(e)}',
          type: AppSnackBarType.error,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isScanning = false;
          _connectingDeviceId = null;
        });
      }
    }
  }

  void _connectTo(
    AppBluetoothDevice device, {
    bool allowTypeMismatch = false,
  }) async {
    if (_legalOnlyDemoEnabled && _looksLikeTachograph(device)) {
      final wantsLegalOnlyDemo = await _confirmLegalOnlyDemo();
      if (!mounted) return;
      if (wantsLegalOnlyDemo == true) {
        await _runLegalOnlyDemo(device);
        return;
      }
    }

    AppBluetoothService.instance.stopScan();
    setState(() {
      _isScanning = true;
      _connectingDeviceId = device.id;
    });

    try {
      final appState = AppStateProvider.of(context);
      await AppBluetoothService.instance.connectToDevice(device, appState, (
        bool connected,
      ) {
        if (mounted) {
          appState.setBluetoothConnected(
            connected,
            deviceName: device.displayName,
          );
        }
      }, allowTypeMismatch: allowTypeMismatch);

      if (mounted) {
        final index = _devices.indexWhere(
          (d) => d.id == device.id && d.type == device.type,
        );
        if (index != -1 && !_devices[index].isPaired) {
          setState(() {
            _devices[index] = AppBluetoothDevice(
              id: device.id,
              name: device.name,
              rssi: device.rssi,
              type: device.type,
              isPaired: true,
            );
            _connectingDeviceId = null;
          });

          await Future.delayed(const Duration(milliseconds: 500));
        }
      }

      if (mounted) {
        showAppSnackBar(
          context,
          AppLocalizations.getText(
            appState.selectedLanguage,
            'bt.connectedSnack',
          ),
          type: AppSnackBarType.success,
        );
        _leave(toDashboard: true);
      }
    } on VuProfileMismatchException catch (e) {
      if (!mounted) return;
      setState(() {
        _isScanning = false;
        _connectingDeviceId = null;
      });
      await _resolveTypeMismatch(device, e);
    } catch (e) {
      if (mounted) {
        setState(() {
          _isScanning = false;
          _connectingDeviceId = null;
        });
        showAppSnackBar(
          context,
          '${device.displayName}: ${_friendlyConnectError(e)}',
          type: AppSnackBarType.error,
        );
      }
    }
  }

  /// The device is the other kind of tachograph than the one chosen on the
  /// launch screen. Nothing has been sent to it yet; ask whether to switch
  /// to the matching kind, go on with the choice, or leave it.
  Future<void> _resolveTypeMismatch(
    AppBluetoothDevice device,
    VuProfileMismatchException e,
  ) async {
    final appState = AppStateProvider.of(context);
    final selected = appState.tachographType;
    final detected = TachographType.forDevice(hasIts: e.deviceHasIts);

    final choice = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_t('connect.mismatchTitle')),
        content: Text(
          _t('connect.mismatchBody')
              .replaceAll('{device}', device.displayName)
              .replaceAll('{detected}', detected.code)
              .replaceAll('{selected}', selected?.code ?? '-'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop('cancel'),
            child: Text(_t('connect.mismatchCancel')),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop('keep'),
            child: Text(_t('connect.mismatchKeep')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop('switch'),
            child: Text(
              _t(
                'connect.mismatchSwitch',
              ).replaceAll('{detected}', detected.code),
            ),
          ),
        ],
      ),
    );
    if (!mounted) return;

    switch (choice) {
      case 'switch':
        appState.setTachographType(detected);
        _connectTo(device);
      case 'keep':
        _connectTo(device, allowTypeMismatch: true);
    }
  }

  String _t(String key) => AppLocalizations.getText(
    AppStateProvider.of(context).selectedLanguage,
    key,
  );

  String _title() {
    final type = AppStateProvider.of(context).tachographType;
    final title = _t('connect.title');
    return type == null ? title : '${type.code} · $title';
  }

  /// Out of this screen: on to the dashboard after connecting (or skipping),
  /// or back. Standalone, back is the tachograph choice; pushed over the
  /// app, both are a pop.
  void _leave({required bool toDashboard}) {
    if (!widget.standalone) {
      Navigator.of(context).pop();
      return;
    }
    context.go(toDashboard ? '/dashboard' : '/select-device');
  }

  Future<void> _removeBond(AppBluetoothDevice device) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_t('scan.removeBondTitle')),
        content: Text(
          _t('scan.removeBondBody').replaceAll('{device}', device.displayName),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(_t('conn.cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(_t('scan.removeBondConfirm')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await AppBluetoothService.instance.removeBond(device.id);
      if (!mounted) return;
      setState(() => _devices.removeWhere((d) => d.id == device.id));
      showAppSnackBar(
        context,
        _t('scan.bondRemoved').replaceAll('{device}', device.displayName),
        type: AppSnackBarType.success,
      );
    } catch (e) {
      if (!mounted) return;
      showAppSnackBar(
        context,
        _t('scan.bondRemoveFailed')
            .replaceAll('{device}', device.displayName)
            .replaceAll('{error}', '${e is UnsupportedError ? e.message : e}'),
        type: AppSnackBarType.error,
      );
    }
  }

  String _friendlyConnectError(Object e) {
    if (e is TimeoutException) {
      return e.message ?? _t('scan.timeout');
    }
    if (e is BleException) {
      return e.message;
    }
    return _t('scan.connectFailed').replaceAll('{error}', '$e');
  }

  ({String label, IconData icon}) _signalInfo(int rssi) {
    if (rssi >= -50) {
      return (
        label: _t('scan.signalExcellent'),
        icon: Icons.signal_cellular_4_bar,
      );
    }
    if (rssi >= -70) {
      return (
        label: _t('scan.signalStrong'),
        icon: Icons.signal_cellular_alt_2_bar,
      );
    }
    if (rssi >= -85) {
      return (
        label: _t('scan.signalMedium'),
        icon: Icons.signal_cellular_alt_1_bar,
      );
    }
    return (label: _t('scan.signalWeak'), icon: Icons.signal_cellular_0_bar);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        shape: Border(bottom: BorderSide(color: scheme.outlineVariant)),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: scheme.primary),
          onPressed: () {
            AppBluetoothService.instance.stopScan();
            _leave(toDashboard: false);
          },
        ),
        title: Text(
          _title(),
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 24,
            color: scheme.primary,
          ),
        ),
        actions: [
          IconButton(
            tooltip: _t('scan.rescan'),
            onPressed: _isScanning ? null : _startScan,
            icon: _isScanning
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: scheme.primary,
                    ),
                  )
                : Icon(Icons.refresh, color: scheme.primary),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 672),
            child: _permissionDenied
                ? _buildPermissionDenied(scheme)
                : ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      _buildScanningHeader(scheme),
                      const SizedBox(height: 24),
                      _buildFilterHeader(scheme),
                      const SizedBox(height: 24),
                      ..._buildDeviceSections(scheme),
                      const SizedBox(height: 40),
                      _buildHelpFooter(scheme),
                      if (widget.standalone) ...[
                        const SizedBox(height: 16),
                        Center(
                          child: TextButton.icon(
                            onPressed: () {
                              AppBluetoothService.instance.stopScan();
                              _leave(toDashboard: true);
                            },
                            icon: const Icon(Icons.skip_next),
                            label: Text(_t('connect.skip')),
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildScanningHeader(ColorScheme scheme) {
    final String title;
    final String subtitle;
    final IconData icon;
    if (_isScanning) {
      title = _t('scan.scanning');
      subtitle = _t('scan.scanningHint');
      icon = Icons.bluetooth_searching;
    } else if (_devices.isEmpty) {
      title = _t('scan.noneFound');
      subtitle = _t('scan.noneFoundHint');
      icon = Icons.bluetooth_disabled;
    } else {
      title = _t('scan.done');
      subtitle = _t(
        'scan.foundCount',
      ).replaceAll('{count}', '${_devices.length}');
      icon = Icons.bluetooth_connected;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        children: [
          GestureDetector(
            onTap: _isScanning ? null : _startScan,
            child: SizedBox(
              width: 128,
              height: 128,
              child: AnimatedBuilder(
                animation: Listenable.merge([_ringController, _dotController]),
                builder: (context, _) {
                  final ring1 = _ringController.value;
                  final ring2 = (_ringController.value + 0.5) % 1.0;
                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      if (_isScanning) ...[
                        _pulseRing(scheme, ring1, baseOpacity: 0.20),
                        _pulseRing(scheme, ring2, baseOpacity: 0.10),
                      ],
                      Transform.scale(
                        scale: _isScanning
                            ? 1.0 + (_dotController.value * 0.06)
                            : 1.0,
                        child: Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: scheme.primary,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: scheme.primary.withValues(alpha: 0.35),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Icon(icon, color: scheme.onPrimary, size: 28),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              color: scheme.primary,
              fontWeight: FontWeight.w500,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _pulseRing(
    ColorScheme scheme,
    double phase, {
    required double baseOpacity,
  }) {
    final scale = 1.0 + phase * 1.0;
    final opacity = (1.0 - phase) * baseOpacity;
    return Transform.scale(
      scale: scale,
      child: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          color: scheme.primaryContainer.withValues(alpha: opacity),
          shape: BoxShape.circle,
        ),
      ),
    );
  }

  Widget _buildFilterHeader(ColorScheme scheme) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: scheme.primaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            _filterNearOnly ? _t('scan.nearDevices') : _t('scan.allDevices'),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: scheme.onPrimaryContainer,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Material(
          color: _filterNearOnly
              ? scheme.secondaryContainer
              : scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(999),
          child: InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: () => setState(() => _filterNearOnly = !_filterNearOnly),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _filterNearOnly ? Icons.filter_alt_off : Icons.filter_alt,
                    size: 16,
                    color: _filterNearOnly
                        ? scheme.onSecondaryContainer
                        : scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _filterNearOnly
                        ? _t('scan.clearFilter')
                        : _t('scan.filter'),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                      color: _filterNearOnly
                          ? scheme.onSecondaryContainer
                          : scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildDeviceSections(ColorScheme scheme) {
    if (_visibleDevices.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 32),
          child: Center(
            child: Text(
              _isScanning
                  ? _t('scan.searching')
                  : (_devices.isEmpty
                        ? _t('scan.noneFound')
                        : _t('scan.noneNear')),
              style: TextStyle(color: scheme.outline),
            ),
          ),
        ),
      ];
    }

    final tachographs = _tachographs;
    final dongles = _dongles;
    final widgets = <Widget>[];

    if (tachographs.isNotEmpty) {
      widgets.add(_sectionLabel(scheme, _t('scan.sectionTachographs')));
      widgets.add(const SizedBox(height: 8));
      for (final d in tachographs) {
        widgets.add(_buildDeviceCard(scheme, d, featured: true));
        widgets.add(const SizedBox(height: 8));
      }
    }

    if (dongles.isNotEmpty) {
      if (tachographs.isNotEmpty) widgets.add(const SizedBox(height: 16));
      widgets.add(_sectionLabel(scheme, _t('scan.sectionDongles')));
      widgets.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 2, 4, 8),
          child: Text(
            _t('scan.donglesHint'),
            style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
          ),
        ),
      );
      for (final d in dongles) {
        widgets.add(_buildDeviceCard(scheme, d, featured: false));
        widgets.add(const SizedBox(height: 8));
      }
    }

    return widgets;
  }

  Widget _sectionLabel(ColorScheme scheme, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.6,
          color: scheme.onSurfaceVariant,
        ),
      ),
    );
  }

  Widget _buildDeviceCard(
    ColorScheme scheme,
    AppBluetoothDevice d, {
    required bool featured,
  }) {
    final isBle = d.type == AppBluetoothType.le;
    final isDongle = _looksLikeDongle(d);
    final isConnecting = _connectingDeviceId == d.id;
    final signal = _signalInfo(d.rssi);
    final isWeak = d.rssi < -85;

    final card = Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: featured ? scheme.primaryContainer : scheme.outlineVariant,
          width: featured ? 2 : 1,
        ),
        boxShadow: featured
            ? [
                BoxShadow(
                  color: scheme.primaryContainer.withValues(alpha: 0.25),
                  blurRadius: 16,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: featured
                  ? scheme.primaryContainer
                  : scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isDongle ? Icons.developer_board : Icons.speed,
              color: featured
                  ? scheme.onPrimaryContainer
                  : scheme.onSurfaceVariant,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // The unit's name is "TACHOGRAPH-" plus a plate of up to 14
                // characters, so it gets a line of its own and may wrap.
                Text(
                  d.displayName,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: scheme.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          isDongle
                              ? _t('scan.tagDongle')
                              : _t('scan.tagTachograph'),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: scheme.primary,
                          ),
                        ),
                      ),
                    ],
                    if (d.isPaired) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: scheme.secondaryContainer,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          _t('scan.tagPaired'),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: scheme.onSecondaryContainer,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${d.id} · ${isBle ? "BLE" : "Classic"}',
                  style: TextStyle(
                    fontSize: 10,
                    color: scheme.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (isConnecting) ...[
                  const SizedBox(height: 4),
                  _buildLinkPhase(scheme),
                ],
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(
                      signal.icon,
                      size: 14,
                      color: featured
                          ? scheme.primary
                          : scheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      signal.label,
                      style: TextStyle(
                        fontSize: 11,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (d.isPaired && !isConnecting && _connectingDeviceId == null)
            IconButton(
              tooltip: _t('scan.removeBondTooltip'),
              icon: Icon(Icons.link_off, color: scheme.error),
              onPressed: () => _removeBond(d),
            ),
          if (isConnecting)
            BouncingDotsLoader(color: scheme.primary, dotSize: 7, travel: 16)
          else if (featured)
            FilledButton(
              onPressed: () => _connectTo(d),
              style: FilledButton.styleFrom(
                backgroundColor: scheme.primary,
                foregroundColor: scheme.onPrimary,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              child: Text(
                _t('scan.connect'),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          else
            TextButton(
              onPressed: () => _connectTo(d),
              style: TextButton.styleFrom(
                foregroundColor: scheme.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              child: Text(
                _t('scan.connect'),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );

    return Opacity(opacity: isWeak ? 0.6 : 1.0, child: card);
  }

  Widget _buildLinkPhase(ColorScheme scheme) {
    return ValueListenableBuilder<VuLinkPhase>(
      valueListenable: AppBluetoothService.instance.linkPhase,
      builder: (context, phase, _) {
        final (text, highlight) = switch (phase) {
          VuLinkPhase.disconnected ||
          VuLinkPhase.connecting => (_t('scan.phaseConnecting'), false),
          VuLinkPhase.discovering => (_t('scan.phaseDiscovering'), false),
          VuLinkPhase.bonding => (_t('scan.phaseBonding'), true),
          VuLinkPhase.subscribing => (_t('scan.phaseSubscribing'), false),
          VuLinkPhase.ready => (_t('scan.phaseReading'), false),
        };
        return Text(
          text,
          style: TextStyle(
            fontSize: 11,
            fontWeight: highlight ? FontWeight.w700 : FontWeight.w400,
            color: highlight ? scheme.primary : scheme.onSurfaceVariant,
          ),
        );
      },
    );
  }

  Widget _buildPermissionDenied(ColorScheme scheme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.bluetooth_disabled, size: 40, color: scheme.error),
            const SizedBox(height: 16),
            Text(
              _t('scan.permissionDenied'),
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.outline),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () => openAppSettings(),
              child: Text(_t('scan.openSettings')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHelpFooter(ColorScheme scheme) {
    return Text(
      _t('scan.helpFooter'),
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 12,
        fontStyle: FontStyle.italic,
        color: scheme.onSurfaceVariant,
      ),
    );
  }
}
