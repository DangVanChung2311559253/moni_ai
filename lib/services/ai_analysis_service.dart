import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/ai_analysis_models.dart';
import '../models/category_model.dart';
import '../models/transaction_model.dart';

class AiAnalysisException implements Exception {
  final String message;
  const AiAnalysisException(this.message);

  @override
  String toString() => message;
}

class AiAnalysisService {
  Future<ForecastResult> forecast(
    List<TransactionModel> expenses,
    int forecastDays,
  ) async {
    final response = await _post('/forecast', {
      'history': expenses
          .map(
            (transaction) => {
              'date': _apiDate(transaction.date),
              'amount': transaction.amount,
            },
          )
          .toList(),
      'forecast_days': forecastDays,
    });
    return ForecastResult.fromJson(response);
  }

  Future<AnomalyResult> detectAnomaly({
    required double amount,
    required CategoryModel category,
    required DateTime date,
    required String merchant,
    required String description,
    required List<TransactionModel> history,
  }) async {
    final response = await _post('/detect-anomaly', {
      'transaction': {
        'amount': amount,
        'category': category.name,
        'date': _apiDate(date),
        'merchant': merchant,
        'description': description,
      },
      'history': history
          .map(
            (transaction) => {
              'amount': transaction.amount,
              'category': CategoryModel.getById(transaction.categoryId).name,
              'date': _apiDate(transaction.date),
            },
          )
          .toList(),
    });
    return AnomalyResult.fromJson(response);
  }

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> body,
  ) async {
    try {
      final response = await http
          .post(
            ApiConfig.endpoint(path),
            headers: ApiConfig.headers(json: true),
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 30));
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final detail = decoded is Map ? decoded['detail']?.toString() : null;
        throw AiAnalysisException(
          detail ?? 'Backend trả về lỗi ${response.statusCode}.',
        );
      }
      if (decoded is! Map) {
        throw const AiAnalysisException('Phản hồi backend không hợp lệ.');
      }
      return Map<String, dynamic>.from(decoded);
    } on AiAnalysisException {
      rethrow;
    } on TimeoutException {
      throw const AiAnalysisException('Backend AI phản hồi quá thời gian.');
    } on SocketException {
      throw const AiAnalysisException('Không thể kết nối backend AI.');
    } on FormatException {
      throw const AiAnalysisException('Backend trả về JSON không hợp lệ.');
    }
  }

  String _apiDate(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }
}
