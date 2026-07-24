import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/category_model.dart';
import '../models/budget_model.dart';
import '../models/app_settings.dart';
import '../models/notification_model.dart';
import '../models/transaction_model.dart';
import '../models/wallet_model.dart';
import 'ai_analysis_service.dart';
import 'database_service.dart';
import 'settings_service.dart';

class NotificationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final DatabaseService _database = DatabaseService();
  final AiAnalysisService _analysis = AiAnalysisService();
  final SettingsService _settings = SettingsService();

  CollectionReference<Map<String, dynamic>> _collection(String userId) =>
      _firestore.collection('users').doc(userId).collection('notifications');

  Stream<List<NotificationModel>> watch(String userId) {
    if (userId.isEmpty) return const Stream.empty();
    return _collection(userId).snapshots().map((snapshot) {
      final values = snapshot.docs
          .map((doc) => NotificationModel.fromFirestore(doc.id, doc.data()))
          .toList();
      values.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return values;
    });
  }

  Stream<int> watchUnreadCount(String userId) => watch(
    userId,
  ).map((values) => values.where((item) => !item.isRead).length);

  Future<void> markRead(String userId, String id) =>
      _collection(userId).doc(id).update({'is_read': true});

  Future<void> markAllRead(String userId) async {
    final snapshot = await _collection(userId).get();
    var batch = _firestore.batch();
    var count = 0;
    for (final doc in snapshot.docs.where(
      (doc) => doc.data()['is_read'] != true,
    )) {
      batch.update(doc.reference, {'is_read': true});
      count++;
      if (count == 450) {
        await batch.commit();
        batch = _firestore.batch();
        count = 0;
      }
    }
    if (count > 0) await batch.commit();
  }

  Future<void> delete(String userId, String id) =>
      _collection(userId).doc(id).delete();

  Future<void> create({
    required String userId,
    required String type,
    required String title,
    required String message,
    required String priority,
    String? referenceId,
    String? dedupeSuffix,
  }) async {
    if (userId.isEmpty) return;
    final now = DateTime.now();
    final day =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final rawId = '${type}_${referenceId ?? 'general'}_${dedupeSuffix ?? day}';
    final id = rawId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    final reference = _collection(userId).doc(id);
    final existing = await reference.get();
    if (existing.exists) return;
    await reference.set({
      'user_id': userId,
      'type': type,
      'title': title,
      'message': message,
      'created_at': FieldValue.serverTimestamp(),
      'is_read': false,
      'priority': priority,
      'reference_id': referenceId,
    });
  }

  Future<void> createAnomaly({
    required String userId,
    required double amount,
    required String category,
    required String reason,
    String? transactionId,
  }) async {
    try {
      final settings = await _settings.get(userId);
      if (!settings.notificationsEnabled) return;
    } catch (_) {
      // Use enabled-by-default behavior when preferences cannot be loaded.
    }
    await create(
      userId: userId,
      type: 'anomaly',
      title: 'Giao dịch bất thường',
      message: 'Khoản chi ${_money(amount)} cho $category: $reason',
      priority: 'high',
      referenceId: transactionId,
      dedupeSuffix:
          transactionId ??
          '${DateTime.now().year}_${DateTime.now().month}_'
              '${DateTime.now().day}_${amount.round()}',
    );
  }

  Future<void> evaluate(String userId, {bool includeForecast = false}) async {
    if (userId.isEmpty) return;
    AppSettings settings;
    try {
      settings = await _settings.get(userId);
    } catch (_) {
      settings = AppSettings.defaults;
    }
    if (!settings.notificationsEnabled) return;

    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    final previousStart = DateTime(now.year, now.month - 1, 1);
    final results = await Future.wait([
      _database.getWallets(userId),
      _database.getBudgets(userId, now.month, now.year),
      _database.getTransactions(userId),
    ]);
    final wallets = results[0] as List<WalletModel>;
    final budgets = results[1] as List<BudgetModel>;
    final transactions = results[2] as List<TransactionModel>;

    for (final wallet in wallets) {
      if (wallet.balance < settings.lowBalanceThreshold) {
        await create(
          userId: userId,
          type: 'low_balance',
          title: 'Số dư ví thấp',
          message: 'Ví ${wallet.name} chỉ còn ${_money(wallet.balance)}.',
          priority: wallet.balance < 50000 ? 'high' : 'medium',
          referenceId: wallet.id.toString(),
        );
      }
    }

    for (final budget in budgets) {
      final spent = await _database.getSpentForCategory(
        userId,
        budget.categoryId,
        now.month,
        now.year,
      );
      if (budget.limitAmount <= 0) continue;
      final percent = spent / budget.limitAmount * 100;
      if (percent < 70) continue;
      final category = CategoryModel.getById(budget.categoryId).name;
      if (percent >= 100) {
        await create(
          userId: userId,
          type: 'budget_exceeded',
          title: 'Đã vượt ngân sách',
          message:
              'Bạn đã vượt ngân sách $category ${_money(spent - budget.limitAmount)}.',
          priority: 'high',
          referenceId: budget.id.toString(),
        );
      } else {
        final threshold = percent >= 90 ? '90' : '70';
        await create(
          userId: userId,
          type: 'budget_warning',
          title: percent >= 90 ? 'Sắp vượt ngân sách' : 'Cảnh báo ngân sách',
          message: 'Ngân sách $category đã dùng ${percent.round()}%.',
          priority: percent >= 90 ? 'high' : 'medium',
          referenceId: budget.id.toString(),
          dedupeSuffix: '${now.year}_${now.month}_$threshold',
        );
      }
    }

    final hasToday = transactions.any(
      (item) =>
          item.date.year == now.year &&
          item.date.month == now.month &&
          item.date.day == now.day,
    );
    if (!hasToday && settings.dailyReminderEnabled) {
      await create(
        userId: userId,
        type: 'reminder',
        title: 'Nhắc ghi giao dịch',
        message: 'Hôm nay bạn chưa ghi nhận giao dịch nào.',
        priority: 'low',
      );
    }

    final currentExpenses = transactions.where(
      (item) =>
          item.isExpense &&
          !item.date.isBefore(monthStart) &&
          item.date.isBefore(DateTime(now.year, now.month + 1, 1)),
    );
    final previousExpenses = transactions.where(
      (item) =>
          item.isExpense &&
          !item.date.isBefore(previousStart) &&
          item.date.isBefore(monthStart),
    );
    final currentByCategory = <int, double>{};
    final previousByCategory = <int, double>{};
    for (final item in currentExpenses) {
      currentByCategory.update(
        item.categoryId,
        (value) => value + item.amount,
        ifAbsent: () => item.amount,
      );
    }
    for (final item in previousExpenses) {
      previousByCategory.update(
        item.categoryId,
        (value) => value + item.amount,
        ifAbsent: () => item.amount,
      );
    }
    for (final entry in currentByCategory.entries) {
      final previous = previousByCategory[entry.key] ?? 0;
      if (previous <= 0) continue;
      final increase = (entry.value - previous) / previous * 100;
      if (increase >= 20) {
        await create(
          userId: userId,
          type: 'saving_tip',
          title: 'Gợi ý tiết kiệm',
          message:
              'Chi tiêu ${CategoryModel.getById(entry.key).name} tăng ${increase.round()}% so với tháng trước.',
          priority: increase >= 50 ? 'high' : 'medium',
          referenceId: entry.key.toString(),
          dedupeSuffix: '${now.year}_${now.month}',
        );
      }
    }

    final expenses = transactions.where((item) => item.isExpense).toList();
    final totalBudget = budgets.fold<double>(
      0,
      (total, item) => total + item.limitAmount,
    );
    if (includeForecast &&
        settings.forecastWarningsEnabled &&
        expenses.isNotEmpty &&
        totalBudget > 0) {
      try {
        final forecast = await _analysis.forecast(expenses, 30);
        if (forecast.success && forecast.predictedTotal > totalBudget) {
          await create(
            userId: userId,
            type: 'forecast_warning',
            title: 'Dự báo vượt ngân sách',
            message:
                'Chi tiêu sắp tới có thể vượt ngân sách ${_money(forecast.predictedTotal - totalBudget)}.',
            priority: 'high',
            dedupeSuffix: '${now.year}_${now.month}',
          );
        }
      } catch (_) {
        // Dashboard remains usable when the AI backend is unavailable.
      }
    }
  }

  String _money(double amount) {
    final digits = amount.round().abs().toString();
    final buffer = StringBuffer();
    for (var index = 0; index < digits.length; index++) {
      if (index > 0 && (digits.length - index) % 3 == 0) buffer.write('.');
      buffer.write(digits[index]);
    }
    return '${amount < 0 ? '-' : ''}$buffer VND';
  }
}
