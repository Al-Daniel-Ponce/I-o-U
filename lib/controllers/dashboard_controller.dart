import 'package:flutter/material.dart';

import '../models/debt.dart';
import '../services/debt_service.dart';
import '../services/logger.dart';

/// Manages all state and logic for the Dashboard screen.
class DashboardController extends ChangeNotifier {
  final DebtService _debtService;
  final Logger _logger;

  DashboardController(this._debtService, {Logger? logger})
      : _logger = logger ?? const Logger('DashboardController');

  List<Debt> _debts = [];
  DebtSummary _summary = DebtSummary.empty;
  DebtStatus? _statusFilter;
  String _searchQuery = '';
  bool _isLoading = false;
  String? _errorMessage;

  List<Debt> get debts => List.unmodifiable(_debts);
  DebtSummary get summary => _summary;
  DebtStatus? get statusFilter => _statusFilter;
  String get searchQuery => _searchQuery;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> loadData() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final debtsFuture = _debtService.getDebts(
        statusFilter: _statusFilter,
        search: _searchQuery.isNotEmpty ? _searchQuery : null,
      );
      final summaryFuture = _debtService.getSummary();

      _debts = await debtsFuture;
      _summary = await summaryFuture;
    } catch (e, stack) {
      _logger.error('Failed to load data', e, stack);
      _errorMessage = 'Failed to load data. Please try again.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void setStatusFilter(DebtStatus? filter) {
    _statusFilter = filter;
    loadData();
  }

  void setSearch(String query) {
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
