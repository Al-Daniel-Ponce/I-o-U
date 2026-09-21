import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../controllers/debt_detail_controller.dart';
import '../models/debt.dart';
import '../services/service_locator.dart';
import '../theme/app_theme.dart';
import '../widgets/common/currency_text.dart';
import '../widgets/common/status_badge.dart';
import 'add_debt_screen.dart';

/// Debt detail screen — pure view layer.
class DebtDetailScreen extends StatefulWidget {
  final Debt debt;
  const DebtDetailScreen({super.key, required this.debt});

  @override
  State<DebtDetailScreen> createState() => _DebtDetailScreenState();
}

class _DebtDetailScreenState extends State<DebtDetailScreen> {
  late final DebtDetailController _controller;

  @override
  void initState() {
    super.initState();
    _controller = DebtDetailController(ServiceLocator.instance.debtService)
      ..addListener(_onUpdate)
      ..loadData(widget.debt.id!);
    // Process missed interest on detail open
    _controller.processMissedInterest(widget.debt.id!);
  }

  void _onUpdate() => setState(() {});

  @override
  void dispose() {
    _controller
      ..removeListener(_onUpdate)
      ..dispose();
    super.dispose();
  }

  Debt get _debt => _controller.debt ?? widget.debt;
  Color get _statusColor => AppTheme.statusColor(_debt.status);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(_debt.lenderName),
        actions: [
          if (!_debt.isPaid)
            IconButton(
              icon: const Icon(Icons.edit_rounded, size: 20),
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => AddDebtScreen(existingDebt: _debt)),
                );
                _controller.loadData(_debt.id!);
              },
            ),
        ],
      ),
      body: _controller.isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primary))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildStatusCard(),
                  if (_debt.notes?.isNotEmpty == true) ...[
                    const SizedBox(height: 20),
                    _buildNotesCard(),
                  ],
                  if (!_debt.isPaid) ...[
                    const SizedBox(height: 20),
                    _buildReminderCard(),
                  ],
                  if (_debt.hasInterest) ...[
                    const SizedBox(height: 20),
                    _buildInterestInfoCard(),
                  ],
                  if (_debt.hasInterest && !_debt.isPaid) ...[
                    const SizedBox(height: 20),
                    _buildApplyInterestButton(),
                  ],
                  if (_controller.interestHistory.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    _buildInterestHistorySection(),
                  ],
                  if (!_debt.isPaid) ...[
                    const SizedBox(height: 20),
                    _buildPaymentActions(),
                  ],
                  const SizedBox(height: 20),
                  _buildPaymentHistory(),
                ],
              ),
            ),
    );
  }

  // ── Status card ────────────────────────────────────────────────────────────

  Widget _buildStatusCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _statusColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          _buildAvatarRow(),
          const SizedBox(height: 20),
          _buildAmountRow(),
          const SizedBox(height: 16),
          _buildProgressBar(),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '${(_debt.progress * 100).toStringAsFixed(1)}% settled',
              style: GoogleFonts.dmSans(
                  color: AppTheme.textMuted, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarRow() {
    return Row(
      children: [
        CircleAvatar(
          radius: 28,
          backgroundColor: AppTheme.primary.withValues(alpha: 0.15),
          child: Text(
            _debt.avatarInitial,
            style: GoogleFonts.spaceGrotesk(
                color: AppTheme.primaryLight,
                fontWeight: FontWeight.w800,
                fontSize: 22),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_debt.lenderName,
                  style: GoogleFonts.spaceGrotesk(
                      color: AppTheme.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w700)),
              Text(
                DateFormat('MMMM d, y').format(_debt.transactionDate),
                style: GoogleFonts.dmSans(
                    color: AppTheme.textMuted, fontSize: 13),
              ),
            ],
          ),
        ),
        StatusBadge(status: _debt.status),
      ],
    );
  }

  Widget _buildAmountRow() {
    return Row(
      children: [
        _AmountTile(
            label: 'Original Debt',
            amount: _debt.amount,
            color: AppTheme.textPrimary),
        _Divider(),
        _AmountTile(
            label: 'Current Balance',
            amount: _debt.remainingBalance,
            color: _statusColor),
      ],
    );
  }

  Widget _buildProgressBar() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: LinearProgressIndicator(
        value: _debt.progress,
        backgroundColor: AppTheme.surfaceLight,
        valueColor: AlwaysStoppedAnimation<Color>(_statusColor),
        minHeight: 8,
      ),
    );
  }

  // ── Interest info card ─────────────────────────────────────────────────────

  Widget _buildInterestInfoCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.accent.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.trending_up_rounded,
                  color: AppTheme.accent, size: 18),
              const SizedBox(width: 8),
              Text('Interest Details',
                  style: GoogleFonts.dmSans(
                      color: AppTheme.textSecondary,
                      fontWeight: FontWeight.w600,
                      fontSize: 13)),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${_debt.interestRate!.toStringAsFixed(1)}%',
                  style: GoogleFonts.spaceGrotesk(
                    color: AppTheme.accent,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildInfoRow(
            'Interest Type',
            _debt.interestType?.label ?? 'Simple Interest',
          ),
          _buildInfoRow(
            'Application',
            _debt.interestMode?.label ?? 'Manual',
          ),
          if (_debt.isAutomaticInterest) ...[
            _buildInfoRow('Frequency', _debt.frequencyLabel),
            if (_debt.nextInterestDate != null)
              _buildInfoRow(
                'Next Interest',
                DateFormat('MMM d, y').format(_debt.nextInterestDate!),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: GoogleFonts.dmSans(
                  color: AppTheme.textMuted, fontSize: 12)),
          Text(value,
              style: GoogleFonts.dmSans(
                  color: AppTheme.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  // ── Apply interest button ──────────────────────────────────────────────────

  Widget _buildApplyInterestButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.accent.withValues(alpha: 0.15),
          foregroundColor: AppTheme.accent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(
                color: AppTheme.accent.withValues(alpha: 0.4)),
          ),
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
        onPressed:
            _controller.isApplyingInterest ? null : _applyInterestWithConfirmation,
        icon: _controller.isApplyingInterest
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    color: AppTheme.accent, strokeWidth: 2))
            : const Icon(Icons.trending_up_rounded, size: 18),
        label: Text(
          _controller.isApplyingInterest
              ? 'Applying...'
              : 'Apply Interest Now',
          style: GoogleFonts.dmSans(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Future<void> _applyInterestWithConfirmation() async {
    final type = _debt.interestType ?? InterestType.simple;
    final rate = _debt.interestRate!;
    final isCompound = type == InterestType.compound;

    final principal = isCompound ? _debt.remainingBalance : _debt.amount;
    final interestAmount = principal * rate / 100;
    final newBalance = _debt.remainingBalance + interestAmount;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardBg,
        title: Text('Apply Interest',
            style: GoogleFonts.spaceGrotesk(color: AppTheme.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDialogRow('Current Balance',
                '₱${NumberFormat("#,##0.00").format(_debt.remainingBalance)}'),
            _buildDialogRow('Interest Rate', '${rate.toStringAsFixed(1)}%'),
            _buildDialogRow(
                'Based on',
                isCompound ? 'Current balance' : 'Original amount (₱${NumberFormat("#,##0.00").format(_debt.amount)})'),
            const Divider(color: AppTheme.textMuted),
            _buildDialogRow(
                'Interest',
                '+₱${NumberFormat("#,##0.00").format(interestAmount)}',
                color: AppTheme.accent),
            _buildDialogRow(
                'New Balance',
                '₱${NumberFormat("#,##0.00").format(newBalance)}',
                bold: true),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
                style: GoogleFonts.dmSans(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accent),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Confirm',
                style: GoogleFonts.dmSans(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final amount = await _controller.applyInterest();
      if (amount > 0 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Interest of ₱${NumberFormat("#,##0.00").format(amount)} applied',
              style: GoogleFonts.dmSans(color: Colors.white),
            ),
            backgroundColor: AppTheme.accent,
          ),
        );
      }
    }
  }

  Widget _buildDialogRow(String label, String value,
      {Color? color, bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: GoogleFonts.dmSans(
                  color: AppTheme.textMuted, fontSize: 13)),
          Text(value,
              style: GoogleFonts.dmSans(
                  color: color ?? AppTheme.textPrimary,
                  fontSize: 13,
                  fontWeight: bold ? FontWeight.w700 : FontWeight.w500)),
        ],
      ),
    );
  }

  // ── Interest history ───────────────────────────────────────────────────────

  Widget _buildInterestHistorySection() {
    final history = _controller.interestHistory;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Interest History',
            style: GoogleFonts.dmSans(
                color: AppTheme.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 10),
        ...history.map((t) => _InterestTransactionItem(transaction: t)),
      ],
    );
  }

  // ── Notes card ─────────────────────────────────────────────────────────────

  Widget _buildNotesCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.notes_rounded,
                  color: AppTheme.textMuted, size: 16),
              const SizedBox(width: 8),
              Text('Notes',
                  style: GoogleFonts.dmSans(
                      color: AppTheme.textSecondary,
                      fontWeight: FontWeight.w600,
                      fontSize: 13)),
            ],
          ),
          const SizedBox(height: 8),
          Text(_debt.notes ?? '',
              style: GoogleFonts.dmSans(
                  color: AppTheme.textPrimary, fontSize: 14, height: 1.5)),
        ],
      ),
    );
  }

  // ── Reminder card ──────────────────────────────────────────────────────────

  Widget _buildReminderCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _debt.reminderEnabled
              ? AppTheme.success.withValues(alpha: 0.3)
              : AppTheme.textMuted.withValues(alpha: 0.15),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.notifications_active_rounded,
                  color: _debt.reminderEnabled
                      ? AppTheme.success
                      : AppTheme.textMuted,
                  size: 18),
              const SizedBox(width: 8),
              Text('Reminder',
                  style: GoogleFonts.dmSans(
                      color: AppTheme.textSecondary,
                      fontWeight: FontWeight.w600,
                      fontSize: 13)),
              const Spacer(),
              Switch.adaptive(
                value: _debt.reminderEnabled,
                onChanged: (v) => _controller.toggleReminder(v),
                activeTrackColor: AppTheme.success.withValues(alpha: 0.3),
              ),
            ],
          ),
          if (_debt.reminderEnabled) ...[
            const SizedBox(height: 12),
            _buildReminderInfoRow(
              'First reminder',
              _debt.reminderStartDate != null
                  ? DateFormat('MMM d, y').format(_debt.reminderStartDate!)
                  : 'Not set',
            ),
            _buildReminderInfoRow(
              'Repeat',
              _debt.reminderFrequencyLabel,
            ),
            if (_debt.nextReminderDate != null)
              _buildReminderInfoRow(
                'Next notification',
                DateFormat('MMM d, y').format(_debt.nextReminderDate!),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildReminderInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: GoogleFonts.dmSans(
                  color: AppTheme.textMuted, fontSize: 12)),
          Text(value,
              style: GoogleFonts.dmSans(
                  color: AppTheme.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  // ── Payment actions ────────────────────────────────────────────────────────

  Widget _buildPaymentActions() {
    return Row(
      children: [
        Expanded(
          child: _ActionButton(
            label: 'Partial Payment',
            icon: Icons.payments_outlined,
            color: AppTheme.partialColor,
            onTap: _showPaymentDialog,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _ActionButton(
            label: 'Mark as Fully Paid',
            icon: Icons.check_circle_outline_rounded,
            color: AppTheme.paidColor,
            onTap: _markFullyPaid,
          ),
        ),
      ],
    );
  }

  Future<void> _markFullyPaid() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardBg,
        title: Text('Mark as Fully Paid',
            style: GoogleFonts.spaceGrotesk(color: AppTheme.textPrimary)),
        content: Text(
          'Record a full payment of ₱${NumberFormat("#,##0.00").format(_debt.remainingBalance)}?',
          style: GoogleFonts.dmSans(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
                style: GoogleFonts.dmSans(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _controller.recordPayment(
        amount: _debt.remainingBalance,
        note: 'Full payment',
      );
    }
  }

  Future<void> _showPaymentDialog() async {
    final formKey = GlobalKey<FormState>();
    final amountCtrl = TextEditingController();
    final noteCtrl = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardBg,
        title: Text('Partial Payment',
            style: GoogleFonts.spaceGrotesk(color: AppTheme.textPrimary)),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: amountCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))
                ],
                autofocus: true,
                style: GoogleFonts.spaceGrotesk(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 16),
                decoration:
                    const InputDecoration(labelText: 'Payment Amount (₱)'),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Enter an amount';
                  final amt = double.tryParse(v);
                  if (amt == null || amt <= 0) return 'Enter a valid amount';
                  if (amt > _debt.remainingBalance) {
                    return 'Payment cannot exceed balance';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: noteCtrl,
                style: GoogleFonts.dmSans(color: AppTheme.textPrimary),
                decoration: const InputDecoration(
                    labelText: 'Note (optional)',
                    hintText: 'e.g. Cash payment'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel',
                style: GoogleFonts.dmSans(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            style:
                ElevatedButton.styleFrom(backgroundColor: AppTheme.partialColor),
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              final amount = double.parse(amountCtrl.text);
              Navigator.pop(ctx);
              await _controller.recordPayment(
                amount: amount,
                note: noteCtrl.text.trim().isEmpty
                    ? null
                    : noteCtrl.text.trim(),
              );
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Payment of ₱${NumberFormat("#,##0.00").format(amount)} recorded!',
                      style: GoogleFonts.dmSans(color: Colors.white),
                    ),
                    backgroundColor: AppTheme.paidColor,
                  ),
                );
              }
            },
            child: Text('Partial Payment',
                style: GoogleFonts.dmSans(
                    color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  // ── Payment history ────────────────────────────────────────────────────────

  Widget _buildPaymentHistory() {
    final payments = _controller.payments;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Payment History',
            style: GoogleFonts.dmSans(
                color: AppTheme.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 10),
        if (payments.isEmpty)
          _EmptyPayments()
        else
          ...payments.map((p) => _PaymentItem(payment: p)),
      ],
    );
  }
}

