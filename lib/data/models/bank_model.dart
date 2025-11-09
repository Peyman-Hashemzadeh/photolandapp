import 'package:cloud_firestore/cloud_firestore.dart';

class BankModel {
  final String id;
  final String bankName;
  final String? accountNumber;
  final String? ibanNumber; // شماره شبا (بدون IR)
  final String?  accountOwner;
  final bool isActive;
  final DateTime createdAt;
  final DateTime? updatedAt;

  BankModel({
    required this.id,
    required this.bankName,
    this.accountNumber,
    this.ibanNumber,
    this.accountOwner,
    this.isActive = true,
    required this.createdAt,
    this.updatedAt,
  });

  // دریافت شماره شبا با IR
  String? get ibanWithPrefix {
    if (ibanNumber == null || ibanNumber!.isEmpty) return null;
    return 'IR$ibanNumber';
  }

  // تبدیل از Map به Object
  factory BankModel.fromMap(Map<String, dynamic> map, String id) {
    return BankModel(
      id: id,
      bankName: map['bankName'] ?? '',
      accountNumber: map['accountNumber'],
      ibanNumber: map['ibanNumber'],
      accountOwner: map['accountOwner'],
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
      'bankName': bankName,
      'accountNumber': accountNumber,
      'ibanNumber': ibanNumber,
      'accountOwner': accountOwner,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }

  // کپی با تغییرات
  BankModel copyWith({
    String? id,
    String? bankName,
    String? accountNumber,
    String? ibanNumber,
    String? accountOwner,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return BankModel(
      id: id ?? this.id,
      bankName: bankName ?? this.bankName,
      accountNumber: accountNumber ?? this.accountNumber,
      ibanNumber: ibanNumber ?? this.ibanNumber,
      accountOwner: accountOwner ?? this.accountOwner,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}