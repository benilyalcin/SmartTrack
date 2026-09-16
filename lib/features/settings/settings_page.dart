import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/providers/app_state.dart';
import '../../core/localization/localization.dart';
import '../../core/services/bluetooth_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/responsive.dart';
import '../../core/widgets/bluetooth_warning_banner.dart';
import '../../core/widgets/card_slot_warning_banner.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String _t(String key) {
    return AppLocalizations.getText(
      AppStateProvider.of(context).selectedLanguage,
      key,
    );
  }

  void _startBluetoothScan() {
    context.push('/bluetooth-scan');
  }

  String _formatRelativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return _t('settings.justNow');
    if (diff.inMinutes < 60)
      return _t(
        'settings.minutesAgo',
      ).replaceFirst('{count}', '${diff.inMinutes}');
    if (diff.inHours < 24)
      return _t('settings.hoursAgo').replaceFirst('{count}', '${diff.inHours}');
    return _t('settings.daysAgo').replaceFirst('{count}', '${diff.inDays}');
  }

  @override
  Widget build(BuildContext context) {
    final appState = AppStateProvider.of(context);
    final isDesktop = isDesktopLayout(context);
    final padding = isDesktop
        ? const EdgeInsets.all(48)
        : const EdgeInsets.all(16);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SingleChildScrollView(
        child: Padding(
          padding: padding,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const BluetoothWarningBanner(),
                  const CardSlotWarningBanner(),

                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildDeviceStatusCard(context, appState),
                      const SizedBox(height: 24),
                      _buildPreferencesCard(context, appState),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDeviceStatusCard(BuildContext context, AppState appState) {
    final status = appState.connectionStatus;
    final isConnected = status != 'disconnected';
    final hasData = status == 'connectedWithData';

    final String statusTitle;
    final String badgeText;
    final Color badgeColor;
    switch (status) {
      case 'connectedWithData':
        statusTitle = _t('settings.connected');
        badgeText = _t('settings.active');
        badgeColor = Theme.of(context).colorScheme.primary;
        break;
      case 'connectedNoData':
        statusTitle = _t('settings.connectedNoData');
        badgeText = _t('settings.noData');
        badgeColor = Colors.orange;
        break;
      default:
        statusTitle = _t('settings.disconnected');
        badgeText = _t('settings.inactive');
        badgeColor = Theme.of(context).colorScheme.outline;
    }

    void handleTap() {
      if (isConnected) {
        AppBluetoothService.instance.disconnect();
        appState.setBluetoothConnected(false);
      } else {
        _startBluetoothScan();
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: hasData
            ? Color.alphaBlend(
                Theme.of(context).colorScheme.primary.withValues(alpha: 0.06),
                Theme.of(context).colorScheme.surface,
              )
            : Theme.of(context).colorScheme.surface,
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
        boxShadow: AppTheme.cardShadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context).colorScheme.surfaceTint.withValues(
                      alpha: hasData ? 0.08 : 0.05,
                    ),
                    Colors.transparent,
                  ],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _t('settings.deviceStatus').toUpperCase(),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.developer_board,
                            color: hasData
                                ? Theme.of(context).colorScheme.secondary
                                : badgeColor,
                            size: 28,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              statusTitle,
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        status == 'connectedNoData' &&
                                appState.dataFailureReason != null
                            ? appState.dataFailureReason!
                            : appState.lastKnownActivityTime == null
                            ? '-'
                            : '${_t('settings.lastSync')}${_formatRelativeTime(appState.lastKnownActivityTime!)}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isConnected
                            ? _t('settings.tapToDisconnect')
                            : _t('settings.tapToConnect'),
                        style: TextStyle(
                          fontSize: 11,
                          fontStyle: FontStyle.italic,
                          color: Theme.of(context).colorScheme.outline,
                        ),
                      ),
                      const SizedBox(height: 8),
                      InkWell(
                        borderRadius: BorderRadius.circular(6),
                        onTap: () =>
                            _showTachographAboutDialog(context, appState),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                size: 14,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  _t('settings.about'),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: handleTap,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: badgeColor.withValues(alpha: 0.1),
                      border: Border.all(
                        color: badgeColor.withValues(alpha: 0.3),
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (hasData)
                          _PulsingDot(
                            color: Theme.of(context).colorScheme.primary,
                          )
                        else
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: badgeColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                        const SizedBox(width: 8),
                        Text(
                          badgeText,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: badgeColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showTachographAboutDialog(BuildContext context, AppState appState) {
    final live = appState.tachographLiveData;
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(_t('settings.about')),
        content: SizedBox(
          width: 360,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!appState.hasTachographData)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      _t('settings.aboutNoData'),
                      style: TextStyle(
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                  ),
                _aboutSectionTitle(
                  context,
                  _t('settings.aboutIdentitySection'),
                ),
                _aboutInfoRow(context, _t('settings.vin'), live.vin),
                _aboutInfoRow(context, _t('settings.vrn'), live.vrn),
                _aboutInfoRow(
                  context,
                  _t('settings.memberState'),
                  live.memberState,
                ),
                const SizedBox(height: 12),
                _aboutSectionTitle(
                  context,
                  _t('settings.aboutManufacturerSection'),
                ),
                _aboutInfoRow(
                  context,
                  _t('settings.supplier'),
                  live.supplierIdentifier,
                ),
                _aboutInfoRow(
                  context,
                  _t('settings.ecuSerial'),
                  live.ecuSerialNumber,
                ),
                _aboutInfoRow(context, _t('settings.hwNumber'), live.hwNumber),
                _aboutInfoRow(context, _t('settings.swNumber'), live.swNumber),
                const SizedBox(height: 12),
                _aboutSectionTitle(context, _t('settings.aboutVersionSection')),
                _aboutInfoRow(
                  context,
                  _t('settings.hwVersion'),
                  live.hwVersion,
                ),
                _aboutInfoRow(
                  context,
                  _t('settings.swVersion'),
                  live.swVersion,
                ),
                _aboutInfoRow(
                  context,
                  _t('settings.ecuInstallDate'),
                  _fmtOrDash(live.ecuInstallDate),
                ),
                const SizedBox(height: 12),
                _aboutSectionTitle(
                  context,
                  _t('settings.aboutProductionSection'),
                ),
                _aboutInfoRow(
                  context,
                  _t('settings.ecuMfgDate'),
                  _fmtOrDash(live.ecuManufacturingDate),
                ),
                _aboutInfoRow(
                  context,
                  _t('settings.typeApproval'),
                  live.typeApproval,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(_t('settings.close')),
          ),
        ],
      ),
    );
  }

  Widget _aboutSectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }

  Widget _aboutInfoRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 4,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
          ),
          Expanded(
            flex: 5,
            child: Text(
              value.isEmpty ? '-' : value,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  String _fmtOrDash(DateTime? dt) {
    if (dt == null) return '';
    return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}';
  }

  Widget _buildPreferencesCard(BuildContext context, AppState appState) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _t('settings.preferences').toUpperCase(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              Icon(
                Icons.language,
                color: Theme.of(context).colorScheme.outline,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                _t('settings.langSelect'),
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              _buildLangButton(context, appState, 'TR'),
              const SizedBox(width: 8),
              _buildLangButton(context, appState, 'EN'),
              const SizedBox(width: 8),
              _buildLangButton(context, appState, 'DE'),
            ],
          ),

          const SizedBox(height: 24),
          Divider(color: Theme.of(context).colorScheme.outlineVariant),
          const SizedBox(height: 16),

          Row(
            children: [
              Icon(
                Icons.dark_mode_outlined,
                color: Theme.of(context).colorScheme.outline,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                _t('settings.themeSelect'),
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              _buildThemeButton(
                context,
                appState,
                ThemeMode.system,
                Icons.brightness_auto,
                _t('settings.themeSystem'),
              ),
              const SizedBox(width: 8),
              _buildThemeButton(
                context,
                appState,
                ThemeMode.light,
                Icons.light_mode,
                _t('settings.themeLight'),
              ),
              const SizedBox(width: 8),
              _buildThemeButton(
                context,
                appState,
                ThemeMode.dark,
                Icons.dark_mode,
                _t('settings.themeDark'),
              ),
            ],
          ),

          const SizedBox(height: 24),
          Divider(color: Theme.of(context).colorScheme.outlineVariant),
          const SizedBox(height: 16),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.screen_rotation_alt_outlined,
                color: Theme.of(context).colorScheme.outline,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _t('settings.freeScreen'),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _t('settings.freeScreenDesc'),
                      style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: appState.freeScreenMode,
                onChanged: (value) => appState.setFreeScreenMode(value),
                activeTrackColor: Theme.of(context).colorScheme.primary,
              ),
            ],
          ),

          const SizedBox(height: 24),
          Divider(color: Theme.of(context).colorScheme.outlineVariant),
          const SizedBox(height: 16),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.sync_outlined,
                color: Theme.of(context).colorScheme.outline,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _t('settings.autoFetchDdd'),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _t('settings.autoFetchDddDesc'),
                      style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: appState.autoFetchDddOnReconnect,
                onChanged: (value) =>
                    appState.setAutoFetchDddOnReconnect(value),
                activeTrackColor: Theme.of(context).colorScheme.primary,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildThemeButton(
    BuildContext context,
    AppState appState,
    ThemeMode mode,
    IconData icon,
    String label,
  ) {
    final isSelected = appState.themeMode == mode;

    return Expanded(
      child: GestureDetector(
        onTap: () => appState.setThemeMode(mode),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Colors.transparent,
            border: Border.all(
              color: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.outlineVariant,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 18,
                color: isSelected
                    ? Theme.of(context).colorScheme.onPrimary
                    : Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isSelected
                      ? Theme.of(context).colorScheme.onPrimary
                      : Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLangButton(
    BuildContext context,
    AppState appState,
    String lang,
  ) {
    final isSelected = appState.selectedLanguage == lang;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          appState.setLanguage(lang);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Colors.transparent,
            border: Border.all(
              color: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.outlineVariant,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            lang,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: isSelected
                  ? Theme.of(context).colorScheme.onPrimary
                  : Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
      ),
    );
  }
}

class _PulsingDot extends StatefulWidget {
  final Color color;
  const _PulsingDot({required this.color});

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.3, end: 1.0).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _animation,
      child: Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
      ),
    );
  }
}
