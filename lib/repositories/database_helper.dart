import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

/// Low-level SQLite connection manager.
///
/// Handles database initialisation, schema creation, and migrations.
/// Repository classes use this to obtain a [Database] reference but
/// own their own query logic — single responsibility.
class DatabaseHelper {
  DatabaseHelper._init();
  static final DatabaseHelper instance = DatabaseHelper._init();

  static Database? _database;

  Future<Database> get database async {
    _database ??= await _initDB('iou_tracker.db');
    return _database!;
  }

  static const _dbVersion = 5;

  Future<Database> _initDB(String fileName) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, fileName);
    return openDatabase(
      path,
      version: _dbVersion,
      onCreate: _createSchema,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _createSchema(Database db, int version) async {
    await db.execute('''
      CREATE TABLE app_settings (
        id              INTEGER PRIMARY KEY,
        pin             TEXT    NOT NULL,
        created_at      TEXT    NOT NULL,
        security_q_id   TEXT,
        security_answer TEXT
      )
    ''');

    await db.execute('''
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

    await db.execute('''
      CREATE TABLE payment_history (
        id             INTEGER PRIMARY KEY AUTOINCREMENT,
        debt_id        INTEGER NOT NULL,
        payment_amount REAL    NOT NULL,
        payment_date   TEXT    NOT NULL,
        payment_note   TEXT,
        FOREIGN KEY (debt_id) REFERENCES debts (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE interest_history (
        id               INTEGER PRIMARY KEY AUTOINCREMENT,
        debt_id          INTEGER NOT NULL,
        applied_at       TEXT    NOT NULL,
        interest_rate    REAL    NOT NULL,
        interest_amount  REAL    NOT NULL,
        balance_before   REAL    NOT NULL,
        balance_after    REAL    NOT NULL,
        type             TEXT    NOT NULL,
        FOREIGN KEY (debt_id) REFERENCES debts (id) ON DELETE CASCADE
      )
    ''');
  }

  Future<Set<String>> _existingColumns(Database db, String table) async {
    final rows = await db.rawQuery('PRAGMA table_info($table)');
    return rows.map((r) => r['name'] as String).toSet();
  }

  Future<void> _addColumnIfMissing(
    Database db,
    String table,
    String column,
    String columnDef,
  ) async {
    final existing = await _existingColumns(db, table);
    if (!existing.contains(column)) {
      await db.execute('ALTER TABLE $table ADD COLUMN $column $columnDef');
    }
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _addColumnIfMissing(db, 'app_settings', 'security_q_id', 'TEXT');
      await _addColumnIfMissing(db, 'app_settings', 'security_answer', 'TEXT');
    }
    if (oldVersion < 3) {
      await _addColumnIfMissing(db, 'debts', 'interest_rate', 'REAL');
      await _addColumnIfMissing(db, 'debts', 'interest_date', 'TEXT');
    }
    if (oldVersion < 4) {
      // Add new interest config columns to debts
      await _addColumnIfMissing(db, 'debts', 'interest_type', 'TEXT');
      await _addColumnIfMissing(db, 'debts', 'interest_mode', 'TEXT');
      await _addColumnIfMissing(
          db, 'debts', 'interest_frequency_days', 'INTEGER');
      await _addColumnIfMissing(db, 'debts', 'interest_start_date', 'TEXT');
      await _addColumnIfMissing(db, 'debts', 'next_interest_date', 'TEXT');

      // Migrate existing debts: if interest_rate is set, default to simple/manual
      await db.rawUpdate('''
        UPDATE debts
        SET interest_type = 'simple',
            interest_mode = 'manual',
            next_interest_date = interest_date
        WHERE interest_rate IS NOT NULL AND interest_rate > 0
          AND interest_type IS NULL
      ''');

      // Create interest_history table
      await db.execute('''
        CREATE TABLE IF NOT EXISTS interest_history (
          id               INTEGER PRIMARY KEY AUTOINCREMENT,
          debt_id          INTEGER NOT NULL,
          applied_at       TEXT    NOT NULL,
          interest_rate    REAL    NOT NULL,
          interest_amount  REAL    NOT NULL,
          balance_before   REAL    NOT NULL,
          balance_after    REAL    NOT NULL,
          type             TEXT    NOT NULL,
          FOREIGN KEY (debt_id) REFERENCES debts (id) ON DELETE CASCADE
        )
      ''');

      // Migrate existing interest entries from payment_history to interest_history
      final interestPayments = await db.rawQuery('''
        SELECT debt_id, payment_amount, payment_date, payment_note
        FROM payment_history
        WHERE payment_amount < 0
      ''');

      for (final row in interestPayments) {
        final amount = (row['payment_amount'] as num).toDouble().abs();
        await db.insert('interest_history', {
          'debt_id': row['debt_id'],
          'applied_at': row['payment_date'],
          'interest_rate': 0.0, // Unknown old rate, set to 0
          'interest_amount': amount,
          'balance_before': 0.0, // Unknown, set to 0
          'balance_after': 0.0, // Unknown, set to 0
          'type': 'manual', // Default assumption
        });
      }

      // Remove old interest_date column data from debts (no longer needed)
      // Keep the column for backward compatibility but it's superseded by next_interest_date
    }
    if (oldVersion < 5) {
      await _addColumnIfMissing(db, 'debts', 'reminder_enabled', 'INTEGER DEFAULT 1');
      await _addColumnIfMissing(db, 'debts', 'reminder_start_date', 'TEXT');
      await _addColumnIfMissing(db, 'debts', 'reminder_interval_days', 'INTEGER DEFAULT 1');
      await _addColumnIfMissing(db, 'debts', 'next_reminder_date', 'TEXT');

      // Existing paid debts should not have reminders enabled
      await db.rawUpdate(
        "UPDATE debts SET reminder_enabled = 0 WHERE status = 'paid'",
      );
    }
  }

  /// Closes the database connection and clears the cached reference.
  /// The next access to [database] will open a fresh connection.
  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }
}
