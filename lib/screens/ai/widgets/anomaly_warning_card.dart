import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/app_theme.dart';

class AnomalyWarningCard extends StatelessWidget {
  final String message;
  final VoidCallback onViewDetails;

  const AnomalyWarningCard({
    super.key,
    required this.message,
    required this.onViewDetails,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 42, right: 18, top: 8, bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.32)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  AppIcons.warningAmberRounded,
                  color: AppColors.warning,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Cảnh báo chi tiêu',
                  style: GoogleFonts.outfit(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            message,
            style: GoogleFonts.outfit(
              color: AppColors.textSecondary,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 10),
          TextButton.icon(
            onPressed: onViewDetails,
            icon: const Icon(AppIcons.arrowForwardRounded, size: 18),
            label: const Text('Xem phân tích bất thường'),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.warning,
              padding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
    );
  }
}
