import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../models/category_model.dart';
import '../../models/transaction_model.dart';
import '../../models/wallet_model.dart';
import '../../services/database_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/vnd_input_formatter.dart';
import '../expenses/add_edit_expense_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen>
    with SingleTickerProviderStateMixin {
  final _db = DatabaseService();
  final _searchCtrl = TextEditingController();
  late TabController _tabCtrl;
  List<TransactionModel> _transactions = [];
  List<WalletModel> _wallets = [];
  bool _loading = true;
  String _search = '';
  int? _filterCategoryId;
  int? _filterWalletId;
  double? _minAmount;
  double? _maxAmount;
  DateTime? _startDate;
  DateTime? _endDate;

  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  String? get _typeFilter {
    if (_tabCtrl.index == 1) return 'income';
    if (_tabCtrl.index == 2) return 'expense';
    return null;
  }

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _tabCtrl.addListener(() {
      if (!_tabCtrl.indexIsChanging) _load();
    });
    _load();
    _loadWallets();
  }

  Future<void> _loadWallets() async {
    final wallets = await _db.getWallets(_uid);
    if (mounted) setState(() => _wallets = wallets);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);
    final txs = await _db.getTransactions(
      _uid,
      search: _search.isEmpty ? null : _search,
      startDate: _startDate,
      endDate: _endDate,
      categoryId: _filterCategoryId,
      walletId: _filterWalletId,
      minAmount: _minAmount,
      maxAmount: _maxAmount,
      type: _typeFilter,
    );
    if (mounted) {
      setState(() {
        _transactions = txs;
        _loading = false;
      });
    }
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
          'Lịch sử',
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
        bottom: TabBar(
          controller: _tabCtrl,
          indicatorColor: AppColors.tealPrimary,
          indicatorWeight: 2,
          labelStyle: GoogleFonts.outfit(fontWeight: FontWeight.w600),
          unselectedLabelStyle: GoogleFonts.outfit(),
          labelColor: AppColors.tealPrimary,
          unselectedLabelColor: AppColors.textMuted,
          tabs: const [
            Tab(text: 'Tất cả'),
            Tab(text: 'Thu nhập'),
            Tab(text: 'Chi tiêu'),
          ],
        ),
      ),
      body: Column(
        children: [
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
          if (_filterCategoryId != null ||
              _filterWalletId != null ||
              _minAmount != null ||
              _maxAmount != null ||
              _startDate != null ||
              _endDate != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
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
                      _filterDescription(),
                      style: GoogleFonts.outfit(
                        color: AppColors.tealPrimary,
                        fontSize: 12,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _filterCategoryId = null;
                        _filterWalletId = null;
                        _minAmount = null;
                        _maxAmount = null;
                        _startDate = null;
                        _endDate = null;
                      });
                      _load();
                    },
                    child: Text(
                      'Xóa',
                      style: GoogleFonts.outfit(
                        color: AppColors.error,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
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
    );
  }

  Widget _buildList() {
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
          final dayNet = txs.fold<double>(
            0,
            (s, t) => t.isExpense ? s - t.amount : s + t.amount,
          );
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDateHeader(date, dayNet),
              const SizedBox(height: 8),
              ...txs.map(_buildTxItem),
              const SizedBox(height: 16),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDateHeader(String date, double net) {
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
          '${net >= 0 ? '+' : ''}${_formatCurrency(net.toInt())}',
          style: GoogleFonts.outfit(
            fontSize: 12,
            color: net >= 0 ? AppColors.income : AppColors.error,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildTxItem(TransactionModel tx) {
    final cat = CategoryModel.getById(tx.categoryId);
    return Dismissible(
      key: Key('hist_${tx.id}'),
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
      confirmDismiss: (_) async {
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
                  'Bạn có chắc muốn xóa giao dịch này không?',
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
      },
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
                    Row(
                      children: [
                        Icon(cat.icon, color: cat.color, size: 11),
                        const SizedBox(width: 4),
                        Text(
                          '${cat.name}  •  ${DateFormat('HH:mm').format(tx.date)}',
                          style: GoogleFonts.outfit(
                            color: AppColors.textMuted,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    tx.isExpense
                        ? '−${_formatCurrency(tx.amount.toInt())}'
                        : '+${_formatCurrency(tx.amount.toInt())}',
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: tx.isExpense ? AppColors.error : AppColors.income,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Icon(
                    AppIcons.chevronRightRounded,
                    color: AppColors.textMuted,
                    size: 14,
                  ),
                ],
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
          Icon(AppIcons.historyRounded, size: 64, color: AppColors.navyBorder),
          const SizedBox(height: 16),
          Text(
            'Không có giao dịch nào',
            style: GoogleFonts.outfit(color: AppColors.textMuted, fontSize: 16),
          ),
          if (_search.isNotEmpty || _filterCategoryId != null) ...[
            const SizedBox(height: 8),
            Text(
              'Thử xóa bộ lọc để xem thêm',
              style: GoogleFonts.outfit(
                color: AppColors.textMuted,
                fontSize: 13,
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showFilterSheet() {
    DateTime? tempStart = _startDate;
    DateTime? tempEnd = _endDate;
    int? tempCat = _filterCategoryId;
    int? tempWallet = _filterWalletId;
    final minCtrl = TextEditingController(
      text: _minAmount != null ? formatVndInput(_minAmount!) : '',
    );
    final maxCtrl = TextEditingController(
      text: _maxAmount != null ? formatVndInput(_maxAmount!) : '',
    );

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.navyCard,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => DraggableScrollableSheet(
          initialChildSize: 0.82,
          maxChildSize: 0.95,
          minChildSize: 0.4,
          expand: false,
          builder: (_, ctrl) => SingleChildScrollView(
            controller: ctrl,
            padding: const EdgeInsets.all(24),
            child: Column(
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
                  'Bộ lọc',
                  style: GoogleFonts.outfit(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 20),

                // ── Khoảng thời gian ──
                Text(
                  'Khoảng thời gian',
                  style: GoogleFonts.outfit(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _dateTile('Từ ngày', tempStart, () async {
                        final d = await _pickDate(ctx, tempStart);
                        if (d != null) setS(() => tempStart = d);
                      }),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _dateTile('Đến ngày', tempEnd, () async {
                        final d = await _pickDate(ctx, tempEnd);
                        if (d != null) setS(() => tempEnd = d);
                      }),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // ── Ví tiền ──
                Text(
                  'Ví tiền',
                  style: GoogleFonts.outfit(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 10),
                _wallets.isEmpty
                    ? Text(
                        'Chưa có ví nào',
                        style: GoogleFonts.outfit(
                          color: AppColors.textMuted,
                          fontSize: 12,
                        ),
                      )
                    : Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _filterChip(
                            'Tất cả ví',
                            null,
                            tempWallet,
                            () => setS(() => tempWallet = null),
                          ),
                          ..._wallets.map(
                            (w) => _filterChip(
                              w.name,
                              w.id,
                              tempWallet,
                              () => setS(() => tempWallet = w.id),
                              color: w.walletType.color,
                            ),
                          ),
                        ],
                      ),
                const SizedBox(height: 20),

                // ── Khoảng tiền ──
                Text(
                  'Khoảng tiền',
                  style: GoogleFonts.outfit(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.navyDeep,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.navyBorder),
                        ),
                        child: TextField(
                          controller: minCtrl,
                          keyboardType: TextInputType.number,
                          inputFormatters: const [VndInputFormatter()],
                          style: GoogleFonts.outfit(
                            color: AppColors.textPrimary,
                            fontSize: 13,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Từ (VND)',
                            hintStyle: GoogleFonts.outfit(
                              color: AppColors.textMuted,
                              fontSize: 12,
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.navyDeep,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.navyBorder),
                        ),
                        child: TextField(
                          controller: maxCtrl,
                          keyboardType: TextInputType.number,
                          inputFormatters: const [VndInputFormatter()],
                          style: GoogleFonts.outfit(
                            color: AppColors.textPrimary,
                            fontSize: 13,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Đến (VND)',
                            hintStyle: GoogleFonts.outfit(
                              color: AppColors.textMuted,
                              fontSize: 12,
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // ── Danh mục ──
                Text(
                  'Danh mục',
                  style: GoogleFonts.outfit(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _filterChip(
                      'Tất cả',
                      null,
                      tempCat,
                      () => setS(() => tempCat = null),
                    ),
                    ...CategoryModel.all.map(
                      (c) => _filterChip(
                        c.name,
                        c.id,
                        tempCat,
                        () => setS(() => tempCat = c.id),
                        color: c.color,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          setState(() {
                            _startDate = null;
                            _endDate = null;
                            _filterCategoryId = null;
                            _filterWalletId = null;
                            _minAmount = null;
                            _maxAmount = null;
                          });
                          minCtrl.dispose();
                          maxCtrl.dispose();
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
                          'Xóa tất cả',
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
                          final minVal = parseVndInput(minCtrl.text);
                          final maxVal = parseVndInput(maxCtrl.text);
                          setState(() {
                            _startDate = tempStart;
                            _endDate = tempEnd;
                            _filterCategoryId = tempCat;
                            _filterWalletId = tempWallet;
                            _minAmount = minVal;
                            _maxAmount = maxVal;
                          });
                          minCtrl.dispose();
                          maxCtrl.dispose();
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
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _dateTile(String label, DateTime? date, VoidCallback onTap) {
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

  Widget _filterChip(
    String label,
    int? id,
    int? selected,
    VoidCallback onTap, {
    Color? color,
  }) {
    final isSelected = selected == id;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? (color ?? AppColors.tealPrimary).withAlpha(38)
              : AppColors.navyDeep,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? (color ?? AppColors.tealPrimary)
                : AppColors.navyBorder,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 12,
            color: isSelected
                ? (color ?? AppColors.tealPrimary)
                : AppColors.textSecondary,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }

  Future<DateTime?> _pickDate(BuildContext ctx, DateTime? initial) {
    return showDatePicker(
      context: ctx,
      initialDate: initial ?? DateTime.now(),
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
  }

  String _filterDescription() {
    final parts = <String>[];
    if (_filterCategoryId != null) {
      parts.add(CategoryModel.getById(_filterCategoryId!).name);
    }
    if (_filterWalletId != null && _wallets.isNotEmpty) {
      final w = _wallets.firstWhere(
        (w) => w.id == _filterWalletId,
        orElse: () => _wallets.first,
      );
      parts.add('Ví: ${w.name}');
    }
    if (_minAmount != null && _maxAmount != null) {
      parts.add(
        '${_formatCurrency(_minAmount!.toInt())}–${_formatCurrency(_maxAmount!.toInt())}',
      );
    } else if (_minAmount != null) {
      parts.add('≥ ${_formatCurrency(_minAmount!.toInt())}');
    } else if (_maxAmount != null) {
      parts.add('≤ ${_formatCurrency(_maxAmount!.toInt())}');
    }
    if (_startDate != null) {
      parts.add('Từ ${DateFormat('dd/MM/yy').format(_startDate!)}');
    }
    if (_endDate != null) {
      parts.add('đến ${DateFormat('dd/MM/yy').format(_endDate!)}');
    }
    return parts.join('  •  ');
  }

  String _formatCurrency(int amount) {
    final isNeg = amount < 0;
    final s = amount.abs().toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
      buf.write(s[i]);
    }
    return '${isNeg ? '−' : ''}${buf.toString()} VND';
  }
}
