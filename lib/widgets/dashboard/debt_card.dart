import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../models/debt.dart';
import '../../theme/app_theme.dart';
import '../common/currency_text.dart';
import '../common/status_badge.dart';

/// Card widget displaying a summary of a single [Debt].
class DebtCard extends StatelessWidget {
  final Debt debt;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const DebtCard({
    super.key,
    required this.debt,
    required this.onTap,
    required this.onDelete,
  });

  Color get _statusColor => AppTheme.statusColor(debt.status);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _statusColor.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 14),
            _buildAmounts(),
            if (!debt.isPaid) ...[
              const SizedBox(height: 10),
              _buildProgressBar(),
            ],
            const SizedBox(height: 10),
            _buildActions(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final isOverdue = debt.hasInterest &&
        debt.nextInterestDate != null &&
        debt.nextInterestDate!.isBefore(DateTime.now());

    return Row(
      children: [
        _LenderAvatar(initial: debt.avatarInitial),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      debt.lenderName,
                      style: GoogleFonts.dmSans(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (debt.hasInterest && !debt.isPaid) ...[
                    const SizedBox(width: 6),
                    Icon(
                      isOverdue
                          ? Icons.error_outline_rounded
                          : Icons.trending_up_rounded,
                      size: 14,
                      color: isOverdue ? AppTheme.error : AppTheme.accent,
                    ),
                  ],
                ],
              ),
              Text(
                DateFormat('MMM d, y').format(debt.transactionDate),
                style: GoogleFonts.dmSans(color: AppTheme.textMuted, fontSize: 12),
              ),
            ],
          ),
        ),
        if (debt.hasInterest && !debt.isPaid) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: (isOverdue ? AppTheme.error : AppTheme.accent)
                  .withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '${debt.interestRate!.toStringAsFixed(0)}%',
              style: GoogleFonts.spaceGrotesk(
                color: isOverdue ? AppTheme.error : AppTheme.accent,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
        StatusBadge(status: debt.status, compact: true),
        if (debt.reminderEnabled && !debt.isPaid) ...[
          const SizedBox(width: 6),
          Icon(
            Icons.notifications_active_rounded,
            size: 12,
            color: AppTheme.success,
          ),
        ],
      ],
    );
  }

  Widget _buildAmounts() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _AmountColumn(label: 'Borrowed', amount: debt.amount, color: AppTheme.textPrimary),
        _AmountColumn(label: 'Remaining', amount: debt.remainingBalance, color: _statusColor),
      ],
    );
  }

  Widget _buildProgressBar() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: LinearProgressIndicator(
        value: debt.progress,
        backgroundColor: AppTheme.surfaceLight,
        valueColor: AlwaysStoppedAnimation<Color>(_statusColor),
        minHeight: 4,
      ),
    );
  }

  Widget _buildActions() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        _IconAction(
          icon: Icons.delete_outline_rounded,
          color: AppTheme.error,
          onTap: onDelete,
        ),
        const SizedBox(width: 8),
        _TextAction(onTap: onTap),
      ],
    );
  }
}

// ── Private sub-widgets ────────────────────────────────────────────────────────

class _LenderAvatar extends StatelessWidget {
  final String initial;
  const _LenderAvatar({required this.initial});

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 20,
      backgroundColor: AppTheme.primary.withValues(alpha: 0.15),
      child: Text(
        initial,
        style: GoogleFonts.spaceGrotesk(
          color: AppTheme.primaryLight,
          fontWeight: FontWeight.w700,
          fontSize: 16,
        ),
      ),
    );
  }
}

class _AmountColumn extends StatelessWidget {
  final String label;
  final double amount;
  final Color color;
  const _AmountColumn({required this.label, required this.amount, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.dmSans(color: AppTheme.textMuted, fontSize: 11)),
        CurrencyText(amount: amount, color: color, fontSize: 16),
      ],
    );
  }
}

class _IconAction extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _IconAction({required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: color, size: 18),
      ),
    );
  }
}

class _TextAction extends StatelessWidget {
  final VoidCallback onTap;
  const _TextAction({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppTheme.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Text('View',
                style: GoogleFonts.dmSans(
                    color: AppTheme.primaryLight,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
            const SizedBox(width: 4),
            const Icon(Icons.arrow_forward_ios_rounded,
                color: AppTheme.primaryLight, size: 12),
          ],
        ),
      ),
    );
  }
}
