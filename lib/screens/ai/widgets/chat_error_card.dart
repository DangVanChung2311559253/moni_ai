import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/app_theme.dart';

class ChatErrorCard extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  final VoidCallback onManualEntry;

  const ChatErrorCard({
    super.key,
    required this.message,
    required this.onRetry,
    required this.onManualEntry,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: MediaQuery.sizeOf(context).width * 0.84,
      margin: const EdgeInsets.only(left: 40, bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.error.withAlpha(18),
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: AppColors.error.withAlpha(90)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(AppIcons.cloudOffRounded, color: AppColors.error),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  'Không thể kết nối Moni AI lúc này',
                  style: GoogleFonts.outfit(
                    color: AppColors.error,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: GoogleFonts.outfit(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(AppIcons.refreshRounded, size: 17),
                  label: const Text('Thử lại'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: onManualEntry,
                  child: const Text('Nhập thủ công'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
