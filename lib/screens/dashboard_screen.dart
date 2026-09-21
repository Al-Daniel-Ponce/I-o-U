// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../controllers/dashboard_controller.dart';
import '../models/debt.dart';
import '../services/service_locator.dart';
import '../theme/app_theme.dart';
import '../widgets/common/settings_drawer.dart';
import '../widgets/dashboard/debt_card.dart';
import '../widgets/dashboard/summary_card.dart';
import 'add_debt_screen.dart';
import 'debt_detail_screen.dart';

/// Dashboard screen — pure view layer.
///
/// OOP principle: Separation of Concerns — UI only. State lives in
/// [DashboardController]; settings live in [SettingsDrawer].
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin {
  late final DashboardController _controller;
  late final TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  static const _filters = <DebtStatus?>[
    null, DebtStatus.unpaid, DebtStatus.partial, DebtStatus.paid
  ];
  static const _tabLabels = ['All', 'Unpaid', 'Partial', 'Paid'];

  @override
  void initState() {
    super.initState();
    _controller = DashboardController(ServiceLocator.instance.debtService)
      ..addListener(_onUpdate)
      ..loadData();

    _tabController = TabController(length: _filters.length, vsync: this);
  }

  void _onUpdate() => setState(() {});

  @override
  void dispose() {
    _controller..removeListener(_onUpdate)..dispose();
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // ── Theme-aware colours ────────────────────────────────────────────────────

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;
  Color get _textPrimary   => _isDark ? AppTheme.textPrimary   : AppTheme.lTextPrimary;
  Color get _textSecondary => _isDark ? AppTheme.textSecondary : AppTheme.lTextSecondary;
  Color get _textMuted     => _isDark ? AppTheme.textMuted     : AppTheme.lTextMuted;
  // Color get _surfaceLight  => _isDark ? AppTheme.surfaceLight  : AppTheme.lSurfaceLight;

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      drawer: const SettingsDrawer(),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            SummaryCard(summary: _controller.summary),
            _buildSearchBar(),
            _buildFilterTabs(),
            Expanded(child: _buildDebtList()),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _navigateToAdd,
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: Text('Add Debt',
            style: GoogleFonts.dmSans(fontWeight: FontWeight.w600)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  // ── Navigation ─────────────────────────────────────────────────────────────

  Future<void> _navigateToAdd() async {
    await Navigator.push(context,
        MaterialPageRoute(builder: (_) => const AddDebtScreen()));
    _controller.loadData();
  }

  Future<void> _navigateToDetail(Debt debt) async {
    await Navigator.push(context,
        MaterialPageRoute(builder: (_) => DebtDetailScreen(debt: debt)));
    _controller.loadData();
  }

  Future<void> _confirmDelete(Debt debt) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _isDark ? AppTheme.cardBg : AppTheme.lSurface,
        title: Text('Delete Debt',
            style: GoogleFonts.spaceGrotesk(color: _textPrimary)),
        content: Text(
          'Remove the debt record for "${debt.lenderName}"? This cannot be undone.',
          style: GoogleFonts.dmSans(color: _textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
                style: GoogleFonts.dmSans(color: _textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete',
                style: GoogleFonts.dmSans(color: AppTheme.error)),
          ),
        ],
      ),
    );
    if (confirmed == true && debt.id != null) {
      await _controller.deleteDebt(debt.id!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Debt record deleted',
              style: GoogleFonts.dmSans(color: _textPrimary)),
        ));
      }
    }
  }

  // ── UI sections ────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        children: [
          // ── Hamburger / settings button ──────────────────────────────────
          GestureDetector(
            onTap: () => _scaffoldKey.currentState?.openDrawer(),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.menu_rounded,
                  color: AppTheme.primaryLight, size: 22),
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
              Text('Debt Tracker',
                  style: GoogleFonts.dmSans(
                      color: _textMuted, fontSize: 12)),
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

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: TextField(
        controller: _searchController,
        onChanged: _controller.setSearch,
        style: GoogleFonts.dmSans(color: _textPrimary),
        decoration: InputDecoration(
          hintText: 'Search by lender name...',
          prefixIcon: Icon(Icons.search_rounded, color: _textMuted, size: 20),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.clear_rounded, color: _textMuted, size: 18),
                  onPressed: () {
                    _searchController.clear();
                    _controller.setSearch('');
                  },
                )
              : null,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }

  Widget _buildFilterTabs() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        dividerColor: Colors.transparent,
        indicator: BoxDecoration(
          color: AppTheme.primary,
          borderRadius: BorderRadius.circular(10),
        ),
        labelColor: Colors.white,
        unselectedLabelColor: _textSecondary,
        labelStyle: GoogleFonts.dmSans(fontWeight: FontWeight.w600, fontSize: 13),
        // onTap is the only reliable callback — fires once per user tap
        // with the correct index, with no animation-state race conditions.
        onTap: (index) => _controller.setStatusFilter(_filters[index]),
        tabs: _tabLabels.map((l) => Tab(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(l),
          ),
        )).toList(),
      ),
    );
  }

  Widget _buildDebtList() {
    if (_controller.isLoading) {
      return const Center(
          child: CircularProgressIndicator(color: AppTheme.primary));
    }
    if (_controller.errorMessage != null) {
      return Center(child: Text(_controller.errorMessage!,
          style: GoogleFonts.dmSans(color: AppTheme.error)));
    }
    if (_controller.debts.isEmpty) {
      return _EmptyState(
        hasFilter: _controller.statusFilter != null ||
            _controller.searchQuery.isNotEmpty,
        textPrimary: _textPrimary,
        textSecondary: _textSecondary,
        textMuted: _textMuted,
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
      itemCount: _controller.debts.length,
      itemBuilder: (_, i) {
        final debt = _controller.debts[i];
        return DebtCard(
          debt: debt,
          onTap: () => _navigateToDetail(debt),
          onDelete: () => _confirmDelete(debt),
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool hasFilter;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;

  const _EmptyState({
    required this.hasFilter,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            hasFilter
                ? Icons.filter_list_off_rounded
                : Icons.account_balance_wallet_outlined,
            color: textMuted, size: 48,
          ),
          const SizedBox(height: 12),
          Text(
            hasFilter ? 'No results found' : 'No debts yet',
            style: GoogleFonts.spaceGrotesk(
                color: textPrimary, fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text(
            hasFilter
                ? 'Try adjusting your filters'
                : 'Tap + to add your first debt record',
            style: GoogleFonts.dmSans(color: textSecondary, fontSize: 14),
          ),
        ],
      ),
    );
  }
}