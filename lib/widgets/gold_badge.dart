// lib/widgets/gold_badge.dart

import 'package:flutter/material.dart';
import '../config/theme.dart';

class GoldBadge extends StatelessWidget {
  final String status;
  final double fontSize;

  const GoldBadge({super.key, required this.status, this.fontSize = 11});

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    Color border;

    switch (status.toUpperCase()) {
      case 'ACTIVE':
      case 'AVAILABLE':
      case 'PAID IN FULL':
        bg = const Color(0xFFECFDF5);
        fg = const Color(0xFF065F46);
        border = const Color(0xFFA7F3D0);
        break;
      case 'PLEDGED':
      case 'PARTIALLY_PAID':
      case 'PARTIALLY_RELEASED':
      case 'PARTIAL':
        bg = const Color(0xFFFFFBEB);
        fg = const Color(0xFF92400E);
        border = const Color(0xFFFDE68A);
        break;
      case 'RELEASED':
      case 'CLOSED':
        bg = const Color(0xFFF1F5F9);
        fg = const Color(0xFF475569);
        border = const Color(0xFFCBD5E1);
        break;
      case 'NEW_LOAN':
        bg = const Color(0xFFEFF6FF);
        fg = const Color(0xFF1E40AF);
        border = const Color(0xFFBFDBFE);
        break;
      case 'EXISTING_LOAN':
        bg = const Color(0xFFFAF5FF);
        fg = const Color(0xFF6B21A8);
        border = const Color(0xFFE9D5FF);
        break;
      case 'ADDITIONAL_LOAN':
        bg = const Color(0xFFFFF7ED);
        fg = const Color(0xFF9A3412);
        border = const Color(0xFFFED7AA);
        break;
      default:
        bg = AppTheme.silverLight;
        fg = AppTheme.darkNavy;
        border = AppTheme.silverBorder;
    }

    final displayText = status.replaceAll('_', ' ');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: border, width: 0.8),
      ),
      child: Text(
        displayText,
        softWrap: false,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: fg,
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}
