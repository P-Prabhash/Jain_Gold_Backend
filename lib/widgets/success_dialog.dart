// lib/widgets/success_dialog.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config/theme.dart';

class SuccessDialog extends StatelessWidget {
  final String title;
  final String message;
  final String okLabel;
  final VoidCallback? onOk;
  final String? nextLabel;
  final VoidCallback? onNext;
  final String? printLabel;
  final VoidCallback? onPrint;

  const SuccessDialog({
    super.key,
    required this.title,
    required this.message,
    this.okLabel = 'OK',
    this.onOk,
    this.nextLabel,
    this.onNext,
    this.printLabel,
    this.onPrint,
  });

  static Future<void> show({
    required BuildContext context,
    required String title,
    required String message,
    String okLabel = 'OK',
    VoidCallback? onOk,
    String? nextLabel,
    VoidCallback? onNext,
    String? printLabel,
    VoidCallback? onPrint,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => SuccessDialog(
        title: title,
        message: message,
        okLabel: okLabel,
        onOk: onOk,
        nextLabel: nextLabel,
        onNext: onNext,
        printLabel: printLabel,
        onPrint: onPrint,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasNext = onNext != null;
    final hasPrint = onPrint != null;

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      elevation: 10,
      backgroundColor: Colors.white,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 440),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: const Color(0xFF065F46).withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_rounded,
                color: Color(0xFF065F46),
                size: 36,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.darkNavy,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                color: AppTheme.slateGray,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      if (onOk != null) onOk!();
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.darkNavy,
                      side: const BorderSide(color: AppTheme.silverBorder),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      okLabel,
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                if (hasNext) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop();
                        if (onNext != null) onNext!();
                      },
                      icon: const Icon(Icons.arrow_forward, size: 18),
                      label: Text(
                        nextLabel ?? 'Next',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.goldDark,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ],
                if (hasPrint) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop();
                        if (onPrint != null) onPrint!();
                      },
                      icon: const Icon(Icons.print, size: 18),
                      label: Text(
                        printLabel ?? 'Print Receipt',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.darkNavy,
                        foregroundColor: AppTheme.goldPrimary,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
