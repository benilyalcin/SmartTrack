import 'package:flutter/material.dart';

import '../localization/localization.dart';
import '../providers/app_state.dart';

class CardSlotWarningBanner extends StatefulWidget {
  const CardSlotWarningBanner({super.key});

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
