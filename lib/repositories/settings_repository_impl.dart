import 'package:sqflite/sqflite.dart';

import '../models/security_question.dart';
import 'database_helper.dart';
import 'i_debt_repositories.dart';

/// Concrete implementation of [ISettingsRepository] using SQLite.
///
/// Owns all settings/PIN/recovery queries directly instead of delegating
/// to [DatabaseHelper], which now only manages the connection.
///
/// PIN values are expected to be pre-hashed by [AuthService] — this
/// repository stores and compares whatever string it receives.
class SettingsRepositoryImpl implements ISettingsRepository {
  final DatabaseHelper _dbHelper;

  const SettingsRepositoryImpl(this._dbHelper);

  Future<Database> get _db => _dbHelper.database;

  @override
  Future<bool> isPinSet() async {
    final db = await _db;
    final rows = await db.query('app_settings', limit: 1);
    return rows.isNotEmpty;
  }

  @override
  Future<void> setPin(String pin) async {
    final db = await _db;
    final existing = await db.query('app_settings', limit: 1);
    if (existing.isNotEmpty) {
      await db.update(
        'app_settings',
        {'pin': pin},
        where: 'id = ?',
        whereArgs: [existing.first['id']],
      );
    } else {
      await db.insert('app_settings', {
        'pin': pin,
        'created_at': DateTime.now().toIso8601String(),
      });
    }
  }

  @override
  Future<bool> verifyPin(String pin) async {
    final db = await _db;
    final rows =
        await db.query('app_settings', where: 'pin = ?', whereArgs: [pin]);
    return rows.isNotEmpty;
  }

  @override
  Future<bool> isSecurityQuestionSet() async {
    final db = await _db;
    final rows = await db.query('app_settings', limit: 1);
    if (rows.isEmpty) return false;
    return rows.first['security_q_id'] != null;
  }

  @override
  Future<void> saveSecurityAnswer(SecurityAnswer answer) async {
    final db = await _db;
    final rows = await db.query('app_settings', limit: 1);
    if (rows.isEmpty) {
      // The settings row is created by setPin() during first-run setup; if
      // it is missing something is broken. Fail loudly instead of silently
      // dropping the answer and breaking offline recovery later.
      throw StateError('app_settings row missing; cannot save the answer.');
    }
    await db.update(
      'app_settings',
      {
        'security_q_id': answer.questionId,
        'security_answer': answer.answer,
      },
      where: 'id = ?',
      whereArgs: [rows.first['id']],
    );
  }

  @override
  Future<SecurityAnswer?> getSecurityAnswer() async {
    final db = await _db;
    final rows = await db.query('app_settings', limit: 1);
    if (rows.isEmpty) return null;
    final qId = rows.first['security_q_id'] as String?;
    final ans = rows.first['security_answer'] as String?;
    if (qId == null || ans == null) return null;
    return SecurityAnswer(questionId: qId, answer: ans);
  }

  @override
  Future<void> wipeAllData() async {
    final db = await _db;
    // One transaction: a mid-wipe crash must leave either all data or none,
    // never a half-wiped mix of debts and credentials.
    await db.transaction((txn) async {
      await txn.delete('payment_history');
      await txn.delete('debts');
      await txn.delete('interest_history');
      await txn.delete('received_debts');
      await txn.delete('app_settings');
    });
    await _dbHelper.close();
  }
}
