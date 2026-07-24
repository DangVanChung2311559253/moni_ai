import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../services/database_service.dart';
import '../services/notification_service.dart';
import '../services/recurring_transaction_service.dart';
import '../models/transaction_model.dart';
import '../models/category_model.dart';
import 'expenses/expenses_screen.dart';
import 'expenses/add_edit_expense_screen.dart';
import 'wallets/wallets_screen.dart';
import 'budgets/budgets_screen.dart';
import 'profile/profile_screen.dart';
import 'scan/scan_ai_screen.dart';
import 'ai/ai_assistant_screen.dart';
import 'ai/ai_analysis_screen.dart';
import 'notifications/notifications_screen.dart';
import 'savings/saving_goals_screen.dart';
import 'recurring/recurring_transactions_screen.dart';
import 'statistics/monthly_statistics_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _ActiveNavIcon extends StatelessWidget {
  final IconData icon;

  const _ActiveNavIcon(this.icon);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(7),
      decoration: BoxDecoration(
        color: AppColors.tealPrimary.withAlpha(24),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Icon(icon, size: 23),
    );
  }
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  final List<Widget> _tabs = const [
    _DashboardTab(),
    ExpensesScreen(),
    ScanAiScreen(),
    AiAssistantScreen(),
    AiAnalysisScreen(),
  ];

  final List<BottomNavigationBarItem> _navItems = const [
    BottomNavigationBarItem(
      icon: Icon(AppIcons.dashboard),
      activeIcon: _ActiveNavIcon(AppIcons.dashboard),
      label: 'Tổng quan',
    ),
    BottomNavigationBarItem(
      icon: Icon(AppIcons.transactions),
      activeIcon: _ActiveNavIcon(AppIcons.transactions),
      label: 'Giao dịch',
    ),
    BottomNavigationBarItem(
      icon: Icon(AppIcons.scan),
      activeIcon: _ActiveNavIcon(AppIcons.scan),
      label: 'Scan AI',
    ),
    BottomNavigationBarItem(
      icon: Icon(AppIcons.ai),
      activeIcon: _ActiveNavIcon(AppIcons.ai),
      label: 'Trợ lý AI',
    ),
    BottomNavigationBarItem(
      icon: Icon(AppIcons.analytics),
      activeIcon: _ActiveNavIcon(AppIcons.analytics),
      label: 'Phân tích',
    ),
    BottomNavigationBarItem(
      icon: Icon(AppIcons.other),
      activeIcon: _ActiveNavIcon(AppIcons.other),
      label: 'Thêm',
    ),
  ];

  void _onNavigationTap(int index) {
    if (index == 5) {
      _showMoreSheet();
      return;
    }
    setState(() => _currentIndex = index);
  }

  void _showMoreSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => SafeArea(
        child: Container(
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
          decoration: BoxDecoration(
            color: AppColors.navyCard,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.navyBorder),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 42,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: AppColors.textMuted,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              Text(
                'Chức năng khác',
                style: GoogleFonts.outfit(
                  color: AppColors.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              _moreItem(
                sheetContext,
                AppIcons.wallet,
                'Ví',
                'Quản lý tài khoản và số dư',
                const WalletsScreen(),
              ),
              _moreItem(
                sheetContext,
                AppIcons.budget,
                'Ngân sách',
                'Theo dõi hạn mức chi tiêu',
                const BudgetsScreen(),
              ),
              _moreItem(
                sheetContext,
                AppIcons.profile,
                'Hồ sơ và cài đặt',
                'Tài khoản, ảnh đại diện và bảo mật',
                const ProfileScreen(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _moreItem(
    BuildContext sheetContext,
    IconData icon,
    String title,
    String subtitle,
    Widget screen,
  ) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      leading: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: AppColors.tealPrimary.withAlpha(28),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: AppColors.tealPrimary),
      ),
      title: Text(
        title,
        style: GoogleFonts.outfit(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: GoogleFonts.outfit(color: AppColors.textSecondary, fontSize: 12),
      ),
      trailing: const Icon(
        AppIcons.chevronRightRounded,
        color: AppColors.textMuted,
      ),
      onTap: () {
        Navigator.pop(sheetContext);
        Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.navyDeep,
      body: IndexedStack(index: _currentIndex, children: _tabs),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.navyMid,
          border: const Border(top: BorderSide(color: AppColors.navyBorder)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(77),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: _onNavigationTap,
          backgroundColor: Colors.transparent,
          elevation: 0,
          type: BottomNavigationBarType.fixed,
          selectedItemColor: AppColors.tealPrimary,
          unselectedItemColor: AppColors.textMuted,
          selectedIconTheme: const IconThemeData(size: 27),
          unselectedIconTheme: const IconThemeData(size: 23),
          selectedLabelStyle: GoogleFonts.outfit(
            fontWeight: FontWeight.w700,
            fontSize: 10,
          ),
          unselectedLabelStyle: GoogleFonts.outfit(fontSize: 9),
          items: _navItems,
        ),
      ),
    );
  }
}

// ──────────────── DASHBOARD TAB ────────────────

class _DashboardTab extends StatefulWidget {
  const _DashboardTab();

  @override
  State<_DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<_DashboardTab> {
  final _db = DatabaseService();
  final _notificationService = NotificationService();
  final _recurringService = RecurringTransactionService();
  bool _loading = true;
  double _totalBalance = 0;
  double _monthIncome = 0;
  double _monthExpense = 0;
  List<TransactionModel> _recent = [];
  List<Map<String, dynamic>> _dailyData = [];
  List<Map<String, dynamic>> _pieData = [];
  List<Map<String, dynamic>> _monthlyStats = [];
  int _selectedChartTab = 0;
  bool _balanceVisible = true;
  String? _avatarPath;

  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void initState() {
    super.initState();
    _load();
    _loadAvatar();
    ProfileScreen.avatarPathNotifier.addListener(_onAvatarChanged);
    DatabaseService.financeChanges.addListener(_onFinanceChanged);
  }

  @override
  void dispose() {
    ProfileScreen.avatarPathNotifier.removeListener(_onAvatarChanged);
    DatabaseService.financeChanges.removeListener(_onFinanceChanged);
    super.dispose();
  }

  void _onFinanceChanged() {
    if (mounted) {
      _load(showLoading: false, runBackgroundChecks: false);
    }
  }

  void _onAvatarChanged() {
    if (mounted) {
      setState(() => _avatarPath = ProfileScreen.avatarPathNotifier.value);
    }
  }

  Future<void> _loadAvatar() async {
    final prefs = await SharedPreferences.getInstance();
    final path = prefs.getString('user_avatar_path');
    if (path != null && mounted) {
      setState(() => _avatarPath = path);
      ProfileScreen.avatarPathNotifier.value = path;
    }
  }

  Future<void> _load({
    bool showLoading = true,
    bool runBackgroundChecks = true,
  }) async {
    if (showLoading && mounted) setState(() => _loading = true);
    final now = DateTime.now();
    final results = await Future.wait([
      _db.getTotalBalance(_uid),
      _db.getTotalThisMonth(_uid, 'income'),
      _db.getTotalThisMonth(_uid, 'expense'),
      _db.getTransactions(_uid, limit: 5),
      _db.getDailySpending(_uid, 30),
      _db.getCategoryExpenseBreakdown(_uid, now.month, now.year),
      _db.getMonthlyStats(_uid, now.year),
    ]);
    if (!mounted) return;
    setState(() {
      _totalBalance = results[0] as double;
      _monthIncome = results[1] as double;
      _monthExpense = results[2] as double;
      _recent = results[3] as List<TransactionModel>;
      _dailyData = results[4] as List<Map<String, dynamic>>;
      _pieData = results[5] as List<Map<String, dynamic>>;
      _monthlyStats = results[6] as List<Map<String, dynamic>>;
      _loading = false;
    });
    if (runBackgroundChecks) {
      _notificationService
          .evaluate(_uid, includeForecast: true)
          .catchError((_) {});
      _recurringService.syncDue(_uid).catchError((_) {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final name = user?.displayName ?? 'Bạn';
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Chào buổi sáng'
        : (hour < 18 ? 'Chào buổi chiều' : 'Chào buổi tối');

    return RefreshIndicator(
      color: AppColors.tealPrimary,
      backgroundColor: AppColors.navyCard,
      onRefresh: _load,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverAppBar(
            expandedHeight: 0,
            backgroundColor: AppColors.navyMid,
            floating: true,
            pinned: false,
            automaticallyImplyLeading: false,
            title: Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      greeting,
                      style: GoogleFonts.outfit(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      name,
                      style: GoogleFonts.outfit(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                StreamBuilder<int>(
                  stream: _notificationService.watchUnreadCount(_uid),
                  builder: (context, snapshot) {
                    final count = snapshot.data ?? 0;
                    return Badge(
                      isLabelVisible: count > 0,
                      label: Text(count > 99 ? '99+' : count.toString()),
                      backgroundColor: AppColors.error,
                      child: IconButton(
                        icon: const Icon(
                          AppIcons.notificationsRounded,
                          color: AppColors.textSecondary,
                        ),
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const NotificationsScreen(),
                          ),
                        ),
                      ),
                    );
                  },
                ),
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ProfileScreen()),
                    );
                  },
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      gradient: AppColors.tealGradient,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: _avatarPath != null
                          ? Image.file(File(_avatarPath!), fit: BoxFit.cover)
                          : Center(
                              child: Text(
                                name.isNotEmpty ? name[0].toUpperCase() : 'U',
                                style: GoogleFonts.outfit(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_loading)
            const SliverFillRemaining(
              child: Center(
                child: CircularProgressIndicator(color: AppColors.tealPrimary),
              ),
            )
          else
            SliverList(
              delegate: SliverChildListDelegate([
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildBalanceCard(),
                      const SizedBox(height: 20),
                      _buildMonthStats(),
                      const SizedBox(height: 24),
                      _buildQuickActions(context),
                      const SizedBox(height: 24),
                      _buildChartSection(),
                      const SizedBox(height: 24),
                      _buildRecentSection(context),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ]),
            ),
        ],
      ),
    );
  }

  Widget _buildBalanceCard() {
    return GestureDetector(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const WalletsScreen()),
        );
        _load();
      },
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: AppColors.balanceCardGradient,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: AppColors.tealPrimary.withAlpha(77),
              blurRadius: 30,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tổng số dư',
                      style: GoogleFonts.outfit(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          'Chạm để xem tài khoản thanh toán',
                          style: GoogleFonts.outfit(
                            color: Colors.white60,
                            fontSize: 10,
                          ),
                        ),
                        const SizedBox(width: 2),
                        const Icon(
                          AppIcons.chevronRightRounded,
                          color: Colors.white60,
                          size: 14,
                        ),
                      ],
                    ),
                  ],
                ),
                IconButton(
                  tooltip: _balanceVisible ? 'Ẩn số dư' : 'Hiện số dư',
                  onPressed: () =>
                      setState(() => _balanceVisible = !_balanceVisible),
                  icon: Icon(
                    _balanceVisible
                        ? AppIcons.visibilityRounded
                        : AppIcons.visibilityOffRounded,
                    color: Colors.white70,
                    size: 20,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: _balanceVisible
                  ? Text(
                      _formatCurrency(_totalBalance.toInt()),
                      key: const ValueKey('visible'),
                      style: GoogleFonts.outfit(
                        fontSize: 32,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    )
                  : Text(
                      '••••••• VND',
                      key: const ValueKey('hidden'),
                      style: GoogleFonts.outfit(
                        fontSize: 32,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _buildBalanceStat(
                    AppIcons.arrowUpwardRounded,
                    'Thu nhập',
                    _monthIncome,
                    AppColors.income,
                  ),
                ),
                Container(width: 1, height: 36, color: Colors.white24),
                Expanded(
                  child: _buildBalanceStat(
                    AppIcons.arrowDownwardRounded,
                    'Chi tiêu',
                    _monthExpense,
                    const Color(0xFFFF6B6B),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBalanceStat(
    IconData icon,
    String label,
    double amount,
    Color color,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: color.withAlpha(51),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 14),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.outfit(color: Colors.white60, fontSize: 11),
              ),
              Text(
                _balanceVisible ? _formatCurrency(amount.toInt()) : '•••',
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMonthStats() {
    final now = DateTime.now();
    final savings = _monthIncome - _monthExpense;
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MonthlyStatisticsScreen(initialMonth: now),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tháng ${now.month}/${now.year}',
                    style: GoogleFonts.outfit(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Chạm để xem thống kê chi tiết',
                    style: GoogleFonts.outfit(
                      color: AppColors.textMuted,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: savings >= 0
                          ? AppColors.income.withAlpha(25)
                          : AppColors.error.withAlpha(25),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      savings >= 0
                          ? '+${_formatCurrency(savings.toInt())}'
                          : _formatCurrency(savings.toInt()),
                      style: GoogleFonts.outfit(
                        color: savings >= 0
                            ? AppColors.income
                            : AppColors.error,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    AppIcons.chevronRightRounded,
                    color: AppColors.textMuted,
                    size: 19,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatTile(
                  'Tổng thu',
                  _monthIncome,
                  AppColors.income,
                  AppIcons.arrowUpwardRounded,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildStatTile(
                  'Tổng chi',
                  _monthExpense,
                  AppColors.error,
                  AppIcons.arrowDownwardRounded,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildStatTile(
                  'Tiết kiệm',
                  savings,
                  savings >= 0 ? AppColors.tealPrimary : AppColors.error,
                  AppIcons.savingsRounded,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatTile(
    String label,
    double amount,
    Color color,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.navyCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.navyBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 13, color: color),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.outfit(
                    color: AppColors.textMuted,
                    fontSize: 10,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            _formatCurrency(amount.abs().toInt()),
            style: GoogleFonts.outfit(
              color: amount < 0 ? AppColors.error : color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    final actions = [
      _QuickAction(
        AppIcons.expense,
        'Thêm giao dịch',
        AppColors.tealPrimary,
        () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  const AddEditExpenseScreen(initialType: 'expense'),
            ),
          );
          _load();
        },
      ),
      _QuickAction(AppIcons.scan, 'Quét hóa đơn', const Color(0xFF22D3EE), () {
        final homeState = context.findAncestorStateOfType<_HomeScreenState>();
        homeState?.setState(() => homeState._currentIndex = 2);
      }),
      _QuickAction(
        AppIcons.savingGoal,
        'Mục tiêu tiết kiệm',
        AppColors.tealPrimary,
        () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SavingGoalsScreen()),
          );
          _load();
        },
      ),
      _QuickAction(
        AppIcons.recurring,
        'Chi tiêu định kỳ',
        const Color(0xFFFF9F43),
        () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const RecurringTransactionsScreen(),
            ),
          );
          _load();
        },
      ),
      _QuickAction(AppIcons.budget, 'Ngân sách', const Color(0xFFA78BFA), () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const BudgetsScreen()),
        );
      }),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Thao tác nhanh',
              style: GoogleFonts.outfit(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
            const Spacer(),
            Text(
              'Vuốt ngang để xem thêm',
              style: GoogleFonts.outfit(
                color: AppColors.textMuted,
                fontSize: 9.5,
              ),
            ),
            const SizedBox(width: 3),
            const Icon(
              Icons.swipe_left_rounded,
              color: AppColors.textMuted,
              size: 15,
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 96,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: actions.length,
            separatorBuilder: (_, _) => const SizedBox(width: 4),
            itemBuilder: (context, index) =>
                SizedBox(width: 88, child: _buildActionButton(actions[index])),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton(_QuickAction action) {
    return GestureDetector(
      onTap: action.onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    action.color.withAlpha(51),
                    action.color.withAlpha(13),
                  ],
                ),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: action.color.withAlpha(102)),
                boxShadow: [
                  BoxShadow(
                    color: action.color.withAlpha(31),
                    blurRadius: 12,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Center(
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: action.color.withAlpha(31),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(action.icon, color: action.color, size: 20),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              action.label,
              textAlign: TextAlign.center,
              maxLines: 2,
              style: GoogleFonts.outfit(
                color: AppColors.textSecondary,
                fontSize: 10.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════ CHART SECTION ══════════════

  Widget _buildChartSection() {
    const tabLabels = ['Danh mục', 'Thu-Chi', 'Xu hướng'];
    const tabIcons = [
      AppIcons.pieChartRounded,
      AppIcons.barChartRounded,
      AppIcons.showChartRounded,
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.navyCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.navyBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Phân tích',
            style: GoogleFonts.outfit(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: AppColors.navyDeep,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: List.generate(3, (i) {
                final isSelected = i == _selectedChartTab;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedChartTab = i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.tealPrimary
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            tabIcons[i],
                            size: 13,
                            color: isSelected
                                ? Colors.white
                                : AppColors.textMuted,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              tabLabels[i],
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.outfit(
                                fontSize: 11,
                                color: isSelected
                                    ? Colors.white
                                    : AppColors.textMuted,
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 20),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            transitionBuilder: (child, animation) =>
                FadeTransition(opacity: animation, child: child),
            child: KeyedSubtree(
              key: ValueKey(_selectedChartTab),
              child: [
                _buildPieChart(),
                _buildBarChart(),
                _buildLineChart(),
              ][_selectedChartTab],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Pie Chart: Chi theo danh mục ───
  Widget _buildPieChart() {
    if (_pieData.isEmpty) {
      return SizedBox(
        height: 200,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                AppIcons.pieChartOutlineRounded,
                size: 48,
                color: AppColors.navyBorder,
              ),
              const SizedBox(height: 8),
              Text(
                'Chưa có chi tiêu tháng này',
                style: GoogleFonts.outfit(
                  color: AppColors.textMuted,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      );
    }
    final total = _pieData.fold<double>(
      0,
      (s, e) => s + (e['total'] as double),
    );
    return SizedBox(
      height: 210,
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: Stack(
              alignment: Alignment.center,
              children: [
                PieChart(
                  PieChartData(
                    sectionsSpace: 2,
                    centerSpaceRadius: 46,
                    sections: _pieData.map((d) {
                      final cat = CategoryModel.getById(d['categoryId'] as int);
                      final pct = total > 0
                          ? (d['total'] as double) / total * 100
                          : 0.0;
                      return PieChartSectionData(
                        color: cat.color,
                        value: d['total'] as double,
                        title: pct >= 10 ? '${pct.toStringAsFixed(0)}%' : '',
                        titleStyle: GoogleFonts.outfit(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                        radius: 58,
                      );
                    }).toList(),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Chi',
                      style: GoogleFonts.outfit(
                        color: AppColors.textMuted,
                        fontSize: 10,
                      ),
                    ),
                    Text(
                      _formatCurrency(_monthExpense.toInt()),
                      style: GoogleFonts.outfit(
                        color: AppColors.textPrimary,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            flex: 4,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: _pieData.take(6).map((d) {
                final cat = CategoryModel.getById(d['categoryId'] as int);
                final pct = total > 0
                    ? (d['total'] as double) / total * 100
                    : 0.0;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: cat.color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          cat.name,
                          style: GoogleFonts.outfit(
                            color: AppColors.textSecondary,
                            fontSize: 11,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${pct.toStringAsFixed(0)}%',
                        style: GoogleFonts.outfit(
                          color: AppColors.textPrimary,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
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
    );
  }

  // ─── Bar Chart: Thu-Chi theo tháng ───
  Widget _buildBarChart() {
    final currentMonthIndex = DateTime.now().month - 1;
    final startIndex = currentMonthIndex >= 5 ? currentMonthIndex - 5 : 0;
    final endIndex = startIndex + 6 > _monthlyStats.length
        ? _monthlyStats.length
        : startIndex + 6;
    final visibleStats = _monthlyStats.sublist(startIndex, endIndex);
    final maxVal = visibleStats.fold<double>(0, (m, e) {
      final inc = e['income'] as double;
      final exp = e['expense'] as double;
      return [m, inc, exp].reduce((a, b) => a > b ? a : b);
    });

    if (maxVal == 0) {
      return SizedBox(
        height: 200,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                AppIcons.barChartRounded,
                size: 48,
                color: AppColors.navyBorder,
              ),
              const SizedBox(height: 8),
              Text(
                'Chưa có dữ liệu năm nay',
                style: GoogleFonts.outfit(
                  color: AppColors.textMuted,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      );
    }

    const months = [
      'T1',
      'T2',
      'T3',
      'T4',
      'T5',
      'T6',
      'T7',
      'T8',
      'T9',
      'T10',
      'T11',
      'T12',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _legendDot(AppColors.income, 'Thu nhập'),
            const SizedBox(width: 16),
            _legendDot(AppColors.error, 'Chi tiêu'),
            const Spacer(),
            Text(
              '6 tháng gần nhất',
              style: GoogleFonts.outfit(
                color: AppColors.textMuted,
                fontSize: 10,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 175,
          child: BarChart(
            BarChartData(
              maxY: maxVal * 1.3,
              barTouchData: BarTouchData(enabled: true),
              titlesData: FlTitlesData(
                show: true,
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (v, _) {
                      final i = v.toInt();
                      if (i < 0 || i >= visibleStats.length) {
                        return const SizedBox();
                      }
                      final monthIndex = startIndex + i;
                      return Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          months[monthIndex],
                          style: GoogleFonts.outfit(
                            color: monthIndex == currentMonthIndex
                                ? AppColors.tealPrimary
                                : AppColors.textMuted,
                            fontSize: 10,
                            fontWeight: monthIndex == currentMonthIndex
                                ? FontWeight.w700
                                : FontWeight.w400,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                leftTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
              ),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                getDrawingHorizontalLine: (_) =>
                    FlLine(color: AppColors.navyBorder, strokeWidth: 0.5),
              ),
              borderData: FlBorderData(show: false),
              barGroups: List.generate(visibleStats.length, (i) {
                final monthIndex = startIndex + i;
                final isCurrent = monthIndex == currentMonthIndex;
                return BarChartGroupData(
                  x: i,
                  barsSpace: 3,
                  barRods: [
                    BarChartRodData(
                      toY: visibleStats[i]['income'] as double,
                      color: AppColors.income,
                      width: isCurrent ? 11 : 9,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(4),
                      ),
                    ),
                    BarChartRodData(
                      toY: visibleStats[i]['expense'] as double,
                      color: AppColors.error,
                      width: isCurrent ? 11 : 9,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(4),
                      ),
                    ),
                  ],
                );
              }),
            ),
          ),
        ),
      ],
    );
  }

  // ─── Line Chart: Xu hướng chi tiêu 30 ngày ───
  Widget _buildLineChart() {
    final hasData = _dailyData.any((d) => (d['total'] as double) > 0);

    if (!hasData) {
      return SizedBox(
        height: 200,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                AppIcons.showChartRounded,
                size: 48,
                color: AppColors.navyBorder,
              ),
              const SizedBox(height: 8),
              Text(
                'Chưa có dữ liệu chi tiêu',
                style: GoogleFonts.outfit(
                  color: AppColors.textMuted,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final maxY = _dailyData.fold<double>(
      0,
      (m, e) => (e['total'] as double) > m ? (e['total'] as double) : m,
    );
    final spots = _dailyData
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), e.value['total'] as double))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Chi tiêu 30 ngày gần đây',
          style: GoogleFonts.outfit(color: AppColors.textMuted, fontSize: 12),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 160,
          child: LineChart(
            LineChartData(
              minY: 0,
              maxY: maxY * 1.3,
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  curveSmoothness: 0.35,
                  color: AppColors.tealPrimary,
                  barWidth: 2.5,
                  isStrokeCapRound: true,
                  dotData: const FlDotData(show: false),
                  belowBarData: BarAreaData(
                    show: true,
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        AppColors.tealPrimary.withAlpha(80),
                        AppColors.tealPrimary.withAlpha(0),
                      ],
                    ),
                  ),
                ),
              ],
              titlesData: FlTitlesData(
                show: true,
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    interval: 7,
                    getTitlesWidget: (v, _) {
                      final i = v.toInt();
                      if (i < 0 || i >= _dailyData.length) {
                        return const SizedBox();
                      }
                      final d = _dailyData[i]['date'] as DateTime;
                      return Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          '${d.day}/${d.month}',
                          style: GoogleFonts.outfit(
                            color: AppColors.textMuted,
                            fontSize: 9,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                leftTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
              ),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                getDrawingHorizontalLine: (_) =>
                    FlLine(color: AppColors.navyBorder, strokeWidth: 0.5),
              ),
              borderData: FlBorderData(show: false),
            ),
          ),
        ),
      ],
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: GoogleFonts.outfit(
            color: AppColors.textSecondary,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildRecentSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Giao dịch gần đây',
              style: GoogleFonts.outfit(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
            GestureDetector(
              onTap: () {
                final s = context.findAncestorStateOfType<_HomeScreenState>();
                s?.setState(() => s._currentIndex = 1);
              },
              child: Text(
                'Xem tất cả',
                style: GoogleFonts.outfit(
                  color: AppColors.tealPrimary,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_recent.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.navyCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.navyBorder),
            ),
            child: Center(
              child: Text(
                'Chưa có giao dịch nào',
                style: GoogleFonts.outfit(
                  color: AppColors.textMuted,
                  fontSize: 13,
                ),
              ),
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
              color: AppColors.navyCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.navyBorder),
            ),
            child: Column(
              children: _recent
                  .asMap()
                  .entries
                  .map(
                    (e) =>
                        _buildRecentItem(e.value, e.key == _recent.length - 1),
                  )
                  .toList(),
            ),
          ),
      ],
    );
  }

  Widget _buildRecentItem(TransactionModel tx, bool isLast) {
    final cat = CategoryModel.getById(tx.categoryId);
    return GestureDetector(
      onTap: () async {
        final res = await Navigator.push<bool>(
          context,
          MaterialPageRoute(builder: (_) => AddEditExpenseScreen(existing: tx)),
        );
        if (res == true) _load();
      },
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
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
                      Text(
                        cat.name,
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
                    fontWeight: FontWeight.w700,
                    color: tx.isExpense ? AppColors.error : AppColors.income,
                  ),
                ),
              ],
            ),
          ),
          if (!isLast)
            const Divider(height: 1, color: AppColors.navyBorder, indent: 68),
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

class _QuickAction {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _QuickAction(this.icon, this.label, this.color, this.onTap);
}
