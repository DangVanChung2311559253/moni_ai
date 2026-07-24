import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/ai_chat_model.dart';
import '../../models/budget_model.dart';
import '../../models/category_model.dart';
import '../../models/chat_message_model.dart';
import '../../models/transaction_model.dart';
import '../../models/wallet_model.dart';
import '../../services/ai_chat_service.dart';
import '../../services/database_service.dart';
import '../../services/notification_service.dart';
import '../../services/speech_input_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/vnd_input_formatter.dart';
import '../expenses/add_edit_expense_screen.dart';
import '../expenses/expenses_screen.dart';
import '../statistics/monthly_statistics_screen.dart';
import 'ai_analysis_screen.dart';
import 'widgets/anomaly_warning_card.dart';
import 'widgets/chat_bubble.dart';
import 'widgets/chat_error_card.dart';
import 'widgets/chat_input_bar.dart';
import 'widgets/financial_summary_card.dart';
import 'widgets/quick_suggestion_chips.dart';
import 'widgets/transaction_preview_card.dart';
import 'widgets/typing_indicator.dart';
import 'widgets/wallet_selection_sheet.dart';

class AiAssistantScreen extends StatefulWidget {
  const AiAssistantScreen({super.key});

  @override
  State<AiAssistantScreen> createState() => _AiAssistantScreenState();
}

