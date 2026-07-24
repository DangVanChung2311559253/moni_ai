import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../models/wallet_model.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/vnd_input_formatter.dart';
import '../../../widgets/financial_brand_mark.dart';

class WalletSelectionSheet extends StatelessWidget {
  final List<WalletModel> wallets;
  final double amount;
  final bool isExpense;

  const WalletSelectionSheet({
    super.key,
    required this.wallets,
    required this.amount,
    required this.isExpense,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        decoration: const BoxDecoration(
          color: AppColors.navyCard,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.textMuted,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 17),
            Text(
              'Chọn ví thanh toán',
              style: GoogleFonts.outfit(
                color: AppColors.textPrimary,
                fontSize: 19,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Ví không đủ số dư sẽ bị khóa.',
              style: GoogleFonts.outfit(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 14),
            if (wallets.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: Text('Bạn chưa có ví nào.')),
              )
            else
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * 0.5,
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: wallets.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 9),
                  itemBuilder: (_, index) {
                    final wallet = wallets[index];
                    final enough =
                        !isExpense || amount <= 0 || wallet.balance >= amount;
                    return Material(
                      color: enough
                          ? AppColors.navyDeep
                          : AppColors.navyDeep.withAlpha(115),
                      borderRadius: BorderRadius.circular(16),
                      child: InkWell(
                        onTap: enough
                            ? () => Navigator.pop(context, wallet)
                            : null,
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: enough
                                  ? wallet.walletType.color.withAlpha(85)
                                  : AppColors.error.withAlpha(70),
                            ),
                          ),
                          child: Row(
                            children: [
                              FinancialBrandMark(
                                name: wallet.name,
                                fallbackIcon: wallet.walletType.icon,
                                fallbackColor: wallet.walletType.color,
                                size: 42,
                              ),
                              const SizedBox(width: 11),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      wallet.name,
                                      style: GoogleFonts.outfit(
                                        color: AppColors.textPrimary,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    Text(
                                      'Số dư: ${formatVndInput(wallet.balance)}đ',
                                      style: GoogleFonts.outfit(
                                        color: AppColors.textSecondary,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (!enough)
                                Text(
                                  'Số dư không đủ',
                                  style: GoogleFonts.outfit(
                                    color: AppColors.error,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                )
                              else
                                const Icon(
                                  AppIcons.chevronRightRounded,
                                  color: AppColors.textMuted,
                                ),
                            ],
                          ),
                        ),
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
}
