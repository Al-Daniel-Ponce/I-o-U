// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/borrower_group.dart';
import '../../theme/app_theme.dart';
import '../common/currency_text.dart';

/// One person in the lender's Borrowers list: their aggregate outstanding
/// balance with a tap-through back to that person's debts.
///
/// OOP principles:
/// - Single Responsibility : layout only; every number shown comes from a
///   getter on [BorrowerGroup].
/// - Information Expert    : the group computes its own totals, so this row
///   can never disagree with another surface using the same model.
class BorrowerRow extends StatelessWidget {
  final BorrowerGroup group;
  final VoidCallback? onTap;

  const BorrowerRow({super.key, required this.group, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.cardBg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppTheme.primary.withValues(alpha: 0.15)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: AppTheme.primary.withValues(alpha: 0.18),
                  child: Text(
                    group.avatarInitial,
                    style: GoogleFonts.spaceGrotesk(
                      color: AppTheme.primaryLight,
                      fontWeight: FontWeight.w700,
                      fontSize: 17,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        group.displayName,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.spaceGrotesk(
                          color: AppTheme.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${group.count} debt${group.count == 1 ? '' : 's'}'
                        '${group.openCount > 0 ? ' · ${group.openCount} open' : ' · all settled'}',
                        style: GoogleFonts.dmSans(
                            color: AppTheme.textMuted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    CurrencyText(
                      amount: group.totalRemaining,
                      color: AppTheme.textPrimary,
                      fontSize: 17,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'outstanding',
                      style: GoogleFonts.dmSans(
                          color: AppTheme.textMuted, fontSize: 11),
                    ),
                  ],
                ),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right_rounded,
                    color: AppTheme.textMuted, size: 22),
              ],
            ),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: group.progress,
                backgroundColor: AppTheme.surfaceLight,
                valueColor: AlwaysStoppedAnimation<Color>(
                  group.progress >= 1 ? AppTheme.success : AppTheme.primary,
                ),
                minHeight: 5,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${(group.progress * 100).round()}% settled',
              style: GoogleFonts.dmSans(color: AppTheme.textMuted, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}
