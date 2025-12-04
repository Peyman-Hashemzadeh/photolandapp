import 'package:shamsi_date/shamsi_date.dart';

class DateHelper {
  /// دریافت تاریخ شمسی امروز به فرمت: ۱۴۰۴/۰۸/۰۷
  static String getCurrentPersianDate() {
    final now = DateTime.now();
    final jalali = Jalali.fromDateTime(now);

    // تبدیل اعداد به فارسی
    return toPersianDigits(
        '${jalali.year}/${jalali.month.toString().padLeft(2, '0')}/${jalali.day.toString().padLeft(2, '0')}'
    );
  }

  /// فرمت کامل تاریخ شمسی: "یکشنبه، آبان ۱۸ ۱۴۰۴"
  static String formatPersianDate(Jalali? date) {
    if (date == null) return 'تاریخ درخواستی';

    final weekDay = date.formatter.wN;  // نام روز (یکشنبه)
    final day = toPersianDigits(date.day.toString());
    final monthName = date.formatter.mN;  // نام ماه (آبان)
    final year = toPersianDigits(date.year.toString());

    return '$weekDay، $day $monthName $year';
  }

  static String getPersianDayName(DateTime date) {
    const days = ['یکشنبه', 'دوشنبه', 'سه‌شنبه', 'چهارشنبه', 'پنجشنبه', 'جمعه', 'شنبه'];
    return days[date.weekday % 7];
  }

  static String getPersianMonthName(int month) {
    const months = [
      'فروردین', 'اردیبهشت', 'خرداد', 'تیر', 'مرداد', 'شهریور',
      'مهر', 'آبان', 'آذر', 'دی', 'بهمن', 'اسفند'
    ];
    return months[month - 1];
  }

  /// فرمت فقط نام ماه و سال: "آبان ۱۴۰۴"
  static String formatMonthYear(Jalali date) {
    final monthName = date.formatter.mN;
    final year = toPersianDigits(date.year.toString());
    return '$monthName $year';
  }

  /// تبدیل DateTime به تاریخ شمسی
  static String dateTimeToShamsi(DateTime dateTime) {
    final jalali = Jalali.fromDateTime(dateTime);
    return toPersianDigits(
        '${jalali.year}/${jalali.month.toString().padLeft(2, '0')}/${jalali.day.toString().padLeft(2, '0')}'
    );
  }

  /// تبدیل تاریخ شمسی به DateTime
  static DateTime shamsiToDateTime(int year, int month, int day) {
    final jalali = Jalali(year, month, day);
    return jalali.toDateTime();
  }

  /// تبدیل اعداد انگلیسی به فارسی (بهبودیافته برای stringهای پیچیده)
  static String toPersianDigits(String input) {
    const englishDigits = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    const persianDigits = ['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'];
    StringBuffer buffer = StringBuffer();
    for (int i = 0; i < input.length; i++) {
      final char = input[i];
      final index = englishDigits.indexOf(char);
      if (index != -1) {
        buffer.write(persianDigits[index]);
      } else {
        buffer.write(char);
      }
    }
    return buffer.toString();
  }
}