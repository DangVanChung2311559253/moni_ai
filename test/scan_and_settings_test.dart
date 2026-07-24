import 'package:flutter_test/flutter_test.dart';
import 'package:moni_ai/config/api_config.dart';
import 'package:moni_ai/models/app_settings.dart';
import 'package:moni_ai/models/scan_result_model.dart';
import 'package:moni_ai/utils/vnd_input_formatter.dart';

void main() {
  test('all AI features share one backend base URL', () {
    expect(ApiConfig.endpoint('/scan').toString(), '${ApiConfig.baseUrl}/scan');
    expect(
      ApiConfig.endpoint('ai/chat').toString(),
      '${ApiConfig.baseUrl}/ai/chat',
    );
  });

  test('API requests bypass the ngrok browser warning', () {
    expect(ApiConfig.headers()['ngrok-skip-browser-warning'], 'true');
    expect(ApiConfig.headers(json: true)['Content-Type'], 'application/json');
  });

  test('parses a structured Scan AI response', () {
    final result = ScanResultModel.fromJson({
      'merchant': 'Highlands Coffee',
      'amount': 89000,
      'date': '2026-07-23',
      'category': 'Ăn uống',
      'confidence': 0.96,
      'raw_text': 'Thanh toán thành công',
    });

    expect(result.merchant, 'Highlands Coffee');
    expect(result.amount, 89000);
    expect(result.date, DateTime(2026, 7, 23));
    expect(result.category, 'Ăn uống');
    expect(result.confidence, 0.96);
  });

  test('uses safe notification settings defaults', () {
    final settings = AppSettings.fromMap(null);

    expect(settings.notificationsEnabled, isTrue);
    expect(settings.dailyReminderEnabled, isTrue);
    expect(settings.forecastWarningsEnabled, isTrue);
    expect(settings.lowBalanceThreshold, 200000);
  });

  test('formats and parses VND input with grouping dots', () {
    expect(formatVndInput(12345678), '12.345.678');
    expect(parseVndInput('12.345.678 ₫'), 12345678);
    expect(parseVndInput(''), isNull);
  });
}
