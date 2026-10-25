import 'debt.dart';

/// All debts owed to one person, aggregated for the Borrowers view.
///
/// This app never asks who the borrower is up front — [Debt.lenderName] is
/// the counterparty field, so grouping simply clusters debts by that value.
/// No migration is needed because the data was already there.
///
/// OOP principles:
/// - Information Expert : the group owns the totals its card renders, so the
///   screen stays layout-only and the numbers stay consistent.
/// - Factory method     : [fromDebts] turns an unstructured list into
///   structured, sorted groups without the caller knowing the rules.
class BorrowerGroup {
  /// Counterparty name exactly as typed on each debt.
  final String name;

  final List<Debt> debts;

  const BorrowerGroup(this.name, this.debts);

  static List<BorrowerGroup> fromDebts(List<Debt> debts) {
    final buckets = <String, List<Debt>>{};

    for (final debt in debts) {
      final key = debt.lenderName.trim();
      (buckets[key] ??= []).add(debt);
    }

    final groups = [
      for (final entry in buckets.entries)
        BorrowerGroup(entry.key, List.unmodifiable(entry.value)),
    ];

    // Most money outstanding first; names break ties for a stable order.
    groups.sort((a, b) {
      final byBalance = b.totalRemaining.compareTo(a.totalRemaining);
      return byBalance != 0 ? byBalance : a.name.compareTo(b.name);
    });

    return groups;
  }

  String get displayName => name.isEmpty ? 'Unknown borrower' : name;

  String get avatarInitial =>
      displayName.isEmpty ? '?' : displayName.substring(0, 1).toUpperCase();

  int get count => debts.length;

  double get totalRemaining =>
      debts.fold(0, (sum, debt) => sum + debt.remainingBalance);

  double get totalAmount => debts.fold(0, (sum, debt) => sum + debt.amount);

  int get paidCount => debts.where((d) => d.isPaid).length;

  int get openCount => count - paidCount;

  /// 0.0 – 1.0 share of this person's debt already settled.
  double get progress => totalAmount <= 0
      ? 0
      : ((totalAmount - totalRemaining) / totalAmount).clamp(0, 1);

  /// Newest creation time in the group.
  ///
  /// A group only ever exists when [fromDebts] found at least one debt;
  /// the fallback keeps the getter total if that invariant is ever broken.
  DateTime get mostRecent => debts.isEmpty
      ? DateTime.now()
      : debts.fold(
          debts.first.createdAt,
          (latest, debt) =>
              debt.createdAt.isAfter(latest) ? debt.createdAt : latest,
        );
}
