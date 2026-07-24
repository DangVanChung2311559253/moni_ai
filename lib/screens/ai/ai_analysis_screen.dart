import 'dart:convert';
import 'dart:math' as math;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/ai_analysis_models.dart';
import '../../models/budget_model.dart';
import '../../models/category_model.dart';
import '../../models/transaction_model.dart';
import '../../services/ai_analysis_service.dart';
import '../../services/anomaly_alert_store.dart';
import '../../services/database_service.dart';
import '../../theme/app_theme.dart';

class AiAnalysisScreen extends StatefulWidget {
  final int initialSection;

  const AiAnalysisScreen({super.key, this.initialSection = 0});

  @override
  State<AiAnalysisScreen> createState() => _AiAnalysisScreenState();
}

class _AiAnalysisScreenState extends State<AiAnalysisScreen> {
  late int _section;

  @override
  void initState() {
    super.initState();
    _section = widget.initialSection.clamp(0, 2);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.navyDeep,
      appBar: AppBar(
        backgroundColor: AppColors.navyMid,
        title: Text(
          'Phân tích AI',
          style: GoogleFonts.outfit(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppColors.navyCard,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.navyBorder),
              ),
              child: Row(
                children: [
                  _sectionButton(0, AppIcons.showChartRounded, 'Dự báo'),
                  _sectionButton(1, AppIcons.warningAmberRounded, 'Bất thường'),
                  _sectionButton(2, AppIcons.savingsOutlined, 'Tiết kiệm'),
                ],
              ),
            ),
          ),
          Expanded(
            child: IndexedStack(
              index: _section,
              children: const [
                _ForecastPanel(),
                _AnomalyHistoryPanel(),
                _SavingAdvicePanel(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionButton(int index, IconData icon, String label) {
    final selected = _section == index;
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(11),
        onTap: () => setState(() => _section = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            color: selected ? AppColors.tealPrimary : Colors.transparent,
            borderRadius: BorderRadius.circular(11),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: selected ? Colors.white : AppColors.textMuted,
              ),
              const SizedBox(width: 7),
              Text(
                label,
                style: GoogleFonts.outfit(
                  color: selected ? Colors.white : AppColors.textSecondary,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ForecastPanel extends StatefulWidget {
  const _ForecastPanel();

  @override
  State<_ForecastPanel> createState() => _ForecastPanelState();
}

class _ForecastPanelState extends State<_ForecastPanel> {
  final _database = DatabaseService();
  final _service = AiAnalysisService();
  int? _days;
  bool _loading = false;
  String? _error;
  ForecastResult? _result;
  double _monthlyBudget = 0;

  String get _userId => FirebaseAuth.instance.currentUser?.uid ?? '';
  String _cacheKey(int days) => 'forecast_${_userId}_$days';

  Future<void> _loadCache(int days) async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_cacheKey(days));
    if (raw == null || !mounted) return;
    try {
      final cached = ForecastResult.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
      if (mounted && _days == days) setState(() => _result = cached);
    } catch (_) {}
  }

  Future<void> _loadForecast() async {
    final requestedDays = _days;
    if (requestedDays == null) {
      setState(() => _error = 'Hãy chọn 7, 14 hoặc 30 ngày trước.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final now = DateTime.now();
      final data = await Future.wait([
        _database.getTransactions(_userId, type: 'expense'),
        _database.getBudgets(_userId, now.month, now.year),
      ]);
      final expenses = data[0] as List<TransactionModel>;
      final budgets = data[1] as List<BudgetModel>;
      final result = await _service.forecast(expenses, requestedDays);
      _monthlyBudget = budgets.fold<double>(
        0,
        (total, budget) => total + budget.limitAmount,
      );
      if (result.success) {
        final preferences = await SharedPreferences.getInstance();
        await preferences.setString(
          _cacheKey(requestedDays),
          jsonEncode(result.toJson()),
        );
      }
      if (mounted && _days == requestedDays) {
        setState(() => _result = result);
      }
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: AppColors.tealPrimary,
      onRefresh: _loadForecast,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
        children: [
          Text(
            'Dự báo chi tiêu',
            style: GoogleFonts.outfit(
              color: AppColors.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Prophet phân tích lịch sử chi tiêu theo ngày.',
            style: GoogleFonts.outfit(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [7, 14, 30]
                .map(
                  (days) => Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(right: days == 30 ? 0 : 8),
                      child: ChoiceChip(
                        label: SizedBox(
                          width: double.infinity,
                          child: Text(
                            '$days ngày',
                            textAlign: TextAlign.center,
                          ),
                        ),
                        selected: _days == days,
                        onSelected: _loading
                            ? null
                            : (_) {
                                setState(() {
                                  _days = days;
                                  _result = null;
                                  _error = null;
                                });
                                _loadCache(days);
                              },
                        selectedColor: AppColors.tealPrimary,
                        backgroundColor: AppColors.navyCard,
                        labelStyle: TextStyle(
                          color: _days == days
                              ? Colors.white
                              : AppColors.textSecondary,
                        ),
                        side: const BorderSide(color: AppColors.navyBorder),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 16),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(50),
              child: Center(
                child: CircularProgressIndicator(color: AppColors.tealPrimary),
              ),
            )
          else if (_error != null)
            _messageCard(
              AppIcons.cloudOffRounded,
              'Không thể tải dự báo',
              _error!,
              AppColors.error,
            )
          else if (_result == null)
            _messageCard(
              AppIcons.autoGraphRounded,
              'Chọn thời gian dự báo',
              'Chọn 7, 14 hoặc 30 ngày. Mỗi lựa chọn dùng một kết quả và biểu đồ riêng.',
              AppColors.tealPrimary,
            )
          else if (!_result!.success)
            _messageCard(
              AppIcons.hourglassBottomRounded,
              'Chưa đủ dữ liệu',
              _result!.message,
              AppColors.warning,
            )
          else
            ..._resultWidgets(_result!),
          const SizedBox(height: 18),
          SizedBox(
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _loading || _days == null ? null : _loadForecast,
              icon: const Icon(AppIcons.refreshRounded),
              label: Text(
                _days == null ? 'Chọn số ngày' : 'Dự báo $_days ngày',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.tealPrimary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _resultWidgets(ForecastResult result) {
    final isIncrease = result.trend == 'increase';
    final trendColor = isIncrease ? AppColors.error : AppColors.income;
    final budgetRisk =
        _monthlyBudget > 0 && result.predictedTotal > _monthlyBudget;
    final overBudget = result.predictedTotal - _monthlyBudget;
    return [
      Row(
        children: [
          Expanded(
            child: _metricCard(
              'Tổng ${result.forecastDays} ngày',
              _money(result.predictedTotal),
              AppIcons.paymentsRounded,
              AppColors.tealPrimary,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _metricCard(
              'Trung bình/ngày',
              _money(result.averagePerDay),
              AppIcons.calendarTodayRounded,
              AppColors.purpleAccent,
            ),
          ),
        ],
      ),
      const SizedBox(height: 10),
      _metricCard(
        'Xu hướng ${result.trendPercent.abs().toStringAsFixed(1)}%',
        result.message,
        isIncrease
            ? AppIcons.trendingUpRounded
            : result.trend == 'decrease'
            ? AppIcons.trendingDownRounded
            : AppIcons.trendingFlatRounded,
        trendColor,
      ),
      if (isIncrease && result.trendPercent > 10) ...[
        const SizedBox(height: 10),
        _messageCard(
          AppIcons.warningAmberRounded,
          'Cảnh báo xu hướng tăng',
          'Dự báo chi tiêu tăng hơn 10% so với giai đoạn gần nhất.',
          AppColors.warning,
        ),
      ],
      if (budgetRisk) ...[
        const SizedBox(height: 10),
        _messageCard(
          AppIcons.accountBalanceWalletOutlined,
          'Nguy cơ vượt ngân sách',
          'Bạn có nguy cơ vượt ngân sách ${_money(overBudget)}.',
          AppColors.error,
        ),
      ],
      const SizedBox(height: 16),
      _forecastChart(result.dailyForecast),
      const SizedBox(height: 12),
      _metricCard(
        'Khoảng dự báo',
        '${_money(result.lowerTotal)} – ${_money(result.upperTotal)}',
        AppIcons.compareArrowsRounded,
        AppColors.warning,
      ),
    ];
  }

  Widget _forecastChart(List<DailyForecast> points) {
    if (points.isEmpty) return const SizedBox.shrink();
    final maxY = points.fold<double>(
      0,
      (value, point) => math.max(value, point.upperAmount),
    );
    return Container(
      height: 250,
      padding: const EdgeInsets.fromLTRB(12, 18, 18, 12),
      decoration: BoxDecoration(
        color: AppColors.navyCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.navyBorder),
      ),
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: (points.length - 1).toDouble(),
          minY: 0,
          maxY: maxY <= 0 ? 1 : maxY * 1.1,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) =>
                const FlLine(color: AppColors.navyBorder, strokeWidth: 1),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            leftTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: math.max(1, (points.length / 5).floor()).toDouble(),
                getTitlesWidget: (value, meta) {
                  final index = value.round();
                  if (index < 0 || index >= points.length) {
                    return const SizedBox.shrink();
                  }
                  final date = points[index].date;
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      '${date.day}/${date.month}',
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 10,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: points
                  .asMap()
                  .entries
                  .map(
                    (entry) => FlSpot(
                      entry.key.toDouble(),
                      entry.value.predictedAmount,
                    ),
                  )
                  .toList(),
              isCurved: true,
              color: AppColors.tealPrimary,
              barWidth: 3,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: AppColors.tealPrimary.withAlpha(30),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _metricCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppColors.navyCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.navyBorder),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 23),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.outfit(
                    color: AppColors.textMuted,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: GoogleFonts.outfit(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _messageCard(
    IconData icon,
    String title,
    String message,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: color.withAlpha(18),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withAlpha(90)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.outfit(
                    color: color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: GoogleFonts.outfit(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _money(double value) {
    final digits = value.round().abs().toString();
    final buffer = StringBuffer();
    for (var index = 0; index < digits.length; index++) {
      if (index > 0 && (digits.length - index) % 3 == 0) buffer.write('.');
      buffer.write(digits[index]);
    }
    return '${value < 0 ? '-' : ''}$buffer VND';
  }
}

class _SavingAdvicePanel extends StatefulWidget {
  const _SavingAdvicePanel();

  @override
  State<_SavingAdvicePanel> createState() => _SavingAdvicePanelState();
}

class _SavingAdvicePanelState extends State<_SavingAdvicePanel> {
  final _database = DatabaseService();
  bool _loading = true;
  String? _error;
  double _currentExpense = 0;
  double _previousExpense = 0;
  double _totalBudget = 0;
  String? _topCategory;
  double _topCategoryAmount = 0;

  String get _userId => FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (_userId.isEmpty) {
      setState(() {
        _loading = false;
        _error = 'Bạn cần đăng nhập để xem gợi ý tiết kiệm.';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final now = DateTime.now();
      final currentStart = DateTime(now.year, now.month, 1);
      final nextStart = DateTime(now.year, now.month + 1, 1);
      final previousStart = DateTime(now.year, now.month - 1, 1);
      final results = await Future.wait([
        _database.getTransactions(_userId, type: 'expense'),
        _database.getBudgets(_userId, now.month, now.year),
      ]);
      final transactions = results[0] as List<TransactionModel>;
      final budgets = results[1] as List<BudgetModel>;
      final current = transactions
          .where(
            (item) =>
                !item.date.isBefore(currentStart) &&
                item.date.isBefore(nextStart),
          )
          .toList();
      final previous = transactions
          .where(
            (item) =>
                !item.date.isBefore(previousStart) &&
                item.date.isBefore(currentStart),
          )
          .toList();
      final byCategory = <int, double>{};
      for (final item in current) {
        byCategory.update(
          item.categoryId,
          (value) => value + item.amount,
          ifAbsent: () => item.amount,
        );
      }
      MapEntry<int, double>? top;
      for (final entry in byCategory.entries) {
        if (top == null || entry.value > top.value) top = entry;
      }
      if (!mounted) return;
      setState(() {
        _currentExpense = current.fold(0, (total, item) => total + item.amount);
        _previousExpense = previous.fold(
          0,
          (total, item) => total + item.amount,
        );
        _totalBudget = budgets.fold(
          0,
          (total, item) => total + item.limitAmount,
        );
        _topCategory = top == null ? null : CategoryModel.getById(top.key).name;
        _topCategoryAmount = top?.value ?? 0;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Không tải được dữ liệu gợi ý tiết kiệm.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.tealPrimary),
      );
    }
    if (_error != null) {
      return _state(AppIcons.cloudOffRounded, _error!);
    }
    if (_currentExpense == 0 && _previousExpense == 0) {
      return _state(
        AppIcons.savingsOutlined,
        'Hãy ghi thêm giao dịch để Moni AI tạo gợi ý tiết kiệm.',
      );
    }

    final changePercent = _previousExpense > 0
        ? (_currentExpense - _previousExpense) / _previousExpense * 100
        : null;
    final suggestedSaving = _currentExpense * 0.1;
    final remainingBudget = _totalBudget - _currentExpense;
    return RefreshIndicator(
      color: AppColors.tealPrimary,
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(18),
        children: [
          _adviceCard(
            AppIcons.compareArrowsRounded,
            'So với tháng trước',
            changePercent == null
                ? 'Chưa đủ dữ liệu tháng trước để so sánh.'
                : changePercent > 0
                ? 'Chi tiêu đang tăng ${changePercent.abs().round()}%. Hãy giảm các khoản không thiết yếu.'
                : 'Chi tiêu đã giảm ${changePercent.abs().round()}%. Bạn đang kiểm soát khá tốt.',
            changePercent != null && changePercent > 0
                ? AppColors.warning
                : AppColors.income,
          ),
          if (_topCategory != null) ...[
            const SizedBox(height: 12),
            _adviceCard(
              AppIcons.pieChartOutlineRounded,
              'Danh mục chi nhiều nhất',
              '$_topCategory đang chiếm ${_money(_topCategoryAmount)}. '
                  'Thử đặt giới hạn nhỏ hơn 10% cho danh mục này.',
              AppColors.purpleAccent,
            ),
          ],
          if (_totalBudget > 0) ...[
            const SizedBox(height: 12),
            _adviceCard(
              remainingBudget >= 0
                  ? AppIcons.accountBalanceWalletOutlined
                  : AppIcons.warningAmberRounded,
              'Tình trạng ngân sách',
              remainingBudget >= 0
                  ? 'Bạn còn ${_money(remainingBudget)} trong tổng ngân sách tháng.'
                  : 'Bạn đã vượt tổng ngân sách ${_money(remainingBudget.abs())}.',
              remainingBudget >= 0 ? AppColors.tealPrimary : AppColors.error,
            ),
          ],
          const SizedBox(height: 12),
          _adviceCard(
            AppIcons.savingsRounded,
            'Mục tiêu gợi ý',
            'Hãy thử dành ${_money(suggestedSaving)} (10% mức chi hiện tại) '
                'cho quỹ tiết kiệm.',
            AppColors.income,
          ),
        ],
      ),
    );
  }

  Widget _adviceCard(IconData icon, String title, String message, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.navyCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withAlpha(80)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withAlpha(25),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.outfit(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  message,
                  style: GoogleFonts.outfit(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _state(IconData icon, String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: AppColors.textMuted, size: 58),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  String _money(double value) {
    final digits = value.round().abs().toString();
    final buffer = StringBuffer();
    for (var index = 0; index < digits.length; index++) {
      if (index > 0 && (digits.length - index) % 3 == 0) buffer.write('.');
      buffer.write(digits[index]);
    }
    return '$buffer VND';
  }
}

class _AnomalyHistoryPanel extends StatefulWidget {
  const _AnomalyHistoryPanel();

  @override
  State<_AnomalyHistoryPanel> createState() => _AnomalyHistoryPanelState();
}

class _AnomalyHistoryPanelState extends State<_AnomalyHistoryPanel> {
  final _store = AnomalyAlertStore();
  List<AnomalyAlertRecord> _records = [];
  bool _loading = true;

  String get _userId => FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void initState() {
    super.initState();
    _load();
    AnomalyAlertStore.changes.addListener(_load);
  }

  @override
  void dispose() {
    AnomalyAlertStore.changes.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    final records = await _store.getAll(_userId);
    if (mounted) {
      setState(() {
        _records = records;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.tealPrimary),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.tealPrimary,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
        children: [
          Text(
            'Giao dịch bất thường',
            style: GoogleFonts.outfit(
              color: AppColors.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Các cảnh báo người dùng đã xác nhận hoặc hủy.',
            style: GoogleFonts.outfit(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 16),
          if (_records.isEmpty)
            Container(
              padding: const EdgeInsets.all(30),
              decoration: BoxDecoration(
                color: AppColors.navyCard,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.navyBorder),
              ),
              child: Column(
                children: [
                  const Icon(
                    AppIcons.verifiedUserOutlined,
                    color: AppColors.income,
                    size: 48,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Chưa có cảnh báo bất thường',
                    style: GoogleFonts.outfit(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            )
          else
            ..._records.map(_recordCard),
        ],
      ),
    );
  }

  Widget _recordCard(AnomalyAlertRecord record) {
    final severityColor = record.severity == 'high'
        ? AppColors.error
        : record.severity == 'medium'
        ? AppColors.warning
        : AppColors.purpleAccent;
    final confirmed = record.status == 'confirmed';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppColors.navyCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: severityColor.withAlpha(100)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${record.category} · ${_money(record.amount)}',
                  style: GoogleFonts.outfit(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: severityColor.withAlpha(25),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  record.severity.toUpperCase(),
                  style: TextStyle(
                    color: severityColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            '${record.date.day}/${record.date.month}/${record.date.year}',
            style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
          ),
          const SizedBox(height: 8),
          Text(
            record.reason,
            style: GoogleFonts.outfit(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 9),
          Row(
            children: [
              Icon(
                confirmed
                    ? AppIcons.checkCircleOutline
                    : AppIcons.cancelOutlined,
                color: confirmed ? AppColors.income : AppColors.error,
                size: 16,
              ),
              const SizedBox(width: 5),
              Text(
                confirmed ? 'Đã xác nhận và lưu' : 'Đã hủy',
                style: TextStyle(
                  color: confirmed ? AppColors.income : AppColors.error,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _money(double value) {
    final digits = value.round().toString();
    final buffer = StringBuffer();
    for (var index = 0; index < digits.length; index++) {
      if (index > 0 && (digits.length - index) % 3 == 0) buffer.write('.');
      buffer.write(digits[index]);
    }
    return '$buffer VND';
  }
}
