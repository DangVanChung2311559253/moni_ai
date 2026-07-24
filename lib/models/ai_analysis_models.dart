class DailyForecast {
  final DateTime date;
  final double predictedAmount;
  final double lowerAmount;
  final double upperAmount;

  const DailyForecast({
    required this.date,
    required this.predictedAmount,
    required this.lowerAmount,
    required this.upperAmount,
  });

  factory DailyForecast.fromJson(Map<String, dynamic> json) => DailyForecast(
    date: DateTime.parse(json['date'] as String),
    predictedAmount: (json['predicted_amount'] as num?)?.toDouble() ?? 0,
    lowerAmount: (json['lower_amount'] as num?)?.toDouble() ?? 0,
    upperAmount: (json['upper_amount'] as num?)?.toDouble() ?? 0,
  );

  Map<String, dynamic> toJson() => {
    'date': date.toIso8601String(),
    'predicted_amount': predictedAmount,
    'lower_amount': lowerAmount,
    'upper_amount': upperAmount,
  };
}

class ForecastResult {
  final bool success;
  final int forecastDays;
  final double predictedTotal;
  final double averagePerDay;
  final double lowerTotal;
  final double upperTotal;
  final String trend;
  final double trendPercent;
  final String message;
  final int? availableDays;
  final List<DailyForecast> dailyForecast;

  const ForecastResult({
    required this.success,
    required this.forecastDays,
    required this.predictedTotal,
    required this.averagePerDay,
    required this.lowerTotal,
    required this.upperTotal,
    required this.trend,
    required this.trendPercent,
    required this.message,
    required this.dailyForecast,
    this.availableDays,
  });

  factory ForecastResult.fromJson(Map<String, dynamic> json) => ForecastResult(
    success: json['success'] == true,
    forecastDays: (json['forecast_days'] as num?)?.toInt() ?? 0,
    predictedTotal: (json['predicted_total'] as num?)?.toDouble() ?? 0,
    averagePerDay: (json['average_per_day'] as num?)?.toDouble() ?? 0,
    lowerTotal: (json['lower_total'] as num?)?.toDouble() ?? 0,
    upperTotal: (json['upper_total'] as num?)?.toDouble() ?? 0,
    trend: (json['trend'] ?? 'stable').toString(),
    trendPercent: (json['trend_percent'] as num?)?.toDouble() ?? 0,
    message: (json['message'] ?? '').toString(),
    availableDays: (json['available_days'] as num?)?.toInt(),
    dailyForecast: ((json['daily_forecast'] as List?) ?? const [])
        .map(
          (item) =>
              DailyForecast.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList(),
  );

  Map<String, dynamic> toJson() => {
    'success': success,
    'forecast_days': forecastDays,
    'predicted_total': predictedTotal,
    'average_per_day': averagePerDay,
    'lower_total': lowerTotal,
    'upper_total': upperTotal,
    'trend': trend,
    'trend_percent': trendPercent,
    'message': message,
    'available_days': availableDays,
    'daily_forecast': dailyForecast.map((item) => item.toJson()).toList(),
  };
}

class AnomalyResult {
  final bool isAnomaly;
  final double anomalyScore;
  final String severity;
  final String reason;
  final double categoryAverage;
  final double userAverage;
  final double amountRatio;
  final bool requiresConfirmation;
  final String detectionMode;
  final String message;

  const AnomalyResult({
    required this.isAnomaly,
    required this.anomalyScore,
    required this.severity,
    required this.reason,
    required this.categoryAverage,
    required this.userAverage,
    required this.amountRatio,
    required this.requiresConfirmation,
    required this.detectionMode,
    required this.message,
  });

  factory AnomalyResult.fromJson(Map<String, dynamic> json) => AnomalyResult(
    isAnomaly: json['is_anomaly'] == true,
    anomalyScore: (json['anomaly_score'] as num?)?.toDouble() ?? 0,
    severity: (json['severity'] ?? 'none').toString(),
    reason: (json['reason'] ?? '').toString(),
    categoryAverage: (json['category_average'] as num?)?.toDouble() ?? 0,
    userAverage: (json['user_average'] as num?)?.toDouble() ?? 0,
    amountRatio: (json['amount_ratio'] as num?)?.toDouble() ?? 0,
    requiresConfirmation: json['requires_confirmation'] == true,
    detectionMode: (json['detection_mode'] ?? '').toString(),
    message: (json['message'] ?? '').toString(),
  );
}

class AnomalyAlertRecord {
  final double amount;
  final String category;
  final DateTime date;
  final String severity;
  final String reason;
  final String status;

  const AnomalyAlertRecord({
    required this.amount,
    required this.category,
    required this.date,
    required this.severity,
    required this.reason,
    required this.status,
  });

  factory AnomalyAlertRecord.fromJson(Map<String, dynamic> json) =>
      AnomalyAlertRecord(
        amount: (json['amount'] as num).toDouble(),
        category: json['category'].toString(),
        date: DateTime.parse(json['date'].toString()),
        severity: json['severity'].toString(),
        reason: json['reason'].toString(),
        status: json['status'].toString(),
      );

  Map<String, dynamic> toJson() => {
    'amount': amount,
    'category': category,
    'date': date.toIso8601String(),
    'severity': severity,
    'reason': reason,
    'status': status,
  };
}
