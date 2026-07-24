class ScanResultModel {
  final String merchant;
  final double amount;
  final DateTime date;
  final String category;
  final double confidence;
  final String rawText;

  const ScanResultModel({
    required this.merchant,
    required this.amount,
    required this.date,
    required this.category,
    required this.confidence,
    required this.rawText,
  });

  factory ScanResultModel.fromJson(Map<String, dynamic> json) {
    return ScanResultModel(
      merchant: (json['merchant'] ?? '').toString(),
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      date:
          DateTime.tryParse((json['date'] ?? '').toString()) ?? DateTime.now(),
      category: (json['category'] ?? 'Khác').toString(),
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0,
      rawText: (json['raw_text'] ?? '').toString(),
    );
  }
}
