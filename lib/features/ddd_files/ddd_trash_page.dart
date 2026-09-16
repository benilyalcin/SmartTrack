import 'package:flutter/material.dart';

import '../../core/localization/localization.dart';
import '../../core/models/ddd_file.dart';
import '../../core/providers/app_state.dart';
import '../../core/utils/responsive.dart';
import '../../core/widgets/app_snackbar.dart';

class DddTrashPage extends StatefulWidget {
  const DddTrashPage({super.key});

  @override
  State<DddTrashPage> createState() => _DddTrashPageState();
}

class _DddTrashPageState extends State<DddTrashPage> {
  String _t(String key) => AppLocalizations.getText(
    AppStateProvider.of(context).selectedLanguage,
    key,
  );

  Future<void> _restore(AppState appState, DddFile file) async {
    await appState.restoreDddFiles([file]);
    if (mounted)
      showAppSnackBar(
        context,
        _t('ddd.restoreSuccess'),
        type: AppSnackBarType.success,
      );
  }

  Future<void> _confirmAndDeleteForever(AppState appState, DddFile file) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_t('ddd.deletePermanently')),
        content: Text(_t('ddd.deletePermanentlyConfirmSingle')),
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
            child: Text(_t('ddd.deletePermanently')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await appState.permanentlyDeleteDddFiles([file]);
    if (mounted)
      showAppSnackBar(
        context,
        _t('ddd.deleteSuccess'),
        type: AppSnackBarType.success,
      );
  }

  Future<void> _confirmAndDeleteAll(
    AppState appState,
    List<DddFile> files,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_t('ddd.deletePermanently')),
        content: Text(
          _t(
            'ddd.deletePermanentlyConfirmAll',
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
            child: Text(_t('ddd.deletePermanently')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await appState.permanentlyDeleteDddFiles(files);
    if (mounted)
      showAppSnackBar(
        context,
        _t('ddd.deleteSuccess'),
        type: AppSnackBarType.success,
      );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final appState = AppStateProvider.of(context);
    final files = appState.trashedDddFiles;
    final isDesktop = isDesktopLayout(context);

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Text(_t('ddd.trashTitle')),
      ),
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
                  if (files.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(32),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _t('ddd.trashEmpty'),
                        style: TextStyle(color: scheme.outline),
                        textAlign: TextAlign.center,
                      ),
                    )
                  else ...[
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () => _confirmAndDeleteAll(appState, files),
                        icon: Icon(Icons.delete_forever, color: scheme.error),
                        label: Text(
                          _t('ddd.deleteAll'),
                          style: TextStyle(color: scheme.error),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    ...files.map(
                      (f) => _buildTrashCard(context, scheme, appState, f),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTrashCard(
    BuildContext context,
    ColorScheme scheme,
    AppState appState,
    DddFile file,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        border: Border.all(color: scheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: scheme.errorContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.article, color: scheme.onErrorContainer),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  file.cardHolderName.isNotEmpty
                      ? file.cardHolderName
                      : file.cardType,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '${_t('ddd.trashedAt')}: ${_formatDate(file.trashedAt ?? file.downloadedAt)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: _t('ddd.restore'),
            icon: Icon(Icons.restore, color: scheme.primary),
            onPressed: () => _restore(appState, file),
          ),
          IconButton(
            tooltip: _t('ddd.deletePermanently'),
            icon: Icon(Icons.delete_forever, color: scheme.error),
            onPressed: () => _confirmAndDeleteForever(appState, file),
          ),
        ],
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
}
