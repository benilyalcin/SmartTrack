import 'package:flutter/material.dart';

import '../../core/localization/localization.dart';
import '../../core/providers/app_state.dart';

Future<void> showDriverIdentityDialog(BuildContext context) {
  return showDialog(
    context: context,
    builder: (_) => const DriverIdentityDialog(),
  );
}

class DriverIdentityDialog extends StatefulWidget {
  const DriverIdentityDialog({super.key});

  @override
  State<DriverIdentityDialog> createState() => _DriverIdentityDialogState();
}

class _DriverIdentityDialogState extends State<DriverIdentityDialog> {
  bool _showDriver2 = false;

  String _t(BuildContext context, String key) {
    return AppLocalizations.getText(
      AppStateProvider.of(context).selectedLanguage,
      key,
    );
  }

  String _fmtDate(DateTime? dt) {
    if (dt == null) return '-';
    return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final appState = AppStateProvider.of(context);
    final live = appState.tachographLiveData;
    final scheme = Theme.of(context).colorScheme;

    final name = _showDriver2 ? live.driver2Name : live.driver1Name;
    final issuingState = _showDriver2
        ? live.driver2IssuingState
        : live.driver1IssuingState;
    final cardNumber = _showDriver2
        ? live.driver2CardNumber
        : live.driver1CardNumber;
    final language = _showDriver2
        ? live.driver2PreferredLanguage
        : live.driver1PreferredLanguage;
    final expiryDate = _showDriver2
        ? live.driver2CardExpiryDate
        : live.driver1CardExpiryDate;
    final nextDownloadDate = _showDriver2
        ? live.driver2CardNextMandatoryDownloadDate
        : live.driver1CardNextMandatoryDownloadDate;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(Icons.badge, color: scheme.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _t(context, 'driverIdentity.title'),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: scheme.onSurface,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _tabButton(
                        context,
                        label: _t(context, 'dashboard.driver1Tab'),
                        selected: !_showDriver2,
                        onTap: () => setState(() => _showDriver2 = false),
                      ),
                    ),
                    Expanded(
                      child: _tabButton(
                        context,
                        label: _t(context, 'dashboard.driver2Tab'),
                        selected: _showDriver2,
                        onTap: () => setState(() => _showDriver2 = true),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              _row(
                context,
                _t(context, 'driverIdentity.name'),
                name.isEmpty ? '-' : name,
              ),
              const Divider(height: 1),
              _row(
                context,
                _t(context, 'driverIdentity.issuingState'),
                issuingState.isEmpty ? '-' : issuingState,
              ),
              const Divider(height: 1),
              _row(
                context,
                _t(context, 'driverIdentity.cardNumber'),
                cardNumber.isEmpty ? '-' : cardNumber,
              ),
              const Divider(height: 1),
              _row(
                context,
                _t(context, 'driverIdentity.language'),
                language.isEmpty ? '-' : language,
              ),
              const Divider(height: 1),
              _row(
                context,
                _t(context, 'driverIdentity.expiryDate'),
                _fmtDate(expiryDate),
              ),
              const Divider(height: 1),
              _row(
                context,
                _t(context, 'driverIdentity.nextDownloadDate'),
                _fmtDate(nextDownloadDate),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tabButton(
    BuildContext context, {
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: selected ? scheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: selected ? scheme.onPrimary : scheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }

  Widget _row(BuildContext context, String label, String value) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 5,
            child: Text(
              label,
              style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 6,
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: scheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
