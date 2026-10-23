// lib/widgets/quick_actions_bar.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config/theme.dart';

class QuickActionItem {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool isPrimary;

  QuickActionItem({
    required this.label,
    required this.icon,
    required this.onTap,
    this.isPrimary = false,
  });
}

class QuickActionsBar extends StatelessWidget {
  final List<QuickActionItem> actions;

  const QuickActionsBar({super.key, required this.actions});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.silverBorder, width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bolt, size: 18, color: AppTheme.goldDark),
              const SizedBox(width: 6),
              Text(
                'QUICK ACTIONS',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.darkNavy,
                  letterSpacing: 0.6,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: actions.map((act) {
              return Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: act.onTap,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: act.isPrimary ? AppTheme.goldLight.withValues(alpha: 0.4) : AppTheme.silverLight,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: act.isPrimary ? AppTheme.goldPrimary : AppTheme.silverBorder,
                        width: act.isPrimary ? 1.2 : 0.8,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          act.icon,
                          size: 16,
                          color: act.isPrimary ? AppTheme.goldDark : AppTheme.darkNavy,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          act.label,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: act.isPrimary ? FontWeight.w700 : FontWeight.w600,
                            color: act.isPrimary ? AppTheme.darkNavy : AppTheme.darkNavy,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
