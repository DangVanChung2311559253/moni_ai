import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../models/category_model.dart';
import '../../models/wallet_model.dart';
import '../../models/transaction_model.dart';
import '../../services/database_service.dart';
import '../../services/ai_analysis_service.dart';
import '../../services/anomaly_alert_store.dart';
import '../../services/notification_service.dart';
import '../../models/ai_analysis_models.dart';
import '../../theme/app_theme.dart';
import '../../widgets/financial_brand_mark.dart';
import '../wallets/wallets_screen.dart';

class AddEditExpenseScreen extends StatefulWidget {
  final TransactionModel? existing;
  final String initialType;

  const AddEditExpenseScreen({
    super.key,
    this.existing,
    this.initialType = 'expense',
  }) : assert(initialType == 'expense' || initialType == 'income');

  @override
  State<AddEditExpenseScreen> createState() => _AddEditExpenseScreenState();
}

class _AddEditExpenseScreenState extends State<AddEditExpenseScreen> {
  final _db = DatabaseService();
  final _aiAnalysis = AiAnalysisService();
  final _alertStore = AnomalyAlertStore();
  final _notificationService = NotificationService();
  final _amountController = TextEditingController();
  final _titleController = TextEditingController();
  final _noteController = TextEditingController();

  List<WalletModel> _wallets = [];
  WalletModel? _selectedWallet;
  CategoryModel _selectedCategory = CategoryModel.expenseCategories.first;
  DateTime _selectedDate = DateTime.now();
  late String _transactionType;
  String _paymentMethod = 'cash';
  bool _loading = false;
  AnomalyResult? _confirmedAnomaly;

  bool get isExpense => _transactionType == 'expense';
  bool get isEditing => widget.existing != null;
  List<WalletModel> get _paymentWallets => _wallets
      .where((wallet) => _isCashWallet(wallet) == (_paymentMethod == 'cash'))
      .toList();

  @override
  void initState() {
    super.initState();
    _transactionType = widget.initialType;
    _selectedCategory = isExpense
        ? CategoryModel.expenseCategories.first
        : CategoryModel.incomeCategories.first;
    if (isEditing) _fillExisting();
    _loadWallets();
  }

  void _fillExisting() {
    final e = widget.existing!;
    _transactionType = e.type;
    _amountController.text = _formatAmountInput(e.amount);
    _titleController.text = e.title;
    _noteController.text = e.note ?? '';
    _selectedCategory = CategoryModel.getById(e.categoryId);
    _selectedDate = e.date;
  }

