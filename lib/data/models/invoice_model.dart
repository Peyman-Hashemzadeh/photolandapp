import 'package:cloud_firestore/cloud_firestore.dart';

/// مدل آیتم فاکتور (هر خدمت)
class InvoiceItem {
  final String id;
  final String invoiceId; // ارجاع به فاکتور اصلی
  final String serviceId;
  final String serviceName;
  final int quantity; // تعداد
  final int unitPrice; // قیمت واحد
  final DateTime createdAt;

  InvoiceItem({
    required this.id,
    required this.invoiceId,
    required this.serviceId,
    required this.serviceName,
    required this.quantity,
    required this.unitPrice,
    required this.createdAt,
  });

  // محاسبه مبلغ کل این آیتم
  int get totalPrice => quantity * unitPrice;

  // تبدیل از Map به Object
  factory InvoiceItem.fromMap(Map<String, dynamic> map, String id) {
    return InvoiceItem(
      id: id,
      invoiceId: map['invoiceId'] ?? '',
      serviceId: map['serviceId'] ?? '',
      serviceName: map['serviceName'] ?? '',
      quantity: map['quantity'] ?? 1,
      unitPrice: map['unitPrice'] ?? 0,
      createdAt: (map['createdAt'] as Timestamp).toDate(),
    );
  }

  // تبدیل از Object به Map
  Map<String, dynamic> toMap() {
    return {
      'invoiceId': invoiceId,
      'serviceId': serviceId,
      'serviceName': serviceName,
      'quantity': quantity,
      'unitPrice': unitPrice,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  // کپی با تغییرات
  InvoiceItem copyWith({
    String? id,
    String? invoiceId,
    String? serviceId,
    String? serviceName,
    int? quantity,
    int? unitPrice,
    DateTime? createdAt,
  }) {
    return InvoiceItem(
      id: id ?? this.id,
      invoiceId: invoiceId ?? this.invoiceId,
      serviceId: serviceId ?? this.serviceId,
      serviceName: serviceName ?? this.serviceName,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

/// مدل فاکتور اصلی (توسعه یافته)
class InvoiceModel {
  final String id;
  final String? appointmentId; // ارجاع به نوبت (اختیاری - برای فاکتور دستی null است)
  final String customerId;
  final String customerName;
  final String customerMobile;

  // فیلدهای اصلی
  final int invoiceNumber; // شماره سند (از 1000 شروع)
  final DateTime invoiceDate; // تاریخ سند
  final int? shippingCost; // هزینه ارسال
  final int? discount; // تخفیف
  final String? notes; // توضیحات

  //  وضعیت فاکتور
  final String? status; // وضعیت: 'editing', 'confirmed', 'printing', 'printed', 'delivered'

  //  تاریخ تحویل
  final DateTime? deliveryDate; // تاریخ تحویل (14 روز بعد از تسویه به صورت پیش‌فرض)

  final DateTime createdAt;
  final DateTime? updatedAt;

  InvoiceModel({
    required this.id,
    this.appointmentId,
    required this.customerId,
    required this.customerName,
    required this.customerMobile,
    required this.invoiceNumber,
    required this.invoiceDate,
    this.shippingCost,
    this.discount,
    this.notes,
    this.status = 'editing', // 🔥 تغییر: پیش‌فرض "editing" (درصف ویرایش)
    this.deliveryDate,
    required this.createdAt,
    this.updatedAt,
  });

  // تبدیل از Map به Object
  factory InvoiceModel.fromMap(Map<String, dynamic> map, String id) {
    return InvoiceModel(
      id: id,
      appointmentId: map['appointmentId'],
      customerId: map['customerId'] ?? '',
      customerName: map['customerName'] ?? '',
      customerMobile: map['customerMobile'] ?? '',
      invoiceNumber: map['invoiceNumber'] ?? 1000,
      invoiceDate: (map['invoiceDate'] as Timestamp).toDate(),
      shippingCost: map['shippingCost'],
      discount: map['discount'],
      notes: map['notes'],
      status: map['status'], // 🔥 اضافه شد
      deliveryDate: map['deliveryDate'] != null // 🔥 جدید
          ? (map['deliveryDate'] as Timestamp).toDate()
          : null,
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
      'customerId': customerId,
      'customerName': customerName,
      'customerMobile': customerMobile,
      'invoiceNumber': invoiceNumber,
      'invoiceDate': Timestamp.fromDate(invoiceDate),
      'shippingCost': shippingCost,
      'discount': discount,
      'notes': notes,
      'status': status, // 🔥 اضافه شد
      'deliveryDate': deliveryDate != null // 🔥 جدید
          ? Timestamp.fromDate(deliveryDate!)
          : null,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }

  // کپی با تغییرات
  InvoiceModel copyWith({
    String? id,
    String? appointmentId,
    String? customerId,
    String? customerName,
    String? customerMobile,
    int? invoiceNumber,
    DateTime? invoiceDate,
    int? shippingCost,
    int? discount,
    String? notes,
    String? status, // 🔥 اضافه شد
    DateTime? deliveryDate,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return InvoiceModel(
      id: id ?? this.id,
      appointmentId: appointmentId ?? this.appointmentId,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      customerMobile: customerMobile ?? this.customerMobile,
      invoiceNumber: invoiceNumber ?? this.invoiceNumber,
      invoiceDate: invoiceDate ?? this.invoiceDate,
      shippingCost: shippingCost ?? this.shippingCost,
      discount: discount ?? this.discount,
      notes: notes ?? this.notes,
      status: status ?? this.status, // 🔥 اضافه شد
      deliveryDate: deliveryDate ?? this.deliveryDate, // 🔥 جدید
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}