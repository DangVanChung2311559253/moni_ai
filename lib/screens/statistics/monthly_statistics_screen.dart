import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../models/category_model.dart';
import '../../models/transaction_model.dart';
import '../../services/database_service.dart';
import '../../theme/app_theme.dart';

class MonthlyStatisticsScreen extends StatefulWidget {
  final DateTime? initialMonth;

  const MonthlyStatisticsScreen({super.key, this.initialMonth});

  @override
  State<MonthlyStatisticsScreen> createState() =>
      _MonthlyStatisticsScreenState();
}

class _MonthlyStatisticsScreenState extends State<MonthlyStatisticsScreen> {
  final _db = DatabaseService();
  late DateTime _selectedMonth;
  bool _loading = true;
  String? _error;
  List<TransactionModel> _transactions = [];

  @override
  void initState() {
    super.initState();
    final initial = widget.initialMonth ?? DateTime.now();
    _selectedMonth = DateTime(initial.year, initial.month);
    _load();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
      if (userId.isEmpty) throw StateError('Người dùng chưa đăng nhập.');
      final nextMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1);
      final values = await _db.getTransactions(
        userId,
        startDate: _selectedMonth,
        endDate: nextMonth.subtract(const Duration(microseconds: 1)),
      );
      if (mounted) setState(() => _transactions = values);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _changeMonth(int offset) {
    setState(() {
      _selectedMonth = DateTime(
        _selectedMonth.year,
        _selectedMonth.month + offset,
      );
    });
    _load();
  }

  double get _income => _transactions
      .where((transaction) => transaction.isIncome)
      .fold(0, (total, transaction) => total + transaction.amount);

  double get _expense => _transactions
      .where((transaction) => transaction.isExpense)
      .fold(0, (total, transaction) => total + transaction.amount);

  double get _savings => _income - _expense;

  List<MapEntry<int, double>> get _categoryExpenses {
    final totals = <int, double>{};
    for (final transaction in _transactions.where((value) => value.isExpense)) {
      totals.update(
        transaction.categoryId,
        (amount) => amount + transaction.amount,
        ifAbsent: () => transaction.amount,
      );
    }
    final entries = totals.entries.toList();
    entries.sort((a, b) => b.value.compareTo(a.value));
    return entries;
  }

