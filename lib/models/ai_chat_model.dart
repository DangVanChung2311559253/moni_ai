class AiChatResult {
  final String intent;
  final String? transactionType;
  final double? amount;
  final String? category;
  final String? merchant;
  final String? description;
  final String? wallet;
  final DateTime? date;
  final List<String> missingFields;
  final bool requiresConfirmation;
  final String message;

  const AiChatResult({
    required this.intent,
    required this.transactionType,
    required this.amount,
    required this.category,
    required this.merchant,
    required this.description,
    required this.wallet,
    required this.date,
    required this.missingFields,
    required this.requiresConfirmation,
    required this.message,
  });

  bool get isTransaction => intent == 'create_transaction';
  bool get isExpense => transactionType == 'expense';

  factory AiChatResult.fromJson(Map<String, dynamic> json) => AiChatResult(
    intent: (json['intent'] ?? 'unknown').toString(),
    transactionType: json['transaction_type']?.toString(),
    amount: (json['amount'] as num?)?.toDouble(),
    category: json['category']?.toString(),
    merchant: json['merchant']?.toString(),
    description: json['description']?.toString(),
    wallet: json['wallet']?.toString(),
    date: json['date'] == null
        ? null
        : DateTime.tryParse(json['date'].toString()),
    missingFields: ((json['missing_fields'] as List?) ?? const [])
        .map((item) => item.toString())
        .toList(),
    requiresConfirmation: json['requires_confirmation'] == true,
    message: (json['message'] ?? '').toString(),
  );

  AiChatResult copyWith({
    String? transactionType,
    double? amount,
    String? category,
    String? description,
    String? wallet,
    DateTime? date,
  }) {
    return AiChatResult(
      intent: intent,
      transactionType: transactionType ?? this.transactionType,
      amount: amount ?? this.amount,
      category: category ?? this.category,
      merchant: merchant,
      description: description ?? this.description,
      wallet: wallet ?? this.wallet,
      date: date ?? this.date,
      missingFields: missingFields,
      requiresConfirmation: requiresConfirmation,
      message: message,
    );
  }
}
