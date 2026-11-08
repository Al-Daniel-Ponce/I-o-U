import 'package:sqflite/sqflite.dart';

import '../models/debt.dart';
import 'database_helper.dart';
import 'i_debt_repositories.dart';

/// Concrete implementation of [IDebtRepository] using SQLite.
///
/// Owns all debt-related queries directly instead of delegating to
/// [DatabaseHelper], which now only manages the connection.
class DebtRepositoryImpl implements IDebtRepository {
  final DatabaseHelper _dbHelper;

  const DebtRepositoryImpl(this._dbHelper);

  Future<Database> get _db => _dbHelper.database;

  @override
  Future<int> insertDebt(Debt debt) async {
    final db = await _db;
    final map = debt.toMap()..remove('id');
    return db.insert('debts', map);
  }

  @override
  Future<List<Debt>> getAllDebts({
    DebtStatus? statusFilter,
    String? search,
  }) async {
    final db = await _db;

    await db.rawUpdate(
      "UPDATE debts SET status = 'paid' WHERE remaining_balance <= 0 AND status != 'paid'",
    );
    await db.rawUpdate(
      "UPDATE debts SET status = 'partial' WHERE remaining_balance > 0 AND remaining_balance < amount AND status = 'unpaid'",
    );

    final conditions = <String>[];
    final args = <dynamic>[];

    if (statusFilter != null) {
      conditions.add('status = ?');
      args.add(statusFilter.name);
    }
    if (search != null) {
      // Trim whitespace and neutralize LIKE wildcards so "50%" or "John_S"
      // match literally instead of acting as % and _ patterns.
      final term = search.trim();
      if (term.isNotEmpty) {
        final escaped = term
            .replaceAll(r'\', r'\\')
            .replaceAll('%', r'\%')
            .replaceAll('_', r'\_');
        conditions.add(r"lender_name LIKE ? ESCAPE '\'");
        args.add('%$escaped%');
      }
    }

    final rows = await db.query(
      'debts',
      where: conditions.isNotEmpty ? conditions.join(' AND ') : null,
      whereArgs: args.isNotEmpty ? args : null,
      orderBy: 'created_at DESC',
    );

    return rows.map(Debt.fromMap).toList();
  }

  @override
  Future<Debt?> getDebtById(int id) async {
    final db = await _db;
    final rows = await db.query('debts', where: 'id = ?', whereArgs: [id]);
    return rows.isNotEmpty ? Debt.fromMap(rows.first) : null;
  }

  @override
  Future<int> updateDebt(Debt debt) async {
    final db = await _db;
    final map = debt.toMap()..remove('id');
    return db.update('debts', map, where: 'id = ?', whereArgs: [debt.id]);
  }

  @override
  Future<int> deleteDebt(int id) async {
    final db = await _db;
    // One transaction so a crash can never orphan history rows.
    final deleted = await db.transaction<int>((txn) async {
      await txn
          .delete('interest_history', where: 'debt_id = ?', whereArgs: [id]);
      await txn.delete('payment_history', where: 'debt_id = ?', whereArgs: [id]);
      return txn.delete('debts', where: 'id = ?', whereArgs: [id]);
    });
    return deleted;
  }

  @override
  Future<int> insertPayment(PaymentHistory payment) async {
    final db = await _db;
    final map = payment.toMap()..remove('id');
    return db.insert('payment_history', map);
  }

  @override
  Future<List<PaymentHistory>> getPaymentsByDebtId(int debtId) async {
    final db = await _db;
    final rows = await db.query(
      'payment_history',
      where: 'debt_id = ?',
      whereArgs: [debtId],
      orderBy: 'payment_date DESC',
    );
    return rows.map(PaymentHistory.fromMap).toList();
  }

  @override
  Future<int> insertInterestTransaction(InterestTransaction transaction) async {
    final db = await _db;
    final map = transaction.toMap()..remove('id');
    return db.insert('interest_history', map);
  }

  @override
  Future<List<InterestTransaction>> getInterestTransactionsByDebtId(
      int debtId) async {
    final db = await _db;
    final rows = await db.query(
      'interest_history',
      where: 'debt_id = ?',
      whereArgs: [debtId],
      orderBy: 'applied_at DESC',
    );
    return rows.map(InterestTransaction.fromMap).toList();
  }

  @override
  Future<InterestTransaction?> getLastInterestTransaction(int debtId) async {
    final db = await _db;
    final rows = await db.query(
      'interest_history',
      where: 'debt_id = ?',
      whereArgs: [debtId],
      orderBy: 'applied_at DESC',
      limit: 1,
    );
    return rows.isNotEmpty ? InterestTransaction.fromMap(rows.first) : null;
  }

  @override
  Future<bool> hasInterestTransactionOnDate(int debtId, DateTime date) async {
    final db = await _db;
    final dateStr = DateTime(date.year, date.month, date.day).toIso8601String();
    final nextDay =
        DateTime(date.year, date.month, date.day + 1).toIso8601String();
    final rows = await db.rawQuery(
      'SELECT COUNT(*) as count FROM interest_history WHERE debt_id = ? AND applied_at >= ? AND applied_at < ?',
      [debtId, dateStr, nextDay],
    );
    return (rows.first['count'] as int) > 0;
  }

  @override
  Future<List<DateTime>> getAppliedInterestDates(int debtId) async {
    final db = await _db;
    final rows = await db.query(
      'interest_history',
      columns: ['applied_at'],
      where: 'debt_id = ?',
      whereArgs: [debtId],
    );
    final dates = <DateTime>[];
    for (final row in rows) {
      final parsed = DateTime.tryParse(row['applied_at'] as String);
      if (parsed != null) {
        dates.add(DateTime(parsed.year, parsed.month, parsed.day));
      }
    }
    return dates;
  }

  @override
  Future<void> recordPaymentAtomic({
    required PaymentHistory payment,
    required Debt updatedDebt,
  }) async {
    final db = await _db;
    await db.transaction((txn) async {
      await txn.insert('payment_history', payment.toMap()..remove('id'));
      await txn.update(
        'debts',
        updatedDebt.toMap()..remove('id'),
        where: 'id = ?',
        whereArgs: [updatedDebt.id],
      );
    });
  }

  @override
  Future<void> applyInterestAtomic({
    required Debt updatedDebt,
    required List<InterestTransaction> transactions,
  }) async {
    final db = await _db;
    await db.transaction((txn) async {
      for (final transaction in transactions) {
        await txn.insert('interest_history', transaction.toMap()..remove('id'));
      }
      await txn.update(
        'debts',
        updatedDebt.toMap()..remove('id'),
        where: 'id = ?',
        whereArgs: [updatedDebt.id],
      );
    });
  }

  @override
  Future<DebtSummary> getSummary() async {
    final db = await _db;

    final amountRows = await db.rawQuery('''
      SELECT SUM(amount) as total_borrowed, SUM(remaining_balance) as total_remaining
      FROM debts
    ''');

    final countRows = await db.rawQuery('''
      SELECT status, COUNT(*) as count FROM debts GROUP BY status
    ''');

    final totalBorrowed =
        (amountRows.first['total_borrowed'] as num?)?.toDouble() ?? 0.0;
    final totalRemaining =
        (amountRows.first['total_remaining'] as num?)?.toDouble() ?? 0.0;

    final counts = <String, int>{};
    for (final row in countRows) {
      counts[row['status'] as String] = row['count'] as int;
    }

    return DebtSummary(
      totalBorrowed: totalBorrowed,
      totalRemaining: totalRemaining,
      unpaidCount: counts['unpaid'] ?? 0,
      partialCount: counts['partial'] ?? 0,
      paidCount: counts['paid'] ?? 0,
    );
  }

  @override
  Future<List<Debt>> getDebtsWithAutomaticInterest() async {
    final db = await _db;
    final rows = await db.query(
      'debts',
      where:
          "interest_rate IS NOT NULL AND interest_rate > 0 AND interest_mode = 'automatic' AND status != 'paid'",
    );
    return rows.map(Debt.fromMap).toList();
  }
}
