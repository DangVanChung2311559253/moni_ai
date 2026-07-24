class BudgetModel {
  final int? id;
  final String userId;
  final int categoryId;
  final double limitAmount;
  final int month;
  final int year;
  final DateTime createdAt;

  BudgetModel({
    this.id,
    required this.userId,
    required this.categoryId,
    required this.limitAmount,
    required this.month,
    required this.year,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id,
    'user_id': userId,
    'category_id': categoryId,
    'limit_amount': limitAmount,
    'month': month,
    'year': year,
    'created_at': createdAt.toIso8601String(),
  };

  factory BudgetModel.fromMap(Map<String, dynamic> map) => BudgetModel(
    id: map['id'] as int?,
    userId: map['user_id'] as String,
    categoryId: map['category_id'] as int,
    limitAmount: (map['limit_amount'] as num).toDouble(),
    month: map['month'] as int,
    year: map['year'] as int,
    createdAt: DateTime.parse(map['created_at'] as String),
  );

  BudgetModel copyWith({
    int? id,
    String? userId,
    int? categoryId,
    double? limitAmount,
    int? month,
    int? year,
  }) => BudgetModel(
    id: id ?? this.id,
    userId: userId ?? this.userId,
    categoryId: categoryId ?? this.categoryId,
    limitAmount: limitAmount ?? this.limitAmount,
    month: month ?? this.month,
    year: year ?? this.year,
    createdAt: createdAt,
  );
}
