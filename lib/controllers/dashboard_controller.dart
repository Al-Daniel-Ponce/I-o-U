import 'package:flutter/material.dart';

import '../models/borrower_group.dart';
import '../models/debt.dart';
import '../services/debt_service.dart';
import '../services/logger.dart';

/// Which list the Dashboard is currently showing.
enum DashboardView {
  /// Individual debt records (default).
  debts,

  /// People who owe money, grouped.
  borrowers,
}

/// Manages all state and logic for the Dashboard screen.
class DashboardController extends ChangeNotifier {
  final DebtService _debtService;
  final Logger _logger;

  DashboardController(this._debtService, {Logger? logger})
      : _logger = logger ?? const Logger('DashboardController');

  List<Debt> _debts = [];
  List<BorrowerGroup> _borrowers = [];
  DebtSummary _summary = DebtSummary.empty;
  DebtStatus? _statusFilter;
  String _searchQuery = '';
  DashboardView _view = DashboardView.debts;
  String? _borrowerFilter;
  bool _isLoading = false;
  String? _errorMessage;

  List<Debt> get debts => List.unmodifiable(_debts);
  List<BorrowerGroup> get borrowers => List.unmodifiable(_borrowers);
  DebtSummary get summary => _summary;
  DebtStatus? get statusFilter => _statusFilter;
  String get searchQuery => _searchQuery;
  DashboardView get view => _view;

  /// Name of the borrower whose debts the list is narrowed to, if any.
  String? get borrowerFilter => _borrowerFilter;
  bool get hasBorrowerFilter => _borrowerFilter != null;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// Monotonic token so only the newest [loadData] may publish its result.
  /// Without it, fast search typing races the async reads and an older
  /// response can overwrite a newer one.
  int _loadToken = 0;

  Future<void> loadData() async {
    final token = ++_loadToken;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      if (_view == DashboardView.borrowers) {
        // Grouping is independent of the status/search filters — those
        // belong to the Debts view — so the group list reads everything.
        final all = await _debtService.getDebts();
        final summary = await _debtService.getSummary();
        if (token != _loadToken) return;
        _summary = summary;
        _borrowers = BorrowerGroup.fromDebts(all);
      } else {
        // Awaited in sequence: starting both futures up front means a
        // rejection in the first would leave the second one unhandled.
        final debts = await _debtService.getDebts(
          statusFilter: _statusFilter,
          search: _searchQuery.isNotEmpty ? _searchQuery : null,
        );
        final summary = await _debtService.getSummary();
        if (token != _loadToken) return;
        _debts = debts;
        _summary = summary;
      }
    } catch (e, stack) {
      if (token != _loadToken) return;
      _logger.error('Failed to load data', e, stack);
      _errorMessage = 'Failed to load data. Please try again.';
    } finally {
      if (token == _loadToken) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  /// Switches between the Debts and Borrowers lists.
  Future<void> setView(DashboardView view) async {
    if (_view == view) return;
    _view = view;
    await loadData();
  }

  /// Narrow the Debts list to this borrower and return to that view.
  ///
  /// Reuses the existing search mechanism (the repository matches
  /// `lender_name LIKE %query%`), so no new query path is introduced.
  Future<void> selectBorrower(BorrowerGroup group) async {
    _borrowerFilter = group.name;
    _searchQuery = group.name;
    _statusFilter = null;
    _view = DashboardView.debts;
    await loadData();
  }

  /// Drops the borrower chip and its underlying search term.
  Future<void> clearBorrowerFilter() async {
    if (_borrowerFilter == null) return;
    _borrowerFilter = null;
    _searchQuery = '';
    await loadData();
  }

  void setStatusFilter(DebtStatus? filter) {
    _statusFilter = filter;
    loadData();
  }

  void setSearch(String query) {
    // Typing in the search box supersedes an active borrower chip.
    if (_borrowerFilter != null && query != _borrowerFilter) {
      _borrowerFilter = null;
    }
    _searchQuery = query;
    loadData();
  }

  Future<void> deleteDebt(int id) async {
    try {
      await _debtService.deleteDebt(id);
      await loadData();
    } catch (e, stack) {
      _logger.error('Failed to delete debt', e, stack);
      _errorMessage = 'Failed to delete debt. Please try again.';
      notifyListeners();
    }
  }
}
