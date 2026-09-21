// ignore_for_file: prefer_const_constructors

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../controllers/add_debt_controller.dart';
import '../models/debt.dart';
import '../services/service_locator.dart';
import '../theme/app_theme.dart';
import '../widgets/common/section_label.dart';

/// Add / Edit Debt screen — pure view layer.
class AddDebtScreen extends StatefulWidget {
  final Debt? existingDebt;
  const AddDebtScreen({super.key, this.existingDebt});

  @override
  State<AddDebtScreen> createState() => _AddDebtScreenState();
}

class _AddDebtScreenState extends State<AddDebtScreen> {
  final _formKey = GlobalKey<FormState>();
  final _lenderController = TextEditingController();
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();
  final _interestRateController = TextEditingController();
  final _customFrequencyController = TextEditingController();
  final _customReminderFrequencyController = TextEditingController();

  late final AddDebtController _controller;
  DateTime _selectedDate = DateTime.now();
  bool _hasInterest = false;
  InterestType _interestType = InterestType.simple;
  InterestMode _interestMode = InterestMode.manual;
  int _selectedFrequencyDays = 2;
  bool _isCustomFrequency = false;
  DateTime? _interestStartDate;

  // Reminder state
  bool _hasReminder = true;
  DateTime? _reminderStartDate;
  int _reminderIntervalDays = 1;
  bool _isCustomReminderFrequency = false;

  @override
  void initState() {
    super.initState();
    _controller = AddDebtController(
      ServiceLocator.instance.debtService,
      existingDebt: widget.existingDebt,
    )..addListener(_onControllerUpdate);

    if (widget.existingDebt != null) {
      final d = widget.existingDebt!;
      _lenderController.text = d.lenderName;
      _amountController.text = d.amount.toStringAsFixed(2);
      _notesController.text = d.notes ?? '';
      _selectedDate = d.transactionDate;
      if (d.hasInterest) {
        _hasInterest = true;
        _interestRateController.text = d.interestRate!.toStringAsFixed(1);
        _interestType = d.interestType ?? InterestType.simple;
        _interestMode = d.interestMode ?? InterestMode.manual;
        if (d.interestFrequencyDays != null) {
          final freq = d.interestFrequencyDays!;
          if (_frequencyPresets.contains(freq)) {
            _selectedFrequencyDays = freq;
            _isCustomFrequency = false;
          } else {
            _selectedFrequencyDays = freq;
            _isCustomFrequency = true;
            _customFrequencyController.text = freq.toString();
          }
        }
        _interestStartDate = d.interestStartDate;
      }
      // Load reminder settings
      _hasReminder = d.reminderEnabled;
      _reminderStartDate = d.reminderStartDate;
      _reminderIntervalDays = d.reminderIntervalDays;
      if (!_reminderFrequencyPresets.contains(_reminderIntervalDays)) {
        _isCustomReminderFrequency = true;
        _customReminderFrequencyController.text = _reminderIntervalDays.toString();
      }
    }
  }

  static const _frequencyPresets = [1, 2, 3, 7, 14, 30];
  static const _reminderFrequencyPresets = [1, 2, 3, 7, 14, 30];

  void _onControllerUpdate() => setState(() {});

