import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/budget_model.dart';
import '../models/transaction_model.dart';
import '../models/wallet_model.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  static final ValueNotifier<int> financeChanges = ValueNotifier<int>(0);
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _userCollection(
    String userId,
    String name,
  ) {
    if (userId.isEmpty) {
      throw StateError('Người dùng chưa đăng nhập.');
    }
    return _firestore.collection('users').doc(userId).collection(name);
  }

  String get _currentUserId => FirebaseAuth.instance.currentUser?.uid ?? '';

  int _newId() => DateTime.now().microsecondsSinceEpoch;

  static void notifyFinanceChanged() {
    financeChanges.value++;
  }

  Future<int> insertWallet(WalletModel wallet) async {
    final id = wallet.id ?? _newId();
    final value = wallet.copyWith(id: id);
    if (value.isDefault) {
      await _unsetDefaultWallets(wallet.userId);
    }
    await _userCollection(
      wallet.userId,
      'wallets',
    ).doc(id.toString()).set(value.toMap());
    notifyFinanceChanged();
    return id;
  }

  Future<List<WalletModel>> getWallets(String userId) async {
    final snapshot = await _userCollection(userId, 'wallets').get();
    final wallets = snapshot.docs
        .map((doc) => WalletModel.fromMap(doc.data()))
        .toList();
    wallets.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return wallets;
  }

  Future<WalletModel?> getWalletById(int id) async {
    final userId = _currentUserId;
    if (userId.isEmpty) return null;
    final snapshot = await _userCollection(
      userId,
      'wallets',
    ).doc(id.toString()).get();
    final data = snapshot.data();
    return data == null ? null : WalletModel.fromMap(data);
  }

  Future<void> updateWallet(WalletModel wallet) async {
    if (wallet.id == null) throw StateError('Ví không có ID.');
    if (wallet.isDefault) {
      await _unsetDefaultWallets(wallet.userId, exceptId: wallet.id);
    }
    await _userCollection(
      wallet.userId,
      'wallets',
    ).doc(wallet.id.toString()).set(wallet.toMap(), SetOptions(merge: true));
    notifyFinanceChanged();
  }

  Future<void> _unsetDefaultWallets(String userId, {int? exceptId}) async {
    final snapshot = await _userCollection(userId, 'wallets').get();
    final batch = _firestore.batch();
    var hasUpdates = false;
    for (final document in snapshot.docs) {
      final id = (document.data()['id'] as num?)?.toInt();
      if (id == exceptId || document.data()['is_default'] != true) continue;
      batch.update(document.reference, {'is_default': false});
      hasUpdates = true;
    }
    if (hasUpdates) await batch.commit();
  }

  Future<void> deleteWallet(int id) async {
    final userId = _currentUserId;
    if (userId.isEmpty) throw StateError('Người dùng chưa đăng nhập.');
    final transactions = await _userCollection(userId, 'transactions').get();
    final related = transactions.docs.where(
      (doc) => (doc.data()['wallet_id'] as num?)?.toInt() == id,
    );
    for (final doc in related) {
      await doc.reference.delete();
    }
    await _userCollection(userId, 'wallets').doc(id.toString()).delete();
    notifyFinanceChanged();
  }

  Future<double> getTotalBalance(String userId) async {
    final wallets = await getWallets(userId);
    return wallets.fold<double>(0, (total, wallet) => total + wallet.balance);
  }

  Future<int> insertTransaction(TransactionModel transaction) async {
    final id = transaction.id ?? _newId();
    final value = transaction.copyWith(id: id);
    final transactionRef = _userCollection(
      transaction.userId,
      'transactions',
    ).doc(id.toString());
    final walletRef = _userCollection(
      transaction.userId,
      'wallets',
    ).doc(transaction.walletId.toString());

    await _firestore.runTransaction((firestoreTransaction) async {
      final walletSnapshot = await firestoreTransaction.get(walletRef);
      final walletData = walletSnapshot.data();
      if (walletData == null) throw StateError('Không tìm thấy ví.');
      final wallet = WalletModel.fromMap(walletData);
      if (value.isExpense && wallet.balance < value.amount) {
        throw StateError(
          'Ví ${wallet.name} không đủ số dư. '
          'Bạn không thể thanh toán vượt quá số tiền hiện có.',
        );
      }
      final newBalance = value.isExpense
          ? wallet.balance - value.amount
          : wallet.balance + value.amount;
      firestoreTransaction.set(transactionRef, value.toMap());
      firestoreTransaction.update(walletRef, {'balance': newBalance});
    });
    notifyFinanceChanged();
    return id;
  }

  Future<List<TransactionModel>> getTransactions(
    String userId, {
    String? search,
    DateTime? startDate,
    DateTime? endDate,
    int? categoryId,
    int? walletId,
    double? minAmount,
    double? maxAmount,
    String? type,
    int? limit,
    int? offset,
  }) async {
    final snapshot = await _userCollection(userId, 'transactions').get();
    var values = snapshot.docs
        .map((doc) => TransactionModel.fromMap(doc.data()))
        .where((transaction) {
          if (search != null &&
              search.isNotEmpty &&
              !transaction.title.toLowerCase().contains(search.toLowerCase())) {
            return false;
          }
          if (startDate != null && transaction.date.isBefore(startDate)) {
            return false;
          }
          if (endDate != null && transaction.date.isAfter(endDate)) {
            return false;
          }
          if (categoryId != null && transaction.categoryId != categoryId) {
            return false;
          }
          if (walletId != null && transaction.walletId != walletId) {
            return false;
          }
          if (minAmount != null && transaction.amount < minAmount) return false;
          if (maxAmount != null && transaction.amount > maxAmount) return false;
          if (type != null && transaction.type != type) return false;
          return true;
        })
        .toList();

    values.sort((a, b) {
      final byDate = b.date.compareTo(a.date);
      return byDate != 0 ? byDate : b.createdAt.compareTo(a.createdAt);
    });
    final start = (offset ?? 0).clamp(0, values.length);
    values = values.sublist(start);
    if (limit != null && values.length > limit) {
      values = values.sublist(0, limit);
    }
    return values;
  }

  Future<TransactionModel?> getTransactionById(String userId, int id) async {
    final snapshot = await _userCollection(
      userId,
      'transactions',
    ).doc(id.toString()).get();
    final data = snapshot.data();
    return data == null ? null : TransactionModel.fromMap(data);
  }

  Future<void> updateTransaction(
    TransactionModel newTransaction,
    TransactionModel oldTransaction,
  ) async {
    if (newTransaction.id == null) {
      throw StateError('Giao dịch không có ID.');
    }
    final userId = newTransaction.userId;
    final transactionRef = _userCollection(
      userId,
      'transactions',
    ).doc(newTransaction.id.toString());
    final oldWalletRef = _userCollection(
      userId,
      'wallets',
    ).doc(oldTransaction.walletId.toString());
    final newWalletRef = _userCollection(
      userId,
      'wallets',
    ).doc(newTransaction.walletId.toString());

    await _firestore.runTransaction((firestoreTransaction) async {
      final oldWalletSnapshot = await firestoreTransaction.get(oldWalletRef);
      final oldData = oldWalletSnapshot.data();
      if (oldData == null) throw StateError('Không tìm thấy ví cũ.');
      final oldWallet = WalletModel.fromMap(oldData);
      var revertedBalance = oldTransaction.isExpense
          ? oldWallet.balance + oldTransaction.amount
          : oldWallet.balance - oldTransaction.amount;

      if (oldTransaction.walletId == newTransaction.walletId) {
        final updatedBalance = newTransaction.isExpense
            ? revertedBalance - newTransaction.amount
            : revertedBalance + newTransaction.amount;
        if (updatedBalance < 0) {
          throw StateError(
            'Ví ${oldWallet.name} không đủ số dư để cập nhật giao dịch.',
          );
        }
        firestoreTransaction.update(oldWalletRef, {'balance': updatedBalance});
      } else {
        if (revertedBalance < 0) {
          throw StateError(
            'Không thể đổi ví vì thao tác này sẽ làm ví '
            '${oldWallet.name} bị âm.',
          );
        }
        final newWalletSnapshot = await firestoreTransaction.get(newWalletRef);
        final newData = newWalletSnapshot.data();
        if (newData == null) throw StateError('Không tìm thấy ví mới.');
        final newWallet = WalletModel.fromMap(newData);
        if (newTransaction.isExpense &&
            newWallet.balance < newTransaction.amount) {
          throw StateError(
            'Ví ${newWallet.name} không đủ số dư để cập nhật giao dịch.',
          );
        }
        final newBalance = newTransaction.isExpense
            ? newWallet.balance - newTransaction.amount
            : newWallet.balance + newTransaction.amount;
        firestoreTransaction.update(oldWalletRef, {'balance': revertedBalance});
        firestoreTransaction.update(newWalletRef, {'balance': newBalance});
      }
      firestoreTransaction.set(transactionRef, newTransaction.toMap());
    });
    notifyFinanceChanged();
  }

  Future<void> deleteTransaction(TransactionModel transaction) async {
    if (transaction.id == null) return;
    final transactionRef = _userCollection(
      transaction.userId,
      'transactions',
    ).doc(transaction.id.toString());
    final walletRef = _userCollection(
      transaction.userId,
      'wallets',
    ).doc(transaction.walletId.toString());
    await _firestore.runTransaction((firestoreTransaction) async {
      final walletSnapshot = await firestoreTransaction.get(walletRef);
      final data = walletSnapshot.data();
      if (data != null) {
        final wallet = WalletModel.fromMap(data);
        final balance = transaction.isExpense
            ? wallet.balance + transaction.amount
            : wallet.balance - transaction.amount;
        if (balance < 0) {
          throw StateError(
            'Không thể xóa khoản thu vì ví ${wallet.name} '
            'không còn đủ số dư.',
          );
        }
        firestoreTransaction.update(walletRef, {'balance': balance});
      }
      firestoreTransaction.delete(transactionRef);
    });
    notifyFinanceChanged();
  }

  Future<double> getTotalThisMonth(String userId, String type) async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, 1);
    final end = DateTime(now.year, now.month + 1);
    final values = await getTransactions(
      userId,
      type: type,
      startDate: start,
      endDate: end.subtract(const Duration(microseconds: 1)),
    );
    return values.fold<double>(
      0,
      (total, transaction) => total + transaction.amount,
    );
  }

  Future<double> getSpentForCategory(
    String userId,
    int categoryId,
    int month,
    int year,
  ) async {
    final values = await getTransactions(
      userId,
      type: 'expense',
      categoryId: categoryId,
      startDate: DateTime(year, month, 1),
      endDate: DateTime(
        year,
        month + 1,
      ).subtract(const Duration(microseconds: 1)),
    );
    return values.fold<double>(
      0,
      (total, transaction) => total + transaction.amount,
    );
  }

  Future<List<Map<String, dynamic>>> getDailySpending(
    String userId,
    int days,
  ) async {
    final now = DateTime.now();
    final firstDay = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: days - 1));
    final values = await getTransactions(
      userId,
      type: 'expense',
      startDate: firstDay,
    );
    return List.generate(days, (index) {
      final day = firstDay.add(Duration(days: index));
      final total = values
          .where(
            (transaction) =>
                transaction.date.year == day.year &&
                transaction.date.month == day.month &&
                transaction.date.day == day.day,
          )
          .fold<double>(0, (total, transaction) => total + transaction.amount);
      return {'date': day, 'total': total};
    });
  }

  Future<List<Map<String, dynamic>>> getCategoryExpenseBreakdown(
    String userId,
    int month,
    int year,
  ) async {
    final values = await getTransactions(
      userId,
      type: 'expense',
      startDate: DateTime(year, month, 1),
      endDate: DateTime(
        year,
        month + 1,
      ).subtract(const Duration(microseconds: 1)),
    );
    final totals = <int, double>{};
    for (final transaction in values) {
      totals.update(
        transaction.categoryId,
        (value) => value + transaction.amount,
        ifAbsent: () => transaction.amount,
      );
    }
    final result = totals.entries
        .map((entry) => {'categoryId': entry.key, 'total': entry.value})
        .toList();
    result.sort(
      (a, b) => (b['total'] as double).compareTo(a['total'] as double),
    );
    return result;
  }

  Future<List<Map<String, dynamic>>> getMonthlyStats(
    String userId,
    int year,
  ) async {
    final values = await getTransactions(
      userId,
      startDate: DateTime(year, 1, 1),
      endDate: DateTime(
        year + 1,
        1,
        1,
      ).subtract(const Duration(microseconds: 1)),
    );
    return List.generate(12, (index) {
      final month = index + 1;
      final monthValues = values.where(
        (transaction) => transaction.date.month == month,
      );
      return {
        'month': month,
        'income': monthValues
            .where((transaction) => transaction.isIncome)
            .fold<double>(
              0,
              (total, transaction) => total + transaction.amount,
            ),
        'expense': monthValues
            .where((transaction) => transaction.isExpense)
            .fold<double>(
              0,
              (total, transaction) => total + transaction.amount,
            ),
      };
    });
  }

  Future<int> insertBudget(BudgetModel budget) async {
    final id = budget.id ?? _newId();
    final value = budget.copyWith(id: id);
    await _userCollection(
      budget.userId,
      'budgets',
    ).doc(id.toString()).set(value.toMap());
    return id;
  }

  Future<List<BudgetModel>> getBudgets(
    String userId,
    int month,
    int year,
  ) async {
    final snapshot = await _userCollection(userId, 'budgets').get();
    return snapshot.docs
        .map((doc) => BudgetModel.fromMap(doc.data()))
        .where((budget) => budget.month == month && budget.year == year)
        .toList();
  }

  Future<void> updateBudget(BudgetModel budget) async {
    if (budget.id == null) throw StateError('Ngân sách không có ID.');
    await _userCollection(
      budget.userId,
      'budgets',
    ).doc(budget.id.toString()).set(budget.toMap(), SetOptions(merge: true));
  }

  Future<void> deleteBudget(int id) async {
    final userId = _currentUserId;
    if (userId.isEmpty) throw StateError('Người dùng chưa đăng nhập.');
    await _userCollection(userId, 'budgets').doc(id.toString()).delete();
  }
}
