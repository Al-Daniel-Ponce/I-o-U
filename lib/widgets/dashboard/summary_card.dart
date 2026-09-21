// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/debt.dart';
import '../../theme/app_theme.dart';
import '../common/currency_text.dart';

/// Displays the overall borrowed / remaining summary at the top of the Dashboard.
class SummaryCard extends StatelessWidget {
  final DebtSummary summary;

  const SummaryCard({super.key, required this.summary});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.primary, AppTheme.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTotalsRow(),
          const SizedBox(height: 16),
          _buildProgressBar(),
          const SizedBox(height: 8),
          _buildProgressFooter(),
        ],
      ),
    );
  }

  Widget _buildTotalsRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTotalBorrowed(),
        const Spacer(),
        _buildTotalRemaining(),
      ],
    );
  }

  Widget _buildTotalBorrowed() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Total Borrowed',
            style: GoogleFonts.dmSans(
                color: Colors.white.withOpacity(0.75), fontSize: 12)),
        const SizedBox(height: 4),
        CurrencyText(
          amount: summary.totalBorrowed,
          color: Colors.white,
          fontSize: 28,
        ),
      ],
    );
  }

  Widget _buildTotalRemaining() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text('Remaining',
            style: GoogleFonts.dmSans(
                color: Colors.white.withOpacity(0.75), fontSize: 12)),
        const SizedBox(height: 4),
        CurrencyText(
          amount: summary.totalRemaining,
          color: AppTheme.accent,
          fontSize: 22,
        ),
      ],
    );
  }

  Widget _buildProgressBar() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: LinearProgressIndicator(
        value: summary.overallProgress,
        backgroundColor: Colors.white.withOpacity(0.2),
        valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.accent),
        minHeight: 6,
      ),
    );
  }

  Widget _buildProgressFooter() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          '${(summary.overallProgress * 100).toStringAsFixed(0)}% paid off',
          style: GoogleFonts.dmSans(
              color: Colors.white.withOpacity(0.7), fontSize: 12),
        ),
        _StatusCountRow(summary: summary),
      ],
    );
  }
}

class _StatusCountRow extends StatelessWidget {
  final DebtSummary summary;
  const _StatusCountRow({required this.summary});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _CountChip(count: summary.unpaidCount, color: AppTheme.unpaidColor),
        const SizedBox(width: 6),
        _CountChip(count: summary.partialCount, color: AppTheme.partialColor),
        const SizedBox(width: 6),
        _CountChip(count: summary.paidCount, color: AppTheme.paidColor),
      ],
    );
  }
}

class _CountChip extends StatelessWidget {
  final int count;
  final Color color;
  const _CountChip({required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$count',
        style: GoogleFonts.spaceGrotesk(
            color: color, fontSize: 12, fontWeight: FontWeight.w700),
      ),
    );
  }
}