import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/recurring_transaction_model.dart';
import '../models/transaction_model.dart';
import '../models/wallet_model.dart';
import 'database_service.dart';
import 'notification_service.dart';

class RecurringTransactionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final NotificationService _notifications = NotificationService();

  CollectionReference<Map<String, dynamic>> _collection(
    String userId,
    String name,
  ) {
    if (userId.isEmpty) throw StateError('Người dùng chưa đăng nhập.');
    return _firestore.collection('users').doc(userId).collection(name);
  }

  Future<List<RecurringTransaction>> getPlans(String userId) async {
    final snapshot = await _collection(userId, 'recurring_transactions').get();
    final values = snapshot.docs
        .map((doc) => RecurringTransaction.fromMap(doc.id, doc.data()))
        .toList();
    values.sort((a, b) => a.nextDueDate.compareTo(b.nextDueDate));
    return values;
  }

  Future<String> savePlan({
    String? id,
    required String userId,
    required String name,
    required String type,
    required double amount,
    required int categoryId,
    required int walletId,
    required String frequency,
    required DateTime nextDueDate,
    int? dueDay,
    required int reminderDays,
    String? note,
    String status = 'active',
  }) async {
    if (amount <= 0) throw StateError('Số tiền phải lớn hơn 0.');
    if (!{'income', 'expense'}.contains(type)) {
      throw StateError('Loại giao dịch không hợp lệ.');
    }
    if (!{'weekly', 'monthly', 'yearly'}.contains(frequency)) {
      throw StateError('Tần suất không hợp lệ.');
    }
    if (reminderDays < 0 || reminderDays > 30) {
      throw StateError('Số ngày nhắc trước phải từ 0 đến 30.');
    }
    final reference = id == null
        ? _collection(userId, 'recurring_transactions').doc()
        : _collection(userId, 'recurring_transactions').doc(id);
    final old = await reference.get();
    final now = DateTime.now();
    final value = RecurringTransaction(
      id: reference.id,
      userId: userId,
      name: name.trim(),
      type: type,
      amount: amount,
      categoryId: categoryId,
      walletId: walletId,
      frequency: frequency,
      nextDueDate: _dateOnly(nextDueDate),
      dueDay: dueDay ?? nextDueDate.day,
      reminderDays: reminderDays,
      status: status,
      note: note?.trim(),
      createdAt: old.exists
          ? RecurringTransaction.fromMap(reference.id, old.data()!).createdAt
          : now,
      updatedAt: now,
    );
    await reference.set(value.toMap());
    return reference.id;
  }

  Future<void> deletePlan(String userId, String id) async {
    final occurrences = await _collection(
      userId,
      'recurring_occurrences',
    ).where('recurring_id', isEqualTo: id).get();
    final batch = _firestore.batch();
    for (final doc in occurrences.docs) {
      batch.delete(doc.reference);
    }
    batch.delete(_collection(userId, 'recurring_transactions').doc(id));
    await batch.commit();
  }

  Future<List<RecurringOccurrence>> getOccurrences(
    String userId, {
    String? recurringId,
    String? status,
  }) async {
    final snapshot = await _collection(userId, 'recurring_occurrences').get();
    final values = snapshot.docs
        .map((doc) => RecurringOccurrence.fromMap(doc.id, doc.data()))
        .where(
          (value) =>
              (recurringId == null || value.recurringId == recurringId) &&
              (status == null || value.status == status),
        )
        .toList();
    values.sort((a, b) => b.dueDate.compareTo(a.dueDate));
    return values;
  }

  Future<void> syncDue(String userId) async {
    if (userId.isEmpty) return;
    final plans = await getPlans(userId);
    final today = _dateOnly(DateTime.now());
    for (final plan in plans.where((item) => item.status == 'active')) {
      var due = _dateOnly(plan.nextDueDate);
      var created = 0;
      while (!due.isAfter(today) && created < 36) {
        final key = '${plan.id}_${_dateKey(due)}';
        final reference = _collection(userId, 'recurring_occurrences').doc(key);
        final existing = await reference.get();
        if (!existing.exists) {
          await reference.set({
            'schema_version': 1,
            'id': key,
            'recurring_id': plan.id,
            'user_id': userId,
            'due_date': Timestamp.fromDate(due),
            'status': 'pending',
            'transaction_id': null,
            'created_at': Timestamp.now(),
            'resolved_at': null,
          });
        }
        due = calculateNextDate(due, plan.frequency, plan.dueDay);
        created++;
      }
      if (due != plan.nextDueDate) {
        await _collection(userId, 'recurring_transactions').doc(plan.id).update(
          {
            'next_due_date': Timestamp.fromDate(due),
            'updated_at': Timestamp.now(),
          },
        );
      }
      final reminderDate = due.subtract(Duration(days: plan.reminderDays));
      if (!today.isBefore(reminderDate) && today.isBefore(due)) {
        await _notifications.create(
          userId: userId,
          type: 'recurring_reminder',
          title: 'Sắp đến hạn ${plan.name}',
          message:
              '${plan.name} sẽ đến hạn ngày '
              '${due.day}/${due.month}/${due.year}.',
          priority: 'medium',
          referenceId: plan.id,
          dedupeSuffix: _dateKey(due),
        );
      }
    }
  }

  Future<void> confirmOccurrence({
    required String userId,
    required String occurrenceId,
  }) async {
    final occurrenceRef = _collection(
      userId,
      'recurring_occurrences',
    ).doc(occurrenceId);
    await _firestore.runTransaction((transaction) async {
      final occurrenceSnapshot = await transaction.get(occurrenceRef);
      final occurrenceData = occurrenceSnapshot.data();
      if (occurrenceData == null) {
        throw StateError('Kỳ giao dịch không tồn tại.');
      }
      final occurrence = RecurringOccurrence.fromMap(
        occurrenceId,
        occurrenceData,
      );
      if (occurrence.status != 'pending') {
        throw StateError('Kỳ này đã được xử lý.');
      }

      final planRef = _collection(
        userId,
        'recurring_transactions',
      ).doc(occurrence.recurringId);
      final planSnapshot = await transaction.get(planRef);
      final planData = planSnapshot.data();
      if (planData == null) throw StateError('Khoản định kỳ không tồn tại.');
      final plan = RecurringTransaction.fromMap(planRef.id, planData);
      final walletRef = _collection(
        userId,
        'wallets',
      ).doc(plan.walletId.toString());
      final walletSnapshot = await transaction.get(walletRef);
      final walletData = walletSnapshot.data();
      if (walletData == null) throw StateError('Không tìm thấy ví.');
      final wallet = WalletModel.fromMap(walletData);
      if (plan.isExpense && wallet.balance < plan.amount) {
        throw StateError('Ví không đủ số dư.');
      }

      final transactionId = DateTime.now().microsecondsSinceEpoch;
      final financeTransaction = TransactionModel(
        id: transactionId,
        userId: userId,
        title: plan.name,
        amount: plan.amount,
        categoryId: plan.categoryId,
        walletId: plan.walletId,
        date: occurrence.dueDate,
        note: plan.note,
        type: plan.type,
      );
      final balance = plan.isExpense
          ? wallet.balance - plan.amount
          : wallet.balance + plan.amount;
      transaction.update(walletRef, {'balance': balance});
      transaction.set(
        _collection(userId, 'transactions').doc(transactionId.toString()),
        financeTransaction.toMap(),
      );
      transaction.update(occurrenceRef, {
        'status': 'confirmed',
        'transaction_id': transactionId,
        'resolved_at': Timestamp.now(),
      });
    });
    DatabaseService.notifyFinanceChanged();
  }

  Future<void> skipOccurrence(String userId, String occurrenceId) async {
    final reference = _collection(
      userId,
      'recurring_occurrences',
    ).doc(occurrenceId);
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(reference);
      final data = snapshot.data();
      if (data == null) throw StateError('Kỳ giao dịch không tồn tại.');
      if ((data['status'] ?? 'pending') != 'pending') {
        throw StateError('Kỳ này đã được xử lý.');
      }
      transaction.update(reference, {
        'status': 'skipped',
        'resolved_at': Timestamp.now(),
      });
    });
  }

  static DateTime calculateNextDate(
    DateTime date,
    String frequency,
    int preferredDay,
  ) {
    if (frequency == 'weekly') return date.add(const Duration(days: 7));
    if (frequency == 'yearly') {
      return _safeDate(date.year + 1, date.month, preferredDay);
    }
    return _safeDate(date.year, date.month + 1, preferredDay);
  }

  static DateTime _safeDate(int year, int month, int preferredDay) {
    final normalized = DateTime(year, month, 1);
    final lastDay = DateTime(normalized.year, normalized.month + 1, 0).day;
    return DateTime(
      normalized.year,
      normalized.month,
      math.min(preferredDay, lastDay),
    );
  }

  String _dateKey(DateTime value) =>
      '${value.year}${value.month.toString().padLeft(2, '0')}'
      '${value.day.toString().padLeft(2, '0')}';

  DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);
}
