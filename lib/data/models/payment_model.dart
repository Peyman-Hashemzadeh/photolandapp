import 'package:cloud_firestore/cloud_firestore.dart';

class PaymentModel {
  final String id;
  final String appointmentId; // ارجاع به نوبت
  final String? invoiceId;
  final int amount; // مبلغ دریافتی
  final String type; // 'deposit' (بیعانه) یا 'settlement' (تسویه)
  final DateTime paymentDate; // تاریخ دریافت
  final String? bankId;
  final String? bankName;
  final String? accountNumber;
  final bool isCash; // آیا نقدی است؟
  final DateTime createdAt;
  final DateTime? updatedAt;

  PaymentModel({
    required this.id,
    required this.appointmentId,
    this.invoiceId,
    required this.amount,
    required this.type,
    required this.paymentDate,
    this.bankId,
    this.bankName,
    this.accountNumber,
    this.isCash = false,
    required this.createdAt,
    this.updatedAt,
  });

  // برچسب نوع دریافت
  String get typeLabel {
    switch (type) {
      case 'deposit':
        return 'بیعانه';
      case 'settlement':
        return 'تسویه';
      default:
        return 'نامشخص';
    }
  }

  // 🔥 نمایش بانک (نقدی یا نام بانک با 4 رقم آخر)
  String get bankDisplay {
    if (isCash) return 'نقدی';

    if (bankName != null) {
      if (accountNumber != null && accountNumber!.length >= 4) {
        final lastFour = accountNumber!.substring(accountNumber!.length - 4);
        return '$bankName ($lastFour)';
      }
      return bankName!;
    }

    return 'نامشخص';
  }

  // تبدیل از Map به Object
  factory PaymentModel.fromMap(Map<String, dynamic> map, String id) {
    return PaymentModel(
      id: id,
      appointmentId: map['appointmentId'] ?? '',
      invoiceId: map['invoiceId'],
      amount: map['amount'] ?? 0,
      type: map['type'] ?? 'settlement',
      paymentDate: (map['paymentDate'] as Timestamp).toDate(),
      bankId: map['bankId'],
      bankName: map['bankName'],
      accountNumber: map['accountNumber'],
      isCash: map['isCash'] ?? false,
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      updatedAt: map['updatedAt'] != null
          ? (map['updatedAt'] as Timestamp).toDate()
          : null,
    );
  }

  // تبدیل از Object به Map
  Map<String, dynamic> toMap() {
    return {
      'appointmentId': appointmentId,
      'invoiceId': invoiceId,
      'amount': amount,
      'type': type,
      'paymentDate': Timestamp.fromDate(paymentDate),
      'bankId': bankId,
      'bankName': bankName,
      'accountNumber': accountNumber,
      'isCash': isCash,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }

  // کپی با تغییرات
  PaymentModel copyWith({
    String? id,
    String? appointmentId,
    String? invoiceId,
    int? amount,
    String? type,
    DateTime? paymentDate,
    String? bankId,
    String? bankName,
    String? accountNumber,
    bool? isCash,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PaymentModel(
      id: id ?? this.id,
      appointmentId: appointmentId ?? this.appointmentId,
      invoiceId: invoiceId ?? this.invoiceId,
      amount: amount ?? this.amount,
      type: type ?? this.type,
      paymentDate: paymentDate ?? this.paymentDate,
      bankId: bankId ?? this.bankId,
      bankName: bankName ?? this.bankName,
      accountNumber: accountNumber ?? this.accountNumber,
      isCash: isCash ?? this.isCash,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}