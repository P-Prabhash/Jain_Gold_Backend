import 'package:flutter/material.dart';
import '../config/theme.dart';

enum ToastType { success, error, warning, info }

class AppToast {
  static void show(
    BuildContext context,
    String message, {
    ToastType type = ToastType.info,
    Duration duration = const Duration(seconds: 3),
  }) {
    final cleanMsg = message.trim();
    if (cleanMsg.isEmpty) return;

    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;

    messenger.hideCurrentSnackBar();

    Color bg;
    IconData icon;

    switch (type) {
      case ToastType.success:
        bg = AppTheme.statusSuccess;
        icon = Icons.check_circle_outline;
        break;
      case ToastType.error:
        bg = AppTheme.statusDanger;
        icon = Icons.error_outline;
        break;
      case ToastType.warning:
        bg = AppTheme.statusWarning;
        icon = Icons.warning_amber_outlined;
        break;
      case ToastType.info:
        bg = AppTheme.accentBlue;
        icon = Icons.info_outline;
        break;
    }

    messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                cleanMsg,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: bg,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        duration: duration,
      ),
    );
  }

  static void showSuccess(BuildContext context, String message) {
    show(context, message, type: ToastType.success);
  }

  static void showError(BuildContext context, String message) {
    show(context, message, type: ToastType.error);
  }

  static void showWarning(BuildContext context, String message) {
    show(context, message, type: ToastType.warning);
  }

  static void showInfo(BuildContext context, String message) {
    show(context, message, type: ToastType.info);
  }
}
