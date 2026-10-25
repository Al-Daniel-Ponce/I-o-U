// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../models/received_debt.dart';
import '../services/received_debt_service.dart';
import '../services/service_locator.dart';
import '../theme/app_theme.dart';
import '../widgets/borrower/borrower_summary_card.dart';
import '../widgets/borrower/received_debt_card.dart';
import '../widgets/common/settings_drawer.dart';
import 'received_debt_screen.dart';
import 'scan_debt_qr_screen.dart';

/// Borrower-mode dashboard — the "what I owe" perspective.
///
/// Visual twin of [DashboardScreen] (same header, drawer, summary and
/// empty-state rhythm) so switching roles feels like changing a filter
/// rather than changing apps, but themed in amber to mark the mode.
///
/// Data comes from [ReceivedDebtService]: a read-only copy of each debt the
/// user scanned. OOP principles:
/// - Dependency Inversion : the screen asks the locator for the service and
///   never touches SQLite.
/// - Single Responsibility : load + navigate; aggregation lives in
///   ReceivedSummary, rendering in the card widgets.
class BorrowerDashboardScreen extends StatefulWidget {
  const BorrowerDashboardScreen({super.key});

  @override
  State<BorrowerDashboardScreen> createState() =>
      _BorrowerDashboardScreenState();
}

class _BorrowerDashboardScreenState extends State<BorrowerDashboardScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  bool _loading = true;
  String? _error;
  ReceivedSummary? _summary;
  List<ReceivedDebt> _records = const [];

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  // ── Data ───────────────────────────────────────────────────────────────────

  Future<void> _refresh() async {
    try {
      final service = ServiceLocator.instance.receivedDebtService;
      final records = await service.getRecords();
      if (!mounted) return;
      setState(() {
        _records = records;
        _summary = ReceivedSummary.fromList(records);
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not load your debts.';
      });
    }
  }

  Future<void> _scan() async {
    final result = await Navigator.push<QrImportResult>(
      context,
      MaterialPageRoute(builder: (_) => const ScanDebtQrScreen()),
    );
    if (!mounted || result == null) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.message,
          style: GoogleFonts.dmSans(color: AppTheme.textPrimary),
        ),
        backgroundColor:
            result.isSuccess ? AppTheme.success : AppTheme.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
    await _refresh();
  }

  void _openRecord(ReceivedDebt record) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ReceivedDebtScreen(record: record)),
    );
  }

  // ── Theme-aware colours ────────────────────────────────────────────────────

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;
  Color get _textPrimary =>
      _isDark ? AppTheme.textPrimary : AppTheme.lTextPrimary;
  Color get _textSecondary =>
      _isDark ? AppTheme.textSecondary : AppTheme.lTextSecondary;
  Color get _textMuted => _isDark ? AppTheme.textMuted : AppTheme.lTextMuted;

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      drawer: const SettingsDrawer(),
      backgroundColor: _isDark ? AppTheme.background : AppTheme.lBackground,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _scan,
        backgroundColor: AppTheme.accent,
        foregroundColor: AppTheme.background,
        icon: const Icon(Icons.qr_code_scanner_rounded),
        label: Text(
          'Scan QR',
          style: GoogleFonts.dmSans(fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            BorrowerSummaryCard(summary: _summary),
            _buildSectionHeader('Received'),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  // ── UI sections ────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        children: [
          // ── Hamburger / settings button ──────────────────────────────
          GestureDetector(
            onTap: () => _scaffoldKey.currentState?.openDrawer(),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.accent.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.menu_rounded,
                  color: AppTheme.accent, size: 22),
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('I owe U',
                  style: GoogleFonts.spaceGrotesk(
                    color: _textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  )),
              const SizedBox(height: 4),
              _buildModeBadge(),
            ],
          ),
          const Spacer(),
          Text(
            DateFormat('MMM d, y').format(DateTime.now()),
            style: GoogleFonts.dmSans(color: _textSecondary, fontSize: 13),
          ),
        ],
      ),
    );
  }

  /// Amber pill that keeps the active mode visible at all times.
  Widget _buildModeBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppTheme.accent.withOpacity(0.15),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: AppTheme.accent.withOpacity(0.35)),
      ),
      child: Text(
        'BORROWER',
        style: GoogleFonts.dmSans(
          color: AppTheme.accentDark,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.1,
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Text(
        label.toUpperCase(),
        style: GoogleFonts.dmSans(
          color: _textMuted,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.accent),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _error!,
              style: GoogleFonts.dmSans(color: _textSecondary, fontSize: 14),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: _refresh,
              child: Text('Retry', style: GoogleFonts.dmSans()),
            ),
          ],
        ),
      );
    }

    if (_records.isEmpty) return _buildEmptyState();

    return RefreshIndicator(
      onRefresh: _refresh,
      color: AppTheme.accent,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 96),
        itemCount: _records.length,
        separatorBuilder: (_, __) => const SizedBox(height: 0),
        itemBuilder: (context, index) => ReceivedDebtCard(
          record: _records[index],
          onTap: () => _openRecord(_records[index]),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 72),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.qr_code_scanner_rounded, color: _textMuted, size: 48),
            const SizedBox(height: 12),
            Text(
              'No debts yet',
              style: GoogleFonts.spaceGrotesk(
                  color: _textPrimary, fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                'Scan the QR a lender shares with you\nto keep a read-only copy here.',
                textAlign: TextAlign.center,
                style: GoogleFonts.dmSans(color: _textSecondary, fontSize: 14),
              ),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: _scan,
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.accent,
                foregroundColor: AppTheme.background,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
              label: Text('Scan QR',
                  style: GoogleFonts.dmSans(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }
}
