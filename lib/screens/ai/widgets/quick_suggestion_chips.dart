import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/app_theme.dart';

class QuickSuggestionChips extends StatelessWidget {
  final List<String> suggestions;
  final ValueChanged<String> onSelected;
  final bool enabled;

  const QuickSuggestionChips({
    super.key,
    required this.suggestions,
    required this.onSelected,
    required this.enabled,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      padding: const EdgeInsets.only(left: 12),
      decoration: BoxDecoration(
        color: AppColors.navyMid,
        border: Border(
          top: BorderSide(color: AppColors.navyBorder.withAlpha(120)),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            AppIcons.autoAwesomeRounded,
            size: 15,
            color: AppColors.tealPrimary,
          ),
          const SizedBox(width: 6),
          Text(
            'Gợi ý',
            style: GoogleFonts.outfit(
              color: AppColors.tealPrimary,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(0, 6, 12, 5),
              itemCount: suggestions.length,
              separatorBuilder: (_, _) => const SizedBox(width: 7),
              itemBuilder: (_, index) => ActionChip(
                label: Text(suggestions[index]),
                onPressed: enabled
                    ? () => onSelected(suggestions[index])
                    : null,
                backgroundColor: AppColors.navyCard,
                disabledColor: AppColors.navyCard.withAlpha(120),
                side: BorderSide(color: AppColors.tealPrimary.withAlpha(55)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                labelStyle: GoogleFonts.outfit(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
