import 'package:cloud_firestore/cloud_firestore.dart';

class ServiceModel {
  final String id;
  final String serviceName;
  final int? price; // قیمت به تومان (عدد صحیح)
  final bool isActive;
  final DateTime createdAt;
  final DateTime? updatedAt;

  ServiceModel({
    required this.id,
    required this.serviceName,
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
  static String _formatNumber(int number) {
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

  // تبدیل رشته قیمت با کاما به عدد
  static int? parsePrice(String priceStr) {
    if (priceStr.isEmpty) return null;
    final cleaned = priceStr.replaceAll(',', '');
    return int.tryParse(cleaned);
  }

  // تبدیل از Map به Object
  factory ServiceModel.fromMap(Map<String, dynamic> map, String id) {
    return ServiceModel(
      id: id,
      serviceName: map['serviceName'] ?? '',
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
      'serviceName': serviceName,
      'price': price,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }

  // کپی با تغییرات
  ServiceModel copyWith({
    String? id,
    String? serviceName,
    int? price,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ServiceModel(
      id: id ?? this.id,
      serviceName: serviceName ?? this.serviceName,
      price: price ?? this.price,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}