// ── Private sub-widgets ────────────────────────────────────────────────────────

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 40,
      color: AppTheme.textMuted.withValues(alpha: 0.2),
      margin: const EdgeInsets.symmetric(horizontal: 16),
    );
  }
}

class _AmountTile extends StatelessWidget {
  final String label;
  final double amount;
  final Color color;
  const _AmountTile(
      {required this.label, required this.amount, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(label,
              style: GoogleFonts.dmSans(
                  color: AppTheme.textMuted, fontSize: 10),
              textAlign: TextAlign.center),
          const SizedBox(height: 4),
          CurrencyText(amount: amount, color: color, fontSize: 13),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _ActionButton(
      {required this.label,
      required this.icon,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 6),
            Text(label,
                style: GoogleFonts.dmSans(
                    color: color,
                    fontWeight: FontWeight.w600,
                    fontSize: 13),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _EmptyPayments extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.1)),
      ),
      child: Center(
        child: Text('No payments recorded yet',
            style: GoogleFonts.dmSans(
                color: AppTheme.textMuted, fontSize: 13)),
      ),
    );
  }
}

class _PaymentItem extends StatelessWidget {
  final PaymentHistory payment;
  const _PaymentItem({required this.payment});

  @override
  Widget build(BuildContext context) {
    final accentColor = AppTheme.paidColor;
    final icon = Icons.check_rounded;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accentColor.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: accentColor, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  payment.displayNote,
                  style: GoogleFonts.dmSans(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w500,
                      fontSize: 14),
                ),
                Text(
                  DateFormat('MMM d, y • h:mm a')
                      .format(payment.paymentDate),
                  style: GoogleFonts.dmSans(
                      color: AppTheme.textMuted, fontSize: 12),
                ),
              ],
            ),
          ),
          CurrencyText(
            amount: payment.paymentAmount.abs(),
            color: accentColor,
          ),
        ],
      ),
    );
  }
}

