import 'package:flutter/material.dart';

class ContinuousDrivingLimitDialog extends StatelessWidget {
  final String message;
  final VoidCallback onAcknowledge;

  const ContinuousDrivingLimitDialog({
    super.key,
    required this.message,
    required this.onAcknowledge,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return PopScope(
      canPop: false,
      child: AlertDialog(
        icon: Icon(Icons.warning_amber_rounded, color: scheme.error, size: 36),
        title: const Text('Kesintisiz Sürüş Süresi Aşıldı'),
        content: Text(message),
        actions: [
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () {
                onAcknowledge();
                Navigator.of(context).pop();
              },
              style: FilledButton.styleFrom(backgroundColor: scheme.error),
              child: const Text('Anladım'),
            ),
          ),
        ],
      ),
    );
  }
}
