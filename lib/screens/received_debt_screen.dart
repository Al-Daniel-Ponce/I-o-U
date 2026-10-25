import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../models/debt.dart';
import '../models/received_debt.dart';
import '../theme/app_theme.dart';
import '../widgets/common/currency_text.dart';
import '../widgets/common/status_badge.dart';

/// Read-only view of a debt received by scanning a lender's QR code.
///
/// Deliberately *not* [DebtDetailScreen] with a flag: that screen owns edit,
/// delete, payment and reminder actions, none of which make sense for a copy
/// this device cannot change. A separate type makes it impossible to hand a
/// borrowed record to the payment flows by accident.
///
/// OOP principles:
/// - Single Responsibility : display only — no controller, no mutations.
/// - Liskov Substitution    : shares presentation pieces (status badge,
///   currency text) with the detail screen without inheriting behaviour it
///   must not offer.
class ReceivedDebtScreen extends StatelessWidget {
  final ReceivedDebt record;

  const ReceivedDebtScreen({super.key, required this.record});

  Color get _statusColor => AppTheme.statusColor(record.status);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(record.lenderDisplay),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatusCard(),
            const SizedBox(height: 20),
            _buildLenderCard(),
            const SizedBox(height: 20),
            _buildDetailsCard(),
            if (record.notes?.isNotEmpty == true) ...[
              const SizedBox(height: 20),
              _buildNotesCard(),
            ],
            if (record.hasInterest) ...[
              const SizedBox(height: 20),
              _buildInterestCard(),
            ],
            const SizedBox(height: 20),
            _buildReadOnlyNotice(),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ── Sections ───────────────────────────────────────────────────────────────

  Widget _buildStatusCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _statusColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                record.isPaid ? 'Settled' : 'You owe',
                style: GoogleFonts.dmSans(
                  color: AppTheme.textMuted,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              StatusBadge(status: record.status),
            ],
          ),
          const SizedBox(height: 8),
          CurrencyText(
            amount: record.remainingBalance,
            color: AppTheme.textPrimary,
            fontSize: 34,
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: record.progress,
              backgroundColor: AppTheme.surfaceLight,
              valueColor: AlwaysStoppedAnimation<Color>(_statusColor),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${(record.progress * 100).round()}% paid · ₱${_money(record.amountPaid)} of ₱${_money(record.amount)}',
            style: GoogleFonts.dmSans(color: AppTheme.textMuted, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildLenderCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: AppTheme.primary.withValues(alpha: 0.2),
            child: Text(
              record.lenderAvatarInitial,
              style: GoogleFonts.spaceGrotesk(
                color: AppTheme.primaryLight,
                fontWeight: FontWeight.w700,
                fontSize: 18,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  record.lenderDisplay,
                  style: GoogleFonts.spaceGrotesk(
                    color: AppTheme.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Lent you this amount',
                  style: GoogleFonts.dmSans(
                    color: AppTheme.textMuted,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          StatusBadge(status: record.status, compact: true),
        ],
      ),
    );
  }

  Widget _buildDetailsCard() {
    final dateFormat = DateFormat('MMM d, y');
    return _card(
      title: 'Details',
      child: Column(
        children: [
          _row('Amount', '₱${_money(record.amount)}'),
          _row('Paid so far', '₱${_money(record.amountPaid)}'),
          _row('Date', dateFormat.format(record.transactionDate)),
          _row('Received', dateFormat.format(record.receivedAt)),
          _row('Lender record', record.borrowerDisplay),
        ],
      ),
    );
  }

  Widget _buildNotesCard() => _card(
        title: 'Notes',
        child: Text(
          record.notes!,
          style: GoogleFonts.dmSans(
            color: AppTheme.textSecondary,
            fontSize: 14,
            height: 1.5,
          ),
        ),
      );

  Widget _buildInterestCard() => _card(
        title: 'Interest (set by lender)',
        child: Column(
          children: [
            _row('Rate', '${_trim(record.interestRate!)}%'),
            _row('Type', record.interestType!.label),
            if (record.interestMode != null)
              _row(
                'Mode',
                record.interestMode == InterestMode.automatic
                    ? 'Automatic'
                    : 'Manual',
              ),
            if (record.interestFrequencyDays != null)
              _row('Every', '${record.interestFrequencyDays} day(s)'),
          ],
        ),
      );

  Widget _buildReadOnlyNotice() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.1)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.visibility_rounded,
              color: AppTheme.textMuted, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Read-only copy. ${record.lenderDisplay} keeps the original '
              'record and sends you updates by sharing the code again.',
              style: GoogleFonts.dmSans(
                color: AppTheme.textMuted,
                fontSize: 12.5,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  Widget _card({required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: GoogleFonts.dmSans(
              color: AppTheme.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: GoogleFonts.dmSans(
                  color: AppTheme.textMuted, fontSize: 14)),
          Text(
            value,
            style: GoogleFonts.dmSans(
              color: AppTheme.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  static String _money(double value) =>
      NumberFormat('#,##0.00').format(value);

  static String _trim(double value) =>
      value == value.roundToDouble() ? value.toStringAsFixed(0) : '$value';
}
