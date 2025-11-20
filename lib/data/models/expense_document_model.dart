import 'package:cloud_firestore/cloud_firestore.dart';

class ExpenseDocumentModel {
  final String id;
  final int documentNumber; // شماره سند (از 1 شروع)
  final String expenseId; // ID هزینه انتخاب شده
  final String expenseName; // نام هزینه
  final DateTime documentDate; // تاریخ سند
  final int amount; // مبلغ هزینه
  final String? bankId; // ID بانک (اختیاری)
  final String? bankName; // نام بانک (اختیاری)
  final bool isCash; // پرداخت نقدی؟
  final String? notes; // توضیحات (اختیاری)
  final DateTime createdAt;
  final DateTime? updatedAt;

  ExpenseDocumentModel({
    required this.id,
    required this.documentNumber,
    required this.expenseId,
    required this.expenseName,
    required this.documentDate,
    required this.amount,
    this.bankId,
    this.bankName,
    this.isCash = false,
    this.notes,
    required this.createdAt,
    this.updatedAt,
  });

  // نمایش نوع پرداخت
  String get paymentTypeLabel => isCash ? 'نقدی' : (bankName ?? 'بانکی');

  // تبدیل از Map به Object
  factory ExpenseDocumentModel.fromMap(Map<String, dynamic> map, String id) {
    return ExpenseDocumentModel(
      id: id,
      documentNumber: map['documentNumber'] ?? 1,
      expenseId: map['expenseId'] ?? '',
      expenseName: map['expenseName'] ?? '',
      documentDate: (map['documentDate'] as Timestamp).toDate(),
      amount: map['amount'] ?? 0,
      bankId: map['bankId'],
      bankName: map['bankName'],
      isCash: map['isCash'] ?? false,
      notes: map['notes'],
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      updatedAt: map['updatedAt'] != null
          ? (map['updatedAt'] as Timestamp).toDate()
          : null,
    );
  }

  // تبدیل از Object به Map
  Map<String, dynamic> toMap() {
    return {
      'documentNumber': documentNumber,
      'expenseId': expenseId,
      'expenseName': expenseName,
      'documentDate': Timestamp.fromDate(documentDate),
      'amount': amount,
      'bankId': bankId,
      'bankName': bankName,
      'isCash': isCash,
      'notes': notes,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }

  // کپی با تغییرات
  ExpenseDocumentModel copyWith({
    String? id,
    int? documentNumber,
    String? expenseId,
    String? expenseName,
    DateTime? documentDate,
    int? amount,
    String? bankId,
    String? bankName,
    bool? isCash,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ExpenseDocumentModel(
      id: id ?? this.id,
      documentNumber: documentNumber ?? this.documentNumber,
      expenseId: expenseId ?? this.expenseId,
      expenseName: expenseName ?? this.expenseName,
      documentDate: documentDate ?? this.documentDate,
      amount: amount ?? this.amount,
      bankId: bankId ?? this.bankId,
      bankName: bankName ?? this.bankName,
      isCash: isCash ?? this.isCash,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}