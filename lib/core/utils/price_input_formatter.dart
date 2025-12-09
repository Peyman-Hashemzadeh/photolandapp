import 'package:flutter/services.dart';
import '../utils/date_helper.dart';

class PersianPriceInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue,
      TextEditingValue newValue,
      ) {
    // جلوگیری از حذف یکجا
    if (newValue.text.isEmpty) {
      return newValue;
    }

    // حذف جداکننده و تبدیل فارسی → انگلیسی برای پردازش
    String clean = newValue.text
        .replaceAll('٬', '') // کاما فارسی
        .replaceAll(',', '') // کاما انگلیسی
        .replaceAllMapped(RegExp('[۰-۹]'), (Match m) {
      return (m.group(0)!.codeUnitAt(0) - 1776).toString();
    });

    // اگر خالی شد
    if (clean.isEmpty) clean = "0";

    // تبدیل به int
    final number = int.tryParse(clean) ?? 0;

    // جداکننده سه‌رقمی انگلیسی
    String formatted = _formatWithComma(number.toString());

    // تبدیل اعداد انگلیسی به فارسی
    formatted = DateHelper.toPersianDigits(formatted);

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  /// ۳ رقم ۳ رقم جدا می‌کند
  String _formatWithComma(String value) {
    final buffer = StringBuffer();
    int digits = 0;

    for (int i = value.length - 1; i >= 0; i--) {
      buffer.write(value[i]);
      digits++;
      if (digits == 3 && i != 0) {
        buffer.write(',');
        digits = 0;
      }
    }

    return buffer.toString().split('').reversed.join('');
  }
}

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