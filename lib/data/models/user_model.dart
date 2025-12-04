import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String id;
  final String fullName;
  final String mobileNumber;
  final String studioCode;
  final DateTime createdAt;
  final bool isActive;
  final String? email;  // 🔥 جدید
  final String? profileImagePath;  // 🔥 جدید

  UserModel({
    required this.id,
    required this.fullName,
    required this.mobileNumber,
    required this.studioCode,
    required this.createdAt,
    this.isActive = true,
    this.email,  // 🔥 جدید
    this.profileImagePath,  // 🔥 جدید
  });

  // تبدیل از Map به Object
  factory UserModel.fromMap(Map<String, dynamic> map, String id) {
    return UserModel(
      id: id,
      fullName: map['fullName'] ?? '',
      mobileNumber: map['mobileNumber'] ?? '',
      studioCode: map['studioCode'] ?? '',
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      isActive: map['isActive'] ?? true,
      email: map['email'],  // 🔥 جدید
      profileImagePath: map['profileImagePath'],  // 🔥 جدید
    );
  }

  // تبدیل از Object به Map
  Map<String, dynamic> toMap() {
    return {
      'fullName': fullName,
      'mobileNumber': mobileNumber,
      'studioCode': studioCode,
      'createdAt': Timestamp.fromDate(createdAt),
      'isActive': isActive,
      'email': email,  // 🔥 جدید
      'profileImagePath': profileImagePath,  // 🔥 جدید
    };
  }

  // کپی با تغییرات
  UserModel copyWith({
    String? id,
    String? fullName,
    String? mobileNumber,
    String? studioCode,
    DateTime? createdAt,
    bool? isActive,
    String? email,  // 🔥 جدید
    String? profileImagePath,  // 🔥 جدید
  }) {
    return UserModel(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      mobileNumber: mobileNumber ?? this.mobileNumber,
      studioCode: studioCode ?? this.studioCode,
      createdAt: createdAt ?? this.createdAt,
      isActive: isActive ?? this.isActive,
      email: email ?? this.email,  // 🔥 جدید
      profileImagePath: profileImagePath ?? this.profileImagePath,  // 🔥 جدید
    );
  }
}