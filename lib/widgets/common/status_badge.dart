// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/debt.dart';
import '../../theme/app_theme.dart';

/// Displays a colour-coded badge for a [DebtStatus].
///
/// OOP principle: Encapsulation — the colour/label mapping stays inside this
/// widget; no other file needs to know how statuses translate to colours.
class StatusBadge extends StatelessWidget {
  final DebtStatus status;
  final bool compact;

  const StatusBadge({super.key, required this.status, this.compact = false});

  Color get _color {
    switch (status) {
      case DebtStatus.paid:
        return AppTheme.paidColor;
      case DebtStatus.partial:
        return AppTheme.partialColor;
      case DebtStatus.unpaid:
        return AppTheme.unpaidColor;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: _color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        status.label.toUpperCase(),
        style: GoogleFonts.dmSans(
          color: _color,
          fontSize: compact ? 11 : 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}