  Future<void> _loadWallets() async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final wallets = await _db.getWallets(uid);
    if (!mounted) return;
    setState(() {
      _wallets = wallets;
      if (isEditing && wallets.isNotEmpty) {
        _selectedWallet = wallets.firstWhere(
          (w) => w.id == widget.existing!.walletId,
          orElse: () => wallets.first,
        );
        _paymentMethod = _isCashWallet(_selectedWallet!) ? 'cash' : 'transfer';
      } else if (wallets.isNotEmpty) {
        _selectedWallet = WalletModel.preferred(wallets);
        _paymentMethod = _isCashWallet(_selectedWallet!) ? 'cash' : 'transfer';
      }
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    _titleController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.navyDeep,
      appBar: AppBar(
        backgroundColor: AppColors.navyMid,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            AppIcons.arrowBackIosNewRounded,
            color: AppColors.textPrimary,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          isEditing ? 'Chỉnh sửa giao dịch' : 'Thêm giao dịch',
          style: GoogleFonts.outfit(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTypeSelector(),
            const SizedBox(height: 16),
            _buildAmountCard(),
            const SizedBox(height: 20),
            _buildSection('Thanh toán bằng', _buildPaymentSection()),
            const SizedBox(height: 20),
            _buildSection('Danh mục', _buildCategoryGrid()),
            const SizedBox(height: 20),
            _buildSection('Thông tin', _buildInfoCard()),
            const SizedBox(height: 32),
            _buildSaveButton(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeSelector() {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: AppColors.navyCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.navyBorder),
      ),
      child: Row(
        children: [
          Expanded(
            child: _typeOption(
              type: 'expense',
              label: 'Chi tiêu',
              icon: AppIcons.northEastRounded,
              color: AppColors.error,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _typeOption(
              type: 'income',
              label: 'Thu nhập',
              icon: AppIcons.southWestRounded,
              color: AppColors.income,
            ),
          ),
        ],
      ),
    );
  }

  Widget _typeOption({
    required String type,
    required String label,
    required IconData icon,
    required Color color,
  }) {
    final selected = _transactionType == type;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => _selectTransactionType(type),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          color: selected ? color.withAlpha(38) : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? color.withAlpha(180) : Colors.transparent,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: selected ? color : AppColors.textMuted, size: 19),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.outfit(
                color: selected ? color : AppColors.textSecondary,
                fontSize: 14,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _selectTransactionType(String type) {
    if (_transactionType == type) return;
    setState(() {
      _transactionType = type;
      _selectedCategory = isExpense
          ? CategoryModel.expenseCategories.first
          : CategoryModel.incomeCategories.first;
    });
  }

  Widget _buildAmountCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: isExpense
            ? const LinearGradient(
                colors: [Color(0xFF2A1A1A), Color(0xFF1C1616)],
              )
            : const LinearGradient(
                colors: [Color(0xFF0D2A1A), Color(0xFF0A1E14)],
              ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isExpense
              ? AppColors.error.withAlpha(77)
              : AppColors.income.withAlpha(77),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Số tiền',
            style: GoogleFonts.outfit(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                isExpense ? '−' : '+',
                style: GoogleFonts.outfit(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: isExpense ? AppColors.error : AppColors.income,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _amountController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [_VndInputFormatter()],
                  style: GoogleFonts.outfit(
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                  decoration: InputDecoration(
                    hintText: '0',
                    hintStyle: GoogleFonts.outfit(
                      fontSize: 32,
                      color: AppColors.textMuted,
                      fontWeight: FontWeight.w700,
                    ),
                    border: InputBorder.none,
                    filled: false,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
              Text(
                '₫',
                style: GoogleFonts.outfit(
                  fontSize: 24,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [50000, 100000, 200000, 500000]
                .map(
                  (amount) => InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () => setState(
                      () => _amountController.text = _formatAmountInput(
                        amount.toDouble(),
                      ),
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(13),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withAlpha(31)),
                      ),
                      child: Text(
                        _compactMoney(amount),
                        style: GoogleFonts.outfit(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentSection() {
    final wallets = _paymentWallets;
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _paymentOption(
                method: 'cash',
                label: 'Tiền mặt',
                icon: AppIcons.paymentsRounded,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _paymentOption(
                method: 'transfer',
                label: 'Chuyển khoản',
                icon: AppIcons.accountBalanceRounded,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (wallets.isEmpty)
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: _openWallets,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.navyCard,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.navyBorder),
              ),
              child: Row(
                children: [
                  const Icon(
                    AppIcons.addCardRounded,
                    color: AppColors.tealPrimary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _paymentMethod == 'cash'
                          ? 'Chưa có ví tiền mặt'
                          : 'Chưa có ví ngân hàng hoặc ví điện tử',
                      style: GoogleFonts.outfit(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const Icon(
                    AppIcons.chevronRightRounded,
                    color: AppColors.textMuted,
                  ),
                ],
              ),
            ),
          )
        else
          SizedBox(
            height: 82,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: wallets.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (_, index) => _walletChoice(wallets[index]),
            ),
          ),
      ],
    );
  }

  Widget _paymentOption({
    required String method,
    required String label,
    required IconData icon,
  }) {
    final selected = _paymentMethod == method;
    return InkWell(
      borderRadius: BorderRadius.circular(15),
      onTap: () => _selectPaymentMethod(method),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.tealPrimary.withAlpha(31)
              : AppColors.navyCard,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: selected ? AppColors.tealPrimary : AppColors.navyBorder,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: selected ? AppColors.tealPrimary : AppColors.textMuted,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.outfit(
                color: selected
                    ? AppColors.textPrimary
                    : AppColors.textSecondary,
                fontSize: 13,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _walletChoice(WalletModel wallet) {
    final selected = _selectedWallet?.id == wallet.id;
    final type = wallet.walletType;
    return InkWell(
      borderRadius: BorderRadius.circular(15),
      onTap: () => setState(() => _selectedWallet = wallet),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 164,
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
        decoration: BoxDecoration(
          color: selected ? type.color.withAlpha(25) : AppColors.navyCard,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: selected ? type.color : AppColors.navyBorder,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            FinancialBrandMark(
              name: wallet.name,
              fallbackIcon: type.icon,
              fallbackColor: type.color,
              size: 38,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    wallet.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.outfit(
                      color: AppColors.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${NumberFormat.decimalPattern('vi_VN').format(wallet.balance)}₫',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.outfit(
                      color: AppColors.textMuted,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
            if (selected)
              Icon(AppIcons.checkCircleRounded, color: type.color, size: 17),
          ],
        ),
      ),
    );
  }

  bool _isCashWallet(WalletModel wallet) => wallet.type == 'cash';

  void _selectPaymentMethod(String method) {
    if (_paymentMethod == method) return;
    setState(() {
      _paymentMethod = method;
      _selectedWallet = _paymentWallets.isEmpty ? null : _paymentWallets.first;
    });
  }

  Future<void> _openWallets() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const WalletsScreen()),
    );
    await _loadWallets();
  }

  Widget _buildSection(String title, Widget child) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.outfit(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 10),
        child,
      ],
    );
  }

  Widget _buildCategoryGrid() {
    final cats = isExpense
        ? CategoryModel.expenseCategories
        : CategoryModel.incomeCategories;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        childAspectRatio: 0.85,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: cats.length,
      itemBuilder: (_, i) {
        final cat = cats[i];
        final selected = _selectedCategory.id == cat.id;
        return GestureDetector(
          onTap: () => setState(() => _selectedCategory = cat),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: selected ? cat.color.withAlpha(51) : AppColors.navyCard,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected ? cat.color : AppColors.navyBorder,
                width: selected ? 2 : 1,
              ),
              boxShadow: selected
                  ? [BoxShadow(color: cat.color.withAlpha(51), blurRadius: 8)]
                  : [],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(cat.icon, color: cat.color, size: 24),
                const SizedBox(height: 6),
                Text(
                  cat.name,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    fontSize: 10,
                    color: selected ? cat.color : AppColors.textSecondary,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoCard() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.navyCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.navyBorder),
      ),
      child: Column(
        children: [
          _buildInfoRow(
            icon: AppIcons.titleRounded,
            label: 'Tiêu đề',
            child: TextField(
              controller: _titleController,
              style: GoogleFonts.outfit(
                color: AppColors.textPrimary,
                fontSize: 14,
              ),
              decoration: InputDecoration(
                hintText: 'Nhập tiêu đề...',
                hintStyle: GoogleFonts.outfit(
                  color: AppColors.textMuted,
                  fontSize: 14,
                ),
                border: InputBorder.none,
                filled: false,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          _buildDivider(),
          _buildInfoRow(
            icon: AppIcons.calendarTodayRounded,
            label: 'Ngày',
            child: GestureDetector(
              onTap: _pickDate,
              child: Text(
                '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                style: GoogleFonts.outfit(
                  color: AppColors.tealPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          _buildDivider(),
          _buildInfoRow(
            icon: AppIcons.notesRounded,
            label: 'Ghi chú',
            child: TextField(
              controller: _noteController,
              style: GoogleFonts.outfit(
                color: AppColors.textPrimary,
                fontSize: 14,
              ),
              decoration: InputDecoration(
                hintText: 'Tuỳ chọn...',
                hintStyle: GoogleFonts.outfit(
                  color: AppColors.textMuted,
                  fontSize: 14,
                ),
                border: InputBorder.none,
                filled: false,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required Widget child,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(icon, color: AppColors.textMuted, size: 18),
          const SizedBox(width: 12),
          SizedBox(
            width: 60,
            child: Text(
              label,
              style: GoogleFonts.outfit(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }

  Widget _buildDivider() =>
      const Divider(height: 1, color: AppColors.navyBorder, indent: 16);

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: _loading
              ? const LinearGradient(
                  colors: [AppColors.navyBorder, AppColors.navyBorder],
                )
              : AppColors.tealGradient,
          borderRadius: BorderRadius.circular(16),
          boxShadow: _loading
              ? []
              : [
                  BoxShadow(
                    color: AppColors.tealPrimary.withAlpha(77),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ],
        ),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          onPressed: _loading ? null : _save,
          child: _loading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white,
                  ),
                )
              : Text(
                  isEditing ? 'Cập nhật' : 'Lưu giao dịch',
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppColors.tealPrimary,
            surface: AppColors.navyCard,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _save() async {
    final amountText = _amountController.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (amountText.isEmpty || amountText == '0') {
      _showError('Vui lòng nhập số tiền');
      return;
    }
    if (_selectedWallet == null) {
      _showError('Vui lòng thêm ví trước');
      return;
    }

    setState(() => _loading = true);
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final amount = double.parse(amountText);
    final title = _titleController.text.trim().isEmpty
        ? _selectedCategory.name
        : _titleController.text.trim();
    final type = isExpense ? 'expense' : 'income';

    try {
      if (!isEditing && isExpense && _selectedWallet!.balance < amount) {
        throw StateError(
          'Ví ${_selectedWallet!.name} chỉ còn '
          '${NumberFormat.decimalPattern('vi_VN').format(_selectedWallet!.balance)}₫. '
          'Vui lòng chọn ví khác hoặc nhập số tiền nhỏ hơn.',
        );
      }
      int? savedTransactionId;
      if (!isEditing && isExpense) {
        final shouldContinue = await _checkAnomaly(
          uid: uid,
          amount: amount,
          title: title,
        );
        if (!shouldContinue) return;
      }
      if (isEditing) {
        final updated = widget.existing!.copyWith(
          title: title,
          amount: amount,
          categoryId: _selectedCategory.id,
          walletId: _selectedWallet!.id!,
          date: _selectedDate,
          note: _noteController.text.trim(),
          type: type,
        );
        await _db.updateTransaction(updated, widget.existing!);
      } else {
        final tx = TransactionModel(
          userId: uid,
          title: title,
          amount: amount,
          categoryId: _selectedCategory.id,
          walletId: _selectedWallet!.id!,
          date: _selectedDate,
          note: _noteController.text.trim().isEmpty
              ? null
              : _noteController.text.trim(),
          type: type,
        );
        savedTransactionId = await _db.insertTransaction(tx);
      }
      unawaited(
        _runPostSaveChecks(
          uid: uid,
          amount: amount,
          transactionId: savedTransactionId,
        ),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      _showError('Có lỗi xảy ra: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _runPostSaveChecks({
    required String uid,
    required double amount,
    int? transactionId,
  }) async {
    try {
      final anomaly = _confirmedAnomaly;
      if (anomaly != null && transactionId != null) {
        await _notificationService.createAnomaly(
          userId: uid,
          amount: amount,
          category: _selectedCategory.name,
          reason: anomaly.reason,
          transactionId: transactionId.toString(),
        );
      }
      await _notificationService.evaluate(uid);
    } catch (_) {
      // Saving a transaction must not be blocked by optional notifications.
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.navyCard,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Row(
          children: [
            const Icon(AppIcons.errorOutlineRounded, color: AppColors.error),
            const SizedBox(width: 8),
            Text(msg, style: GoogleFonts.outfit(color: AppColors.textPrimary)),
          ],
        ),
      ),
    );
  }

  Future<bool> _checkAnomaly({
    required String uid,
    required double amount,
    required String title,
  }) async {
    _confirmedAnomaly = null;
    try {
      final history = await _db.getTransactions(uid, type: 'expense');
      final result = await _aiAnalysis.detectAnomaly(
        amount: amount,
        category: _selectedCategory,
        date: _selectedDate,
        merchant: title,
        description: _noteController.text.trim(),
        history: history,
      );
      if (!result.isAnomaly || !result.requiresConfirmation) return true;
      if (!mounted) return false;

      final confirmed =
          await showDialog<bool>(
            context: context,
            barrierDismissible: false,
            builder: (dialogContext) => AlertDialog(
              backgroundColor: AppColors.navyCard,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              title: Row(
                children: [
                  const Icon(
                    AppIcons.warningAmberRounded,
                    color: AppColors.warning,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Phát hiện khoản chi bất thường',
                      style: GoogleFonts.outfit(
                        color: AppColors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Khoản chi ${_formatMoney(amount)} cho '
                      '${_selectedCategory.name} cao hơn nhiều so với '
                      'thói quen chi tiêu của bạn.',
                      style: GoogleFonts.outfit(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _anomalyDetail(
                      'Trung bình danh mục',
                      _formatMoney(result.categoryAverage),
                    ),
                    _anomalyDetail(
                      'Mức chênh lệch',
                      '${result.amountRatio.toStringAsFixed(1)} lần',
                    ),
                    _anomalyDetail(
                      'Mức cảnh báo',
                      result.severity.toUpperCase(),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      result.reason,
                      style: GoogleFonts.outfit(
                        color: AppColors.warning,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: Text(
                    'Kiểm tra lại',
                    style: GoogleFonts.outfit(color: AppColors.textSecondary),
                  ),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Vẫn lưu giao dịch'),
                ),
              ],
            ),
          ) ??
          false;

      await _alertStore.add(
        uid,
        AnomalyAlertRecord(
          amount: amount,
          category: _selectedCategory.name,
          date: _selectedDate,
          severity: result.severity,
          reason: result.reason,
          status: confirmed ? 'confirmed' : 'cancelled',
        ),
      );
      if (confirmed) {
        _confirmedAnomaly = result;
      }
      return confirmed;
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppColors.warning,
            content: Text(
              'Không thể kiểm tra bất thường lúc này. '
              'Giao dịch vẫn có thể được lưu.',
            ),
          ),
        );
      }
      return true;
    }
  }

  Widget _anomalyDetail(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.outfit(
                color: AppColors.textMuted,
                fontSize: 12,
              ),
            ),
          ),
          Text(
            value,
            style: GoogleFonts.outfit(
              color: AppColors.textPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  String _formatMoney(double amount) {
    final digits = amount.round().toString();
    final buffer = StringBuffer();
    for (var index = 0; index < digits.length; index++) {
      if (index > 0 && (digits.length - index) % 3 == 0) buffer.write('.');
      buffer.write(digits[index]);
    }
    return '$buffer VND';
  }

  String _formatAmountInput(double amount) =>
      NumberFormat.decimalPattern('vi_VN').format(amount.round());

  String _compactMoney(int amount) {
    if (amount >= 1000000) {
      return '${amount ~/ 1000000} triệu';
    }
    return '${amount ~/ 1000}k';
  }
}

class _VndInputFormatter extends TextInputFormatter {
  final NumberFormat _formatter = NumberFormat.decimalPattern('vi_VN');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return const TextEditingValue();

    final value = int.tryParse(digits);
    if (value == null) return oldValue;
    final formatted = _formatter.format(value);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
