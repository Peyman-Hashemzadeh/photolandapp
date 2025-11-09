import 'package:cloud_firestore/cloud_firestore.dart';

class CustomerModel {
  final String id;
  final String fullName;
  final String mobileNumber;
  final String? notes;
  final bool isActive;
  final DateTime createdAt;
  final DateTime? updatedAt;

  CustomerModel({
    required this.id,
    required this.fullName,
    required this.mobileNumber,
    this.notes,
    this.isActive = true,
    required this.createdAt,
    this.updatedAt,
  });

  // تبدیل از Map به Object
  factory CustomerModel.fromMap(Map<String, dynamic> map, String id) {
    return CustomerModel(
      id: id,
      fullName: map['fullName'] ?? '',
      mobileNumber: map['mobileNumber'] ?? '',
      notes: map['notes'],
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
      'fullName': fullName,
      'mobileNumber': mobileNumber,
      'notes': notes,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }

  // کپی با تغییرات
  CustomerModel copyWith({
    String? id,
    String? fullName,
    String? mobileNumber,
    String? notes,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CustomerModel(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      mobileNumber: mobileNumber ?? this.mobileNumber,
      notes: notes ?? this.notes,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}