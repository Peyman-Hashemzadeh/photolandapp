class Validators {
  // اعتبارسنجی نام و نام خانوادگی
  static String? validateFullName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'لطفاً نام و نام خانوادگی را وارد کنید';
    }
    if (value.trim().length > 20) {
      return 'نام و نام خانوادگی نباید بیشتر از ۲۰ کاراکتر باشد';
    }
    return null;
  }

  // اعتبارسنجی شماره همراه
  static String? validateMobileNumber(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'لطفاً شماره همراه را وارد کنید';
    }

    // حذف فاصله‌ها
    final cleanValue = value.replaceAll(' ', '');

    // بررسی طول ۱۱ رقمی
    if (cleanValue.length != 11) {
      return 'شماره همراه باید ۱۱ رقمی باشد';
    }

    // بررسی شروع با ۰۹
    if (!cleanValue.startsWith('09')) {
      return 'شماره همراه باید با ۰۹ شروع شود';
    }

    // بررسی فقط عدد بودن
    if (!RegExp(r'^[0-9]+$').hasMatch(cleanValue)) {
      return 'شماره همراه فقط باید شامل اعداد باشد';
    }

    return null;
  }

  // اعتبارسنجی کد آتلیه
  static String? validateStudioCode(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'لطفاً کد آتلیه را وارد کنید';
    }

    // حذف فاصله‌ها
    final cleanValue = value.replaceAll(' ', '');

    // بررسی طول ۱۶ رقمی
    if (cleanValue.length != 16) {
      return 'کد آتلیه باید ۱۶ رقمی باشد';
    }

    // بررسی فقط عدد بودن
    if (!RegExp(r'^[0-9]+$').hasMatch(cleanValue)) {
      return 'کد آتلیه فقط باید شامل اعداد باشد';
    }

    return null;
  }

  // اعتبارسنجی رمز عبور
  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'لطفاً رمز عبور را وارد کنید';
    }

    if (value.length < 6) {
      return 'رمز عبور باید حداقل ۶ کاراکتر باشد';
    }

    return null;
  }

  // اعتبارسنجی تکرار رمز عبور
  static String? validateConfirmPassword(String? value, String password) {
    if (value == null || value.isEmpty) {
      return 'لطفاً تکرار رمز عبور را وارد کنید';
    }

    if (value != password) {
      return 'تکرار رمز عبور با رمز عبور مطابقت ندارد';
    }

    return null;
  }

  // پاک‌سازی شماره همراه (حذف فاصله‌ها)
  static String cleanMobileNumber(String value) {
    return value.replaceAll(' ', '');
  }

  // پاک‌سازی کد آتلیه (حذف فاصله‌ها)
  static String cleanStudioCode(String value) {
    return value.replaceAll(' ', '');
  }
}