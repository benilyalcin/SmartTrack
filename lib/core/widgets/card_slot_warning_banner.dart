import 'package:flutter/material.dart';

import '../localization/localization.dart';
import '../providers/app_state.dart';

class CardSlotWarningBanner extends StatefulWidget {
  /// When true, renders a slim single-line strip instead of the full
  /// banner. Used on screens with tight vertical space (e.g. the
  /// landscape driver-mode cockpit), where the full-height banner can push
  /// the rest of the layout into overflow.
  final bool compact;

  const CardSlotWarningBanner({super.key, this.compact = false});

  @override
  State<CardSlotWarningBanner> createState() => _CardSlotWarningBannerState();
}

class _CardSlotWarningBannerState extends State<CardSlotWarningBanner> {
  bool _dismissed = false;
  bool _wasEmpty = false;

  @override
  Widget build(BuildContext context) {
    final appState = AppStateProvider.of(context);

    final slot1Empty =
        appState.isBluetoothConnected &&
        appState.tachographLiveData.cardSlot1 == 0;
    final slot2Empty =
        appState.isBluetoothConnected &&
        appState.tachographLiveData.cardSlot2 == 0;
    final anyEmpty = slot1Empty || slot2Empty;

    if (!anyEmpty) {
      _wasEmpty = false;
      _dismissed = false;
      return const SizedBox.shrink();
    }
    if (!_wasEmpty) {
      _dismissed = false;
    }
    _wasEmpty = true;
    if (_dismissed) return const SizedBox.shrink();

    final lang = appState.selectedLanguage;
    final scheme = Theme.of(context).colorScheme;
    final slotKey = slot1Empty && slot2Empty
        ? 'cardSlot.noCardBoth'
        : (slot1Empty ? 'cardSlot.noCardSlot1' : 'cardSlot.noCardSlot2');

    if (widget.compact) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: scheme.secondaryContainer,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Icon(
                Icons.credit_card_off,
                color: scheme.onSecondaryContainer,
                size: 16,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${AppLocalizations.getText(lang, slotKey)} '
                  '${AppLocalizations.getText(lang, 'cardSlot.ambiguityWarning')}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: scheme.onSecondaryContainer,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => setState(() => _dismissed = true),
                child: Padding(
                  padding: const EdgeInsets.all(2),
                  child: Icon(
                    Icons.close,
                    size: 16,
                    color: scheme.onSecondaryContainer,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: scheme.secondaryContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(Icons.credit_card_off, color: scheme.onSecondaryContainer),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '${AppLocalizations.getText(lang, slotKey)} '
                '${AppLocalizations.getText(lang, 'cardSlot.ambiguityWarning')}',
                style: TextStyle(
                  color: scheme.onSecondaryContainer,
                  fontSize: 13,
                ),
              ),
            ),
            const SizedBox(width: 8),
            InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => setState(() => _dismissed = true),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(
                  Icons.close,
                  size: 18,
                  color: scheme.onSecondaryContainer,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