class _InterestTransactionItem extends StatelessWidget {
  final InterestTransaction transaction;
  const _InterestTransactionItem({required this.transaction});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(14),
        border:
            Border.all(color: AppTheme.accent.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppTheme.accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.trending_up_rounded,
                    color: AppTheme.accent, size: 14),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      transaction.isAutomatic
                          ? 'Automatic Interest'
                          : 'Manual Interest',
                      style: GoogleFonts.dmSans(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w500,
                          fontSize: 14),
                    ),
                    Text(
                      DateFormat('MMM d, y • h:mm a')
                          .format(transaction.appliedAt),
                      style: GoogleFonts.dmSans(
                          color: AppTheme.textMuted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              CurrencyText(
                amount: transaction.interestAmount,
                color: AppTheme.accent,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.surfaceLight.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildDetailChip(
                    'Rate', '${transaction.interestRate.toStringAsFixed(1)}%'),
                _buildDetailChip(
                    'Before',
                    '₱${NumberFormat("#,##0.00").format(transaction.balanceBefore)}'),
                _buildDetailChip(
                    'After',
                    '₱${NumberFormat("#,##0.00").format(transaction.balanceAfter)}'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailChip(String label, String value) {
    return Column(
      children: [
        Text(label,
            style:
                GoogleFonts.dmSans(color: AppTheme.textMuted, fontSize: 10)),
        const SizedBox(height: 2),
        Text(value,
            style: GoogleFonts.spaceGrotesk(
                color: AppTheme.textPrimary,
                fontSize: 11,
                fontWeight: FontWeight.w600)),
      ],
    );
  }
}
