import 'package:flutter/services.dart';

class PriceInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue,
      TextEditingValue newValue,
      ) {
    if (newValue.text.isEmpty) {
      return newValue;
    }

    // حذف همه چیز به جز اعداد
    String digitsOnly = newValue.text.replaceAll(RegExp(r'[^\d]'), '');

    // محدودیت ۱۲ رقم
    if (digitsOnly.length > 12) {
      digitsOnly = digitsOnly.substring(0, 12);
    }

    // اضافه کردن جداکننده (کاما) هر سه رقم
    String formatted = _formatWithComma(digitsOnly);

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  String _formatWithComma(String number) {
    if (number.isEmpty) return '';

    final buffer = StringBuffer();
    final length = number.length;

    for (int i = 0; i < length; i++) {
      if (i > 0 && (length - i) % 3 == 0) {
        buffer.write(',');
      }
      buffer.write(number[i]);
    }

    return buffer.toString();
  }
}