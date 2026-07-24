import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/category_model.dart';
import '../../models/budget_model.dart';
import '../../services/database_service.dart';
import '../../theme/app_theme.dart';
import 'add_edit_budget_screen.dart';

class BudgetsScreen extends StatefulWidget {
  const BudgetsScreen({super.key});

  @override
  State<BudgetsScreen> createState() => _BudgetsScreenState();
}

class _BudgetsScreenState extends State<BudgetsScreen> {
  final _db = DatabaseService();
  List<_BudgetWithSpent> _budgets = [];
  bool _loading = true;
  late int _month;
  late int _year;

  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  static const _monthNames = [
    'Tháng 1',
    'Tháng 2',
    'Tháng 3',
    'Tháng 4',
    'Tháng 5',
    'Tháng 6',
    'Tháng 7',
    'Tháng 8',
    'Tháng 9',
    'Tháng 10',
    'Tháng 11',
    'Tháng 12',
  ];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = now.month;
    _year = now.year;
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final budgets = await _db.getBudgets(_uid, _month, _year);
    final result = <_BudgetWithSpent>[];
    for (final b in budgets) {
      final spent = await _db.getSpentForCategory(
        _uid,
        b.categoryId,
        _month,
        _year,
      );
      result.add(_BudgetWithSpent(budget: b, spent: spent));
    }
    setState(() {
      _budgets = result;
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
        title: Text(
          'Ngân sách',
          style: GoogleFonts.outfit(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 20,
          ),
        ),
      ),
      body: Column(
        children: [
          _buildMonthSelector(),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.tealPrimary,
                    ),
                  )
                : RefreshIndicator(
                    color: AppColors.tealPrimary,
                    backgroundColor: AppColors.navyCard,
                    onRefresh: _load,
                    child: _budgets.isEmpty
                        ? _buildEmpty()
                        : ListView(
                            padding: const EdgeInsets.all(16),
                            children: [
                              _buildSummaryCard(),
                              const SizedBox(height: 16),
                              ..._budgets.map(_buildBudgetCard),
                              const SizedBox(height: 80),
                            ],
                          ),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.push<bool>(
            context,
            MaterialPageRoute(builder: (_) => const AddEditBudgetScreen()),
          );
          if (result == true) _load();
        },
        backgroundColor: AppColors.tealPrimary,
        icon: const Icon(AppIcons.addRounded, color: Colors.white),
        label: Text(
          'Thêm ngân sách',
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildMonthSelector() {
    return Container(
      color: AppColors.navyMid,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(
              AppIcons.chevronLeftRounded,
              color: AppColors.textSecondary,
            ),
            onPressed: () {
              setState(() {
                _month--;
                if (_month < 1) {
                  _month = 12;
                  _year--;
                }
              });
              _load();
            },
          ),
          Text(
            '${_monthNames[_month - 1]} $_year',
            style: GoogleFonts.outfit(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          IconButton(
            icon: const Icon(
              AppIcons.chevronRightRounded,
              color: AppColors.textSecondary,
            ),
            onPressed: () {
              setState(() {
                _month++;
                if (_month > 12) {
                  _month = 1;
                  _year++;
                }
              });
              _load();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard() {
    final totalLimit = _budgets.fold<double>(
      0,
      (s, b) => s + b.budget.limitAmount,
    );
    final totalSpent = _budgets.fold<double>(0, (s, b) => s + b.spent);
    final percent = totalLimit > 0 ? (totalSpent / totalLimit) : 0.0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0D2A1A), Color(0xFF0A1E14)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.tealPrimary.withAlpha(77)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tổng ngân sách',
                    style: GoogleFonts.outfit(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    _formatCurrency(totalLimit.toInt()),
                    style: GoogleFonts.outfit(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Đã dùng',
                    style: GoogleFonts.outfit(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    '${(percent * 100).toStringAsFixed(0)}%',
                    style: GoogleFonts.outfit(
                      color: percent > 0.8
                          ? AppColors.error
                          : AppColors.tealPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: percent.clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: AppColors.navyBorder,
              valueColor: AlwaysStoppedAnimation(
                percent > 0.8 ? AppColors.error : AppColors.tealPrimary,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Đã chi: ${_formatCurrency(totalSpent.toInt())}',
                style: GoogleFonts.outfit(
                  color: AppColors.textMuted,
                  fontSize: 12,
                ),
              ),
              Text(
                'Còn lại: ${_formatCurrency((totalLimit - totalSpent).toInt())}',
                style: GoogleFonts.outfit(
                  color: AppColors.textMuted,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBudgetCard(_BudgetWithSpent bws) {
    final cat = CategoryModel.getById(bws.budget.categoryId);
    final percent = bws.budget.limitAmount > 0
        ? (bws.spent / bws.budget.limitAmount).clamp(0.0, 1.0)
        : 0.0;
    final isOver = percent >= 1.0;
    final isWarning = percent >= 0.8 && !isOver;
    final barColor = isOver
        ? AppColors.error
        : (isWarning ? const Color(0xFFFFBF00) : cat.color);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.navyCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isOver ? AppColors.error.withAlpha(77) : AppColors.navyBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: cat.color.withAlpha(25),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(cat.icon, color: cat.color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  cat.name,
                  style: GoogleFonts.outfit(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (isOver)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.error.withAlpha(38),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Vượt hạn mức',
                    style: GoogleFonts.outfit(
                      color: AppColors.error,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                )
              else if (isWarning)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFBF00).withAlpha(38),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Gần hạn mức',
                    style: GoogleFonts.outfit(
                      color: const Color(0xFFFFBF00),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () async {
                  final res = await Navigator.push<bool>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AddEditBudgetScreen(existing: bws.budget),
                    ),
                  );
                  if (res == true) _load();
                },
                child: const Icon(
                  AppIcons.editRounded,
                  color: AppColors.textMuted,
                  size: 18,
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () async {
                  final confirm = await _showDeleteConfirm();
                  if (confirm == true) {
                    await _db.deleteBudget(bws.budget.id!);
                    _load();
                  }
                },
                child: const Icon(
                  AppIcons.deleteRounded,
                  color: AppColors.error,
                  size: 18,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: percent,
              minHeight: 8,
              backgroundColor: AppColors.navyBorder,
              valueColor: AlwaysStoppedAnimation(barColor),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Đã dùng: ${_formatCurrency(bws.spent.toInt())}',
                style: GoogleFonts.outfit(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
              Text(
                '${(percent * 100).toStringAsFixed(0)}%',
                style: GoogleFonts.outfit(
                  color: barColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            'Còn lại: ${_formatCurrency((bws.budget.limitAmount - bws.spent).toInt())} / ${_formatCurrency(bws.budget.limitAmount.toInt())}',
            style: GoogleFonts.outfit(color: AppColors.textMuted, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return ListView(
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.2),
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              AppIcons.pieChartOutlineRounded,
              size: 64,
              color: AppColors.navyBorder,
            ),
            const SizedBox(height: 16),
            Text(
              'Chưa có ngân sách nào',
              style: GoogleFonts.outfit(
                color: AppColors.textMuted,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Nhấn + để thiết lập ngân sách',
              style: GoogleFonts.outfit(
                color: AppColors.textMuted,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<bool?> _showDeleteConfirm() {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.navyCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Xóa ngân sách',
          style: GoogleFonts.outfit(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          'Bạn có chắc muốn xóa ngân sách này?',
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
    );
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

class _BudgetWithSpent {
  final BudgetModel budget;
  final double spent;
  const _BudgetWithSpent({required this.budget, required this.spent});
}
