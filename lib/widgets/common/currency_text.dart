import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

/// Renders a Philippine-peso amount using SpaceGrotesk.
///
/// OOP principle: DRY (Don't Repeat Yourself) — every currency display in the
/// app delegates here, so the format is consistent and only defined once.
class CurrencyText extends StatelessWidget {
  final double amount;
  final Color color;
  final double fontSize;
  final FontWeight fontWeight;

  static final _fmt = NumberFormat('#,##0.00');

  const CurrencyText({
    super.key,
    required this.amount,
    required this.color,
    this.fontSize = 15,
    this.fontWeight = FontWeight.w700,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      '₱${_fmt.format(amount)}',
      style: GoogleFonts.spaceGrotesk(
        color: color,
        fontSize: fontSize,
        fontWeight: fontWeight,
      ),
    );
  }
}