  String _currency(double value) =>
      '${NumberFormat.decimalPattern('vi_VN').format(value.round())} ₫';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.navyDeep,
      appBar: AppBar(
        backgroundColor: AppColors.navyMid,
        title: Text(
          'Thống kê tháng',
          style: GoogleFonts.outfit(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: RefreshIndicator(
        color: AppColors.tealPrimary,
        backgroundColor: AppColors.navyCard,
        onRefresh: _load,
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.tealPrimary),
              )
            : _error != null
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(24),
                children: [
                  const SizedBox(height: 100),
                  const Icon(
                    AppIcons.cloudOffRounded,
                    color: AppColors.error,
                    size: 52,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Không tải được thống kê',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(color: AppColors.textSecondary),
                  ),
                ],
              )
            : ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 36),
                children: [
                  _buildMonthPicker(),
                  const SizedBox(height: 18),
                  _buildOverviewCard(),
                  const SizedBox(height: 14),
                  _buildMetrics(),
                  const SizedBox(height: 22),
                  _buildHighlights(),
                  const SizedBox(height: 22),
                  _buildCategorySection(),
                ],
              ),
      ),
    );
  }

  Widget _buildMonthPicker() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.navyCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.navyBorder),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Tháng trước',
            onPressed: () => _changeMonth(-1),
            icon: const Icon(
              AppIcons.chevronLeftRounded,
              color: AppColors.textSecondary,
            ),
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  'THỜI GIAN THỐNG KÊ',
                  style: GoogleFonts.outfit(
                    color: AppColors.textMuted,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Tháng ${_selectedMonth.month}/${_selectedMonth.year}',
                  style: GoogleFonts.outfit(
                    color: AppColors.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Tháng sau',
            onPressed: () => _changeMonth(1),
            icon: const Icon(
              AppIcons.chevronRightRounded,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewCard() {
    final rate = _income > 0 ? (_savings / _income * 100) : 0.0;
    final positive = _savings >= 0;
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: positive
            ? AppColors.balanceCardGradient
            : const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFFF6B6B), Color(0xFF7C3AED)],
              ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: (positive ? AppColors.tealPrimary : AppColors.error)
                .withAlpha(45),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  positive ? 'Tiết kiệm ròng' : 'Chi vượt thu',
                  style: GoogleFonts.outfit(
                    color: Colors.white70,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  _currency(_savings.abs()),
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  _transactions.isEmpty
                      ? 'Chưa có giao dịch trong tháng'
                      : positive
                      ? 'Bạn đang giữ thu lớn hơn chi.'
                      : 'Chi tiêu đang cao hơn thu nhập.',
                  style: GoogleFonts.outfit(
                    color: Colors.white.withAlpha(210),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(35),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withAlpha(65)),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  positive
                      ? AppIcons.savingsRounded
                      : AppIcons.trendingDownRounded,
                  color: Colors.white,
                  size: 22,
                ),
                const SizedBox(height: 2),
                Text(
                  '${rate.abs().toStringAsFixed(0)}%',
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetrics() {
    return Row(
      children: [
        Expanded(
          child: _metricCard(
            'Tổng thu',
            _income,
            AppIcons.southWestRounded,
            AppColors.income,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _metricCard(
            'Tổng chi',
            _expense,
            AppIcons.northEastRounded,
            AppColors.error,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _metricCard(
            'Tiết kiệm',
            _savings,
            AppIcons.savingsRounded,
            _savings >= 0 ? AppColors.tealPrimary : AppColors.error,
          ),
        ),
      ],
    );
  }

  Widget _metricCard(String label, double value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AppColors.navyCard,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: color.withAlpha(55)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: color.withAlpha(28),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(height: 9),
          Text(
            label,
            style: GoogleFonts.outfit(color: AppColors.textMuted, fontSize: 10),
          ),
          const SizedBox(height: 2),
          Text(
            _currency(value.abs()),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.outfit(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHighlights() {
    final expenses = _transactions.where((value) => value.isExpense).toList();
    expenses.sort((a, b) => b.amount.compareTo(a.amount));
    final daysInMonth = DateTime(
      _selectedMonth.year,
      _selectedMonth.month + 1,
      0,
    ).day;
    final average = daysInMonth == 0 ? 0.0 : _expense / daysInMonth;
    final largest = expenses.isEmpty ? null : expenses.first;
    return _sectionCard(
      title: 'Điểm nổi bật',
      icon: AppIcons.autoGraphRounded,
      child: Column(
        children: [
          _highlightRow(
            AppIcons.receiptLongRounded,
            'Số giao dịch',
            '${_transactions.length} giao dịch',
            const Color(0xFF60A5FA),
          ),
          _divider(),
          _highlightRow(
            AppIcons.calendarTodayRounded,
            'Chi trung bình mỗi ngày',
            _currency(average),
            AppColors.warning,
          ),
          _divider(),
          _highlightRow(
            AppIcons.localFireDepartmentRounded,
            'Khoản chi lớn nhất',
            largest == null
                ? 'Chưa có khoản chi'
                : '${largest.title} • ${_currency(largest.amount)}',
            AppColors.error,
          ),
        ],
      ),
    );
  }

  Widget _buildCategorySection() {
    final entries = _categoryExpenses;
    return _sectionCard(
      title: 'Chi tiêu theo danh mục',
      icon: AppIcons.donutLargeRounded,
      child: entries.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 28),
              child: Column(
                children: [
                  const Icon(
                    AppIcons.pieChartOutlineRounded,
                    color: AppColors.textMuted,
                    size: 44,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Chưa có dữ liệu chi tiêu',
                    style: GoogleFonts.outfit(color: AppColors.textSecondary),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                SizedBox(
                  height: 190,
                  child: Row(
                    children: [
                      Expanded(
                        child: PieChart(
                          PieChartData(
                            centerSpaceRadius: 42,
                            sectionsSpace: 2,
                            sections: entries.map((entry) {
                              final category = CategoryModel.getById(entry.key);
                              final percent = _expense <= 0
                                  ? 0.0
                                  : entry.value / _expense * 100;
                              return PieChartSectionData(
                                color: category.color,
                                value: entry.value,
                                radius: 54,
                                title: percent >= 9
                                    ? '${percent.toStringAsFixed(0)}%'
                                    : '',
                                titleStyle: GoogleFonts.outfit(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: entries.take(5).map((entry) {
                            final category = CategoryModel.getById(entry.key);
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 5),
                              child: Row(
                                children: [
                                  Container(
                                    width: 9,
                                    height: 9,
                                    decoration: BoxDecoration(
                                      color: category.color,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 7),
                                  Expanded(
                                    child: Text(
                                      category.name,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.outfit(
                                        color: AppColors.textSecondary,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                ),
                ...entries.map((entry) {
                  final category = CategoryModel.getById(entry.key);
                  final percent = _expense <= 0 ? 0.0 : entry.value / _expense;
                  return Padding(
                    padding: const EdgeInsets.only(top: 13),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: category.color.withAlpha(25),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                category.icon,
                                color: category.color,
                                size: 17,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                category.name,
                                style: GoogleFonts.outfit(
                                  color: AppColors.textPrimary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  _currency(entry.value),
                                  style: GoogleFonts.outfit(
                                    color: AppColors.textPrimary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  '${(percent * 100).toStringAsFixed(1)}%',
                                  style: GoogleFonts.outfit(
                                    color: AppColors.textMuted,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            minHeight: 5,
                            value: percent.clamp(0, 1),
                            backgroundColor: AppColors.navyDeep,
                            valueColor: AlwaysStoppedAnimation(category.color),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
    );
  }

  Widget _sectionCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.navyCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.navyBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.tealPrimary, size: 19),
              const SizedBox(width: 8),
              Text(
                title,
                style: GoogleFonts.outfit(
                  color: AppColors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _highlightRow(IconData icon, String label, String value, Color color) {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: color.withAlpha(25),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 19),
        ),
        const SizedBox(width: 12),
        Expanded(
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
              const SizedBox(height: 2),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.outfit(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _divider() => const Padding(
    padding: EdgeInsets.symmetric(vertical: 12),
    child: Divider(height: 1, color: AppColors.navyBorder),
  );
}
