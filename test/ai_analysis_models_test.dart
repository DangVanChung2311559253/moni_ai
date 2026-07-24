import 'package:flutter_test/flutter_test.dart';
import 'package:moni_ai/models/ai_analysis_models.dart';
import 'package:moni_ai/models/ai_chat_model.dart';
import 'package:moni_ai/models/chat_message_model.dart';

void main() {
  test('parses Prophet forecast response', () {
    final result = ForecastResult.fromJson({
      'success': true,
      'forecast_days': 7,
      'predicted_total': 1250000,
      'average_per_day': 178571,
      'lower_total': 980000,
      'upper_total': 1520000,
      'trend': 'increase',
      'trend_percent': 12.5,
      'message': 'Chi tiêu sắp tới có xu hướng tăng.',
      'daily_forecast': [
        {
          'date': '2026-07-24',
          'predicted_amount': 190000,
          'lower_amount': 150000,
          'upper_amount': 230000,
        },
      ],
    });

    expect(result.success, isTrue);
    expect(result.forecastDays, 7);
    expect(result.dailyForecast, hasLength(1));
    expect(result.dailyForecast.first.predictedAmount, 190000);
  });

  test('parses Isolation Forest response', () {
    final result = AnomalyResult.fromJson({
      'success': true,
      'is_anomaly': true,
      'anomaly_score': -0.1735,
      'severity': 'high',
      'reason': 'Khoản chi cao hơn mức trung bình.',
      'category_average': 72000,
      'user_average': 185000,
      'amount_ratio': 69.44,
      'requires_confirmation': true,
      'detection_mode': 'isolation_forest',
      'message': 'Bạn vẫn muốn lưu?',
    });

    expect(result.isAnomaly, isTrue);
    expect(result.severity, 'high');
    expect(result.requiresConfirmation, isTrue);
    expect(result.detectionMode, 'isolation_forest');
  });

  test('parses Gemini transaction preview without auto-saving', () {
    final result = AiChatResult.fromJson({
      'intent': 'create_transaction',
      'transaction_type': 'expense',
      'amount': 250000,
      'category': 'Mua sắm',
      'merchant': null,
      'description': 'Đi chợ',
      'wallet': null,
      'date': '2026-07-23',
      'missing_fields': ['wallet'],
      'requires_confirmation': true,
      'message': 'Bạn muốn chọn ví nào?',
    });

    expect(result.isTransaction, isTrue);
    expect(result.amount, 250000);
    expect(result.wallet, isNull);
    expect(result.requiresConfirmation, isTrue);
  });

  test('keeps chat transaction preview unsaved until confirmation', () {
    final preview = AiChatResult.fromJson({
      'intent': 'create_transaction',
      'transaction_type': 'expense',
      'amount': 35000,
      'category': 'Ăn uống',
      'description': 'Ăn sáng',
      'date': '2026-07-24',
      'missing_fields': ['wallet'],
      'requires_confirmation': true,
      'message': 'Hãy chọn ví.',
    });
    final message = ChatMessageModel(
      id: 'message_1',
      role: ChatRole.assistant,
      type: ChatMessageType.transactionPreview,
      content: preview.message,
      transactionPreview: preview,
    );

    expect(message.saved, isFalse);
    expect(message.wallet, isNull);
    expect(message.type, ChatMessageType.transactionPreview);
  });
}
