import 'package:flutter/material.dart';

enum AppSnackBarType { success, error, info }

void showAppSnackBar(
  BuildContext context,
  String message, {
  AppSnackBarType type = AppSnackBarType.info,
}) {
  final scheme = Theme.of(context).colorScheme;
  final Color bg;
  final Color fg;
  final IconData icon;
  switch (type) {
    case AppSnackBarType.success:
      bg = scheme.primary;
      fg = scheme.onPrimary;
      icon = Icons.check_circle_outline;
      break;
    case AppSnackBarType.error:
      bg = scheme.errorContainer;
      fg = scheme.onErrorContainer;
      icon = Icons.error_outline;
      break;
    case AppSnackBarType.info:
      bg = scheme.secondaryContainer;
      fg = scheme.onSecondaryContainer;
      icon = Icons.info_outline;
      break;
  }

  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: bg,
        elevation: 3,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: Duration(seconds: type == AppSnackBarType.error ? 5 : 3),
        content: Row(
          children: [
            Icon(icon, color: fg, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: TextStyle(color: fg, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
}
