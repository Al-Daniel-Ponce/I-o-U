import 'package:flutter_test/flutter_test.dart';
import 'package:iou_debt_tracker/models/debt.dart';
import 'package:iou_debt_tracker/models/security_question.dart';
import 'package:iou_debt_tracker/repositories/database_helper.dart';
import 'package:iou_debt_tracker/repositories/debt_repository_impl.dart';
import 'package:iou_debt_tracker/repositories/settings_repository_impl.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    await DatabaseHelper.instance.close();
    final path = p.join(await getDatabasesPath(), 'iou_tracker.db');
    if (await databaseExists(path)) {
      await deleteDatabase(path);
    }
  });

  tearDown(() async {
    await DatabaseHelper.instance.close();
  });

  Debt debt({required bool reminders}) => Debt(
        lenderName: 'Maria',
        amount: 500,
        transactionDate: DateTime(2026, 10, 20),
        remainingBalance: 500,
        createdAt: DateTime(2026, 10, 20),
        reminderEnabled: reminders,
        reminderStartDate:
            reminders ? DateTime(2026, 10, 21) : null,
      );

  test('fresh install: every Debt.toMap column exists in the debts table',
      () async {
    final db = await DatabaseHelper.instance.database;

    final map = debt(reminders: true).toMap()..remove('id');
    final columns = (await db.rawQuery('PRAGMA table_info(debts)'))
        .map((row) => row['name'] as String)
        .toSet();

    for (final column in map.keys) {
      expect(columns, contains(column),
          reason: 'Fresh-install schema is missing column "$column"');
    }
  });

  test('fresh install: inserting a debt with reminders succeeds', () async {
    final repo = DebtRepositoryImpl(DatabaseHelper.instance);

    final id = await repo.insertDebt(debt(reminders: true));
    expect(id, greaterThan(0));

    final stored = await repo.getAllDebts();
    expect(stored, hasLength(1));
    expect(stored.first.reminderEnabled, isTrue);
    expect(stored.first.reminderStartDate, DateTime(2026, 10, 21));
  });

  test('legacy v6 database without reminder columns is repaired on upgrade',
      () async {
    final path = p.join(await getDatabasesPath(), 'iou_tracker.db');

    // Fixture mirroring the old buggy fresh-install schema (v6):
    // debts table created WITHOUT the reminder columns.
    final legacy = await openDatabase(path, version: 6);
    await legacy.execute('''
      CREATE TABLE debts (
        id                       INTEGER PRIMARY KEY AUTOINCREMENT,
        lender_name              TEXT    NOT NULL,
        amount                   REAL    NOT NULL,
        transaction_date         TEXT    NOT NULL,
        notes                    TEXT,
        status                   TEXT    NOT NULL DEFAULT 'unpaid',
        remaining_balance        REAL    NOT NULL,
        created_at               TEXT    NOT NULL,
        interest_rate            REAL,
        interest_type            TEXT,
        interest_mode            TEXT,
        interest_frequency_days  INTEGER,
        interest_start_date      TEXT,
        next_interest_date       TEXT
      )
    ''');
    await legacy.close();

    // Opening through DatabaseHelper bumps the version and must repair.
    final db = await DatabaseHelper.instance.database;
    final columns = (await db.rawQuery('PRAGMA table_info(debts)'))
        .map((row) => row['name'] as String)
        .toSet();
    expect(
      columns,
      containsAll(<String>[
        'reminder_enabled',
        'reminder_start_date',
        'reminder_interval_days',
        'next_reminder_date',
      ]),
    );

    final repo = DebtRepositoryImpl(DatabaseHelper.instance);
    final id = await repo.insertDebt(debt(reminders: true));
    expect(id, greaterThan(0));
  });

  test('legacy v3 database without interest_date upgrades without crashing',
      () async {
    final path = p.join(await getDatabasesPath(), 'iou_tracker.db');

    // v1-era core tables plus the v3 step's interest_rate column; a v3
    // fresh scaffold never had interest_date, which the v4 data migration
    // referenced. The guard must skip it instead of throwing.
    final legacy = await openDatabase(path, version: 3);
    await legacy.execute('''
      CREATE TABLE app_settings (
        id              INTEGER PRIMARY KEY,
        pin             TEXT    NOT NULL,
        created_at      TEXT    NOT NULL,
        security_q_id   TEXT,
        security_answer TEXT
      )
    ''');
    await legacy.execute('''
      CREATE TABLE debts (
        id                INTEGER PRIMARY KEY AUTOINCREMENT,
        lender_name       TEXT    NOT NULL,
        amount            REAL    NOT NULL,
        transaction_date  TEXT    NOT NULL,
        notes             TEXT,
        status            TEXT    NOT NULL DEFAULT 'unpaid',
        remaining_balance REAL    NOT NULL,
        created_at        TEXT    NOT NULL,
        interest_rate     REAL
      )
    ''');
    await legacy.execute('''
      CREATE TABLE payment_history (
        id             INTEGER PRIMARY KEY AUTOINCREMENT,
        debt_id        INTEGER NOT NULL,
        payment_amount REAL    NOT NULL,
        payment_date   TEXT    NOT NULL,
        payment_note   TEXT
      )
    ''');
    await legacy.insert('debts', {
      'lender_name': 'Old Maria',
      'amount': 500.0,
      'transaction_date': DateTime(2026, 1, 1).toIso8601String(),
      'status': 'unpaid',
      'remaining_balance': 525.0,
      'created_at': DateTime(2026, 1, 1).toIso8601String(),
      'interest_rate': 5.0,
    });
    await legacy.insert('payment_history', {
      'debt_id': 1,
      'payment_amount': -25.0,
      'payment_date': DateTime(2026, 1, 2).toIso8601String(),
    });
    await legacy.close();

    final db = await DatabaseHelper.instance.database;
    final columns = (await db.rawQuery('PRAGMA table_info(debts)'))
        .map((row) => row['name'] as String)
        .toSet();
    expect(
      columns,
      containsAll(<String>[
        'interest_type',
        'interest_mode',
        'interest_frequency_days',
        'interest_start_date',
        'next_interest_date',
        'reminder_enabled',
        'reminder_start_date',
        'reminder_interval_days',
        'next_reminder_date',
      ]),
    );

    final interest = await db.query('interest_history');
    expect(interest, hasLength(1));
    expect(interest.first['interest_amount'], 25.0);

    final repo = DebtRepositoryImpl(DatabaseHelper.instance);
    final id = await repo.insertDebt(debt(reminders: true));
    expect(id, greaterThan(0));
  });

  test('search trims whitespace and treats LIKE wildcards literally',
      () async {
    final repo = DebtRepositoryImpl(DatabaseHelper.instance);

    Future<void> add(String name) => repo.insertDebt(Debt(
          lenderName: name,
          amount: 100,
          transactionDate: DateTime(2026, 10, 20),
          remainingBalance: 100,
          createdAt: DateTime(2026, 10, 20),
        ));

    await add('Maria Santos');
    await add('John_S');
    await add('JohnXS');
    await add('50% Lender');

    expect((await repo.getAllDebts(search: '  Maria  ')).single.lenderName,
        'Maria Santos');
    expect((await repo.getAllDebts(search: 'John_S')).single.lenderName,
        'John_S');
    expect((await repo.getAllDebts(search: '50%')).single.lenderName,
        '50% Lender');
    expect(await repo.getAllDebts(search: '   '), hasLength(4));
  });

  test('fresh install: saving a security answer without a settings row fails',
      () async {
    final settings = SettingsRepositoryImpl(DatabaseHelper.instance);
    await expectLater(
      settings.saveSecurityAnswer(
          const SecurityAnswer(questionId: 'q1', answer: 'pet')),
      throwsStateError,
    );
  });

  test('wipeAllData empties every table in one pass', () async {
    final settings = SettingsRepositoryImpl(DatabaseHelper.instance);
    await settings.setPin('hashed-pin');
    await settings.saveSecurityAnswer(
        const SecurityAnswer(questionId: 'q1', answer: 'pet'));
    await DebtRepositoryImpl(DatabaseHelper.instance)
        .insertDebt(debt(reminders: true));

    var db = await DatabaseHelper.instance.database;
    await db.insert('received_debts', {
      'record_uid': 'uid-1',
      'lender_name': 'Someone',
      'amount': 100.0,
      'remaining_balance': 100.0,
      'transaction_date': DateTime(2026, 10, 20).toIso8601String(),
      'status': 'unpaid',
      'created_at': DateTime(2026, 10, 20).toIso8601String(),
      'received_at': DateTime(2026, 10, 20).toIso8601String(),
    });

    await settings.wipeAllData();

    db = await DatabaseHelper.instance.database;
    expect(await db.query('app_settings'), isEmpty);
    expect(await db.query('debts'), isEmpty);
    expect(await db.query('received_debts'), isEmpty);
  });
}
