import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

final NumberFormat _vndDigits = NumberFormat.decimalPattern('vi_VN');

String formatVndInput(num value) => _vndDigits.format(value.round());

double? parseVndInput(String value) {
  final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
  return digits.isEmpty ? null : double.tryParse(digits);
}

class VndInputFormatter extends TextInputFormatter {
  const VndInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return const TextEditingValue();
    final normalized = digits.replaceFirst(RegExp(r'^0+(?=\d)'), '');
    final number = int.tryParse(normalized);
    if (number == null) return oldValue;
    final formatted = _vndDigits.format(number);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
