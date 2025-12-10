import 'package:cloud_firestore/cloud_firestore.dart';

class ExpenseModel {
  final String id;
  final String expenseName;
  final int? price; // قیمت به تومان (عدد صحیح)
  final bool isActive;
  final DateTime createdAt;
  final DateTime? updatedAt;

  ExpenseModel({
    required this.id,
    required this.expenseName,
    this.price,
    this.isActive = true,
    required this.createdAt,
    this.updatedAt,
  });

  // قیمت با فرمت (جداکننده سه رقمی)
  String? get formattedPrice {
    if (price == null) return null;
    return _formatNumber(price!);
  }

  // تابع فرمت‌کننده عدد
  static String formatNumber(int number) {
    final str = number.toString();
    final buffer = StringBuffer();

    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) {
        buffer.write(',');
      }
      buffer.write(str[i]);
    }

    return buffer.toString();
  }

  String _formatNumber(int number) {
    return formatNumber(number);
  }

  // تبدیل رشته قیمت با کاما به عدد
  // تبدیل رشته قیمت با کاما به عدد
  static int? parsePrice(String priceStr) {
    if (priceStr.isEmpty) return null;

    // حذف کاما (فارسی و انگلیسی)
    String cleaned = priceStr
        .replaceAll('٬', '')  // کاما فارسی
        .replaceAll(',', ''); // کاما انگلیسی

    // تبدیل اعداد فارسی به انگلیسی
    cleaned = cleaned.replaceAllMapped(RegExp('[۰-۹]'), (Match m) {
      return (m.group(0)!.codeUnitAt(0) - 1776).toString();
    });

    return int.tryParse(cleaned);
  }

  // تبدیل از Map به Object
  factory ExpenseModel.fromMap(Map<String, dynamic> map, String id) {
    return ExpenseModel(
      id: id,
      expenseName: map['expenseName'] ?? '',
      price: map['price'],
      isActive: map['isActive'] ?? true,
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      updatedAt: map['updatedAt'] != null
          ? (map['updatedAt'] as Timestamp).toDate()
          : null,
    );
  }

  // تبدیل از Object به Map
  Map<String, dynamic> toMap() {
    return {
      'expenseName': expenseName,
      'price': price,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }

  // کپی با تغییرات
  ExpenseModel copyWith({
    String? id,
    String? expenseName,
    int? price,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ExpenseModel(
      id: id ?? this.id,
      expenseName: expenseName ?? this.expenseName,
      price: price ?? this.price,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}