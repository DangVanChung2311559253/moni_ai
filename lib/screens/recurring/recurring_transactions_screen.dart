import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../models/category_model.dart';
import '../../models/recurring_transaction_model.dart';
import '../../models/wallet_model.dart';
import '../../services/database_service.dart';
import '../../services/recurring_transaction_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/vnd_input_formatter.dart';

class RecurringTransactionsScreen extends StatefulWidget {
  const RecurringTransactionsScreen({super.key});

  @override
  State<RecurringTransactionsScreen> createState() =>
      _RecurringTransactionsScreenState();
}

class _RecurringTransactionsScreenState
    extends State<RecurringTransactionsScreen> {
  final _service = RecurringTransactionService();
  List<RecurringTransaction> _plans = [];
  List<RecurringOccurrence> _pending = [];
  bool _loading = true;

  String get _userId => FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (_userId.isEmpty) {
      setState(() => _loading = false);
      return;
    }
    try {
      await _service.syncDue(_userId);
      final results = await Future.wait([
        _service.getPlans(_userId),
        _service.getOccurrences(_userId, status: 'pending'),
      ]);
      if (!mounted) return;
      setState(() {
        _plans = results[0] as List<RecurringTransaction>;
        _pending = results[1] as List<RecurringOccurrence>;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      _error(error);
    }
  }

  RecurringTransaction? _planFor(String id) {
    for (final plan in _plans) {
      if (plan.id == id) return plan;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.navyDeep,
      appBar: AppBar(
        backgroundColor: AppColors.navyMid,
        title: Text(
          'Chi tiêu định kỳ',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w700),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.tealPrimary),
            )
          : RefreshIndicator(
              onRefresh: _load,
              color: AppColors.tealPrimary,
              backgroundColor: AppColors.navyCard,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 110),
                children: [
                  _overview(),
                  if (_pending.isNotEmpty) ...[
                    const SizedBox(height: 22),
                    _heading(
                      'Chờ xác nhận',
                      '${_pending.length} kỳ đến hạn',
                      AppColors.warning,
                    ),
                    const SizedBox(height: 10),
                    ..._pending.map(_pendingCard),
                  ],
                  const SizedBox(height: 22),
                  _heading(
                    'Khoản định kỳ',
                    '${_plans.length} khoản',
                    AppColors.tealPrimary,
                  ),
                  const SizedBox(height: 10),
                  if (_plans.isEmpty) _empty() else ..._plans.map(_planCard),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(),
        backgroundColor: AppColors.tealPrimary,
        foregroundColor: Colors.white,
        icon: const Icon(AppIcons.addRounded),
        label: Text(
          'Tạo khoản định kỳ',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  Widget _overview() {
    final active = _plans.where((plan) => plan.status == 'active').length;
    final monthlyExpense = _plans
        .where(
          (plan) =>
              plan.status == 'active' &&
              plan.isExpense &&
              plan.frequency == 'monthly',
        )
        .fold<double>(0, (sum, plan) => sum + plan.amount);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF5B63B7), Color(0xFF7C6FCD)],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.purpleAccent.withAlpha(50),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(30),
              borderRadius: BorderRadius.circular(17),
            ),
            child: const Icon(
              AppIcons.eventRepeatRounded,
              color: Colors.white,
              size: 29,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$active khoản đang hoạt động',
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Chi cố định theo tháng: ${_money(monthlyExpense)}',
                  style: GoogleFonts.outfit(
                    color: Colors.white.withAlpha(190),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _heading(String title, String count, Color color) => Row(
    children: [
      Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 8),
      Text(
        title,
        style: GoogleFonts.outfit(
          color: AppColors.textPrimary,
          fontSize: 17,
          fontWeight: FontWeight.w700,
        ),
      ),
      const Spacer(),
      Text(
        count,
        style: GoogleFonts.outfit(color: AppColors.textMuted, fontSize: 11),
      ),
    ],
  );

  Widget _pendingCard(RecurringOccurrence occurrence) {
    final plan = _planFor(occurrence.recurringId);
    if (plan == null) return const SizedBox.shrink();
    final category = CategoryModel.getById(plan.categoryId);
    return Container(
      margin: const EdgeInsets.only(bottom: 11),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.warning.withAlpha(17),
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: AppColors.warning.withAlpha(95)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 45,
                height: 45,
                decoration: BoxDecoration(
                  color: category.color.withAlpha(30),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(category.icon, color: category.color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      plan.name,
                      style: GoogleFonts.outfit(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'Đến hạn ${DateFormat('dd/MM/yyyy').format(occurrence.dueDate)}',
                      style: GoogleFonts.outfit(
                        color: AppColors.warning,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${plan.isExpense ? '-' : '+'}${_money(plan.amount)}',
                style: GoogleFonts.outfit(
                  color: plan.isExpense ? AppColors.error : AppColors.income,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              TextButton.icon(
                onPressed: () => _skip(occurrence),
                icon: const Icon(AppIcons.skipNextRounded, size: 18),
                label: const Text('Bỏ qua'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.textSecondary,
                ),
              ),
              const Spacer(),
              OutlinedButton(
                onPressed: () => _openEditor(plan),
                child: const Text('Chỉnh sửa'),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: () => _confirm(occurrence, plan),
                icon: const Icon(AppIcons.checkRounded, size: 18),
                label: const Text('Xác nhận'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.tealPrimary,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _planCard(RecurringTransaction plan) {
    final category = CategoryModel.getById(plan.categoryId);
    final active = plan.status == 'active';
    return Container(
      margin: const EdgeInsets.only(bottom: 11),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.navyCard,
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: AppColors.navyBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: category.color.withAlpha(active ? 31 : 15),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(
              category.icon,
              color: active ? category.color : AppColors.textMuted,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  plan.name,
                  style: GoogleFonts.outfit(
                    color: active ? AppColors.textPrimary : AppColors.textMuted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${_frequencyName(plan.frequency)} • '
                  'Kỳ tới ${DateFormat('dd/MM').format(plan.nextDueDate)}',
                  style: GoogleFonts.outfit(
                    color: AppColors.textMuted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _money(plan.amount),
                style: GoogleFonts.outfit(
                  color: plan.isExpense ? AppColors.error : AppColors.income,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              PopupMenuButton<String>(
                padding: EdgeInsets.zero,
                icon: const Icon(
                  AppIcons.moreHorizRounded,
                  color: AppColors.textMuted,
                ),
                color: AppColors.navyCard,
                onSelected: (action) => _planAction(action, plan),
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'edit', child: Text('Chỉnh sửa')),
                  const PopupMenuItem(value: 'history', child: Text('Lịch sử')),
                  PopupMenuItem(
                    value: 'status',
                    child: Text(active ? 'Tạm dừng' : 'Tiếp tục'),
                  ),
                  const PopupMenuItem(value: 'delete', child: Text('Xóa')),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _empty() => Container(
    padding: const EdgeInsets.all(30),
    decoration: BoxDecoration(
      color: AppColors.navyCard,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: AppColors.navyBorder),
    ),
    child: Column(
      children: [
        const Icon(
          AppIcons.eventRepeatOutlined,
          color: AppColors.textMuted,
          size: 58,
        ),
        const SizedBox(height: 12),
        Text(
          'Chưa có khoản thu chi định kỳ',
          style: GoogleFonts.outfit(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          'Tạo tiền nhà, Internet, Netflix hoặc lương để được nhắc đúng hạn.',
          textAlign: TextAlign.center,
          style: GoogleFonts.outfit(
            color: AppColors.textSecondary,
            fontSize: 12,
          ),
        ),
      ],
    ),
  );

  Future<void> _openEditor([RecurringTransaction? plan]) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AddEditRecurringTransactionScreen(plan: plan),
      ),
    );
    if (changed == true) _load();
  }

  Future<void> _confirm(
    RecurringOccurrence occurrence,
    RecurringTransaction plan,
  ) async {
    final accepted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.navyCard,
        title: const Text('Xác nhận giao dịch'),
        content: Text(
          '${plan.isExpense ? 'Trừ' : 'Cộng'} ${_money(plan.amount)} '
          '${plan.isExpense ? 'khỏi' : 'vào'} ví đã chọn?\n\n'
          'Số dư chỉ thay đổi sau khi bạn xác nhận.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Để sau'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Xác nhận'),
          ),
        ],
      ),
    );
    if (accepted != true) return;
    try {
      await _service.confirmOccurrence(
        userId: _userId,
        occurrenceId: occurrence.id,
      );
      await _load();
    } catch (error) {
      _error(error);
    }
  }

  Future<void> _skip(RecurringOccurrence occurrence) async {
    try {
      await _service.skipOccurrence(_userId, occurrence.id);
      await _load();
    } catch (error) {
      _error(error);
    }
  }

  Future<void> _planAction(String action, RecurringTransaction plan) async {
    if (action == 'edit') return _openEditor(plan);
    if (action == 'history') return _showHistory(plan);
    try {
      if (action == 'status') {
        await _service.savePlan(
          id: plan.id,
          userId: plan.userId,
          name: plan.name,
          type: plan.type,
          amount: plan.amount,
          categoryId: plan.categoryId,
          walletId: plan.walletId,
          frequency: plan.frequency,
          nextDueDate: plan.nextDueDate,
          dueDay: plan.dueDay,
          reminderDays: plan.reminderDays,
          note: plan.note,
          status: plan.status == 'active' ? 'paused' : 'active',
        );
      } else if (action == 'delete') {
        final accepted = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            backgroundColor: AppColors.navyCard,
            title: const Text('Xóa khoản định kỳ?'),
            content: const Text(
              'Lịch sử kỳ định kỳ sẽ bị xóa. Giao dịch đã xác nhận vẫn được giữ.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Hủy'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Xóa'),
              ),
            ],
          ),
        );
        if (accepted != true) return;
        await _service.deletePlan(_userId, plan.id);
      }
      await _load();
    } catch (error) {
      _error(error);
    }
  }

  Future<void> _showHistory(RecurringTransaction plan) async {
    final history = await _service.getOccurrences(
      _userId,
      recurringId: plan.id,
    );
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        constraints: const BoxConstraints(maxHeight: 520),
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
        decoration: const BoxDecoration(
          color: AppColors.navyCard,
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        ),
        child: Column(
          children: [
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textMuted,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Lịch sử ${plan.name}',
              style: GoogleFonts.outfit(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: history.isEmpty
                  ? const Center(child: Text('Chưa có kỳ nào được xử lý.'))
                  : ListView.separated(
                      itemCount: history.length,
                      separatorBuilder: (_, _) =>
                          const Divider(color: AppColors.navyBorder),
                      itemBuilder: (_, index) {
                        final item = history[index];
                        final color = item.status == 'confirmed'
                            ? AppColors.income
                            : item.status == 'skipped'
                            ? AppColors.textMuted
                            : AppColors.warning;
                        return ListTile(
                          leading: Icon(
                            item.status == 'confirmed'
                                ? AppIcons.checkCircleRounded
                                : item.status == 'skipped'
                                ? AppIcons.skipNextRounded
                                : AppIcons.scheduleRounded,
                            color: color,
                          ),
                          title: Text(
                            DateFormat('dd/MM/yyyy').format(item.dueDate),
                          ),
                          subtitle: Text(_occurrenceStatus(item.status)),
                          trailing: Text(
                            _money(plan.amount),
                            style: TextStyle(color: color),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _error(Object error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.error,
        content: Text(error.toString().replaceFirst('Bad state: ', '')),
      ),
    );
  }
}

class AddEditRecurringTransactionScreen extends StatefulWidget {
  final RecurringTransaction? plan;
  const AddEditRecurringTransactionScreen({super.key, this.plan});

  @override
  State<AddEditRecurringTransactionScreen> createState() =>
      _AddEditRecurringTransactionScreenState();
}

class _AddEditRecurringTransactionScreenState
    extends State<AddEditRecurringTransactionScreen> {
  final _service = RecurringTransactionService();
  final _database = DatabaseService();
  final _name = TextEditingController();
  final _amount = TextEditingController();
  final _note = TextEditingController();
  List<WalletModel> _wallets = [];
  WalletModel? _wallet;
  String _type = 'expense';
  String _frequency = 'monthly';
  DateTime _dueDate = DateTime.now().add(const Duration(days: 1));
  int _reminderDays = 3;
  int _dueDay = DateTime.now().add(const Duration(days: 1)).day;
  CategoryModel _category = CategoryModel.expenseCategories.first;
  bool _loading = true;
  bool _saving = false;

  String get _userId => FirebaseAuth.instance.currentUser?.uid ?? '';
  bool get _editing => widget.plan != null;

  @override
  void initState() {
    super.initState();
    final plan = widget.plan;
    if (plan != null) {
      _name.text = plan.name;
      _amount.text = formatVndInput(plan.amount);
      _note.text = plan.note ?? '';
      _type = plan.type;
      _frequency = plan.frequency;
      _dueDate = plan.nextDueDate;
      _dueDay = plan.dueDay;
      _reminderDays = plan.reminderDays;
      _category = CategoryModel.getById(plan.categoryId);
    }
    _loadWallets();
  }

  Future<void> _loadWallets() async {
    try {
      final values = await _database.getWallets(_userId);
      if (!mounted) return;
      setState(() {
        _wallets = values;
        if (values.isNotEmpty) {
          final wantedId = widget.plan?.walletId;
          _wallet = values.firstWhere(
            (value) => value.id == wantedId,
            orElse: () => WalletModel.preferred(values)!,
          );
        }
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      _error(error);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final categories = _type == 'expense'
        ? CategoryModel.expenseCategories
        : CategoryModel.incomeCategories;
    return Scaffold(
      backgroundColor: AppColors.navyDeep,
      appBar: AppBar(
        backgroundColor: AppColors.navyMid,
        title: Text(
          _editing ? 'Chỉnh sửa định kỳ' : 'Tạo khoản định kỳ',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w700),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.tealPrimary),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _typeSelector(),
                  const SizedBox(height: 18),
                  _label('Thông tin giao dịch'),
                  TextField(
                    controller: _name,
                    decoration: const InputDecoration(
                      labelText: 'Tên khoản định kỳ',
                      hintText: 'Tiền nhà, Internet, Netflix...',
                      prefixIcon: Icon(AppIcons.editNoteRounded),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _amount,
                    keyboardType: TextInputType.number,
                    inputFormatters: const [VndInputFormatter()],
                    decoration: const InputDecoration(
                      labelText: 'Số tiền',
                      prefixIcon: Icon(AppIcons.paymentsRounded),
                      suffixText: '₫',
                    ),
                  ),
                  const SizedBox(height: 18),
                  _label('Danh mục'),
                  SizedBox(
                    height: 84,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: categories.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 9),
                      itemBuilder: (_, index) {
                        final value = categories[index];
                        final selected = _category.id == value.id;
                        return InkWell(
                          onTap: () => setState(() => _category = value),
                          borderRadius: BorderRadius.circular(15),
                          child: Container(
                            width: 92,
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: selected
                                  ? value.color.withAlpha(30)
                                  : AppColors.navyCard,
                              borderRadius: BorderRadius.circular(15),
                              border: Border.all(
                                color: selected
                                    ? value.color
                                    : AppColors.navyBorder,
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(value.icon, color: value.color, size: 22),
                                const SizedBox(height: 5),
                                Text(
                                  value.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.outfit(
                                    color: selected
                                        ? value.color
                                        : AppColors.textSecondary,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 18),
                  _label('Ví sử dụng'),
                  if (_wallets.isEmpty)
                    _notice('Bạn cần tạo ví trước khi tạo khoản định kỳ.')
                  else
                    DropdownButtonFormField<WalletModel>(
                      initialValue: _wallet,
                      dropdownColor: AppColors.navyCard,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(AppIcons.accountBalanceWalletRounded),
                      ),
                      items: _wallets
                          .map(
                            (value) => DropdownMenuItem(
                              value: value,
                              child: Text(
                                '${value.name} • ${_money(value.balance)}',
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) => setState(() => _wallet = value),
                    ),
                  const SizedBox(height: 18),
                  _label('Lặp lại'),
                  Row(
                    children: [
                      _frequencyButton('weekly', 'Tuần'),
                      const SizedBox(width: 8),
                      _frequencyButton('monthly', 'Tháng'),
                      const SizedBox(width: 8),
                      _frequencyButton('yearly', 'Năm'),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _label('Ngày đến hạn tiếp theo'),
                  InkWell(
                    onTap: _pickDate,
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.all(17),
                      decoration: BoxDecoration(
                        color: AppColors.navyCard,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.navyBorder),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            AppIcons.eventAvailableRounded,
                            color: AppColors.tealPrimary,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            DateFormat('dd/MM/yyyy').format(_dueDate),
                            style: GoogleFonts.outfit(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Spacer(),
                          const Icon(
                            AppIcons.chevronRightRounded,
                            color: AppColors.textMuted,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  _label('Nhắc trước'),
                  Row(
                    children: [0, 1, 3, 7]
                        .map(
                          (days) => Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(right: 7),
                              child: ChoiceChip(
                                selected: _reminderDays == days,
                                onSelected: (_) =>
                                    setState(() => _reminderDays = days),
                                label: Text(
                                  days == 0 ? 'Đúng ngày' : '$days ngày',
                                ),
                                selectedColor: AppColors.tealPrimary,
                                backgroundColor: AppColors.navyCard,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 18),
                  TextField(
                    controller: _note,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Ghi chú',
                      prefixIcon: Icon(AppIcons.notesRounded),
                    ),
                  ),
                  const SizedBox(height: 18),
                  _notice(
                    'Đến hạn, Moni AI chỉ tạo giao dịch chờ. '
                    'Tiền không tự động cộng hoặc trừ khi bạn bấm Xác nhận.',
                  ),
                  const SizedBox(height: 26),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _saving || _wallet == null ? null : _save,
                      icon: _saving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(AppIcons.checkCircleRounded),
                      label: Text(_editing ? 'Lưu thay đổi' : 'Tạo định kỳ'),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(56),
                        backgroundColor: AppColors.tealPrimary,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _typeSelector() => Container(
    padding: const EdgeInsets.all(5),
    decoration: BoxDecoration(
      color: AppColors.navyCard,
      borderRadius: BorderRadius.circular(17),
      border: Border.all(color: AppColors.navyBorder),
    ),
    child: Row(
      children: [
        _typeButton('expense', 'Chi định kỳ', AppIcons.northEastRounded),
        const SizedBox(width: 6),
        _typeButton('income', 'Thu định kỳ', AppIcons.southWestRounded),
      ],
    ),
  );

  Widget _typeButton(String type, String label, IconData icon) {
    final selected = _type == type;
    final color = type == 'expense' ? AppColors.error : AppColors.income;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() {
          _type = type;
          _category = type == 'expense'
              ? CategoryModel.expenseCategories.first
              : CategoryModel.incomeCategories.first;
        }),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 13),
          decoration: BoxDecoration(
            color: selected ? color.withAlpha(28) : Colors.transparent,
            borderRadius: BorderRadius.circular(13),
            border: Border.all(
              color: selected ? color.withAlpha(140) : Colors.transparent,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: selected ? color : AppColors.textMuted),
              const SizedBox(width: 7),
              Text(
                label,
                style: GoogleFonts.outfit(
                  color: selected ? color : AppColors.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _frequencyButton(String value, String label) {
    final selected = _frequency == value;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _frequency = value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 13),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.purpleAccent.withAlpha(35)
                : AppColors.navyCard,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? AppColors.purpleAccent : AppColors.navyBorder,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: GoogleFonts.outfit(
                color: selected
                    ? AppColors.textPrimary
                    : AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      text,
      style: GoogleFonts.outfit(
        color: AppColors.textSecondary,
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
    ),
  );

  Widget _notice(String text) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppColors.tealPrimary.withAlpha(16),
      borderRadius: BorderRadius.circular(15),
      border: Border.all(color: AppColors.tealPrimary.withAlpha(70)),
    ),
    child: Row(
      children: [
        const Icon(AppIcons.infoOutlineRounded, color: AppColors.tealPrimary),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.outfit(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
        ),
      ],
    ),
  );

  Future<void> _pickDate() async {
    final value = await showDatePicker(
      context: context,
      initialDate: _dueDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (value != null) {
      setState(() {
        _dueDate = value;
        _dueDay = value.day;
      });
    }
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) return _error('Vui lòng nhập tên.');
    final amount = parseVndInput(_amount.text) ?? 0;
    setState(() => _saving = true);
    try {
      await _service.savePlan(
        id: widget.plan?.id,
        userId: _userId,
        name: _name.text,
        type: _type,
        amount: amount,
        categoryId: _category.id,
        walletId: _wallet!.id!,
        frequency: _frequency,
        nextDueDate: _dueDate,
        dueDay: _dueDay,
        reminderDays: _reminderDays,
        note: _note.text,
        status: widget.plan?.status ?? 'active',
      );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      _error(error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _error(Object error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.error,
        content: Text(error.toString().replaceFirst('Bad state: ', '')),
      ),
    );
  }
}

String _money(double amount) =>
    '${NumberFormat.decimalPattern('vi_VN').format(amount.round())}₫';

String _frequencyName(String value) => switch (value) {
  'weekly' => 'Hàng tuần',
  'yearly' => 'Hàng năm',
  _ => 'Hàng tháng',
};

String _occurrenceStatus(String value) => switch (value) {
  'confirmed' => 'Đã xác nhận',
  'skipped' => 'Đã bỏ qua',
  _ => 'Chờ xác nhận',
};
