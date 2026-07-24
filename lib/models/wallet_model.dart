import 'package:flutter/material.dart';
import '../theme/app_icons.dart';

class WalletType {
  final String key;
  final String name;
  final Color color;
  final IconData icon;
  final String iconKey;

  const WalletType({
    required this.key,
    required this.name,
    required this.color,
    required this.icon,
    required this.iconKey,
  });

  static const Map<String, IconData> iconOptions = {
    'cash': AppIcons.cash,
    'bank': AppIcons.bank,
    'card': AppIcons.creditCard,
    'phone': AppIcons.eWallet,
    'savings': AppIcons.saving,
    'school': AppIcons.school,
    'car': AppIcons.car,
    'home': AppIcons.home,
    'wallet': AppIcons.wallet,
    'other': AppIcons.package,
  };

  static const List<int> colorOptions = [
    0xFF00D4AA,
    0xFF60A5FA,
    0xFFA78BFA,
    0xFFFF6B9D,
    0xFFFBBF24,
    0xFF4ADE80,
    0xFFFF8C00,
    0xFF22D3EE,
  ];

  static const List<WalletType> all = [
    WalletType(
      key: 'cash',
      name: 'Tiền mặt',
      color: Color(0xFF4ADE80),
      icon: AppIcons.cash,
      iconKey: 'cash',
    ),
    WalletType(
      key: 'bank',
      name: 'Ngân hàng',
      color: Color(0xFF60A5FA),
      icon: AppIcons.bank,
      iconKey: 'bank',
    ),
    WalletType(
      key: 'ewallet',
      name: 'Ví điện tử',
      color: Color(0xFF22D3EE),
      icon: AppIcons.eWallet,
      iconKey: 'phone',
    ),
    WalletType(
      key: 'credit',
      name: 'Thẻ tín dụng',
      color: Color(0xFFA78BFA),
      icon: AppIcons.creditCard,
      iconKey: 'card',
    ),
    WalletType(
      key: 'savings',
      name: 'Tiết kiệm',
      color: Color(0xFFFF6B9D),
      icon: AppIcons.saving,
      iconKey: 'savings',
    ),
    WalletType(
      key: 'other',
      name: 'Khác',
      color: Color(0xFFFBBF24),
      icon: AppIcons.package,
      iconKey: 'other',
    ),
  ];

  static const Map<String, String> _legacyTypes = {
    'mbbank': 'bank',
    'vietcombank': 'bank',
    'bidv': 'bank',
    'agribank': 'bank',
    'momo': 'ewallet',
    'zalopay': 'ewallet',
  };

  static WalletType getByKey(String key) {
    final normalized = _legacyTypes[key] ?? key;
    return all.firstWhere(
      (wallet) => wallet.key == normalized,
      orElse: () => all.last,
    );
  }

  static IconData iconFor(String? key, IconData fallback) =>
      iconOptions[key] ?? fallback;
}

class WalletModel {
  final int? id;
  final String userId;
  final String name;
  final String type;
  final double balance;
  final String? iconKey;
  final int? colorValue;
  final String currency;
  final String? note;
  final bool isDefault;
  final DateTime createdAt;

  WalletModel({
    this.id,
    required this.userId,
    required this.name,
    required this.type,
    required this.balance,
    this.iconKey,
    this.colorValue,
    this.currency = 'VND',
    this.note,
    this.isDefault = false,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  WalletType get walletType {
    final base = WalletType.getByKey(type);
    return WalletType(
      key: base.key,
      name: base.name,
      color: colorValue == null ? base.color : Color(colorValue!),
      icon: WalletType.iconFor(iconKey, base.icon),
      iconKey: iconKey ?? base.iconKey,
    );
  }

  static WalletModel? preferred(List<WalletModel> wallets) {
    if (wallets.isEmpty) return null;
    return wallets.firstWhere(
      (wallet) => wallet.isDefault,
      orElse: () => wallets.first,
    );
  }

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id,
    'user_id': userId,
    'name': name,
    'type': type,
    'balance': balance,
    'icon_key': iconKey,
    'color_value': colorValue,
    'currency': currency,
    'note': note,
    'is_default': isDefault,
    'created_at': createdAt.toIso8601String(),
  };

  factory WalletModel.fromMap(Map<String, dynamic> map) => WalletModel(
    id: (map['id'] as num?)?.toInt(),
    userId: (map['user_id'] ?? '').toString(),
    name: (map['name'] ?? 'Ví').toString(),
    type: (map['type'] ?? 'other').toString(),
    balance: (map['balance'] as num?)?.toDouble() ?? 0,
    iconKey: map['icon_key']?.toString(),
    colorValue: (map['color_value'] as num?)?.toInt(),
    currency: (map['currency'] ?? 'VND').toString(),
    note: map['note']?.toString(),
    isDefault: map['is_default'] == true,
    createdAt:
        DateTime.tryParse((map['created_at'] ?? '').toString()) ??
        DateTime.now(),
  );

  WalletModel copyWith({
    int? id,
    String? userId,
    String? name,
    String? type,
    double? balance,
    String? iconKey,
    int? colorValue,
    String? currency,
    String? note,
    bool? isDefault,
  }) => WalletModel(
    id: id ?? this.id,
    userId: userId ?? this.userId,
    name: name ?? this.name,
    type: type ?? this.type,
    balance: balance ?? this.balance,
    iconKey: iconKey ?? this.iconKey,
    colorValue: colorValue ?? this.colorValue,
    currency: currency ?? this.currency,
    note: note ?? this.note,
    isDefault: isDefault ?? this.isDefault,
    createdAt: createdAt,
  );
}
