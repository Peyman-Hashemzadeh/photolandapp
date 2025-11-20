import 'package:cloud_firestore/cloud_firestore.dart';

class StudioModel {
  final String id; // studioCode (مثلاً: 1205136907021368)
  final String studioName; // نام آتلیه
  final String? address; // آدرس آتلیه (اختیاری)
  final String? logoUrl; // URL لوگو در Firebase Storage
  final String bookingHash; // هش SHA-256 برای لینک فرم
  final bool isActive; // فعال/غیرفعال
  final DateTime createdAt;
  final DateTime? updatedAt;

  StudioModel({
    required this.id,
    required this.studioName,
    this.address,
    this.logoUrl,
    required this.bookingHash,
    this.isActive = true,
    required this.createdAt,
    this.updatedAt,
  });

  // تبدیل از Map به Object
  factory StudioModel.fromMap(Map<String, dynamic> map, String id) {
    return StudioModel(
      id: id,
      studioName: map['studioName'] ?? '',
      address: map['address'],
      logoUrl: map['logoUrl'],
      bookingHash: map['bookingHash'] ?? '',
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
      'studioName': studioName,
      'address': address,
      'logoUrl': logoUrl,
      'bookingHash': bookingHash,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }

  // کپی با تغییرات
  StudioModel copyWith({
    String? id,
    String? studioName,
    String? address,
    String? logoUrl,
    String? bookingHash,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return StudioModel(
      id: id ?? this.id,
      studioName: studioName ?? this.studioName,
      address: address ?? this.address,
      logoUrl: logoUrl ?? this.logoUrl,
      bookingHash: bookingHash ?? this.bookingHash,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // لینک فرم رزرو آنلاین
  String get bookingUrl {
    return 'https://photoland-studio.web.app/?ref=$bookingHash';
  }
}