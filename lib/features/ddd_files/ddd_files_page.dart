import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/localization/localization.dart';
import '../../core/models/ddd_file.dart';
import '../../core/providers/app_state.dart';
import '../../core/services/bluetooth_service.dart';
import '../../core/services/ddd_file_repository.dart';

import '../../core/services/google_drive_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/responsive.dart';
import '../../core/widgets/app_snackbar.dart';
import '../../core/widgets/bluetooth_warning_banner.dart';

import '../../core/widgets/card_slot_warning_banner.dart';

typedef RealDownloadOptions = ({
  bool includeCard,
  bool includeVehicleUnit,
  DateTimeRange? activityRange,
  bool includeEventsFaults,
  bool includeDetailedSpeed,
  bool includeTechnicalData,
});

class DddFilesPage extends StatefulWidget {
  const DddFilesPage({super.key});

  @override
  State<DddFilesPage> createState() => _DddFilesPageState();
}

class _DddFilesPageState extends State<DddFilesPage> {
  bool _selectionMode = false;
  final Set<String> _selectedIds = {};
  bool _newestFirst = true;
  bool _isDriveBackupEnabled = false;

  bool _isSharing = false;
  GoogleSignInAccount? _driveUser;
  bool _isDriveConnecting = false;

  @override
  void initState() {
    super.initState();
    _loadDriveState();
  }

  Future<void> _loadDriveState() async {
    final enabled = await GoogleDriveService.instance.isBackupEnabled();
    final user = await GoogleDriveService.instance.signInSilently();
    if (!mounted) return;
    setState(() {
      _isDriveBackupEnabled = enabled;
      _driveUser = user;
    });
  }

  Future<void> _connectDrive() async {
    setState(() => _isDriveConnecting = true);
    try {
      final user = await GoogleDriveService.instance.signIn();
      if (!mounted) return;
      setState(() {
        _driveUser = user;
        if (user != null) _isDriveBackupEnabled = true;
      });
      if (user != null)
        await GoogleDriveService.instance.setBackupEnabled(true);
    } catch (e) {
      debugPrint('Google Drive sign-in failed: $e');
      if (mounted)
        showAppSnackBar(
          context,
          _t('ddd.driveConnectError'),
          type: AppSnackBarType.error,
        );
    } finally {
      if (mounted) setState(() => _isDriveConnecting = false);
    }
  }

  Future<void> _disconnectDrive() async {
    await GoogleDriveService.instance.signOut();
    await GoogleDriveService.instance.setBackupEnabled(false);
    if (!mounted) return;
    setState(() {
      _driveUser = null;
      _isDriveBackupEnabled = false;
    });
  }

  Future<void> _toggleDriveBackup() async {
    final next = !_isDriveBackupEnabled;
    setState(() => _isDriveBackupEnabled = next);
    await GoogleDriveService.instance.setBackupEnabled(next);
  }

  String _t(String key) => AppLocalizations.getText(
    AppStateProvider.of(context).selectedLanguage,
    key,
  );

  void _enterSelectionWith(String id) {
    setState(() {
      _selectionMode = true;
      _selectedIds
        ..clear()
        ..add(id);
    });
  }

