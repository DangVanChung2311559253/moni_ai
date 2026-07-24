import 'package:flutter/material.dart';
import '../theme/app_icons.dart';

class CategoryModel {
  final int id;
  final String name;
  final String iconKey;
  final int colorValue;
  final bool isIncome;

  const CategoryModel({
    required this.id,
    required this.name,
    required this.iconKey,
    required this.colorValue,
    required this.isIncome,
  });

  Color get color => Color(colorValue);
  IconData get icon => _iconMap[iconKey] ?? AppIcons.other;

  static const Map<String, IconData> _iconMap = {
    'restaurant': AppIcons.food,
    'directions_car': AppIcons.transport,
    'home': AppIcons.home,
    'school': AppIcons.education,
    'shopping_bag': AppIcons.shopping,
    'sports_esports': AppIcons.entertainment,
    'favorite': AppIcons.health,
    'receipt': AppIcons.bill,
    'category': AppIcons.other,
    'account_balance': AppIcons.salary,
    'card_giftcard': AppIcons.gift,
    'work': AppIcons.investment,
    'savings': AppIcons.saving,
  };

  static const List<CategoryModel> all = [
    CategoryModel(
      id: 1,
      name: 'Ăn uống',
      iconKey: 'restaurant',
      colorValue: 0xFFFF6B9D,
      isIncome: false,
    ),
    CategoryModel(
      id: 2,
      name: 'Đi lại',
      iconKey: 'directions_car',
      colorValue: 0xFFFBBF24,
      isIncome: false,
    ),
    CategoryModel(
      id: 3,
      name: 'Nhà ở',
      iconKey: 'home',
      colorValue: 0xFF60A5FA,
      isIncome: false,
    ),
    CategoryModel(
      id: 4,
      name: 'Học tập',
      iconKey: 'school',
      colorValue: 0xFFA78BFA,
      isIncome: false,
    ),
    CategoryModel(
      id: 5,
      name: 'Mua sắm',
      iconKey: 'shopping_bag',
      colorValue: 0xFFF472B6,
      isIncome: false,
    ),
    CategoryModel(
      id: 6,
      name: 'Giải trí',
      iconKey: 'sports_esports',
      colorValue: 0xFF34D399,
      isIncome: false,
    ),
    CategoryModel(
      id: 7,
      name: 'Sức khỏe',
      iconKey: 'favorite',
      colorValue: 0xFFFF6B6B,
      isIncome: false,
    ),
    CategoryModel(
      id: 8,
      name: 'Hóa đơn',
      iconKey: 'receipt',
      colorValue: 0xFF22D3EE,
      isIncome: false,
    ),
    CategoryModel(
      id: 9,
      name: 'Khác',
      iconKey: 'category',
      colorValue: 0xFF9CA3AF,
      isIncome: false,
    ),
    CategoryModel(
      id: 10,
      name: 'Lương',
      iconKey: 'account_balance',
      colorValue: 0xFF4ADE80,
      isIncome: true,
    ),
    CategoryModel(
      id: 11,
      name: 'Thưởng',
      iconKey: 'card_giftcard',
      colorValue: 0xFF4ADE80,
      isIncome: true,
    ),
    CategoryModel(
      id: 12,
      name: 'Thu nhập khác',
      iconKey: 'work',
      colorValue: 0xFF4ADE80,
      isIncome: true,
    ),
    CategoryModel(
      id: 13,
      name: 'Tiết kiệm',
      iconKey: 'savings',
      colorValue: 0xFF00D4AA,
      isIncome: false,
    ),
  ];

  static List<CategoryModel> get expenseCategories =>
      all.where((c) => !c.isIncome).toList();
  static List<CategoryModel> get incomeCategories =>
      all.where((c) => c.isIncome).toList();

  static CategoryModel getById(int id) =>
      all.firstWhere((c) => c.id == id, orElse: () => all[8]);
}
