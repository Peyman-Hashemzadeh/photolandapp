import 'package:shamsi_date/shamsi_date.dart';

class DateHelper {
  /// دریافت تاریخ شمسی امروز به فرمت: ۱۴۰۴/۰۸/۰۷
  static String getCurrentPersianDate() {
    final now = DateTime.now();
    final jalali = Jalali.fromDateTime(now);

    // تبدیل اعداد به فارسی
    return _toPersianNumber(
        '${jalali.year}/${jalali.month.toString().padLeft(2, '0')}/${jalali.day.toString().padLeft(2, '0')}'
    );
  }

  /// تبدیل اعداد انگلیسی به فارسی
  static String _toPersianNumber(String input) {
    const english = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    const farsi = ['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'];

    String result = input;
    for (int i = 0; i < english.length; i++) {
      result = result.replaceAll(english[i], farsi[i]);
    }
    return result;
  }

  /// تبدیل DateTime به تاریخ شمسی
  static String dateTimeToShamsi(DateTime dateTime) {
    final jalali = Jalali.fromDateTime(dateTime);
    return _toPersianNumber(
        '${jalali.year}/${jalali.month.toString().padLeft(2, '0')}/${jalali.day.toString().padLeft(2, '0')}'
    );
  }

  /// تبدیل تاریخ شمسی به DateTime
  static DateTime shamsiToDateTime(int year, int month, int day) {
    final jalali = Jalali(year, month, day);
    return jalali.toDateTime();
  }
}