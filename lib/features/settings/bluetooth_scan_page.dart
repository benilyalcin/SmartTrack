import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart'
    show openAppSettings;

import '../../core/exceptions/ble_exception.dart';
import '../../core/localization/localization.dart';
import '../../core/providers/app_state.dart';
import '../../core/services/bluetooth_service.dart';
import '../../core/widgets/app_snackbar.dart';
import '../../core/widgets/bouncing_dots_loader.dart';

const String _tachographOuiPrefix = '00:03:73';

class BluetoothScanPage extends StatefulWidget {
  const BluetoothScanPage({super.key});

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
      d.id.toUpperCase().startsWith(_tachographOuiPrefix);

  bool _looksLikeDongle(AppBluetoothDevice d) =>
      d.id.toUpperCase() == AppBluetoothService.dongleDeviceId;

  bool _isFeatured(AppBluetoothDevice d) =>
      _looksLikeTachograph(d) || _looksLikeDongle(d);

  List<AppBluetoothDevice> get _featuredDevices =>
      _devices.where(_isFeatured).toList();

  List<AppBluetoothDevice> get _otherDevices {
    final others = _devices.where((d) => !_isFeatured(d));
    if (!_filterNearOnly) return others.toList();

    return others.where((d) => d.rssi >= -70).toList();
  }

  List<AppBluetoothDevice> get _visibleDevices => [
    ..._featuredDevices,
    ..._otherDevices,
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
        title: const Text('Ekran görüntüsü için mi bağlanıyorsun?'),
        content: const Text(
          'Evet dersen sadece EU 2016/799 Annex 1C, Ek 8, Tablo 28\'de (ücretsiz, resmi kaynak — ISO 16844-7 değil) '
          'tanımlı alanlardan 4 tanesi okunur: VIN, tarih/saat, kilometre, izinli hız. Başka hiçbir alan sorulmaz.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Hayır'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Evet'),
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
          'Tamamlandı — Log ekranında görebilirsin.',
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

  void _connectTo(AppBluetoothDevice device) async {
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
      });

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
        Navigator.of(context).pop();
        showAppSnackBar(
          context,
          AppLocalizations.getText(
            appState.selectedLanguage,
            'bt.connectedSnack',
          ),
          type: AppSnackBarType.success,
        );
      }
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

  String _friendlyConnectError(Object e) {
    if (e is TimeoutException) {
      return e.message ?? 'Cihaz yanıt vermiyor (zaman aşımı)';
    }
    if (e is BleException) {
      return e.message;
    }
    return 'Bağlanılamadı ($e)';
  }

  ({String label, IconData icon}) _signalInfo(int rssi) {
    if (rssi >= -50)
      return (label: 'Mükemmel Sinyal', icon: Icons.signal_cellular_4_bar);
    if (rssi >= -70)
      return (label: 'Güçlü Sinyal', icon: Icons.signal_cellular_alt_2_bar);
    if (rssi >= -85)
      return (label: 'Orta Sinyal', icon: Icons.signal_cellular_alt_1_bar);
    return (label: 'Zayıf Sinyal', icon: Icons.signal_cellular_0_bar);
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
            Navigator.of(context).pop();
          },
        ),
        title: Text(
          'Cihaz Bağla',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 24,
            color: scheme.primary,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Yeniden Ara',
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
      title = 'Cihazlar taranıyor...';
      subtitle = 'Bluetooth kapsama alanındaki aygıtlar aranıyor';
      icon = Icons.bluetooth_searching;
    } else if (_devices.isEmpty) {
      title = 'Cihaz bulunamadı';
      subtitle = 'Tekrar taramak için yukarıdaki simgeye dokunun';
      icon = Icons.bluetooth_disabled;
    } else {
      title = 'Tarama tamamlandı';
      subtitle = '${_devices.length} cihaz bulundu';
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
            _filterNearOnly ? 'Yakındaki Cihazlar' : 'Tüm Cihazlar',
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
                    _filterNearOnly ? 'Filtreyi Kaldır' : 'Filtrele',
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
                  ? 'Aranıyor...'
                  : (_devices.isEmpty
                        ? 'Cihaz bulunamadı'
                        : 'Yakında cihaz yok'),
              style: TextStyle(color: scheme.outline),
            ),
          ),
        ),
      ];
    }

    final featured = _featuredDevices;
    final others = _otherDevices;
    final widgets = <Widget>[];

    if (featured.isNotEmpty) {
      widgets.add(_sectionLabel(scheme, 'Öne Çıkan Cihazlar'));
      widgets.add(const SizedBox(height: 8));
      for (final d in featured) {
        widgets.add(_buildDeviceCard(scheme, d, featured: true));
        widgets.add(const SizedBox(height: 8));
      }
      if (others.isNotEmpty) {
        widgets.add(const SizedBox(height: 16));
        widgets.add(_sectionLabel(scheme, 'Diğer Cihazlar'));
        widgets.add(const SizedBox(height: 8));
      }
    }

    for (final d in others) {
      widgets.add(_buildDeviceCard(scheme, d, featured: false));
      widgets.add(const SizedBox(height: 8));
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
              featured
                  ? (isDongle ? Icons.developer_board : Icons.speed)
                  : (isBle ? Icons.bluetooth_searching : Icons.bluetooth),
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
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        d.displayName,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: scheme.onSurface,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (featured) ...[
                      const SizedBox(width: 6),
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
                          isDongle ? 'DONGLE' : 'TAKOGRAF',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: scheme.primary,
                          ),
                        ),
                      ),
                    ],
                    if (d.isPaired) ...[
                      const SizedBox(width: 6),
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
                          'EŞLEŞTİ',
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
          if (isConnecting)
            BouncingDotsLoader(color: scheme.primary, dotSize: 7, travel: 16)
          else if (featured)
            FilledButton(
              onPressed: () => _connectTo(d),
              style: FilledButton.styleFrom(
                backgroundColor: scheme.primary,
                foregroundColor: scheme.onPrimary,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              child: const Text(
                'Bağlan',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
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
              child: const Text(
                'Bağlan',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
        ],
      ),
    );

    return Opacity(opacity: isWeak ? 0.6 : 1.0, child: card);
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
              'Bluetooth taraması için gerekli izinler verilmedi. Lütfen uygulama ayarlarından Bluetooth ve Konum izinlerini verin.',
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.outline),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () => openAppSettings(),
              child: const Text('Ayarları Aç'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHelpFooter(ColorScheme scheme) {
    return Text(
      'Cihazınızı listede göremiyor musunuz? Takografın Bluetooth modunun açık olduğundan ve eşleşme moduna geçtiğinden emin olun.',
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 12,
        fontStyle: FontStyle.italic,
        color: scheme.onSurfaceVariant,
      ),
    );
  }
}
