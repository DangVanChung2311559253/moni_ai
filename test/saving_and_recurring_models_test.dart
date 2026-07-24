import 'package:flutter_test/flutter_test.dart';
import 'package:moni_ai/models/category_model.dart';
import 'package:moni_ai/models/saving_goal_model.dart';
import 'package:moni_ai/services/recurring_transaction_service.dart';

void main() {
  test('calculates saving goal progress and remaining amount', () {
    final now = DateTime.now();
    final goal = SavingGoal(
      id: 'goal_1',
      userId: 'user_1',
      name: 'Mua laptop',
      targetAmount: 20000000,
      savedAmount: 8000000,
      deadline: DateTime(now.year, now.month + 6, now.day),
      icon: 'laptop',
      color: 0xFF00D4AA,
      status: 'active',
      createdAt: now,
      updatedAt: now,
    );

    expect(goal.progressPercent, 40);
    expect(goal.remainingAmount, 12000000);
    expect(goal.monthsRemaining, greaterThanOrEqualTo(6));
    expect(goal.requiredPerMonth, greaterThan(0));
  });

  test('marks an unfinished saving goal as overdue', () {
    final now = DateTime.now();
    final goal = SavingGoal(
      id: 'goal_2',
      userId: 'user_1',
      name: 'Quỹ khẩn cấp',
      targetAmount: 10000000,
      savedAmount: 1000000,
      deadline: now.subtract(const Duration(days: 1)),
      icon: 'emergency',
      color: 0xFFFF6B6B,
      status: 'active',
      createdAt: now,
      updatedAt: now,
    );

    expect(goal.isOverdue, isTrue);
    expect(goal.monthsRemaining, 0);
    expect(goal.requiredPerMonth, 9000000);
  });

  test('monthly recurrence uses the final day for short months', () {
    final february = RecurringTransactionService.calculateNextDate(
      DateTime(2027, 1, 31),
      'monthly',
      31,
    );
    final march = RecurringTransactionService.calculateNextDate(
      february,
      'monthly',
      31,
    );

    expect(february, DateTime(2027, 2, 28));
    expect(march, DateTime(2027, 3, 31));
  });

  test('saving transaction category is available', () {
    final category = CategoryModel.getById(13);
    expect(category.name, 'Tiết kiệm');
    expect(category.isIncome, isFalse);
  });
}
