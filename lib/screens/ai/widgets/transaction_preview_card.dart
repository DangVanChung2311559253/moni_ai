import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../models/ai_chat_model.dart';
import '../../../models/category_model.dart';
import '../../../models/wallet_model.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/vnd_input_formatter.dart';

class TransactionPreviewCard extends StatelessWidget {
  final AiChatResult result;
  final CategoryModel category;
  final WalletModel? wallet;
  final bool saved;
  final bool saving;
  final bool cancelled;
  final VoidCallback onEdit;
  final VoidCallback onCancel;
  final VoidCallback onChooseWallet;
  final VoidCallback onSave;

  const TransactionPreviewCard({
    super.key,
    required this.result,
    required this.category,
    required this.wallet,
    required this.saved,
    required this.saving,
    required this.cancelled,
    required this.onEdit,
    required this.onCancel,
    required this.onChooseWallet,
    required this.onSave,
  });

  bool get _hasRequiredFields =>
      result.amount != null &&
      result.amount! > 0 &&
      result.date != null &&
      wallet != null;

  @override
  Widget build(BuildContext context) {
    final expense = result.isExpense;
    final accent = expense ? AppColors.error : AppColors.income;
    final date = result.date ?? DateTime.now();
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 180),
      opacity: cancelled ? 0.55 : 1,
      child: Container(
        width: MediaQuery.sizeOf(context).width * 0.86,
        margin: const EdgeInsets.only(left: 40, bottom: 16),
        padding: const EdgeInsets.all(17),
        decoration: BoxDecoration(
          color: AppColors.navyCard,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: accent.withAlpha(105)),
          boxShadow: [
            BoxShadow(
              color: accent.withAlpha(20),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: accent.withAlpha(25),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(
                    expense
                        ? AppIcons.northEastRounded
                        : AppIcons.southWestRounded,
                    color: accent,
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Text(
                    'Xác nhận giao dịch',
                    style: GoogleFonts.outfit(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ),
                if (saved)
                  const Icon(AppIcons.verifiedRounded, color: AppColors.income),
              ],
            ),
            const SizedBox(height: 15),
            Text(
              result.amount == null
                  ? 'Chưa rõ số tiền'
                  : '${formatVndInput(result.amount!)}đ',
              style: GoogleFonts.outfit(
                color: result.amount == null ? AppColors.warning : accent,
                fontSize: 27,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 14),
            _infoRow(
              AppIcons.swapVertRounded,
              'Loại',
              expense ? 'Chi tiêu' : 'Thu nhập',
            ),
            _infoRow(category.icon, 'Danh mục', category.name),
            _infoRow(
              AppIcons.accountBalanceWalletRounded,
              'Ví',
              wallet?.name ?? 'Chưa chọn',
              warning: wallet == null,
              trailing: wallet == null && !saved && !cancelled
                  ? TextButton(
                      onPressed: onChooseWallet,
                      child: const Text('Chọn ví'),
                    )
                  : null,
            ),
            _infoRow(
              AppIcons.eventRounded,
              'Ngày',
              _isToday(date)
                  ? 'Hôm nay'
                  : '${date.day}/${date.month}/${date.year}',
            ),
            _infoRow(
              AppIcons.notesRounded,
              'Ghi chú',
              result.description?.trim().isNotEmpty == true
                  ? result.description!
                  : 'Không có',
            ),
            const SizedBox(height: 12),
            if (cancelled)
              _status(
                AppIcons.cancelRounded,
                'Đã hủy giao dịch',
                AppColors.error,
              )
            else if (saved)
              _status(
                AppIcons.checkCircleRounded,
                'Đã lưu giao dịch',
                AppColors.income,
              )
            else
              Row(
                children: [
                  IconButton.outlined(
                    tooltip: 'Hủy',
                    onPressed: saving ? null : onCancel,
                    icon: const Icon(AppIcons.closeRounded),
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: saving ? null : onEdit,
                      icon: const Icon(AppIcons.editRounded, size: 17),
                      label: const Text('Chỉnh sửa'),
                    ),
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _hasRequiredFields && !saving ? onSave : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.tealPrimary,
                        foregroundColor: Colors.white,
                      ),
                      child: saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Xác nhận lưu'),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(
    IconData icon,
    String label,
    String value, {
    bool warning = false,
    Widget? trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.textMuted),
          const SizedBox(width: 8),
          SizedBox(
            width: 68,
            child: Text(
              label,
              style: GoogleFonts.outfit(
                color: AppColors.textMuted,
                fontSize: 11,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.outfit(
                color: warning ? AppColors.warning : AppColors.textPrimary,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (trailing != null) trailing,
        ],
      ),
    );
  }

  Widget _status(IconData icon, String text, Color color) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: color.withAlpha(18),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 7),
        Text(
          text,
          style: GoogleFonts.outfit(color: color, fontWeight: FontWeight.w700),
        ),
      ],
    ),
  );

  bool _isToday(DateTime value) {
    final now = DateTime.now();
    return value.year == now.year &&
        value.month == now.month &&
        value.day == now.day;
  }
}