  @override
  void dispose() {
    _controller
      ..removeListener(_onControllerUpdate)
      ..dispose();
    _lenderController.dispose();
    _amountController.dispose();
    _notesController.dispose();
    _interestRateController.dispose();
    _customFrequencyController.dispose();
    _customReminderFrequencyController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(
                primary: AppTheme.primary,
                surface: AppTheme.cardBg,
              ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _pickInterestStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _interestStartDate ?? DateTime.now().add(Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
      builder: (ctx, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(
                primary: AppTheme.primary,
                surface: AppTheme.cardBg,
              ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _interestStartDate = picked);
  }

  Future<void> _pickReminderStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _reminderStartDate ??
          DateTime.now().add(Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
      builder: (ctx, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(
                primary: AppTheme.primary,
                surface: AppTheme.cardBg,
              ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _reminderStartDate = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final amount = double.parse(_amountController.text.replaceAll(',', ''));

    double? interestRate;
    InterestType? type;
    InterestMode? mode;
    int? freqDays;
    DateTime? startDate;

    if (_hasInterest && _interestRateController.text.isNotEmpty) {
      interestRate = double.parse(_interestRateController.text);
      type = _interestType;
      mode = _interestMode;

      if (_interestMode == InterestMode.automatic) {
        if (_isCustomFrequency) {
          freqDays = int.tryParse(_customFrequencyController.text);
        } else {
          freqDays = _selectedFrequencyDays;
        }
        startDate = _interestStartDate;
      }
    }

    // Reminder settings
    int reminderIntervalDays = _reminderIntervalDays;
    if (_hasReminder && _isCustomReminderFrequency) {
      reminderIntervalDays =
          int.tryParse(_customReminderFrequencyController.text) ?? 1;
    }

    // Calculate reminder start date (default: transaction date + interval)
    DateTime? reminderStartDate = _reminderStartDate;
    if (_hasReminder && reminderStartDate == null) {
      reminderStartDate = _selectedDate.add(Duration(days: reminderIntervalDays));
    }

    await _controller.save(
      lenderName: _lenderController.text,
      amount: amount,
      transactionDate: _selectedDate,
      notes:
          _notesController.text.trim().isEmpty ? null : _notesController.text,
      interestRate: interestRate,
      interestType: type,
      interestMode: mode,
      interestFrequencyDays: freqDays,
      interestStartDate: startDate,
      clearInterest: !_hasInterest && widget.existingDebt?.hasInterest == true,
      reminderEnabled: _hasReminder,
      reminderStartDate: reminderStartDate,
      reminderIntervalDays: reminderIntervalDays,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _controller.isEditing ? 'Debt record updated!' : 'Debt record saved!',
            style: GoogleFonts.dmSans(color: AppTheme.textPrimary),
          ),
          backgroundColor: AppTheme.success,
        ),
      );
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(_controller.isEditing ? 'Edit Debt' : 'Add New Debt'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionLabel('Lender Information'),
              const SizedBox(height: 10),
              _buildLenderField(),
              const SizedBox(height: 20),
              const SectionLabel('Amount Borrowed'),
              const SizedBox(height: 10),
              _buildAmountField(),
              const SizedBox(height: 20),
              const SectionLabel('Transaction Date'),
              const SizedBox(height: 10),
              _buildDatePicker(),
              const SizedBox(height: 20),
              _buildInterestSection(),
              const SizedBox(height: 20),
              const SectionLabel('Notes (Optional)'),
              const SizedBox(height: 10),
              _buildNotesField(),
              const SizedBox(height: 20),
              _buildReminderSection(),
              const SizedBox(height: 32),
              _buildSaveButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInterestSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _hasInterest
              ? AppTheme.accent.withValues(alpha: 0.4)
              : AppTheme.textMuted.withValues(alpha: 0.15),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.trending_up_rounded,
                  color: _hasInterest ? AppTheme.accent : AppTheme.textMuted,
                  size: 18),
              const SizedBox(width: 10),
              Text('Interest',
                  style: GoogleFonts.dmSans(
                      color: _hasInterest
                          ? AppTheme.textPrimary
                          : AppTheme.textMuted,
                      fontSize: 14,
                      fontWeight: FontWeight.w600)),
              const Spacer(),
              Switch.adaptive(
                value: _hasInterest,
                onChanged: (v) => setState(() {
                  _hasInterest = v;
                  if (!v) {
                    _interestRateController.clear();
                    _interestStartDate = null;
                  }
                }),
                activeTrackColor: AppTheme.accent.withValues(alpha: 0.3),
              ),
            ],
          ),
          if (_hasInterest) ...[
            const SizedBox(height: 16),
            _buildInterestRateField(),
            const SizedBox(height: 16),
            _buildInterestTypeSelector(),
            const SizedBox(height: 16),
            _buildInterestModeSelector(),
            if (_interestMode == InterestMode.automatic) ...[
              const SizedBox(height: 16),
              _buildFrequencySelector(),
              const SizedBox(height: 16),
              _buildStartDatePicker(),
            ],
            const SizedBox(height: 10),
            _buildInterestInfoRow(),
          ],
        ],
      ),
    );
  }

  Widget _buildInterestRateField() {
    return TextFormField(
      controller: _interestRateController,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
      style: GoogleFonts.spaceGrotesk(
          color: AppTheme.textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        labelText: 'Interest Rate (%)',
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 14, right: 6),
          child: Text('%',
              style: GoogleFonts.spaceGrotesk(
                  color: AppTheme.textMuted,
                  fontSize: 16,
                  fontWeight: FontWeight.w600)),
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 36),
        hintText: 'e.g. 5.0',
      ),
      validator: (v) {
        if (v == null || v.isEmpty) return 'Required';
        final rate = double.tryParse(v);
        if (rate == null || rate <= 0) return 'Enter a valid %';
        if (rate > 100) return 'Max 100%';
        return null;
      },
    );
  }

  Widget _buildInterestTypeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Calculation Type',
            style: GoogleFonts.dmSans(
                color: AppTheme.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildTypeOption(
                label: 'Simple',
                subtitle: 'Based on original amount',
                icon: Icons.linear_scale_rounded,
                isSelected: _interestType == InterestType.simple,
                onTap: () =>
                    setState(() => _interestType = InterestType.simple),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildTypeOption(
                label: 'Compound',
                subtitle: 'Based on current balance',
                icon: Icons.show_chart_rounded,
                isSelected: _interestType == InterestType.compound,
                onTap: () =>
                    setState(() => _interestType = InterestType.compound),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTypeOption({
    required String label,
    required String subtitle,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.accent.withValues(alpha: 0.1)
              : AppTheme.surfaceLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? AppTheme.accent.withValues(alpha: 0.5)
                : AppTheme.textMuted.withValues(alpha: 0.2),
          ),
        ),
        child: Column(
          children: [
            Icon(icon,
                color: isSelected ? AppTheme.accent : AppTheme.textMuted,
                size: 20),
            const SizedBox(height: 6),
            Text(label,
                style: GoogleFonts.dmSans(
                    color: isSelected ? AppTheme.accent : AppTheme.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
            Text(subtitle,
                style: GoogleFonts.dmSans(
                    color: AppTheme.textMuted, fontSize: 10),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _buildInterestModeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Application Method',
            style: GoogleFonts.dmSans(
                color: AppTheme.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildModeOption(
                label: 'Manual',
                subtitle: 'Apply when you want',
                icon: Icons.touch_app_rounded,
                isSelected: _interestMode == InterestMode.manual,
                onTap: () => setState(() {
                  _interestMode = InterestMode.manual;
                  _interestStartDate = null;
                }),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildModeOption(
                label: 'Automatic',
                subtitle: 'Recurring schedule',
                icon: Icons.autorenew_rounded,
                isSelected: _interestMode == InterestMode.automatic,
                onTap: () =>
                    setState(() => _interestMode = InterestMode.automatic),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildModeOption({
    required String label,
    required String subtitle,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primary.withValues(alpha: 0.1)
              : AppTheme.surfaceLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? AppTheme.primary.withValues(alpha: 0.5)
                : AppTheme.textMuted.withValues(alpha: 0.2),
          ),
        ),
        child: Column(
          children: [
            Icon(icon,
                color: isSelected ? AppTheme.primary : AppTheme.textMuted,
                size: 20),
            const SizedBox(height: 6),
            Text(label,
                style: GoogleFonts.dmSans(
                    color: isSelected ? AppTheme.primary : AppTheme.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
            Text(subtitle,
                style: GoogleFonts.dmSans(
                    color: AppTheme.textMuted, fontSize: 10),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _buildFrequencySelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Frequency',
            style: GoogleFonts.dmSans(
                color: AppTheme.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final days in _frequencyPresets)
              _buildFrequencyChip(
                label: _frequencyLabel(days),
                isSelected: !_isCustomFrequency && _selectedFrequencyDays == days,
                onTap: () => setState(() {
                  _selectedFrequencyDays = days;
                  _isCustomFrequency = false;
                }),
              ),
            _buildFrequencyChip(
              label: 'Custom',
              isSelected: _isCustomFrequency,
              onTap: () => setState(() {
                _isCustomFrequency = true;
              }),
            ),
          ],
        ),
        if (_isCustomFrequency) ...[
          const SizedBox(height: 10),
          TextFormField(
            controller: _customFrequencyController,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: GoogleFonts.spaceGrotesk(
                color: AppTheme.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              labelText: 'Every how many days?',
              hintText: 'e.g. 5',
              isDense: true,
            ),
            validator: (v) {
              if (!_hasInterest || _interestMode != InterestMode.automatic) {
                return null;
              }
              if (_isCustomFrequency) {
                if (v == null || v.isEmpty) return 'Required';
                final days = int.tryParse(v);
                if (days == null || days <= 0) return 'Must be > 0';
              }
              return null;
            },
          ),
        ],
      ],
    );
  }

  Widget _buildFrequencyChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.accent.withValues(alpha: 0.15)
              : AppTheme.surfaceLight,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? AppTheme.accent.withValues(alpha: 0.5)
                : AppTheme.textMuted.withValues(alpha: 0.2),
          ),
        ),
        child: Text(label,
            style: GoogleFonts.dmSans(
                color: isSelected ? AppTheme.accent : AppTheme.textMuted,
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal)),
      ),
    );
  }

  String _frequencyLabel(int days) {
    if (days == 1) return 'Daily';
    if (days == 7) return 'Weekly';
    if (days == 14) return '2 weeks';
    if (days == 30) return 'Monthly';
    return 'Every $days days';
  }

  Widget _buildStartDatePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Interest Start Date',
            style: GoogleFonts.dmSans(
                color: AppTheme.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _pickInterestStartDate,
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: AppTheme.surfaceLight,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: AppTheme.textMuted.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_today_rounded,
                    color: AppTheme.textMuted, size: 16),
                const SizedBox(width: 10),
                Text(
                  _interestStartDate != null
                      ? DateFormat('MMMM d, y').format(_interestStartDate!)
                      : 'Select start date',
                  style: GoogleFonts.dmSans(
                      color: _interestStartDate != null
                          ? AppTheme.textPrimary
                          : AppTheme.textMuted,
                      fontSize: 14),
                ),
                const Spacer(),
                const Icon(Icons.expand_more_rounded,
                    color: AppTheme.textMuted, size: 18),
              ],
            ),
          ),
        ),
        if (_interestMode == InterestMode.automatic)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'Interest starts accruing from this date.',
              style: GoogleFonts.dmSans(
                  color: AppTheme.textMuted, fontSize: 11),
            ),
          ),
      ],
    );
  }

  Widget _buildInterestInfoRow() {
    final freqText = _interestMode == InterestMode.automatic
        ? _isCustomFrequency
            ? 'Every ${_customFrequencyController.text.isEmpty ? '?' : _customFrequencyController.text} days'
            : _frequencyLabel(_selectedFrequencyDays)
        : null;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppTheme.surfaceLight.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded,
              color: AppTheme.textMuted, size: 14),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _interestMode == InterestMode.automatic
                  ? 'Interest will be applied ${freqText?.toLowerCase() ?? ''}.'
                  : 'You can apply interest manually from the debt details.',
              style: GoogleFonts.dmSans(
                  color: AppTheme.textMuted, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }

  // ── Reminder section ────────────────────────────────────────────────────────

  Widget _buildReminderSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _hasReminder
              ? AppTheme.success.withValues(alpha: 0.4)
              : AppTheme.textMuted.withValues(alpha: 0.15),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.notifications_active_rounded,
                  color: _hasReminder ? AppTheme.success : AppTheme.textMuted,
                  size: 18),
              const SizedBox(width: 10),
              Text('Set Reminder',
                  style: GoogleFonts.dmSans(
                      color: _hasReminder
                          ? AppTheme.textPrimary
                          : AppTheme.textMuted,
                      fontSize: 14,
                      fontWeight: FontWeight.w600)),
              const Spacer(),
              Switch.adaptive(
                value: _hasReminder,
                onChanged: (v) => setState(() {
                  _hasReminder = v;
                  if (v && _reminderStartDate == null) {
                    _reminderStartDate = DateTime.now().add(Duration(days: 1));
                  }
                }),
                activeTrackColor: AppTheme.success.withValues(alpha: 0.3),
              ),
            ],
          ),
          if (_hasReminder) ...[
            const SizedBox(height: 16),
            _buildReminderStartDatePicker(),
            const SizedBox(height: 16),
            _buildReminderFrequencySelector(),
            const SizedBox(height: 10),
            _buildReminderInfoRow(),
          ],
        ],
      ),
    );
  }

  Widget _buildReminderStartDatePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('First Reminder',
            style: GoogleFonts.dmSans(
                color: AppTheme.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _pickReminderStartDate,
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: AppTheme.surfaceLight,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: AppTheme.textMuted.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_today_rounded,
                    color: AppTheme.textMuted, size: 16),
                const SizedBox(width: 10),
                Text(
                  _reminderStartDate != null
                      ? DateFormat('MMMM d, y').format(_reminderStartDate!)
                      : 'Select first reminder date',
                  style: GoogleFonts.dmSans(
                      color: _reminderStartDate != null
                          ? AppTheme.textPrimary
                          : AppTheme.textMuted,
                      fontSize: 14),
                ),
                const Spacer(),
                const Icon(Icons.expand_more_rounded,
                    color: AppTheme.textMuted, size: 18),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReminderFrequencySelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Repeat Reminder',
            style: GoogleFonts.dmSans(
                color: AppTheme.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final days in _reminderFrequencyPresets)
              _buildReminderFrequencyChip(
                label: _reminderFrequencyLabel(days),
                isSelected:
                    !_isCustomReminderFrequency && _reminderIntervalDays == days,
                onTap: () => setState(() {
                  _reminderIntervalDays = days;
                  _isCustomReminderFrequency = false;
                }),
              ),
            _buildReminderFrequencyChip(
              label: 'Custom',
              isSelected: _isCustomReminderFrequency,
              onTap: () => setState(() {
                _isCustomReminderFrequency = true;
              }),
            ),
          ],
        ),
        if (_isCustomReminderFrequency) ...[
          const SizedBox(height: 10),
          TextFormField(
            controller: _customReminderFrequencyController,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: GoogleFonts.spaceGrotesk(
                color: AppTheme.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              labelText: 'Every how many days?',
              hintText: 'e.g. 5',
              isDense: true,
            ),
            validator: (v) {
              if (!_hasReminder) return null;
              if (_isCustomReminderFrequency) {
                if (v == null || v.isEmpty) return 'Required';
                final days = int.tryParse(v);
                if (days == null || days <= 0) return 'Must be > 0';
              }
              return null;
            },
          ),
        ],
      ],
    );
  }

  Widget _buildReminderFrequencyChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.success.withValues(alpha: 0.15)
              : AppTheme.surfaceLight,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? AppTheme.success.withValues(alpha: 0.5)
                : AppTheme.textMuted.withValues(alpha: 0.2),
          ),
        ),
        child: Text(label,
            style: GoogleFonts.dmSans(
                color: isSelected ? AppTheme.success : AppTheme.textMuted,
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal)),
      ),
    );
  }

  String _reminderFrequencyLabel(int days) {
    if (days == 1) return 'Daily';
    if (days == 7) return 'Weekly';
    if (days == 14) return '2 weeks';
    if (days == 30) return 'Monthly';
    return 'Every $days days';
  }

  Widget _buildReminderInfoRow() {
    final freqText = _isCustomReminderFrequency
        ? 'Every ${_customReminderFrequencyController.text.isEmpty ? '?' : _customReminderFrequencyController.text} days'
        : _reminderFrequencyLabel(_reminderIntervalDays);

    final startDateText = _reminderStartDate != null
        ? DateFormat('MMMM d, y').format(_reminderStartDate!)
        : 'the start date';

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppTheme.surfaceLight.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded,
              color: AppTheme.textMuted, size: 14),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              "You'll be reminded ${freqText.toLowerCase()} starting $startDateText.",
              style: GoogleFonts.dmSans(
                  color: AppTheme.textMuted, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLenderField() {
    return TextFormField(
      controller: _lenderController,
      maxLength: 50,
      style: GoogleFonts.dmSans(color: AppTheme.textPrimary),
      decoration: const InputDecoration(
        labelText: "Lender's Name",
        prefixIcon:
            Icon(Icons.person_outline_rounded, color: AppTheme.textMuted),
        counterStyle: TextStyle(color: AppTheme.textMuted, fontSize: 11),
      ),
      validator: (v) {
        if (v == null || v.trim().isEmpty) return 'Lender name is required';
        if (v.trim().length < 2) return 'Name must be at least 2 characters';
        return null;
      },
    );
  }

  Widget _buildAmountField() {
    return TextFormField(
      controller: _amountController,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
      style: GoogleFonts.spaceGrotesk(
          color: AppTheme.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        labelText: 'Amount (₱)',
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 14, right: 8),
          child: Text('₱',
              style: GoogleFonts.spaceGrotesk(
                  color: AppTheme.textMuted,
                  fontSize: 18,
                  fontWeight: FontWeight.w600)),
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 40),
      ),
      validator: (v) {
        if (v == null || v.isEmpty) return 'Amount is required';
        final amt = double.tryParse(v.replaceAll(',', ''));
        if (amt == null) return 'Enter a valid amount';
        if (amt <= 0) return 'Amount must be greater than zero';
        return null;
      },
    );
  }

  Widget _buildDatePicker() {
    return GestureDetector(
      onTap: _pickDate,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: AppTheme.surfaceLight,
          borderRadius: BorderRadius.circular(12),
          border:
              Border.all(color: AppTheme.textMuted.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today_rounded,
                color: AppTheme.textMuted, size: 20),
            const SizedBox(width: 12),
            Text(
              DateFormat('MMMM d, y').format(_selectedDate),
              style:
                  GoogleFonts.dmSans(color: AppTheme.textPrimary, fontSize: 15),
            ),
            const Spacer(),
            const Icon(Icons.expand_more_rounded,
                color: AppTheme.textMuted, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildNotesField() {
    return TextFormField(
      controller: _notesController,
      maxLines: 3,
      maxLength: 200,
      style: GoogleFonts.dmSans(color: AppTheme.textPrimary),
      decoration: const InputDecoration(
        hintText: 'Add a note about this debt...',
        alignLabelWithHint: true,
        counterStyle: TextStyle(color: AppTheme.textMuted, fontSize: 11),
      ),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _controller.isSaving ? null : _save,
        child: _controller.isSaving
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2))
            : Text(_controller.isEditing ? 'Update Debt' : 'Save Debt Record'),
      ),
    );
  }
}
