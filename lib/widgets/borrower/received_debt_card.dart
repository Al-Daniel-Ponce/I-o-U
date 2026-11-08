// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../models/received_debt.dart';
import '../../theme/app_theme.dart';
import '../common/currency_text.dart';
import '../common/status_badge.dart';

/// One row in the borrower's list of received debts.
///
/// Shows the *lender* as the primary identity (that is who can be asked for
/// updates) with the outstanding balance, mirroring the lender's [DebtCard]
/// layout so the two lists read the same.
///
/// OOP principles:
/// - Single Responsibility : layout only; all interpretation comes from
///   getters on [ReceivedDebt].
class ReceivedDebtCard extends StatelessWidget {
  final ReceivedDebt record;
  final VoidCallback? onTap;

  const ReceivedDebtCard({super.key, required this.record, this.onTap});

  @override
  Widget build(BuildContext context) {
    final statusColor = AppTheme.statusColor(record.status);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.cardBg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: statusColor.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: AppTheme.accent.withValues(alpha: 0.18),
                  child: Text(
                    record.lenderAvatarInitial,
                    style: GoogleFonts.spaceGrotesk(
                      color: AppTheme.accent,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        record.lenderDisplay,
                        style: GoogleFonts.spaceGrotesk(
                          color: AppTheme.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        DateFormat('MMM d, y').format(record.transactionDate),
                        style: GoogleFonts.dmSans(
                            color: AppTheme.textMuted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                StatusBadge(status: record.status, compact: true),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                CurrencyText(
                  amount: record.remainingBalance,
                  color: AppTheme.textPrimary,
                  fontSize: 20,
                ),
                Text(
                  record.isPaid
                      ? 'Settled'
                      : '₱${_money(record.amountPaid)} paid of ₱${_money(record.amount)}',
                  style: GoogleFonts.dmSans(
                    color: AppTheme.textMuted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            if (!record.isPaid && record.progress > 0) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: record.progress,
                  backgroundColor: AppTheme.surfaceLight,
                  valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                  minHeight: 5,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String _money(double value) =>
      NumberFormat('#,##0.00').format(value);
}
