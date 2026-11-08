import 'package:sqflite/sqflite.dart';

import '../models/received_debt.dart';
import 'database_helper.dart';
import 'i_debt_repositories.dart';

/// SQLite implementation of [IReceivedDebtRepository].
///
/// Owns every query against `received_debts` directly, mirroring how
/// [DebtRepositoryImpl] owns `debts`, so [DatabaseHelper] stays a
/// connection manager.
class ReceivedDebtRepositoryImpl implements IReceivedDebtRepository {
  final DatabaseHelper _dbHelper;

  const ReceivedDebtRepositoryImpl(this._dbHelper);

  Future<Database> get _db => _dbHelper.database;

  @override
  Future<({int id, bool inserted})> upsert(ReceivedDebt record) async {
    final db = await _db;

    // One transaction so two concurrent scans of the same code cannot both
    // miss the existing row and insert duplicates.
    return db.transaction<({int id, bool inserted})>((txn) async {
      final existing = await txn.query(
        'received_debts',
        columns: ['id'],
        where: 'record_uid = ?',
        whereArgs: [record.recordUid],
        limit: 1,
      );

      if (existing.isNotEmpty) {
        final id = existing.first['id'] as int;
        await txn.update(
          'received_debts',
          record.toMap()..remove('id'),
          where: 'id = ?',
          whereArgs: [id],
        );
        return (id: id, inserted: false);
      }

      final id = await txn.insert(
        'received_debts',
        record.toMap()..remove('id'),
      );
      return (id: id, inserted: true);
    });
  }

  @override
  Future<List<ReceivedDebt>> getAll() async {
    final db = await _db;
    final rows = await db.query('received_debts', orderBy: 'received_at DESC');
    return rows.map(ReceivedDebt.fromMap).toList();
  }
}
