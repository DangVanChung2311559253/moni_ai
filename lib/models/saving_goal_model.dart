import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../theme/app_icons.dart';

class SavingGoal {
  final String id;
  final String userId;
  final String name;
  final double targetAmount;
  final double savedAmount;
  final DateTime deadline;
  final String icon;
  final int color;
  final String? note;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;

  const SavingGoal({
    required this.id,
    required this.userId,
    required this.name,
    required this.targetAmount,
    required this.savedAmount,
    required this.deadline,
    required this.icon,
    required this.color,
    this.note,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  double get progressPercent =>
      targetAmount <= 0 ? 0 : (savedAmount / targetAmount * 100).clamp(0, 100);

  double get remainingAmount => math.max(0, targetAmount - savedAmount);

  bool get isOverdue =>
      status != 'completed' &&
      _dateOnly(deadline).isBefore(_dateOnly(DateTime.now()));

  int get monthsRemaining {
    final now = _dateOnly(DateTime.now());
    final end = _dateOnly(deadline);
    if (!end.isAfter(now)) return 0;
    var months = (end.year - now.year) * 12 + end.month - now.month;
    if (end.day > now.day) months++;
    return math.max(1, months);
  }

  double get requiredPerMonth => monthsRemaining <= 0
      ? remainingAmount
      : remainingAmount / monthsRemaining;

  IconData get iconData => savingGoalIcons[icon] ?? AppIcons.saving;
  Color get displayColor => Color(color);

  Map<String, dynamic> toMap() => {
    'schema_version': 1,
    'id': id,
    'user_id': userId,
    'name': name,
    'target_amount': targetAmount,
    'saved_amount': savedAmount,
    'deadline': Timestamp.fromDate(deadline),
    'icon': icon,
    'color': color,
    'note': note,
    'status': status,
    'created_at': Timestamp.fromDate(createdAt),
    'updated_at': Timestamp.fromDate(updatedAt),
  };

  factory SavingGoal.fromMap(String id, Map<String, dynamic> map) {
    return SavingGoal(
      id: id,
      userId: (map['user_id'] ?? '').toString(),
      name: (map['name'] ?? 'Mục tiêu').toString(),
      targetAmount: (map['target_amount'] as num?)?.toDouble() ?? 0,
      savedAmount: (map['saved_amount'] as num?)?.toDouble() ?? 0,
      deadline: _readDate(map['deadline']),
      icon: (map['icon'] ?? 'savings').toString(),
      color: (map['color'] as num?)?.toInt() ?? 0xFF00D4AA,
      note: map['note']?.toString(),
      status: (map['status'] ?? 'active').toString(),
      createdAt: _readDate(map['created_at']),
      updatedAt: _readDate(map['updated_at']),
    );
  }

  SavingGoal copyWith({
    String? name,
    double? targetAmount,
    double? savedAmount,
    DateTime? deadline,
    String? icon,
    int? color,
    String? note,
    String? status,
    DateTime? updatedAt,
  }) {
    return SavingGoal(
      id: id,
      userId: userId,
      name: name ?? this.name,
      targetAmount: targetAmount ?? this.targetAmount,
      savedAmount: savedAmount ?? this.savedAmount,
      deadline: deadline ?? this.deadline,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      note: note ?? this.note,
      status: status ?? this.status,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class SavingGoalContribution {
  final String id;
  final String goalId;
  final String userId;
  final int walletId;
  final double amount;
  final String type;
  final String? note;
  final DateTime createdAt;

  const SavingGoalContribution({
    required this.id,
    required this.goalId,
    required this.userId,
    required this.walletId,
    required this.amount,
    required this.type,
    this.note,
    required this.createdAt,
  });

  factory SavingGoalContribution.fromMap(String id, Map<String, dynamic> map) {
    return SavingGoalContribution(
      id: id,
      goalId: (map['goal_id'] ?? '').toString(),
      userId: (map['user_id'] ?? '').toString(),
      walletId: (map['wallet_id'] as num?)?.toInt() ?? 0,
      amount: (map['amount'] as num?)?.toDouble() ?? 0,
      type: (map['type'] ?? 'deposit').toString(),
      note: map['note']?.toString(),
      createdAt: _readDate(map['created_at']),
    );
  }
}

const Map<String, IconData> savingGoalIcons = {
  'savings': AppIcons.saving,
  'laptop': AppIcons.laptopMacRounded,
  'travel': AppIcons.flightTakeoffRounded,
  'emergency': AppIcons.health,
  'car': AppIcons.car,
  'education': AppIcons.education,
  'home': AppIcons.home,
  'gift': AppIcons.gift,
};

DateTime _readDate(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return DateTime.tryParse(value?.toString() ?? '') ?? DateTime.now();
}

DateTime _dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);
