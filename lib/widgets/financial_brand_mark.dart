import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class FinancialBrandMark extends StatelessWidget {
  final String name;
  final IconData fallbackIcon;
  final Color fallbackColor;
  final double size;
  final bool inverted;

  const FinancialBrandMark({
    super.key,
    required this.name,
    required this.fallbackIcon,
    required this.fallbackColor,
    this.size = 44,
    this.inverted = false,
  });

  @override
  Widget build(BuildContext context) {
    final brand = _FinancialBrand.resolve(name);
    if (brand == null) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: inverted
              ? Colors.white.withAlpha(35)
              : fallbackColor.withAlpha(25),
          borderRadius: BorderRadius.circular(size * 0.28),
        ),
        child: Icon(
          fallbackIcon,
          color: inverted ? Colors.white : fallbackColor,
          size: size * 0.5,
        ),
      );
    }
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: inverted ? Colors.white : brand.color.withAlpha(24),
        borderRadius: BorderRadius.circular(size * 0.28),
        border: Border.all(
          color: inverted
              ? Colors.white.withAlpha(80)
              : brand.color.withAlpha(80),
        ),
      ),
      child: Text(
        brand.mark,
        maxLines: 1,
        style: GoogleFonts.outfit(
          color: brand.color,
          fontSize: size * brand.fontScale,
          fontWeight: FontWeight.w800,
          height: 1,
          letterSpacing: -0.35,
        ),
      ),
    );
  }
}

class _FinancialBrand {
  final String mark;
  final Color color;
  final double fontScale;

  const _FinancialBrand(this.mark, this.color, [this.fontScale = 0.28]);

  static _FinancialBrand? resolve(String value) {
    final name = value.toLowerCase().replaceAll(RegExp(r'[\s_-]'), '');
    if (name.contains('mbbank') || name == 'mb') {
      return const _FinancialBrand('MB', Color(0xFF1464D2), 0.32);
    }
    if (name.contains('vietcombank') || name.contains('vcb')) {
      return const _FinancialBrand('VCB', Color(0xFF0B8F55), 0.24);
    }
    if (name.contains('bidv')) {
      return const _FinancialBrand('BIDV', Color(0xFF075AA8), 0.21);
    }
    if (name.contains('agribank')) {
      return const _FinancialBrand('AGR', Color(0xFF9D1C45), 0.22);
    }
    if (name.contains('momo')) {
      return const _FinancialBrand('M', Color(0xFFD82D8B), 0.38);
    }
    if (name.contains('zalopay')) {
      return const _FinancialBrand('Zalo', Color(0xFF0877E8), 0.2);
    }
    if (name.contains('vnpay')) {
      return const _FinancialBrand('VNPAY', Color(0xFF1464D2), 0.18);
    }
    return null;
  }
}
