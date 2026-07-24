class TransactionModel {
  final int? id;
  final String userId;
  final String title;
  final double amount;
  final int categoryId;
  final int walletId;
  final DateTime date;
  final String? note;
  final String type; // 'income' | 'expense'
  final DateTime createdAt;

  TransactionModel({
    this.id,
    required this.userId,
    required this.title,
    required this.amount,
    required this.categoryId,
    required this.walletId,
    required this.date,
    this.note,
    required this.type,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  bool get isExpense => type == 'expense';
  bool get isIncome => type == 'income';

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id,
    'user_id': userId,
    'title': title,
    'amount': amount,
    'category_id': categoryId,
    'wallet_id': walletId,
    'date': date.toIso8601String(),
    'note': note,
    'type': type,
    'created_at': createdAt.toIso8601String(),
  };

  factory TransactionModel.fromMap(Map<String, dynamic> map) =>
      TransactionModel(
        id: map['id'] as int?,
        userId: map['user_id'] as String,
        title: map['title'] as String,
        amount: (map['amount'] as num).toDouble(),
        categoryId: map['category_id'] as int,
        walletId: map['wallet_id'] as int,
        date: DateTime.parse(map['date'] as String),
        note: map['note'] as String?,
        type: map['type'] as String,
        createdAt: DateTime.parse(map['created_at'] as String),
      );

  TransactionModel copyWith({
    int? id,
    String? userId,
    String? title,
    double? amount,
    int? categoryId,
    int? walletId,
    DateTime? date,
    String? note,
    String? type,
  }) => TransactionModel(
    id: id ?? this.id,
    userId: userId ?? this.userId,
    title: title ?? this.title,
    amount: amount ?? this.amount,
    categoryId: categoryId ?? this.categoryId,
    walletId: walletId ?? this.walletId,
    date: date ?? this.date,
    note: note ?? this.note,
    type: type ?? this.type,
    createdAt: createdAt,
  );
}
