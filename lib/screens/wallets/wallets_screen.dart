import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/wallet_model.dart';
import '../../services/database_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/financial_brand_mark.dart';
import 'add_edit_wallet_screen.dart';

class WalletsScreen extends StatefulWidget {
  const WalletsScreen({super.key});

  @override
  State<WalletsScreen> createState() => _WalletsScreenState();
}

class _WalletsScreenState extends State<WalletsScreen> {
  final _db = DatabaseService();
  List<WalletModel> _wallets = [];
  bool _loading = true;
  double _totalBalance = 0;

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
    super.dispose();
  }

  void _onFinanceChanged() {
    if (mounted) _load(showLoading: false);
  }

  Future<void> _load({bool showLoading = true}) async {
    if (showLoading && mounted) setState(() => _loading = true);
    final wallets = await _db.getWallets(_uid);
    final total = await _db.getTotalBalance(_uid);
    if (!mounted) return;
    setState(() {
      _wallets = wallets;
      _totalBalance = total;
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
          'Quản lý ví',
          style: GoogleFonts.outfit(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 20,
          ),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.tealPrimary),
            )
          : RefreshIndicator(
              color: AppColors.tealPrimary,
              backgroundColor: AppColors.navyCard,
              onRefresh: _load,
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(child: _buildTotalCard()),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                      child: Text(
                        'Danh sách ví (${_wallets.length})',
                        style: GoogleFonts.outfit(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                  if (_wallets.isEmpty)
                    SliverFillRemaining(child: _buildEmpty())
                  else
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (_, i) => _buildWalletCard(_wallets[i]),
                          childCount: _wallets.length,
                        ),
                      ),
                    ),
                  const SliverToBoxAdapter(child: SizedBox(height: 100)),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.push<bool>(
            context,
            MaterialPageRoute(builder: (_) => const AddEditWalletScreen()),
          );
          if (result == true) _load();
        },
        backgroundColor: AppColors.tealPrimary,
        icon: const Icon(AppIcons.addRounded, color: Colors.white),
        label: Text(
          'Thêm ví',
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildTotalCard() {
    return Padding(
      padding: const EdgeInsets.all(20),
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
            Text(
              'Tổng số dư',
              style: GoogleFonts.outfit(
                color: Colors.white.withAlpha(204),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _formatCurrency(_totalBalance.toInt()),
              style: GoogleFonts.outfit(
                fontSize: 30,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(
                  AppIcons.accountBalanceWalletRounded,
                  color: Colors.white70,
                  size: 16,
                ),
                const SizedBox(width: 6),
                Text(
                  '${_wallets.length} ví đang hoạt động',
                  style: GoogleFonts.outfit(
                    color: Colors.white70,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWalletCard(WalletModel wallet) {
    final wt = wallet.walletType;
    return Dismissible(
      key: Key(wallet.id.toString()),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: AppColors.error.withAlpha(38),
          borderRadius: BorderRadius.circular(16),
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
                  'Xóa ví',
                  style: GoogleFonts.outfit(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                content: Text(
                  'Xóa ví này sẽ xóa tất cả giao dịch liên quan. Bạn có chắc không?',
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
        await _db.deleteWallet(wallet.id!);
        _load();
      },
      child: GestureDetector(
        onTap: () async {
          final result = await Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder: (_) => AddEditWalletScreen(existing: wallet),
            ),
          );
          if (result == true) _load();
        },
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.navyCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.navyBorder),
          ),
          child: Row(
            children: [
              FinancialBrandMark(
                name: wallet.name,
                fallbackIcon: wt.icon,
                fallbackColor: wt.color,
                size: 48,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      wallet.name,
                      style: GoogleFonts.outfit(
                        color: AppColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: wt.color.withAlpha(25),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        wt.name,
                        style: GoogleFonts.outfit(
                          color: wt.color,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    if (wallet.isDefault) ...[
                      const SizedBox(height: 5),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            AppIcons.starRounded,
                            color: AppColors.warning,
                            size: 13,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            'Mặc định',
                            style: GoogleFonts.outfit(
                              color: AppColors.warning,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _formatCurrency(wallet.balance.toInt()),
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: wallet.balance >= 0
                          ? AppColors.textPrimary
                          : AppColors.error,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Icon(
                    AppIcons.chevronRightRounded,
                    color: AppColors.textMuted,
                    size: 16,
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
          Icon(
            AppIcons.accountBalanceWalletOutlined,
            size: 64,
            color: AppColors.navyBorder,
          ),
          const SizedBox(height: 16),
          Text(
            'Chưa có ví nào',
            style: GoogleFonts.outfit(color: AppColors.textMuted, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            'Nhấn + để thêm ví mới',
            style: GoogleFonts.outfit(color: AppColors.textMuted, fontSize: 13),
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
