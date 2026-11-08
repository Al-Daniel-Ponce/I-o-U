// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../controllers/dashboard_controller.dart';
import '../models/debt.dart';
import '../services/service_locator.dart';
import '../theme/app_theme.dart';
import '../widgets/common/settings_drawer.dart';
import '../widgets/dashboard/borrower_row.dart';
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
    // Assigned before the listener runs: loadData notifies synchronously.
    _controller = DashboardController(ServiceLocator.instance.debtService);
    _controller
      ..addListener(_onUpdate)
      ..loadData();

    _tabController = TabController(length: _filters.length, vsync: this);
  }

  void _onUpdate() {
    // Keep the field in sync when the controller replaces the query
    // (e.g. tapping a borrower in the Borrowers view).
    if (_searchController.text != _controller.searchQuery) {
      _searchController.text = _controller.searchQuery;
    }
    setState(() {});
  }

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
    final borrowersView = _controller.view == DashboardView.borrowers;

    return Scaffold(
      key: _scaffoldKey,
      drawer: const SettingsDrawer(),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            SummaryCard(summary: _controller.summary),
            _buildViewSwitch(),
            if (!borrowersView) _buildSearchBar(),
            if (!borrowersView && _controller.hasBorrowerFilter)
              _buildBorrowerChip(),
            if (!borrowersView) _buildFilterTabs(),
            Expanded(
              child: borrowersView ? _buildBorrowerList() : _buildDebtList(),
            ),
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

  Widget _buildViewSwitch() {
    final cardBg = _isDark ? AppTheme.cardBg : AppTheme.lCardBg;

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          _buildViewOption(
            view: DashboardView.debts,
            label: 'Debts',
            icon: Icons.receipt_long_rounded,
          ),
          _buildViewOption(
            view: DashboardView.borrowers,
            label: 'Borrowers',
            icon: Icons.people_alt_rounded,
          ),
        ],
      ),
    );
  }

  Widget _buildViewOption({
    required DashboardView view,
    required String label,
    required IconData icon,
  }) {
    final selected = _controller.view == view;

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _controller.setView(view),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: selected ? AppTheme.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(11),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: selected ? Colors.white : _textSecondary,
              ),
              const SizedBox(width: 7),
              Text(
                label,
                style: GoogleFonts.dmSans(
                  color: selected ? Colors.white : _textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Removable chip shown when the list was narrowed from a borrower row.
  Widget _buildBorrowerChip() {
    final name = _controller.borrowerFilter ?? '';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.only(left: 12, top: 5, bottom: 5, right: 4),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.primary.withValues(alpha: 0.35)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.person_rounded,
                    size: 15, color: AppTheme.primaryLight),
                const SizedBox(width: 6),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.55,
                  ),
                  child: Text(
                    name,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.dmSans(
                      color: AppTheme.primaryLight,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  iconSize: 16,
                  icon: Icon(Icons.close_rounded, color: _textMuted),
                  tooltip: 'Clear filter',
                  onPressed: _controller.clearBorrowerFilter,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Only this borrower',
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.dmSans(color: _textMuted, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBorrowerList() {
    if (_controller.isLoading) {
      return const Center(
          child: CircularProgressIndicator(color: AppTheme.primary));
    }
    if (_controller.errorMessage != null) {
      return Center(child: Text(_controller.errorMessage!,
          style: GoogleFonts.dmSans(color: AppTheme.error)));
    }
    if (_controller.borrowers.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.people_outline_rounded, color: _textMuted, size: 48),
            const SizedBox(height: 12),
            Text(
              'No borrowers yet',
              style: GoogleFonts.spaceGrotesk(
                  color: _textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                'Everyone who owes you will be grouped here\nonce you add a debt.',
                textAlign: TextAlign.center,
                style:
                    GoogleFonts.dmSans(color: _textSecondary, fontSize: 14),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
      itemCount: _controller.borrowers.length,
      itemBuilder: (_, i) {
        final group = _controller.borrowers[i];
        return BorrowerRow(
          group: group,
          onTap: () => _controller.selectBorrower(group),
        );
      },
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
    // Scroll-safe: with a keyboard open (or a short viewport) the column can
    // exceed the available height, and a bare Center+Column overflows.
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
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
                      color: textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                Text(
                  hasFilter
                      ? 'Try adjusting your filters'
                      : 'Tap + to add your first debt record',
                  style:
                      GoogleFonts.dmSans(color: textSecondary, fontSize: 14),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}