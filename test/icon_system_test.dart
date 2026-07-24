import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moni_ai/models/category_model.dart';
import 'package:moni_ai/models/wallet_model.dart';
import 'package:moni_ai/theme/app_icons.dart';
import 'package:moni_ai/widgets/financial_brand_mark.dart';

void main() {
  test('primary app icons use Lucide', () {
    const icons = [
      AppIcons.dashboard,
      AppIcons.transactions,
      AppIcons.scan,
      AppIcons.ai,
      AppIcons.analytics,
      AppIcons.wallet,
    ];
    expect(icons.every((icon) => icon.fontFamily != 'MaterialIcons'), isTrue);
  });

  test('category and wallet icons share the Lucide family', () {
    final icons = [
      ...CategoryModel.all.map((category) => category.icon),
      ...WalletType.all.map((wallet) => wallet.icon),
    ];
    expect(icons.every((icon) => icon.fontFamily != 'MaterialIcons'), isTrue);
  });

  testWidgets('financial brands render scalable marks', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Row(
            children: [
              FinancialBrandMark(
                name: 'MB Bank',
                fallbackIcon: AppIcons.bank,
                fallbackColor: Colors.blue,
              ),
              FinancialBrandMark(
                name: 'MoMo',
                fallbackIcon: AppIcons.eWallet,
                fallbackColor: Colors.pink,
              ),
            ],
          ),
        ),
      ),
    );
    expect(find.text('MB'), findsOneWidget);
    expect(find.text('M'), findsOneWidget);
  });
}
