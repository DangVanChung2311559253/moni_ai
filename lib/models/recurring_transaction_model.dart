import 'package:cloud_firestore/cloud_firestore.dart';

class RecurringTransaction {
  final String id;
  final String userId;
  final String name;
  final String type;
  final double amount;
  final int categoryId;
  final int walletId;
  final String frequency;
  final DateTime nextDueDate;
  final int dueDay;
  final int reminderDays;
  final String status;
  final String? note;
  final DateTime createdAt;
  final DateTime updatedAt;

  const RecurringTransaction({
    required this.id,
    required this.userId,
    required this.name,
    required this.type,
    required this.amount,
    required this.categoryId,
    required this.walletId,
    required this.frequency,
    required this.nextDueDate,
    required this.dueDay,
    required this.reminderDays,
    required this.status,
    this.note,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isExpense => type == 'expense';

  Map<String, dynamic> toMap() => {
    'schema_version': 1,
    'id': id,
    'user_id': userId,
    'name': name,
    'type': type,
    'amount': amount,
    'category_id': categoryId,
    'wallet_id': walletId,
    'frequency': frequency,
    'next_due_date': Timestamp.fromDate(nextDueDate),
    'due_day': dueDay,
    'reminder_days': reminderDays,
    'status': status,
    'note': note,
    'created_at': Timestamp.fromDate(createdAt),
    'updated_at': Timestamp.fromDate(updatedAt),
  };

  factory RecurringTransaction.fromMap(String id, Map<String, dynamic> map) {
    return RecurringTransaction(
      id: id,
      userId: (map['user_id'] ?? '').toString(),
      name: (map['name'] ?? 'Khoản định kỳ').toString(),
      type: (map['type'] ?? 'expense').toString(),
      amount: (map['amount'] as num?)?.toDouble() ?? 0,
      categoryId: (map['category_id'] as num?)?.toInt() ?? 9,
      walletId: (map['wallet_id'] as num?)?.toInt() ?? 0,
      frequency: (map['frequency'] ?? 'monthly').toString(),
      nextDueDate: _readRecurringDate(map['next_due_date']),
      dueDay:
          (map['due_day'] as num?)?.toInt() ??
          _readRecurringDate(map['next_due_date']).day,
      reminderDays: (map['reminder_days'] as num?)?.toInt() ?? 3,
      status: (map['status'] ?? 'active').toString(),
      note: map['note']?.toString(),
      createdAt: _readRecurringDate(map['created_at']),
      updatedAt: _readRecurringDate(map['updated_at']),
    );
  }

  RecurringTransaction copyWith({
    String? name,
    String? type,
    double? amount,
    int? categoryId,
    int? walletId,
    String? frequency,
    DateTime? nextDueDate,
    int? dueDay,
    int? reminderDays,
    String? status,
    String? note,
    DateTime? updatedAt,
  }) {
    return RecurringTransaction(
      id: id,
      userId: userId,
      name: name ?? this.name,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      categoryId: categoryId ?? this.categoryId,
      walletId: walletId ?? this.walletId,
      frequency: frequency ?? this.frequency,
      nextDueDate: nextDueDate ?? this.nextDueDate,
      dueDay: dueDay ?? this.dueDay,
      reminderDays: reminderDays ?? this.reminderDays,
      status: status ?? this.status,
      note: note ?? this.note,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class RecurringOccurrence {
  final String id;
  final String recurringId;
  final String userId;
  final DateTime dueDate;
  final String status;
  final int? transactionId;
  final DateTime createdAt;
  final DateTime? resolvedAt;

  const RecurringOccurrence({
    required this.id,
    required this.recurringId,
    required this.userId,
    required this.dueDate,
    required this.status,
    this.transactionId,
    required this.createdAt,
    this.resolvedAt,
  });

  factory RecurringOccurrence.fromMap(String id, Map<String, dynamic> map) {
    final resolved = map['resolved_at'];
    return RecurringOccurrence(
      id: id,
      recurringId: (map['recurring_id'] ?? '').toString(),
      userId: (map['user_id'] ?? '').toString(),
      dueDate: _readRecurringDate(map['due_date']),
      status: (map['status'] ?? 'pending').toString(),
      transactionId: (map['transaction_id'] as num?)?.toInt(),
      createdAt: _readRecurringDate(map['created_at']),
      resolvedAt: resolved == null ? null : _readRecurringDate(resolved),
    );
  }
}

DateTime _readRecurringDate(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return DateTime.tryParse(value?.toString() ?? '') ?? DateTime.now();
}
