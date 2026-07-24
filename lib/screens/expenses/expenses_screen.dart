import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../models/category_model.dart';
import '../../models/transaction_model.dart';
import '../../services/database_service.dart';
import '../../theme/app_theme.dart';
import 'add_edit_expense_screen.dart';

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key});

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  final _db = DatabaseService();
  final _searchCtrl = TextEditingController();
  List<TransactionModel> _transactions = [];
  bool _loading = true;
  String _search = '';
  int? _filterCategoryId;
  DateTime? _startDate;
  DateTime? _endDate;

  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void initState() {
    super.initState();
    _load();
    DatabaseService.financeChanges.addListener(_onFinanceChanged);
  }

  @override
  void dispose() {
    DatabaseService.financeChanges.removeListener(_onFinanceChanged);
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onFinanceChanged() {
    if (mounted) _load(showLoading: false);
  }

  Future<void> _load({bool showLoading = true}) async {
    if (showLoading && mounted) setState(() => _loading = true);
    final txs = await _db.getTransactions(
      _uid,
      search: _search.isEmpty ? null : _search,
      startDate: _startDate,
      endDate: _endDate,
      categoryId: _filterCategoryId,
    );
    if (!mounted) return;
    setState(() {
      _transactions = txs;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.navyDeep,
      appBar: AppBar(
        backgroundColor: AppColors.navyMid,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Text(
          'Chi tiêu',
          style: GoogleFonts.outfit(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 20,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(
              AppIcons.filterListRounded,
              color: AppColors.textSecondary,
            ),
            onPressed: _showFilterSheet,
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.navyCard,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.navyBorder),
              ),
              child: TextField(
                controller: _searchCtrl,
                style: GoogleFonts.outfit(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                ),
                decoration: InputDecoration(
                  hintText: 'Tìm kiếm giao dịch...',
                  hintStyle: GoogleFonts.outfit(
                    color: AppColors.textMuted,
                    fontSize: 14,
                  ),
                  prefixIcon: const Icon(
                    AppIcons.searchRounded,
                    color: AppColors.textMuted,
                    size: 20,
                  ),
                  suffixIcon: _search.isNotEmpty
                      ? IconButton(
                          icon: const Icon(
                            AppIcons.clearRounded,
                            color: AppColors.textMuted,
                            size: 18,
                          ),
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() => _search = '');
                            _load();
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  filled: false,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onChanged: (v) {
                  setState(() => _search = v);
                  _load();
                },
              ),
            ),
          ),
          // Category filter chips
          _buildCategoryChips(),
          // Active filters badge
          if (_startDate != null ||
              _endDate != null ||
              _filterCategoryId != null)
            _buildActiveFilters(),
          // Transaction list
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.tealPrimary,
                    ),
                  )
                : _transactions.isEmpty
                ? _buildEmpty()
                : _buildList(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.push<bool>(
            context,
            MaterialPageRoute(builder: (_) => const AddEditExpenseScreen()),
          );
          if (result == true) _load();
        },
        backgroundColor: AppColors.tealPrimary,
        icon: const Icon(AppIcons.addRounded, color: Colors.white),
        label: Text(
          'Thêm',
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryChips() {
    return SizedBox(
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          _chip('Tất cả', null),
          ...CategoryModel.all.map((c) => _chip(c.name, c.id, color: c.color)),
        ],
      ),
    );
  }

  Widget _chip(String label, int? catId, {Color? color}) {
    final selected = _filterCategoryId == catId;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () {
          setState(() => _filterCategoryId = catId);
          _load();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: selected
                ? (color ?? AppColors.tealPrimary).withAlpha(38)
                : AppColors.navyCard,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected
                  ? (color ?? AppColors.tealPrimary)
                  : AppColors.navyBorder,
            ),
          ),
          child: Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 12,
              color: selected
                  ? (color ?? AppColors.tealPrimary)
                  : AppColors.textSecondary,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActiveFilters() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          const Icon(
            AppIcons.filterAltRounded,
            color: AppColors.tealPrimary,
            size: 14,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              _filterLabel(),
              style: GoogleFonts.outfit(
                color: AppColors.tealPrimary,
                fontSize: 12,
              ),
            ),
          ),
          GestureDetector(
            onTap: () {
              setState(() {
                _startDate = null;
                _endDate = null;
                _filterCategoryId = null;
              });
              _load();
            },
            child: Text(
              'Xóa lọc',
              style: GoogleFonts.outfit(color: AppColors.error, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  String _filterLabel() {
    final parts = <String>[];
    if (_startDate != null) {
      parts.add('Từ ${DateFormat('dd/MM/yy').format(_startDate!)}');
    }
    if (_endDate != null) {
      parts.add('đến ${DateFormat('dd/MM/yy').format(_endDate!)}');
    }
    return parts.join(' ');
  }

  Widget _buildList() {
    // Group by date
    final Map<String, List<TransactionModel>> grouped = {};
    for (final tx in _transactions) {
      final key = DateFormat('dd/MM/yyyy').format(tx.date);
      grouped.putIfAbsent(key, () => []).add(tx);
    }

    return RefreshIndicator(
      color: AppColors.tealPrimary,
      backgroundColor: AppColors.navyCard,
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: grouped.length,
        itemBuilder: (_, i) {
          final date = grouped.keys.elementAt(i);
          final txs = grouped[date]!;
          final dayTotal = txs.fold<double>(0, (sum, tx) {
            return tx.isExpense ? sum - tx.amount : sum + tx.amount;
          });
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDateHeader(date, dayTotal),
              const SizedBox(height: 8),
              ...txs.map((tx) => _buildTxItem(tx)),
              const SizedBox(height: 16),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDateHeader(String date, double total) {
    final formatted = _formatCurrency(total.abs().toInt());
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          date,
          style: GoogleFonts.outfit(
            color: AppColors.textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          total < 0 ? '−$formatted' : '+$formatted',
          style: GoogleFonts.outfit(
            fontSize: 12,
            color: total < 0 ? AppColors.error : AppColors.income,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildTxItem(TransactionModel tx) {
    final cat = CategoryModel.getById(tx.categoryId);
    return Dismissible(
      key: Key(tx.id.toString()),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: AppColors.error.withAlpha(38),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(AppIcons.deleteRounded, color: AppColors.error),
      ),
      confirmDismiss: (_) async => await _confirmDelete(),
      onDismissed: (_) async {
        await _db.deleteTransaction(tx);
        _load();
      },
      child: GestureDetector(
        onTap: () async {
          final result = await Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder: (_) => AddEditExpenseScreen(existing: tx),
            ),
          );
          if (result == true) _load();
        },
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.navyCard,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.navyBorder),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: cat.color.withAlpha(25),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(cat.icon, color: cat.color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tx.title,
                      style: GoogleFonts.outfit(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${cat.name}  •  ${DateFormat('HH:mm').format(tx.date)}',
                      style: GoogleFonts.outfit(
                        color: AppColors.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                tx.isExpense
                    ? '−${_formatCurrency(tx.amount.toInt())}'
                    : '+${_formatCurrency(tx.amount.toInt())}',
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: tx.isExpense ? AppColors.error : AppColors.income,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            AppIcons.receiptLongRounded,
            size: 64,
            color: AppColors.navyBorder,
          ),
          const SizedBox(height: 16),
          Text(
            'Chưa có giao dịch nào',
            style: GoogleFonts.outfit(color: AppColors.textMuted, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            'Nhấn + để thêm giao dịch mới',
            style: GoogleFonts.outfit(color: AppColors.textMuted, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Future<bool> _confirmDelete() async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: AppColors.navyCard,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Text(
              'Xóa giao dịch',
              style: GoogleFonts.outfit(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            content: Text(
              'Bạn có chắc muốn xóa giao dịch này?',
              style: GoogleFonts.outfit(color: AppColors.textSecondary),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(
                  'Hủy',
                  style: GoogleFonts.outfit(color: AppColors.textSecondary),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(
                  'Xóa',
                  style: GoogleFonts.outfit(color: AppColors.error),
                ),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _showFilterSheet() {
    DateTime? tempStart = _startDate;
    DateTime? tempEnd = _endDate;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.navyCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.navyBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Lọc theo ngày',
                style: GoogleFonts.outfit(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _datePickerTile(
                      label: 'Từ ngày',
                      date: tempStart,
                      onTap: () async {
                        final d = await showDatePicker(
                          context: ctx,
                          initialDate: tempStart ?? DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                          builder: (c, child) => Theme(
                            data: ThemeData.dark().copyWith(
                              colorScheme: const ColorScheme.dark(
                                primary: AppColors.tealPrimary,
                                surface: AppColors.navyCard,
                              ),
                            ),
                            child: child!,
                          ),
                        );
                        if (d != null) {
                          setSheetState(() => tempStart = d);
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _datePickerTile(
                      label: 'Đến ngày',
                      date: tempEnd,
                      onTap: () async {
                        final d = await showDatePicker(
                          context: ctx,
                          initialDate: tempEnd ?? DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                          builder: (c, child) => Theme(
                            data: ThemeData.dark().copyWith(
                              colorScheme: const ColorScheme.dark(
                                primary: AppColors.tealPrimary,
                                surface: AppColors.navyCard,
                              ),
                            ),
                            child: child!,
                          ),
                        );
                        if (d != null) {
                          setSheetState(() => tempEnd = d);
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        setState(() {
                          _startDate = null;
                          _endDate = null;
                        });
                        _load();
                        Navigator.pop(ctx);
                      },
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.navyBorder),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text(
                        'Xóa lọc',
                        style: GoogleFonts.outfit(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _startDate = tempStart;
                          _endDate = tempEnd;
                        });
                        _load();
                        Navigator.pop(ctx);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.tealPrimary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text(
                        'Áp dụng',
                        style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _datePickerTile({
    required String label,
    required DateTime? date,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.navyDeep,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.navyBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: GoogleFonts.outfit(
                color: AppColors.textMuted,
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              date != null
                  ? DateFormat('dd/MM/yyyy').format(date)
                  : 'Chọn ngày',
              style: GoogleFonts.outfit(
                color: date != null
                    ? AppColors.tealPrimary
                    : AppColors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatCurrency(int amount) {
    final s = amount.abs().toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
      buf.write(s[i]);
    }
    return '${buf.toString()} VND';
  }
}