class _AiAssistantScreenState extends State<AiAssistantScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final _database = DatabaseService();
  final _chatService = AiChatService();
  final _notificationService = NotificationService();
  final _speechInput = SpeechInputService();
  final List<ChatMessageModel> _messages = [];

  List<WalletModel> _wallets = [];
  Map<String, dynamic> _cachedFinanceContext = const {
    'context_status': 'loading',
  };
  bool _loading = false;
  bool _canSend = false;
  bool _listening = false;
  String _voiceInputPrefix = '';
  int _requestGeneration = 0;

  static const _suggestions = [
    'Đi chợ 250 nghìn',
    'Ăn sáng 35 nghìn',
    'Đổ xăng 100 nghìn',
    'Nhận lương 12 triệu',
    'Chi tiêu hôm nay',
    'Ngân sách ăn uống',
    'Gợi ý tiết kiệm',
  ];

  String get _userId => FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void initState() {
    super.initState();
    _messageController.addListener(_onInputChanged);
    unawaited(_initialize());
  }

  @override
  void dispose() {
    _chatService.cancelActiveRequest();
    unawaited(_speechInput.cancel());
    _messageController.removeListener(_onInputChanged);
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onInputChanged() {
    final value = _messageController.text.trim().isNotEmpty;
    if (mounted && value != _canSend) setState(() => _canSend = value);
  }

  Future<void> _initialize() async {
    await _loadWallets();
    await _refreshFinanceContext();
  }

  Future<void> _loadWallets() async {
    if (_userId.isEmpty) return;
    try {
      final wallets = await _database
          .getWallets(_userId)
          .timeout(const Duration(seconds: 10));
      if (mounted) setState(() => _wallets = wallets);
    } catch (_) {
      // Chat queries still work with partial financial context.
    }
  }

  Future<Map<String, dynamic>> _financeContext() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final monthStart = DateTime(now.year, now.month, 1);
    final nextMonth = DateTime(now.year, now.month + 1, 1);
    final previousMonthStart = DateTime(now.year, now.month - 1, 1);
    final weekStart = today.subtract(Duration(days: today.weekday - 1));
    final previousWeekStart = weekStart.subtract(const Duration(days: 7));
    final data = await Future.wait([
      _database.getTransactions(_userId),
      _database.getBudgets(_userId, now.month, now.year),
    ]).timeout(const Duration(seconds: 10));
    final transactions = data[0] as List<TransactionModel>;
    final budgets = data[1] as List<BudgetModel>;

    double sum(Iterable<TransactionModel> values) =>
        values.fold(0, (total, item) => total + item.amount);

    final todayExpenses = transactions
        .where(
          (item) =>
              item.isExpense &&
              item.date.year == today.year &&
              item.date.month == today.month &&
              item.date.day == today.day,
        )
        .toList();
    final weekExpenses = transactions
        .where(
          (item) =>
              item.isExpense &&
              !item.date.isBefore(weekStart) &&
              item.date.isBefore(today.add(const Duration(days: 1))),
        )
        .toList();
    final previousWeekExpenses = transactions
        .where(
          (item) =>
              item.isExpense &&
              !item.date.isBefore(previousWeekStart) &&
              item.date.isBefore(weekStart),
        )
        .toList();
    final monthTransactions = transactions
        .where(
          (item) =>
              !item.date.isBefore(monthStart) && item.date.isBefore(nextMonth),
        )
        .toList();
    final monthExpenses = monthTransactions
        .where((item) => item.isExpense)
        .toList();
    final monthIncome = monthTransactions
        .where((item) => item.isIncome)
        .toList();
    final previousExpenses = transactions
        .where(
          (item) =>
              item.isExpense &&
              !item.date.isBefore(previousMonthStart) &&
              item.date.isBefore(monthStart),
        )
        .toList();
    final categoryTotals = <String, double>{};
    for (final item in monthExpenses) {
      final name = CategoryModel.getById(item.categoryId).name;
      categoryTotals.update(
        name,
        (value) => value + item.amount,
        ifAbsent: () => item.amount,
      );
    }

    return {
      'today_expense': sum(todayExpenses),
      'today_transaction_count': todayExpenses.length,
      'week_expense': sum(weekExpenses),
      'week_transaction_count': weekExpenses.length,
      'previous_week_expense': sum(previousWeekExpenses),
      'month_expense': sum(monthExpenses),
      'month_income': sum(monthIncome),
      'month_transaction_count': monthTransactions.length,
      'previous_month_expense': sum(previousExpenses),
      'wallet_total': _wallets.fold<double>(
        0,
        (total, wallet) => total + wallet.balance,
      ),
      'category_expense_this_month': categoryTotals,
      'budgets': budgets
          .map(
            (budget) => {
              'category': CategoryModel.getById(budget.categoryId).name,
              'limit': budget.limitAmount,
              'spent':
                  categoryTotals[CategoryModel.getById(
                    budget.categoryId,
                  ).name] ??
                  0,
            },
          )
          .toList(),
    };
  }

  Future<void> _refreshFinanceContext() async {
    try {
      _cachedFinanceContext = await _financeContext();
    } catch (_) {
      _cachedFinanceContext = {
        'wallet_total': _wallets.fold<double>(
          0,
          (total, wallet) => total + wallet.balance,
        ),
        'context_status': 'partial',
      };
    }
  }

  Future<void> _send([String? suggestion]) async {
    final text = (suggestion ?? _messageController.text).trim();
    if (text.isEmpty || _loading) return;
    if (_userId.isEmpty) {
      _showError('Bạn cần đăng nhập để sử dụng Moni AI.');
      return;
    }
    FocusScope.of(context).unfocus();
    if (_listening) {
      await _speechInput.stop();
      if (!mounted) return;
      setState(() => _listening = false);
    }
    _messageController.clear();
    final generation = ++_requestGeneration;
    setState(() {
      _messages.add(
        ChatMessageModel(
          id: _id(),
          role: ChatRole.user,
          type: ChatMessageType.text,
          content: text,
        ),
      );
      _loading = true;
    });
    _scrollToBottom();

    try {
      final result = await _chatService.send(
        message: text,
        currentDate: DateTime.now(),
        wallets: _wallets,
        financeContext: Map<String, dynamic>.from(_cachedFinanceContext),
      );
      if (!mounted || generation != _requestGeneration) return;
      WalletModel? suggestedWallet;
      if (result.wallet != null) {
        for (final wallet in _wallets) {
          if (wallet.id.toString() == result.wallet ||
              wallet.name.toLowerCase() == result.wallet!.toLowerCase()) {
            suggestedWallet = wallet;
            break;
          }
        }
      }
      final type = result.isTransaction
          ? ChatMessageType.transactionPreview
          : result.intent == 'get_anomalies'
          ? ChatMessageType.warningCard
          : result.intent == 'unknown'
          ? ChatMessageType.text
          : ChatMessageType.statisticCard;
      setState(() {
        _messages.add(
          ChatMessageModel(
            id: _id(),
            role: ChatRole.assistant,
            type: type,
            content: result.message,
            transactionPreview: result.isTransaction ? result : null,
            wallet: suggestedWallet,
            statisticCard: result.isTransaction ? null : _statisticData(result),
          ),
        );
      });
    } catch (error) {
      if (!mounted || generation != _requestGeneration) return;
      setState(() {
        _messages.add(
          ChatMessageModel(
            id: _id(),
            role: ChatRole.assistant,
            type: ChatMessageType.errorCard,
            content: error.toString(),
            status: ChatMessageStatus.failed,
            retryText: text,
          ),
        );
      });
    } finally {
      if (mounted && generation == _requestGeneration) {
        setState(() => _loading = false);
      }
      _scrollToBottom();
    }
  }

  void _cancelRequest() {
    if (!_loading) return;
    _requestGeneration++;
    _chatService.cancelActiveRequest();
    setState(() {
      _loading = false;
      _messages.add(
        ChatMessageModel(
          id: _id(),
          role: ChatRole.assistant,
          type: ChatMessageType.text,
          content: 'Đã hủy yêu cầu. Bạn có thể nhập câu khác.',
        ),
      );
    });
    _scrollToBottom();
  }

  Future<void> _toggleVoiceInput() async {
    if (_loading) return;
    if (_listening || _speechInput.isListening) {
      await _speechInput.stop();
      if (mounted) setState(() => _listening = false);
      return;
    }

    FocusScope.of(context).unfocus();
    _voiceInputPrefix = _messageController.text.trim();
    await _speechInput.start(
      onWords: (words) {
        if (!mounted || words.trim().isEmpty) return;
        final value = _voiceInputPrefix.isEmpty
            ? words.trim()
            : '$_voiceInputPrefix ${words.trim()}';
        _messageController.value = TextEditingValue(
          text: value,
          selection: TextSelection.collapsed(offset: value.length),
        );
      },
      onListeningChanged: (value) {
        if (mounted && _listening != value) {
          setState(() => _listening = value);
        }
      },
      onError: (message) {
        if (mounted) _showError(message);
      },
    );
  }

  Map<String, dynamic> _statisticData(AiChatResult result) {
    final context = _cachedFinanceContext;
    double number(String key) => (context[key] as num?)?.toDouble() ?? 0;
    int count(String key) => (context[key] as num?)?.toInt() ?? 0;
    String title = 'Phân tích tài chính';
    String primary = '';
    String description = result.message;
    IconData icon = AppIcons.insightsRounded;
    Color color = AppColors.tealPrimary;
    String action = 'Mở báo cáo';

    switch (result.intent) {
      case 'get_daily_summary':
        title = 'Chi tiêu hôm nay';
        primary = _money(number('today_expense'));
        description = '${count('today_transaction_count')} giao dịch hôm nay';
        icon = AppIcons.todayRounded;
        break;
      case 'get_weekly_summary':
        final current = number('week_expense');
        final previous = number('previous_week_expense');
        final change = previous > 0 ? (current - previous) / previous * 100 : 0;
        title = 'Chi tiêu tuần này';
        primary = _money(current);
        description =
            '${count('week_transaction_count')} giao dịch • '
            '${change >= 0 ? 'Tăng' : 'Giảm'} '
            '${change.abs().toStringAsFixed(1)}% so với tuần trước';
        icon = AppIcons.dateRangeRounded;
        color = change > 0 ? AppColors.warning : AppColors.income;
        break;
      case 'get_monthly_summary':
        title = 'Chi tiêu tháng này';
        primary = _money(number('month_expense'));
        description =
            '${count('month_transaction_count')} giao dịch • '
            'Thu nhập ${_money(number('month_income'))}';
        icon = AppIcons.calendarMonthRounded;
        break;
      case 'get_top_category':
        final categories = Map<String, dynamic>.from(
          context['category_expense_this_month'] as Map? ?? const {},
        );
        MapEntry<String, dynamic>? top;
        for (final entry in categories.entries) {
          if (top == null ||
              (entry.value as num).toDouble() > (top.value as num).toDouble()) {
            top = entry;
          }
        }
        final amount = (top?.value as num?)?.toDouble() ?? 0;
        final total = number('month_expense');
        final percent = total > 0 ? amount / total * 100 : 0;
        title = 'Danh mục chi nhiều nhất';
        primary = top?.key ?? 'Chưa có dữ liệu';
        description =
            '${_money(amount)} • Chiếm ${percent.toStringAsFixed(1)}% tổng chi';
        icon = AppIcons.donutLargeRounded;
        color = AppColors.roseAccent;
        action = 'Xem giao dịch';
        break;
      case 'compare_months':
        final current = number('month_expense');
        final previous = number('previous_month_expense');
        final change = previous > 0 ? (current - previous) / previous * 100 : 0;
        title = 'So sánh hai tháng';
        primary =
            '${change >= 0 ? '+' : '-'}${change.abs().toStringAsFixed(1)}%';
        description =
            'Tháng này ${_money(current)} • Tháng trước ${_money(previous)}';
        icon = change >= 0
            ? AppIcons.trendingUpRounded
            : AppIcons.trendingDownRounded;
        color = change > 0 ? AppColors.error : AppColors.income;
        break;
      case 'get_budget_status':
        final budgets = (context['budgets'] as List?) ?? const [];
        Map<String, dynamic>? selected;
        for (final value in budgets) {
          final budget = Map<String, dynamic>.from(value as Map);
          if (result.category != null &&
              budget['category'].toString().toLowerCase() ==
                  result.category!.toLowerCase()) {
            selected = budget;
            break;
          }
          selected ??= budget;
        }
        final limit = (selected?['limit'] as num?)?.toDouble() ?? 0;
        final spent = (selected?['spent'] as num?)?.toDouble() ?? 0;
        title = 'Ngân sách ${selected?['category'] ?? ''}'.trim();
        primary = _money((limit - spent).clamp(0, double.infinity));
        description = limit <= 0
            ? 'Bạn chưa tạo ngân sách phù hợp.'
            : 'Còn lại • Đã dùng ${(spent / limit * 100).toStringAsFixed(0)}%';
        icon = AppIcons.pieChartRounded;
        color = limit > 0 && spent >= limit
            ? AppColors.error
            : AppColors.warning;
        break;
      case 'get_wallet_balance':
        title = 'Tổng số dư';
        primary = _money(number('wallet_total'));
        description = '${_wallets.length} ví đang hoạt động';
        icon = AppIcons.accountBalanceWalletRounded;
        color = AppColors.income;
        break;
      case 'get_saving_advice':
        final income = number('month_income');
        final saving = income - number('month_expense');
        final rate = income > 0 ? saving / income * 100 : 0;
        title = 'Khả năng tiết kiệm';
        primary = _money(saving);
        description = 'Tỷ lệ tiết kiệm tháng này: ${rate.toStringAsFixed(1)}%';
        icon = AppIcons.savingsRounded;
        color = saving >= 0 ? AppColors.income : AppColors.error;
        action = 'Xem gợi ý';
        break;
      case 'get_forecast':
        title = 'Dự báo chi tiêu';
        primary = 'Prophet AI';
        description = result.message;
        icon = AppIcons.autoGraphRounded;
        color = AppColors.purpleAccent;
        action = 'Mở dự báo';
        break;
      case 'get_anomalies':
        title = 'Cảnh báo bất thường';
        primary = 'Kiểm tra chi tiêu';
        description = result.message;
        icon = AppIcons.warningAmberRounded;
        color = AppColors.warning;
        action = 'Xem cảnh báo';
        break;
    }
    return {
      'intent': result.intent,
      'title': title,
      'primary': primary,
      'description': description,
      'icon': icon,
      'color': color,
      'action': action,
    };
  }

  Future<void> _chooseWallet(ChatMessageModel message) async {
    final result = message.transactionPreview;
    if (result == null) return;
    final wallet = await showModalBottomSheet<WalletModel>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => WalletSelectionSheet(
        wallets: _wallets,
        amount: result.amount ?? 0,
        isExpense: result.isExpense,
      ),
    );
    if (wallet != null && mounted) setState(() => message.wallet = wallet);
  }

  Future<void> _saveTransaction(ChatMessageModel message) async {
    if (message.saving || message.saved || message.cancelled) return;
    final result = message.transactionPreview;
    final wallet = message.wallet;
    if (result == null || result.amount == null || result.amount! <= 0) {
      _showError('Giao dịch đang thiếu số tiền.');
      return;
    }
    if (result.date == null) {
      _showError('Hãy chọn ngày giao dịch trước khi lưu.');
      return;
    }
    if (wallet == null) {
      _showError('Hãy chọn ví trước khi lưu.');
      return;
    }
    if (result.isExpense && wallet.balance < result.amount!) {
      _showError('Số dư ví không đủ để lưu khoản chi này.');
      return;
    }
    final category = _categoryFor(result);
    setState(() => message.saving = true);
    try {
      await _database.insertTransaction(
        TransactionModel(
          userId: _userId,
          title: result.description?.trim().isNotEmpty == true
              ? result.description!.trim()
              : category.name,
          amount: result.amount!,
          categoryId: category.id,
          walletId: wallet.id!,
          date: result.date!,
          note: result.merchant,
          type: result.isExpense ? 'expense' : 'income',
        ),
      );
      final remainingBalance = result.isExpense
          ? wallet.balance - result.amount!
          : wallet.balance + result.amount!;
      if (mounted) {
        setState(() {
          message.saved = true;
          _messages.add(
            ChatMessageModel(
              id: _id(),
              role: ChatRole.assistant,
              type: ChatMessageType.text,
              content:
                  'Đã lưu ${result.isExpense ? 'khoản chi' : 'khoản thu'} '
                  '${_money(result.amount!)} vào ví ${wallet.name}. '
                  'Số dư còn lại: ${_money(remainingBalance)}.',
            ),
          );
        });
      }
      unawaited(_notificationService.evaluate(_userId).catchError((_) {}));
      await _loadWallets();
      unawaited(_refreshFinanceContext());
      _scrollToBottom();
    } catch (error) {
      if (mounted) {
        setState(() {
          _messages.add(
            ChatMessageModel(
              id: _id(),
              role: ChatRole.assistant,
              type: ChatMessageType.errorCard,
              content: 'Không thể lưu giao dịch: $error',
              status: ChatMessageStatus.failed,
              retryText: message.content,
            ),
          );
        });
      }
    } finally {
      if (mounted) setState(() => message.saving = false);
    }
  }

  CategoryModel _categoryFor(AiChatResult result) {
    final values = result.isExpense
        ? CategoryModel.expenseCategories
        : CategoryModel.incomeCategories;
    final requested = result.category?.toLowerCase();
    for (final category in values) {
      if (category.name.toLowerCase() == requested) return category;
    }
    if (!result.isExpense && result.category == 'Thu nhập') {
      return CategoryModel.incomeCategories.first;
    }
    return values.last;
  }

  Future<void> _editPreview(ChatMessageModel message) async {
    var result = message.transactionPreview!;
    final amountController = TextEditingController(
      text: result.amount == null ? '' : formatVndInput(result.amount!),
    );
    final descriptionController = TextEditingController(
      text: result.description ?? '',
    );
    var category = _categoryFor(result);
    var date = result.date ?? DateTime.now();
    final edited = await showModalBottomSheet<AiChatResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.navyCard,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            MediaQuery.viewInsetsOf(context).bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Chỉnh sửa giao dịch',
                  style: GoogleFonts.outfit(
                    color: AppColors.textPrimary,
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  inputFormatters: const [VndInputFormatter()],
                  decoration: const InputDecoration(
                    labelText: 'Số tiền',
                    suffixText: 'VND',
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<CategoryModel>(
                  initialValue: category,
                  dropdownColor: AppColors.navyCard,
                  decoration: const InputDecoration(labelText: 'Danh mục'),
                  items:
                      (result.isExpense
                              ? CategoryModel.expenseCategories
                              : CategoryModel.incomeCategories)
                          .map(
                            (item) => DropdownMenuItem(
                              value: item,
                              child: Text(item.name),
                            ),
                          )
                          .toList(),
                  onChanged: (value) => setSheetState(() => category = value!),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(labelText: 'Ghi chú'),
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Ngày giao dịch'),
                  subtitle: Text('${date.day}/${date.month}/${date.year}'),
                  trailing: const Icon(AppIcons.calendarTodayRounded),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: date,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (picked != null) setSheetState(() => date = picked);
                  },
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      final amount = parseVndInput(amountController.text);
                      if (amount == null || amount <= 0) return;
                      Navigator.pop(
                        sheetContext,
                        result.copyWith(
                          amount: amount,
                          category: category.name,
                          description: descriptionController.text.trim(),
                          date: date,
                        ),
                      );
                    },
                    child: const Text('Cập nhật bản xem trước'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    amountController.dispose();
    descriptionController.dispose();
    if (edited != null && mounted) {
      setState(() => message.transactionPreview = edited);
    }
  }

  @override
  Widget build(BuildContext context) {
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    return Scaffold(
      backgroundColor: AppColors.navyDeep,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: AppColors.navyMid,
        titleSpacing: 16,
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                gradient: AppColors.aiCardGradient,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                AppIcons.autoAwesomeRounded,
                color: Colors.white,
                size: 21,
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Moni AI',
                  style: GoogleFonts.outfit(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 17,
                  ),
                ),
                Text(
                  'Trợ lý tài chính cá nhân',
                  style: GoogleFonts.outfit(
                    color: AppColors.textSecondary,
                    fontSize: 10.5,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Lịch sử trong phiên',
            onPressed: _messages.isEmpty ? null : _showSessionHistory,
            icon: const Icon(AppIcons.historyRounded),
          ),
          IconButton(
            tooltip: 'Xóa cuộc trò chuyện',
            onPressed: _messages.isEmpty ? null : _clearConversation,
            icon: const Icon(AppIcons.deleteOutlineRounded),
          ),
        ],
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.translucent,
        child: Column(
          children: [
            Expanded(
              child: _messages.isEmpty
                  ? _welcome()
                  : ListView.builder(
                      controller: _scrollController,
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 16),
                      itemCount: _messages.length + (_loading ? 1 : 0),
                      itemBuilder: (_, index) {
                        if (index == _messages.length) {
                          return TypingIndicator(onCancel: _cancelRequest);
                        }
                        return _messageWidget(_messages[index]);
                      },
                    ),
            ),
            if (!keyboardOpen && _messages.isNotEmpty)
              QuickSuggestionChips(
                suggestions: _suggestions,
                enabled: !_loading && !_listening,
                onSelected: _send,
              ),
            ChatInputBar(
              controller: _messageController,
              canSend: _canSend,
              loading: _loading,
              listening: _listening,
              onSend: _send,
              onMicrophone: _toggleVoiceInput,
            ),
          ],
        ),
      ),
    );
  }

  Widget _welcome() {
    const items = [
      (
        AppIcons.addCardRounded,
        'Ghi một khoản chi',
        'Đi chợ 250 nghìn',
        AppColors.roseAccent,
      ),
      (
        AppIcons.todayRounded,
        'Chi tiêu hôm nay',
        'Hôm nay tôi đã chi bao nhiêu?',
        Color(0xFF60A5FA),
      ),
      (
        AppIcons.pieChartRounded,
        'Ngân sách còn lại',
        'Ngân sách còn bao nhiêu?',
        AppColors.warning,
      ),
      (
        AppIcons.savingsRounded,
        'Gợi ý tiết kiệm',
        'Tôi nên tiết kiệm thế nào?',
        AppColors.tealPrimary,
      ),
    ];
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
      children: [
        Container(
          width: 76,
          height: 76,
          decoration: BoxDecoration(
            gradient: AppColors.aiCardGradient,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.purpleAccent.withAlpha(65),
                blurRadius: 24,
                offset: const Offset(0, 9),
              ),
            ],
          ),
          child: const Icon(
            AppIcons.autoAwesomeRounded,
            color: Colors.white,
            size: 34,
          ),
        ),
        const SizedBox(height: 18),
        Text(
          'Xin chào, mình là Moni AI 👋',
          textAlign: TextAlign.center,
          style: GoogleFonts.outfit(
            color: AppColors.textPrimary,
            fontSize: 23,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Mình có thể giúp bạn ghi giao dịch, kiểm tra ngân sách '
          'và phân tích chi tiêu.',
          textAlign: TextAlign.center,
          style: GoogleFonts.outfit(
            color: AppColors.textSecondary,
            fontSize: 13,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 26),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 1.25,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
          ),
          itemBuilder: (_, index) {
            final item = items[index];
            return Material(
              color: AppColors.navyCard,
              borderRadius: BorderRadius.circular(18),
              child: InkWell(
                onTap: () => _send(item.$3),
                borderRadius: BorderRadius.circular(18),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: item.$4.withAlpha(65)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(item.$1, color: item.$4, size: 23),
                      const Spacer(),
                      Text(
                        item.$2,
                        style: GoogleFonts.outfit(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _messageWidget(ChatMessageModel message) {
    if (message.type == ChatMessageType.errorCard) {
      return ChatErrorCard(
        message: message.content,
        onRetry: () => _send(message.retryText),
        onManualEntry: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AddEditExpenseScreen()),
        ),
      );
    }
    final widgets = <Widget>[ChatBubble(message: message)];
    if (message.type == ChatMessageType.transactionPreview &&
        message.transactionPreview != null) {
      widgets.add(
        TransactionPreviewCard(
          result: message.transactionPreview!,
          category: _categoryFor(message.transactionPreview!),
          wallet: message.wallet,
          saved: message.saved,
          saving: message.saving,
          cancelled: message.cancelled,
          onEdit: () => _editPreview(message),
          onCancel: () => setState(() => message.cancelled = true),
          onChooseWallet: () => _chooseWallet(message),
          onSave: () => _saveTransaction(message),
        ),
      );
    }
    if (message.type == ChatMessageType.statisticCard &&
        message.statisticCard != null) {
      final card = message.statisticCard!;
      widgets.add(
        FinancialSummaryCard(
          title: card['title'] as String,
          primaryValue: card['primary'] as String,
          description: card['description'] as String,
          icon: card['icon'] as IconData,
          color: card['color'] as Color,
          actionLabel: card['action'] as String?,
          onAction: () => _openReport(card['intent'] as String),
        ),
      );
    }
    if (message.type == ChatMessageType.warningCard &&
        message.statisticCard != null) {
      widgets.add(
        AnomalyWarningCard(
          message: message.statisticCard!['description'] as String,
          onViewDetails: () => _openReport('get_anomalies'),
        ),
      );
    }
    return Column(children: widgets);
  }

  void _openReport(String intent) {
    if (intent == 'get_top_category') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ExpensesScreen()),
      );
      return;
    }
    if (intent == 'get_forecast' ||
        intent == 'get_anomalies' ||
        intent == 'get_saving_advice') {
      final section = intent == 'get_anomalies'
          ? 1
          : intent == 'get_saving_advice'
          ? 2
          : 0;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AiAnalysisScreen(initialSection: section),
        ),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MonthlyStatisticsScreen(initialMonth: DateTime.now()),
      ),
    );
  }

  void _clearConversation() {
    _cancelRequest();
    setState(() => _messages.clear());
  }

  void _showSessionHistory() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.navyCard,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 22),
          itemCount: _messages.length,
          separatorBuilder: (_, _) =>
              const Divider(color: AppColors.navyBorder),
          itemBuilder: (_, index) {
            final message = _messages[index];
            return ListTile(
              leading: CircleAvatar(
                backgroundColor: message.isUser
                    ? AppColors.tealPrimary.withAlpha(30)
                    : AppColors.purpleAccent.withAlpha(30),
                child: Icon(
                  message.isUser
                      ? AppIcons.personRounded
                      : AppIcons.autoAwesomeRounded,
                  color: message.isUser
                      ? AppColors.tealPrimary
                      : AppColors.purpleAccent,
                  size: 19,
                ),
              ),
              title: Text(
                message.isUser ? 'Bạn' : 'Moni AI',
                style: GoogleFonts.outfit(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                message.content,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            );
          },
        ),
      ),
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
    });
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.navyCard,
        behavior: SnackBarBehavior.floating,
        content: Text(message),
      ),
    );
  }

  String _money(double amount) => '${formatVndInput(amount)}đ';

  String _id() => DateTime.now().microsecondsSinceEpoch.toString();
}
