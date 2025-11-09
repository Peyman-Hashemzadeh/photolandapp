import 'package:cloud_firestore/cloud_firestore.dart';

class AppointmentModel {
  final String id;
  final String customerId;
  final String customerName;
  final String customerMobile;
  final String? childAge;
  final DateTime requestedDate;
  final String requestedTime; // فرمت: "14:30"
  final int durationMinutes; // مدت رزرو به دقیقه
  final String? photographyModel;
  final String? notes;

  // بیعانه (اختیاری)
  final int? depositAmount;
  final DateTime? depositReceivedDate;
  final String? bankId;
  final String? bankName;

  final String status; // pending, confirmed, cancelled, completed
  final String source; // manual, online_form
  final DateTime createdAt;
  final DateTime? updatedAt;

  AppointmentModel({
    required this.id,
    required this.customerId,
    required this.customerName,
    required this.customerMobile,
    this.childAge,
    required this.requestedDate,
    required this.requestedTime,
    required this.durationMinutes,
    this.photographyModel,
    this.notes,
    this.depositAmount,
    this.depositReceivedDate,
    this.bankId,
    this.bankName,
    this.status = 'confirmed',
    this.source = 'manual',
    required this.createdAt,
    this.updatedAt,
  });

  // محاسبه ساعت پایان
  String get endTime {
    final parts = requestedTime.split(':');
    final startHour = int.parse(parts[0]);
    final startMinute = int.parse(parts[1]);

    final totalMinutes = startHour * 60 + startMinute + durationMinutes;
    final endHour = (totalMinutes ~/ 60) % 24;
    final endMinute = totalMinutes % 60;

    return '${endHour.toString().padLeft(2, '0')}:${endMinute.toString().padLeft(2, '0')}';
  }

  // بازه زمانی کامل
  String get timeRange => '$requestedTime - $endTime';

  // آیا بیعانه دارد؟
  bool get hasDeposit => depositAmount != null && depositAmount! > 0;

  // تبدیل از Map به Object
  factory AppointmentModel.fromMap(Map<String, dynamic> map, String id) {
    return AppointmentModel(
      id: id,
      customerId: map['customerId'] ?? '',
      customerName: map['customerName'] ?? '',
      customerMobile: map['customerMobile'] ?? '',
      childAge: map['childAge'],
      requestedDate: (map['requestedDate'] as Timestamp).toDate(),
      requestedTime: map['requestedTime'] ?? '',
      durationMinutes: map['durationMinutes'] ?? 30,
      photographyModel: map['photographyModel'],
      notes: map['notes'],
      depositAmount: map['depositAmount'],
      depositReceivedDate: map['depositReceivedDate'] != null
          ? (map['depositReceivedDate'] as Timestamp).toDate()
          : null,
      bankId: map['bankId'],
      bankName: map['bankName'],
      status: map['status'] ?? 'confirmed',
      source: map['source'] ?? 'manual',
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      updatedAt: map['updatedAt'] != null
          ? (map['updatedAt'] as Timestamp).toDate()
          : null,
    );
  }

  // تبدیل از Object به Map
  Map<String, dynamic> toMap() {
    return {
      'customerId': customerId,
      'customerName': customerName,
      'customerMobile': customerMobile,
      'childAge': childAge,
      'requestedDate': Timestamp.fromDate(requestedDate),
      'requestedTime': requestedTime,
      'durationMinutes': durationMinutes,
      'photographyModel': photographyModel,
      'notes': notes,
      'depositAmount': depositAmount,
      'depositReceivedDate': depositReceivedDate != null
          ? Timestamp.fromDate(depositReceivedDate!)
          : null,
      'bankId': bankId,
      'bankName': bankName,
      'status': status,
      'source': source,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }

  // کپی با تغییرات
  AppointmentModel copyWith({
    String? id,
    String? customerId,
    String? customerName,
    String? customerMobile,
    String? childAge,
    DateTime? requestedDate,
    String? requestedTime,
    int? durationMinutes,
    String? photographyModel,
    String? notes,
    int? depositAmount,
    DateTime? depositReceivedDate,
    String? bankId,
    String? bankName,
    String? status,
    String? source,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AppointmentModel(
      id: id ?? this.id,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      customerMobile: customerMobile ?? this.customerMobile,
      childAge: childAge ?? this.childAge,
      requestedDate: requestedDate ?? this.requestedDate,
      requestedTime: requestedTime ?? this.requestedTime,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      photographyModel: photographyModel ?? this.photographyModel,
      notes: notes ?? this.notes,
      depositAmount: depositAmount ?? this.depositAmount,
      depositReceivedDate: depositReceivedDate ?? this.depositReceivedDate,
      bankId: bankId ?? this.bankId,
      bankName: bankName ?? this.bankName,
      status: status ?? this.status,
      source: source ?? this.source,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}