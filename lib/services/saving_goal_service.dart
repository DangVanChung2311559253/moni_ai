import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/saving_goal_model.dart';
import '../models/transaction_model.dart';
import '../models/wallet_model.dart';
import 'database_service.dart';
import 'notification_service.dart';

class SavingGoalService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final DatabaseService _database = DatabaseService();
  final NotificationService _notifications = NotificationService();

  CollectionReference<Map<String, dynamic>> _collection(
    String userId,
    String name,
  ) {
    if (userId.isEmpty) throw StateError('Người dùng chưa đăng nhập.');
    return _firestore.collection('users').doc(userId).collection(name);
  }

  Future<List<SavingGoal>> getGoals(String userId) async {
    final snapshot = await _collection(userId, 'saving_goals').get();
    final goals = snapshot.docs
        .map((doc) => SavingGoal.fromMap(doc.id, doc.data()))
        .toList();
    goals.sort((a, b) {
      if (a.status == b.status) return a.deadline.compareTo(b.deadline);
      if (a.status == 'active') return -1;
      if (b.status == 'active') return 1;
      return b.updatedAt.compareTo(a.updatedAt);
    });
    return goals;
  }

  Future<SavingGoal?> getGoal(String userId, String goalId) async {
    final doc = await _collection(userId, 'saving_goals').doc(goalId).get();
    final data = doc.data();
    return data == null ? null : SavingGoal.fromMap(doc.id, data);
  }

  Future<String> createGoal({
    required String userId,
    required String name,
    required double targetAmount,
    required double savedAmount,
    required DateTime deadline,
    required String icon,
    required int color,
    String? note,
  }) async {
    _validate(
      targetAmount: targetAmount,
      savedAmount: savedAmount,
      deadline: deadline,
    );
    final reference = _collection(userId, 'saving_goals').doc();
    final now = DateTime.now();
    final goal = SavingGoal(
      id: reference.id,
      userId: userId,
      name: name.trim(),
      targetAmount: targetAmount,
      savedAmount: savedAmount,
      deadline: deadline,
      icon: icon,
      color: color,
      note: note?.trim(),
      status: savedAmount >= targetAmount ? 'completed' : 'active',
      createdAt: now,
      updatedAt: now,
    );
    await reference.set(goal.toMap());
    if (goal.status == 'completed') await _notifyCompleted(goal);
    return reference.id;
  }

  Future<void> updateGoal(SavingGoal goal) async {
    _validate(
      targetAmount: goal.targetAmount,
      savedAmount: goal.savedAmount,
      deadline: goal.deadline,
      allowPastDeadline: true,
    );
    final status = goal.savedAmount >= goal.targetAmount
        ? 'completed'
        : goal.status == 'completed'
        ? 'active'
        : goal.status;
    final updated = goal.copyWith(status: status, updatedAt: DateTime.now());
    await _collection(
      goal.userId,
      'saving_goals',
    ).doc(goal.id).set(updated.toMap(), SetOptions(merge: true));
    if (status == 'completed' && goal.status != 'completed') {
      await _notifyCompleted(updated);
    }
  }

  Future<void> setStatus(String userId, String goalId, String status) async {
    const statuses = {'active', 'completed', 'paused', 'cancelled'};
    if (!statuses.contains(status)) {
      throw StateError('Trạng thái không hợp lệ.');
    }
    final goal = await getGoal(userId, goalId);
    if (goal == null) throw StateError('Mục tiêu không tồn tại.');
    await _collection(
      userId,
      'saving_goals',
    ).doc(goalId).update({'status': status, 'updated_at': Timestamp.now()});
    if (status == 'completed' && goal.status != 'completed') {
      await _notifyCompleted(goal.copyWith(status: status));
    }
  }

  Future<void> deleteGoal(String userId, String goalId) async {
    final contributions = await _collection(
      userId,
      'saving_goal_contributions',
    ).where('goal_id', isEqualTo: goalId).get();
    final batch = _firestore.batch();
    for (final doc in contributions.docs) {
      batch.delete(doc.reference);
    }
    batch.delete(_collection(userId, 'saving_goals').doc(goalId));
    await batch.commit();
  }

  Future<List<SavingGoalContribution>> getContributions(
    String userId,
    String goalId,
  ) async {
    final snapshot = await _collection(
      userId,
      'saving_goal_contributions',
    ).where('goal_id', isEqualTo: goalId).get();
    final values = snapshot.docs
        .map((doc) => SavingGoalContribution.fromMap(doc.id, doc.data()))
        .toList();
    values.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return values;
  }

  Future<void> contribute({
    required String userId,
    required String goalId,
    required int walletId,
    required double amount,
    required String type,
    required DateTime date,
    String? note,
  }) async {
    if (amount <= 0) throw StateError('Số tiền phải lớn hơn 0.');
    if (type != 'deposit' && type != 'withdraw') {
      throw StateError('Loại đóng góp không hợp lệ.');
    }

    final goalRef = _collection(userId, 'saving_goals').doc(goalId);
    final walletRef = _collection(userId, 'wallets').doc(walletId.toString());
    final contributionRef = _collection(
      userId,
      'saving_goal_contributions',
    ).doc();
    final transactionId = DateTime.now().microsecondsSinceEpoch;
    final transactionRef = _collection(
      userId,
      'transactions',
    ).doc(transactionId.toString());
    var completedNow = false;
    SavingGoal? completedGoal;

    await _firestore.runTransaction((transaction) async {
      final goalSnapshot = await transaction.get(goalRef);
      final walletSnapshot = await transaction.get(walletRef);
      final goalData = goalSnapshot.data();
      final walletData = walletSnapshot.data();
      if (goalData == null) throw StateError('Mục tiêu không tồn tại.');
      if (walletData == null) throw StateError('Không tìm thấy ví.');

      final goal = SavingGoal.fromMap(goalId, goalData);
      final wallet = WalletModel.fromMap(walletData);
      final depositing = type == 'deposit';
      if (depositing && wallet.balance < amount) {
        throw StateError('Ví không đủ số dư.');
      }
      if (depositing && goal.savedAmount + amount > goal.targetAmount) {
        throw StateError('Số tiền tiết kiệm không được vượt mục tiêu.');
      }
      if (!depositing && amount > goal.savedAmount) {
        throw StateError('Không thể rút nhiều hơn số tiền đã tiết kiệm.');
      }

      final newSaved = depositing
          ? goal.savedAmount + amount
          : goal.savedAmount - amount;
      final newBalance = depositing
          ? wallet.balance - amount
          : wallet.balance + amount;
      final newStatus = newSaved >= goal.targetAmount
          ? 'completed'
          : goal.status == 'completed'
          ? 'active'
          : goal.status;
      completedNow = newStatus == 'completed' && goal.status != 'completed';
      completedGoal = goal.copyWith(
        savedAmount: newSaved,
        status: newStatus,
        updatedAt: DateTime.now(),
      );

      final financeTransaction = TransactionModel(
        id: transactionId,
        userId: userId,
        title: depositing
            ? 'Tiết kiệm: ${goal.name}'
            : 'Rút từ mục tiêu: ${goal.name}',
        amount: amount,
        categoryId: 13,
        walletId: walletId,
        date: date,
        note: note?.trim().isEmpty == true ? null : note?.trim(),
        type: depositing ? 'expense' : 'income',
      );

      transaction.update(walletRef, {'balance': newBalance});
      transaction.update(goalRef, {
        'saved_amount': newSaved,
        'status': newStatus,
        'updated_at': Timestamp.now(),
      });
      transaction.set(transactionRef, financeTransaction.toMap());
      transaction.set(contributionRef, {
        'schema_version': 1,
        'id': contributionRef.id,
        'goal_id': goalId,
        'user_id': userId,
        'wallet_id': walletId,
        'amount': amount,
        'type': type,
        'note': note?.trim(),
        'created_at': Timestamp.fromDate(date),
      });
    });

    if (completedNow && completedGoal != null) {
      await _notifyCompleted(completedGoal!);
    }
    DatabaseService.notifyFinanceChanged();
  }

  Future<double> averageMonthlySaving(String userId) async {
    final transactions = await _database.getTransactions(userId);
    if (transactions.isEmpty) return 0;
    final now = DateTime.now();
    var total = 0.0;
    var monthsWithData = 0;
    for (var offset = 0; offset < 3; offset++) {
      final month = DateTime(now.year, now.month - offset, 1);
      final next = DateTime(month.year, month.month + 1, 1);
      final values = transactions.where(
        (item) => !item.date.isBefore(month) && item.date.isBefore(next),
      );
      if (values.isEmpty) continue;
      monthsWithData++;
      final income = values
          .where((item) => item.isIncome)
          .fold<double>(0, (totalValue, item) => totalValue + item.amount);
      final expense = values
          .where((item) => item.isExpense)
          .fold<double>(0, (totalValue, item) => totalValue + item.amount);
      total += (income - expense).clamp(0, double.infinity);
    }
    return monthsWithData == 0 ? 0 : total / monthsWithData;
  }

  void _validate({
    required double targetAmount,
    required double savedAmount,
    required DateTime deadline,
    bool allowPastDeadline = false,
  }) {
    if (targetAmount <= 0) throw StateError('Số tiền mục tiêu phải lớn hơn 0.');
    if (savedAmount < 0) {
      throw StateError('Số tiền đã tiết kiệm không được âm.');
    }
    if (savedAmount > targetAmount) {
      throw StateError('Số tiền đã tiết kiệm không được vượt mục tiêu.');
    }
    final today = DateTime.now();
    final start = DateTime(today.year, today.month, today.day);
    final end = DateTime(deadline.year, deadline.month, deadline.day);
    if (!allowPastDeadline && end.isBefore(start)) {
      throw StateError('Hạn hoàn thành không được nhỏ hơn ngày hiện tại.');
    }
  }

  Future<void> _notifyCompleted(SavingGoal goal) {
    return _notifications.create(
      userId: goal.userId,
      type: 'saving_goal_completed',
      title: 'Hoàn thành mục tiêu',
      message: 'Bạn đã hoàn thành mục tiêu ${goal.name}.',
      priority: 'medium',
      referenceId: goal.id,
      dedupeSuffix: 'completed',
    );
  }
}
