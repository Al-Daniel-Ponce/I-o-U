// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/received_debt.dart';
import '../../theme/app_theme.dart';
import '../common/currency_text.dart';

/// Headline "what I owe" card at the top of the Borrower dashboard.
///
/// Amber gradient rather than the lender's teal, so the two modes are
/// distinguishable at a glance even before reading any label.
///
/// OOP principles:
/// - Dependency Inversion : takes an immutable [ReceivedSummary] instead of
///   querying a repository, so the widget is pure and tests feed it data.
/// - Open/Closed          : new aggregates ride along in the summary without
///   this widget changing.
class BorrowerSummaryCard extends StatelessWidget {
  final ReceivedSummary? summary;

  const BorrowerSummaryCard({super.key, this.summary});

  @override
  Widget build(BuildContext context) {
    final totalOwed = summary?.totalOwed ?? 0;
    final progress = summary?.progress ?? 0;
    final total = summary?.totalCount ?? 0;
    final paid = summary?.paidCount ?? 0;

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.accent, AppTheme.accentDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppTheme.accent.withOpacity(0.35),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTotalOwed(totalOwed),
              const Spacer(),
              _buildSettled(paid, total),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.white.withOpacity(0.25),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${(progress * 100).round()}% paid off',
                style: GoogleFonts.dmSans(
                    color: Colors.white.withOpacity(0.85), fontSize: 12),
              ),
              Text(
                total == 0 ? 'Nothing received yet' : '$total debt${total == 1 ? '' : 's'}',
                style: GoogleFonts.dmSans(
                    color: Colors.white.withOpacity(0.85), fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTotalOwed(double totalOwed) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Total Owed',
            style: GoogleFonts.dmSans(
                color: Colors.white.withOpacity(0.85), fontSize: 12)),
        const SizedBox(height: 4),
        CurrencyText(
          amount: totalOwed,
          color: Colors.white,
          fontSize: 28,
        ),
      ],
    );
  }

  Widget _buildSettled(int paid, int total) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text('Settled',
            style: GoogleFonts.dmSans(
                color: Colors.white.withOpacity(0.85), fontSize: 12)),
        const SizedBox(height: 4),
        Text(
          total == 0 ? '—' : '$paid/$total',
          style: GoogleFonts.spaceGrotesk(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}
