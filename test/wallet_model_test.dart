import 'package:flutter_test/flutter_test.dart';
import 'package:moni_ai/models/wallet_model.dart';
import 'package:moni_ai/theme/app_icons.dart';

void main() {
  test('reads old bank wallet data without losing compatibility', () {
    final wallet = WalletModel.fromMap({
      'id': 1,
      'user_id': 'user_1',
      'name': 'MB Bank',
      'type': 'mbbank',
      'balance': 5000000,
      'created_at': '2026-07-24T08:00:00',
    });

    expect(wallet.walletType.key, 'bank');
    expect(wallet.walletType.name, 'Ngân hàng');
    expect(wallet.currency, 'VND');
    expect(wallet.isDefault, isFalse);
  });

  test('persists custom wallet appearance and default status', () {
    final wallet = WalletModel(
      id: 2,
      userId: 'user_1',
      name: 'Ví học tập',
      type: 'savings',
      balance: 2500000,
      iconKey: 'school',
      colorValue: 0xFFA78BFA,
      note: 'Đóng học phí',
      isDefault: true,
    );
    final restored = WalletModel.fromMap(wallet.toMap());

    expect(restored.walletType.icon, AppIcons.school);
    expect(restored.walletType.color.toARGB32(), 0xFFA78BFA);
    expect(restored.note, 'Đóng học phí');
    expect(restored.isDefault, isTrue);
  });

  test('selects the default wallet as preferred', () {
    final wallets = [
      WalletModel(
        id: 1,
        userId: 'user_1',
        name: 'Tiền mặt',
        type: 'cash',
        balance: 100000,
      ),
      WalletModel(
        id: 2,
        userId: 'user_1',
        name: 'MB Bank',
        type: 'bank',
        balance: 5000000,
        isDefault: true,
      ),
    ];

    expect(WalletModel.preferred(wallets)?.id, 2);
  });
}
