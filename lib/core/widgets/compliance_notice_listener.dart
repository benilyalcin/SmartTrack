import 'package:flutter/material.dart';

import '../providers/app_state.dart';

class ComplianceNoticeListener extends StatefulWidget {
  final Widget child;
  const ComplianceNoticeListener({super.key, required this.child});

  @override
  State<ComplianceNoticeListener> createState() =>
      _ComplianceNoticeListenerState();
}

class _ComplianceNoticeListenerState extends State<ComplianceNoticeListener> {
  String? _shownForId;

  @override
  Widget build(BuildContext context) {
    final appState = AppStateProvider.of(context);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _sync(context, appState),
    );
    return widget.child;
  }

  void _sync(BuildContext context, AppState appState) {
    if (!mounted) return;
    final notice = appState.pendingComplianceNotice;

    if (notice == null) {
      if (_shownForId != null) {
        ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
        _shownForId = null;
      }
      return;
    }
    if (_shownForId == notice.id) return;

    final scheme = Theme.of(context).colorScheme;
    final isWarning = notice.severity == ComplianceNoticeSeverity.warning;
    final background = isWarning
        ? scheme.errorContainer
        : scheme.secondaryContainer;
    final foreground = isWarning
        ? scheme.onErrorContainer
        : scheme.onSecondaryContainer;

    _shownForId = notice.id;
    ScaffoldMessenger.of(context).showMaterialBanner(
      MaterialBanner(
        backgroundColor: background,
        leading: Icon(
          isWarning ? Icons.warning_amber : Icons.info_outline,
          color: foreground,
        ),
        content: Text(
          notice.message,
          style: TextStyle(color: foreground, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () {
              ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
              appState.dismissComplianceNotice(notice.id);
              _shownForId = null;
            },
            child: Text(
              'Kapat',
              style: TextStyle(color: foreground, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