  void _toggleSelected(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _selectionMode = false;
      _selectedIds.clear();
    });
  }

  Future<void> _confirmAndTrash(AppState appState, List<DddFile> files) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_t('ddd.deleteConfirmTitle')),
        content: Text(
          files.length == 1
              ? _t('ddd.deleteConfirmSingle')
              : _t(
                  'ddd.deleteConfirmMulti',
                ).replaceFirst('{count}', '${files.length}'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(_t('ddd.cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: Text(_t('ddd.moveToTrash')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await appState.moveDddFilesToTrash(files);
    if (mounted) {
      _exitSelectionMode();
      showAppSnackBar(
        context,
        _t('ddd.deleteSuccess'),
        type: AppSnackBarType.success,
      );
    }
  }

  Future<DateTimeRange?> _pickActivityRange() async {
    final choice = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Aktivite verisi — hangi tarih aralığı?'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.of(context).pop('7'),
            child: const Text('Son 7 gün'),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.of(context).pop('30'),
            child: const Text('Son 30 gün'),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.of(context).pop('90'),
            child: const Text('Son 90 gün'),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.of(context).pop('365'),
            child: const Text('Tüm geçmiş (365 gün)'),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.of(context).pop('custom'),
            child: const Text('Özel tarih aralığı seç…'),
          ),
          const Divider(height: 1),
          SimpleDialogOption(
            onPressed: () => Navigator.of(context).pop('skip'),
            child: const Text('Aktivite verisi alma'),
          ),
        ],
      ),
    );
    if (choice == null || choice == 'skip') return null;

    final today = DateTime.now();
    final yesterday = DateTime(today.year, today.month, today.day - 1);
    if (choice == 'custom') {
      if (!mounted) return null;
      return showDateRangePicker(
        context: context,
        firstDate: DateTime(today.year, today.month, today.day - 365),
        lastDate: yesterday,
        initialDateRange: DateTimeRange(
          start: DateTime(today.year, today.month, today.day - 7),
          end: yesterday,
        ),
        helpText: 'Aktivite verisi tarih aralığı',
      );
    }
    final days = int.parse(choice);
    return DateTimeRange(
      start: DateTime(today.year, today.month, today.day - days),
      end: yesterday,
    );
  }

  ({void Function(String) setMessage, void Function() close})
  _showLoadingDialog(String initialMessage) {
    final message = ValueNotifier<String>(initialMessage);
    var open = true;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        titlePadding: const EdgeInsets.fromLTRB(24, 16, 8, 0),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('.ddd Verisi', style: TextStyle(fontSize: 16)),
            IconButton(
              icon: const Icon(Icons.close),
              tooltip: 'Kapat',
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
          ],
        ),
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 16),
            Flexible(
              child: ValueListenableBuilder<String>(
                valueListenable: message,
                builder: (context, value, _) => Text(value),
              ),
            ),
          ],
        ),
      ),
    ).then((_) {
      open = false;
      message.dispose();
    });
    return (
      setMessage: (String m) {
        if (open) message.value = m;
      },
      close: () {
        if (open) {
          open = false;

          Navigator.of(context, rootNavigator: true).pop();
        }
      },
    );
  }

  Future<RealDownloadOptions?> _showRealDownloadOptionsSheet() {
    final scheme = Theme.of(context).colorScheme;
    return showModalBottomSheet<RealDownloadOptions>(
      context: context,
      backgroundColor: scheme.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) =>
          _RealDownloadOptionsSheet(onPickActivityRange: _pickActivityRange),
    );
  }

  Future<void> _startRealDddDownload(AppState appState) async {
    final options = await _showRealDownloadOptionsSheet();
    if (options == null || !mounted) return;
    if (!options.includeCard && !options.includeVehicleUnit) return;

    final kind = options.includeCard && options.includeVehicleUnit
        ? DddFetchKind.both
        : options.includeCard
        ? DddFetchKind.card
        : DddFetchKind.vehicleUnit;

    final dialog = _showLoadingDialog('Dongle aranıyor…');
    try {
      final device = await AppBluetoothService.instance.findDongle();
      if (!mounted) return;
      if (device == null) {
        dialog.close();
        showAppSnackBar(
          context,
          'Dongle bulunamadı — Bluetooth açık ve dongle yakınında olduğundan emin olun.',
          type: AppSnackBarType.error,
        );
        return;
      }

      dialog.setMessage('.ddd verisi indiriliyor…');
      final result = await AppBluetoothService.instance
          .downloadRealDddFromDongle(
            device,
            appState,
            kind: kind,
            activityRangeStart: options.activityRange?.start,
            activityRangeEnd: options.activityRange?.end,
            includeEventsFaults: options.includeEventsFaults,
            includeDetailedSpeed: options.includeDetailedSpeed,
            includeTechnicalData: options.includeTechnicalData,

            onProgress: dialog.setMessage,
          );
      if (!mounted) return;
      dialog.close();
      if (result.card == null && result.vehicleUnit == null) {
        showAppSnackBar(
          context,
          'İndirme tamamlanamadı — cihaz yanıt vermedi.',
          type: AppSnackBarType.error,
        );
        return;
      }
      showAppSnackBar(
        context,
        'İndirildi ve ayrıştırıldı.',
        type: AppSnackBarType.success,
      );
    } catch (e) {
      if (mounted) {
        dialog.close();
        showAppSnackBar(
          context,
          'İndirilemedi: $e',
          type: AppSnackBarType.error,
        );
      }
    }
  }

  Future<void> _shareSelected(List<DddFile> files) async {
    setState(() => _isSharing = true);
    try {
      final xFiles = <XFile>[];
      final fileNames = <String>[];
      for (final f in files) {
        final bytes = await DddFileRepository.instance.readFileBytes(f);
        if (bytes.isNotEmpty) {
          final name = f.downloadKind == 'both'
              ? 'ddd_kart_${f.id}.ddd'
              : 'ddd_${f.id}.ddd';
          xFiles.add(
            XFile.fromData(
              bytes,
              name: name,
              mimeType: 'application/octet-stream',
            ),
          );
          fileNames.add(name);
        }

        if (f.downloadKind == 'both') {
          final vuBytes = await DddFileRepository.instance
              .readSecondaryFileBytes(f);
          if (vuBytes.isNotEmpty) {
            final vuName = 'ddd_takograf_${f.id}.ddd';
            xFiles.add(
              XFile.fromData(
                vuBytes,
                name: vuName,
                mimeType: 'application/octet-stream',
              ),
            );
            fileNames.add(vuName);
          }
        }
      }
      if (xFiles.isEmpty) {
        if (mounted)
          showAppSnackBar(
            context,
            _t('ddd.shareError'),
            type: AppSnackBarType.error,
          );
        return;
      }
      await Share.shareXFiles(xFiles, fileNameOverrides: fileNames);
      if (mounted) _exitSelectionMode();
    } catch (_) {
      if (mounted)
        showAppSnackBar(
          context,
          _t('ddd.shareError'),
          type: AppSnackBarType.error,
        );
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final appState = AppStateProvider.of(context);

    var files = appState.dddFiles;
    if (!_newestFirst) files = files.reversed.toList();
    final isDesktop = isDesktopLayout(context);
    final selectedFiles = files
        .where((f) => _selectedIds.contains(f.id))
        .toList();

    return Scaffold(
      backgroundColor: scheme.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: isDesktop
              ? const EdgeInsets.all(48)
              : const EdgeInsets.all(16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const BluetoothWarningBanner(),
                  const CardSlotWarningBanner(),
                  _buildHeader(scheme, isDesktop),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          _t('ddd.availableFiles'),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: scheme.onSurface,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () =>
                            setState(() => _newestFirst = !_newestFirst),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 4,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.filter_list,
                                size: 16,
                                color: scheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _t('ddd.sortByDate'),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                              Icon(
                                _newestFirst
                                    ? Icons.arrow_downward
                                    : Icons.arrow_upward,
                                size: 14,
                                color: scheme.onSurfaceVariant,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (files.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(32),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _t('ddd.filesEmpty'),
                        style: TextStyle(color: scheme.outline),
                        textAlign: TextAlign.center,
                      ),
                    )
                  else
                    ...files.map((f) => _buildFileCard(context, scheme, f)),
                  const SizedBox(height: 32),
                  _buildGoogleDriveBackupSection(scheme),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomBar(
        context,
        scheme,
        appState,
        selectedFiles,
      ),
    );
  }

  Widget _buildHeader(ColorScheme scheme, bool isDesktop) {
    if (_selectionMode) {
      return Row(
        children: [
          IconButton(
            icon: Icon(Icons.close, color: scheme.onSurface),
            onPressed: _exitSelectionMode,
          ),
          const SizedBox(width: 4),
          Text(
            _t(
              'ddd.selectedCountHeader',
            ).replaceFirst('{count}', '${_selectedIds.length}'),
            style: TextStyle(
              fontSize: isDesktop ? 24 : 20,
              fontWeight: FontWeight.w600,
              color: scheme.onSurface,
            ),
          ),
        ],
      );
    }
    return Text(
      _t('ddd.filesTitle'),
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: isDesktop ? 32 : 24,
        fontWeight: FontWeight.w600,
        color: scheme.onSurface,
      ),
    );
  }

  Widget _buildFileCard(
    BuildContext context,
    ColorScheme scheme,
    DddFile file,
  ) {
    final isSelected = _selectedIds.contains(file.id);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isSelected
            ? scheme.primaryContainer.withValues(alpha: 0.15)
            : scheme.surfaceContainerLowest,
        border: Border.all(
          color: isSelected ? scheme.primary : scheme.outlineVariant,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: AppTheme.cardShadow,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: _selectionMode
            ? () => _toggleSelected(file.id)
            : () => context.push('/ddd-files/${file.id}'),
        onLongPress: _selectionMode ? null : () => _enterSelectionWith(file.id),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              if (_selectionMode) ...[
                Checkbox(
                  value: isSelected,
                  onChanged: (_) => _toggleSelected(file.id),
                ),
                const SizedBox(width: 4),
              ] else ...[
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: scheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.article,
                    color: scheme.onSecondaryContainer,
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            file.cardHolderName.isNotEmpty
                                ? file.cardHolderName
                                : file.cardType,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: scheme.secondaryContainer,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            switch (file.downloadKind) {
                              'vehicleUnit' => _t('ddd.vehicleUnitBadge'),
                              'both' => _t('ddd.bothBadge'),
                              _ => _t('ddd.cardBadge'),
                            },
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: scheme.onSecondaryContainer,
                            ),
                          ),
                        ),
                        if (file.isSimulated) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: scheme.tertiaryContainer,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              _t('ddd.simulatedBadge'),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: scheme.onTertiaryContainer,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today,
                          size: 12,
                          color: scheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            _formatDate(file.downloadedAt),
                            style: TextStyle(
                              fontSize: 12,
                              color: scheme.onSurfaceVariant,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Icon(
                          Icons.sd_storage,
                          size: 12,
                          color: scheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            _formatSize(file.fileSizeBytes),
                            style: TextStyle(
                              fontSize: 12,
                              color: scheme.onSurfaceVariant,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? scheme.primary.withValues(alpha: 0.15)
                      : scheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isSelected
                      ? _t('ddd.selectedStatus')
                      : _formatTimeOnly(file.downloadedAt),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isSelected
                        ? scheme.primary
                        : scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGoogleDriveBackupSection(ColorScheme scheme) {
    final connected = _driveUser != null;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        border: Border.all(color: scheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Icon(Icons.cloud_upload, color: scheme.outline, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _t('settings.backupTitle'),
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: scheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            connected
                                ? (_driveUser!.email.isNotEmpty
                                      ? _driveUser!.email
                                      : _t('settings.statusActive'))
                                : _t('settings.statusInactive'),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: connected
                                  ? scheme.secondary
                                  : scheme.outline,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (connected)
                GestureDetector(
                  onTap: _toggleDriveBackup,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 48,
                    height: 24,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: _isDriveBackupEnabled
                          ? scheme.secondary
                          : scheme.outlineVariant,
                    ),
                    child: Stack(
                      children: [
                        AnimatedPositioned(
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeIn,
                          left: _isDriveBackupEnabled ? 26 : 2,
                          right: _isDriveBackupEnabled ? 2 : 26,
                          top: 2,
                          bottom: 2,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.1),
                                  blurRadius: 2,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _t('settings.backupDesc'),
            style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          if (connected)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _disconnectDrive,
                icon: Icon(Icons.link_off, size: 16, color: scheme.error),
                label: Text(
                  _t('ddd.driveDisconnect'),
                  style: TextStyle(
                    color: scheme.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            )
          else
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _isDriveConnecting ? null : _connectDrive,
                icon: _isDriveConnecting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.g_mobiledata, size: 22),
                label: Text(_t('ddd.driveConnect')),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget? _buildBottomBar(
    BuildContext context,
    ColorScheme scheme,
    AppState appState,
    List<DddFile> selectedFiles,
  ) {
    if (_selectionMode) {
      if (selectedFiles.isEmpty) return null;
      return SafeArea(
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLowest,
            border: Border(top: BorderSide(color: scheme.outlineVariant)),
          ),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isSharing
                      ? null
                      : () => _shareSelected(selectedFiles),
                  icon: _isSharing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.ios_share),
                  label: Text(
                    '${_t('ddd.share')} (${selectedFiles.length})',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    softWrap: false,
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _confirmAndTrash(appState, selectedFiles),
                  icon: const Icon(Icons.delete_outline),
                  label: Text(
                    '${_t('ddd.moveToTrash')} (${selectedFiles.length})',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    softWrap: false,
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: scheme.error,
                    foregroundColor: scheme.onError,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SafeArea(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLowest,
          border: Border(top: BorderSide(color: scheme.outlineVariant)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => _startRealDddDownload(appState),
                icon: const Icon(Icons.bluetooth_searching),
                label: Text(_t('ddd.fetchRealData')),
                style: FilledButton.styleFrom(
                  backgroundColor: scheme.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => context.push('/ddd-files/trash'),
                icon: const Icon(Icons.delete_outline),
                label: Text(_t('ddd.trash')),
                style: OutlinedButton.styleFrom(
                  foregroundColor: scheme.onSurfaceVariant,
                  side: BorderSide(color: scheme.outlineVariant),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final h = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '$d.$m.${dt.year} $h:$min';
  }

  String _formatTimeOnly(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '$h:$min';
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    return '${(bytes / 1024).toStringAsFixed(1)} KB';
  }
}

class _RealDownloadOptionsSheet extends StatefulWidget {
  const _RealDownloadOptionsSheet({required this.onPickActivityRange});

  final Future<DateTimeRange?> Function() onPickActivityRange;

  @override
  State<_RealDownloadOptionsSheet> createState() =>
      _RealDownloadOptionsSheetState();
}

class _RealDownloadOptionsSheetState extends State<_RealDownloadOptionsSheet> {
  bool _includeVehicleUnit = true;
  bool _includeCard = true;
  DateTimeRange? _activityRange;
  bool _includeEventsFaults = true;
  bool _includeDetailedSpeed = true;
  bool _includeTechnicalData = true;

  @override
  void initState() {
    super.initState();

    final today = DateTime.now();
    final yesterday = DateTime(today.year, today.month, today.day - 1);
    _activityRange = DateTimeRange(
      start: DateTime(today.year, today.month, today.day - 30),
      end: yesterday,
    );
  }

  Future<void> _pickRange() async {
    final range = await widget.onPickActivityRange();
    if (!mounted) return;
    setState(() => _activityRange = range);
  }

  String get _rangeLabel {
    final range = _activityRange;
    if (range == null) return 'Alınmayacak';
    final days = range.end.difference(range.start).inDays + 1;
    return 'Son $days gün';
  }

  bool get _canDownload => _includeCard || _includeVehicleUnit;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: scheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '.ddd Verisi İndir',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Hangi verileri almak istediğini seç',
                style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 16),
              _buildBlockToggle(
                scheme,
                icon: Icons.directions_car_filled_outlined,
                title: 'Araç Ünitesi (Takograf)',
                value: _includeVehicleUnit,
                onChanged: (v) => setState(() => _includeVehicleUnit = v),
              ),
              if (_includeVehicleUnit) _buildVuSubPanel(scheme),
              const SizedBox(height: 8),
              _buildBlockToggle(
                scheme,
                icon: Icons.badge_outlined,
                title: 'Sürücü Kartı',
                value: _includeCard,
                onChanged: (v) => setState(() => _includeCard = v),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _canDownload
                      ? () => Navigator.of(context).pop((
                          includeCard: _includeCard,
                          includeVehicleUnit: _includeVehicleUnit,
                          activityRange: _includeVehicleUnit
                              ? _activityRange
                              : null,
                          includeEventsFaults: _includeEventsFaults,
                          includeDetailedSpeed: _includeDetailedSpeed,
                          includeTechnicalData: _includeTechnicalData,
                        ))
                      : null,
                  icon: const Icon(Icons.download_rounded),
                  label: const Text('İndir'),
                  style: FilledButton.styleFrom(
                    backgroundColor: scheme.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBlockToggle(
    ColorScheme scheme, {
    required IconData icon,
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        border: Border.all(
          color: value ? scheme.primary : scheme.outlineVariant,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: CheckboxListTile(
        value: value,
        onChanged: (v) => onChanged(v ?? false),
        controlAffinity: ListTileControlAffinity.leading,
        secondary: Icon(icon, color: scheme.onSurfaceVariant),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: scheme.onSurface,
          ),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildVuSubPanel(ColorScheme scheme) {
    return Container(
      margin: const EdgeInsets.only(left: 20, top: 4, bottom: 4),
      padding: const EdgeInsets.only(left: 12, top: 2, bottom: 2),
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(color: scheme.outlineVariant, width: 2),
        ),
      ),
      child: Column(
        children: [
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text(
              'Aktivite Verisi',
              style: TextStyle(fontSize: 14, color: scheme.onSurface),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _rangeLabel,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: scheme.primary,
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: scheme.onSurfaceVariant,
                ),
              ],
            ),
            onTap: _pickRange,
          ),
          _buildMiniSwitch(
            scheme,
            'Olaylar ve Arızalar',
            _includeEventsFaults,
            (v) => setState(() => _includeEventsFaults = v),
          ),
          _buildMiniSwitch(
            scheme,
            'Detaylı Hız',
            _includeDetailedSpeed,
            (v) => setState(() => _includeDetailedSpeed = v),
          ),
          _buildMiniSwitch(
            scheme,
            'Teknik Veri',
            _includeTechnicalData,
            (v) => setState(() => _includeTechnicalData = v),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniSwitch(
    ColorScheme scheme,
    String label,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontSize: 14, color: scheme.onSurface),
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: scheme.primary,
          ),
        ],
      ),
    );
  }
}
