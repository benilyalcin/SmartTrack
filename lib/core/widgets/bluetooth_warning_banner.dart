import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../localization/localization.dart';
import '../providers/app_state.dart';

class BluetoothWarningBanner extends StatefulWidget {
  const BluetoothWarningBanner({super.key});

  @override
  State<BluetoothWarningBanner> createState() => _BluetoothWarningBannerState();
}

class _BluetoothWarningBannerState extends State<BluetoothWarningBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
    _opacity = Tween<double>(
      begin: 1.0,
      end: 0.55,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appState = AppStateProvider.of(context);
    if (appState.isBluetoothConnected || appState.bluetoothWarningDismissed)
      return const SizedBox.shrink();

    final lang = appState.selectedLanguage;
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: FadeTransition(
        opacity: _opacity,
        child: GestureDetector(
          onTap: () => context.push('/bluetooth-scan'),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: scheme.errorContainer.withValues(alpha: 0.5),
              border: Border.all(color: scheme.error.withValues(alpha: 0.3)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.bluetooth_disabled, color: scheme.error),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppLocalizations.getText(lang, 'bt.errorTitleShort'),
                        style: TextStyle(
                          color: scheme.error,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        AppLocalizations.getText(lang, 'bt.errorMsgShort'),
                        style: TextStyle(color: scheme.error, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: scheme.error),
                const SizedBox(width: 4),

                InkWell(
                  onTap: appState.dismissBluetoothWarning,
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(Icons.close, size: 18, color: scheme.error),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
