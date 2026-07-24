import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/notification_model.dart';
import '../../services/database_service.dart';
import '../../services/notification_service.dart';
import '../../theme/app_theme.dart';
import '../ai/ai_analysis_screen.dart';
import '../budgets/budgets_screen.dart';
import '../expenses/add_edit_expense_screen.dart';
import '../recurring/recurring_transactions_screen.dart';
import '../savings/saving_goals_screen.dart';
import '../wallets/wallets_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _service = NotificationService();
  final _database = DatabaseService();
  bool _unreadOnly = false;

  String get _userId => FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.navyDeep,
      appBar: AppBar(
        backgroundColor: AppColors.navyMid,
        title: Text(
          'Thông báo',
          style: GoogleFonts.outfit(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          TextButton(
            onPressed: _userId.isEmpty
                ? null
                : () => _service.markAllRead(_userId),
            child: const Text('Đọc tất cả'),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                _filterChip('Tất cả', false),
                const SizedBox(width: 9),
                _filterChip('Chưa đọc', true),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<List<NotificationModel>>(
              stream: _service.watch(_userId),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return _messageState(
                    AppIcons.cloudOffRounded,
                    'Không tải được thông báo',
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.tealPrimary,
                    ),
                  );
                }
                final values = snapshot.data!
                    .where((item) => !_unreadOnly || !item.isRead)
                    .toList();
                if (values.isEmpty) {
                  return _messageState(
                    AppIcons.notificationsNoneRounded,
                    _unreadOnly
                        ? 'Không có thông báo chưa đọc.'
                        : 'Bạn chưa có thông báo nào.',
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 24),
                  itemCount: values.length,
                  itemBuilder: (_, index) => _notificationItem(values[index]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String label, bool unread) {
    final selected = _unreadOnly == unread;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() => _unreadOnly = unread),
      selectedColor: AppColors.tealPrimary,
      backgroundColor: AppColors.navyCard,
      labelStyle: TextStyle(
        color: selected ? Colors.white : AppColors.textSecondary,
      ),
      side: const BorderSide(color: AppColors.navyBorder),
    );
  }

  Widget _notificationItem(NotificationModel item) {
    final color = _typeColor(item.type);
    return Dismissible(
      key: ValueKey(item.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => _service.delete(_userId, item.id),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 22),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: AppColors.error.withAlpha(35),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(AppIcons.deleteRounded, color: AppColors.error),
      ),
      child: InkWell(
        onTap: () => _open(item),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: item.isRead
                ? AppColors.navyCard
                : AppColors.tealPrimary.withAlpha(18),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: item.isRead
                  ? AppColors.navyBorder
                  : AppColors.tealPrimary.withAlpha(90),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withAlpha(28),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(_typeIcon(item.type), color: color, size: 21),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.title,
                            style: GoogleFonts.outfit(
                              color: AppColors.textPrimary,
                              fontWeight: item.isRead
                                  ? FontWeight.w600
                                  : FontWeight.w700,
                            ),
                          ),
                        ),
                        if (!item.isRead)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: AppColors.error,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.message,
                      style: GoogleFonts.outfit(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      _time(item.createdAt),
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _open(NotificationModel item) async {
    if (!item.isRead) {
      try {
        await _service.markRead(_userId, item.id);
      } catch (_) {
        _showMessage('Không thể cập nhật trạng thái thông báo.');
      }
    }
    if (!mounted) return;

    switch (item.type) {
      case 'budget_warning':
      case 'budget_exceeded':
        await _push(const BudgetsScreen());
        return;
      case 'low_balance':
        await _push(const WalletsScreen());
        return;
      case 'anomaly':
        await _openAnomaly(item);
        return;
      case 'forecast_warning':
        await _push(const AiAnalysisScreen(initialSection: 0));
        return;
      case 'saving_tip':
        await _push(const AiAnalysisScreen(initialSection: 2));
        return;
      case 'saving_goal_completed':
        await _push(const SavingGoalsScreen());
        return;
      case 'recurring_reminder':
        await _push(const RecurringTransactionsScreen());
        return;
      default:
        return;
    }
  }

  Future<void> _openAnomaly(NotificationModel item) async {
    final transactionId = int.tryParse(item.referenceId ?? '');
    if (transactionId != null) {
      try {
        final transaction = await _database.getTransactionById(
          _userId,
          transactionId,
        );
        if (!mounted) return;
        if (transaction != null) {
          await _push(AddEditExpenseScreen(existing: transaction));
          return;
        }
      } catch (_) {
        if (!mounted) return;
      }
    }
    _showMessage('Không tìm thấy giao dịch liên quan.');
    await _push(const AiAnalysisScreen(initialSection: 1));
  }

  Future<void> _push(Widget screen) {
    return Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => screen),
    );
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _messageState(IconData icon, String message) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.textMuted, size: 58),
          const SizedBox(height: 12),
          Text(
            message,
            style: GoogleFonts.outfit(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  IconData _typeIcon(String type) {
    switch (type) {
      case 'budget_warning':
        return AppIcons.budgetWarning;
      case 'budget_exceeded':
        return AppIcons.overBudget;
      case 'anomaly':
        return AppIcons.anomaly;
      case 'low_balance':
        return AppIcons.wallet;
      case 'forecast_warning':
        return AppIcons.forecast;
      case 'saving_tip':
        return AppIcons.saving;
      case 'saving_goal_completed':
        return AppIcons.savingGoal;
      case 'reminder':
      case 'recurring_reminder':
        return AppIcons.reminder;
      case 'success':
        return AppIcons.success;
      case 'error':
        return AppIcons.error;
      default:
        return AppIcons.notification;
    }
  }

  Color _typeColor(String type) {
    switch (type) {
      case 'budget_exceeded':
      case 'anomaly':
        return AppColors.error;
      case 'budget_warning':
      case 'forecast_warning':
        return AppColors.warning;
      case 'saving_tip':
      case 'saving_goal_completed':
        return AppColors.income;
      case 'recurring_reminder':
        return AppColors.purpleAccent;
      default:
        return AppColors.tealPrimary;
    }
  }

  String _time(DateTime value) {
    final difference = DateTime.now().difference(value);
    if (difference.inMinutes < 1) return 'Vừa xong';
    if (difference.inHours < 1) return '${difference.inMinutes} phút trước';
    if (difference.inDays < 1) return '${difference.inHours} giờ trước';
    if (difference.inDays < 7) return '${difference.inDays} ngày trước';
    return '${value.day}/${value.month}/${value.year}';
  }
}
