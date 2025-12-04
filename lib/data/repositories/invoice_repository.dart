import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/invoice_model.dart';

class InvoiceRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _invoicesCollection = 'invoices';
  final String _itemsCollection = 'invoice_items';

  // =============== فاکتورها ===============

  // دریافت شماره سند بعدی (خودکار)
  Future<int> getNextInvoiceNumber() async {
    try {
      final snapshot = await _firestore
          .collection(_invoicesCollection)
          .orderBy('invoiceNumber', descending: true)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        return 1000; // اولین شماره
      }

      final lastInvoice = InvoiceModel.fromMap(snapshot.docs.first.data(), snapshot.docs.first.id);
      return lastInvoice.invoiceNumber + 1;
    } catch (e) {
      return 1000; // در صورت خطا، از 1000 شروع کن
    }
  }

  // دریافت فاکتور بر اساس نوبت
  Future<InvoiceModel?> getInvoiceByAppointment(String appointmentId) async {
    try {
      final snapshot = await _firestore
          .collection(_invoicesCollection)
          .where('appointmentId', isEqualTo: appointmentId)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) return null;

      final doc = snapshot.docs.first;
      return InvoiceModel.fromMap(doc.data(), doc.id);
    } catch (e) {
      throw Exception('خطا در دریافت فاکتور: $e');
    }
  }

  // دریافت فاکتور بر اساس شماره سند
  Future<InvoiceModel?> getInvoiceByNumber(int invoiceNumber) async {
    try {
      final snapshot = await _firestore
          .collection(_invoicesCollection)
          .where('invoiceNumber', isEqualTo: invoiceNumber)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) return null;

      final doc = snapshot.docs.first;
      return InvoiceModel.fromMap(doc.data(), doc.id);
    } catch (e) {
      throw Exception('خطا در دریافت فاکتور: $e');
    }
  }

  // دریافت همه فاکتورها
  Stream<List<InvoiceModel>> getAllInvoices() {
    return _firestore
        .collection(_invoicesCollection)
        .orderBy('invoiceDate', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => InvoiceModel.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  // 🔥 دریافت فاکتورهای تسویه شده نزدیک به تحویل (برای یادآوری)
  Stream<List<Map<String, dynamic>>> getPendingDeliveryInvoices() async* {
    await for (var snapshot in _firestore
        .collection(_invoicesCollection)
        .snapshots()) {

      final List<Map<String, dynamic>> result = [];

      for (var doc in snapshot.docs) {
        try {
          final invoice = InvoiceModel.fromMap(doc.data(), doc.id);

          // 🔥 چک ۱: فقط editing یا null (فاکتورهای قدیمی)
          if (invoice.status != null && invoice.status != 'editing') {
            print('⏭️ فاکتور ${invoice.invoiceNumber} رد شد: status = ${invoice.status}');
            continue;
          }

          // محاسبه مبالغ
          final grandTotal = await calculateGrandTotal(invoice.id);
          print('💰 فاکتور ${invoice.invoiceNumber}: grandTotal = $grandTotal');

          final paidData = await _calculatePaidAmountAndLastDate(invoice.id);
          final paidAmount = paidData['amount'] as int;
          final lastPaymentDate = paidData['lastDate'] as DateTime?;

          print('💵 فاکتور ${invoice.invoiceNumber}: paidAmount = $paidAmount, lastDate = $lastPaymentDate');

          // فقط فاکتورهای تسویه شده که آخرین پرداخت دارند
          if (paidAmount >= grandTotal && grandTotal > 0 && lastPaymentDate != null) {
            print('✅ فاکتور ${invoice.invoiceNumber} اضافه شد به یادآوری');
            result.add({
              'invoice': invoice,
              'lastPaymentDate': lastPaymentDate,
            });
          } else {
            print('⏭️ فاکتور ${invoice.invoiceNumber} رد شد: تسویه نشده یا پرداخت نداره');
          }
        } catch (e) {
          print('⚠️ خطا در پردازش فاکتور ${doc.id}: $e');
          continue;
        }
      }

      print('📊 تعداد کل فاکتورهای یادآوری: ${result.length}');
      yield result;
    }
  }

  // محاسبه مجموع پرداختی‌ها و آخرین تاریخ پرداخت
  Future<Map<String, dynamic>> _calculatePaidAmountAndLastDate(String invoiceId) async {
    try {
      final snapshot = await _firestore
          .collection('payments')
          .where('appointmentId', isEqualTo: invoiceId)
          .get();

      int total = 0;
      DateTime? lastDate;

      for (var doc in snapshot.docs) {
        final amount = (doc.data()['amount'] as int?) ?? 0;
        total += amount;

        final paymentDate = (doc.data()['paymentDate'] as Timestamp?)?.toDate();
        if (paymentDate != null) {
          if (lastDate == null || paymentDate.isAfter(lastDate)) {
            lastDate = paymentDate;
          }
        }
      }

      return {
        'amount': total,
        'lastDate': lastDate,
      };
    } catch (e) {
      return {
        'amount': 0,
        'lastDate': null,
      };
    }
  }

  // ایجاد فاکتور جدید
  Future<String> createInvoice(InvoiceModel invoice) async {
    try {
      final docRef = await _firestore
          .collection(_invoicesCollection)
          .add(invoice.toMap());
      return docRef.id;
    } catch (e) {
      throw Exception('خطا در ایجاد فاکتور: $e');
    }
  }

  // ویرایش فاکتور
  Future<void> updateInvoice(InvoiceModel invoice) async {
    try {
      await _firestore
          .collection(_invoicesCollection)
          .doc(invoice.id)
          .update(invoice.copyWith(updatedAt: DateTime.now()).toMap());
    } catch (e) {
      throw Exception('خطا در ویرایش فاکتور: $e');
    }
  }

  // بروزرسانی وضعیت فاکتور
  Future<void> updateInvoiceStatus(String invoiceId, String status) async {
    try {
      await _firestore.collection(_invoicesCollection).doc(invoiceId).update({
        'status': status,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
    } catch (e) {
      throw Exception('خطا در تغییر وضعیت فاکتور: $e');
    }
  }

  // حذف فاکتور
  Future<void> deleteInvoice(String invoiceId) async {
    try {
      await _firestore.collection(_invoicesCollection).doc(invoiceId).delete();

      final items = await _firestore
          .collection(_itemsCollection)
          .where('invoiceId', isEqualTo: invoiceId)
          .get();

      for (var doc in items.docs) {
        await doc.reference.delete();
      }
    } catch (e) {
      throw Exception('خطا در حذف فاکتور: $e');
    }
  }

  // =============== آیتم‌های فاکتور ===============

  // دریافت آیتم‌های یک فاکتور
  Stream<List<InvoiceItem>> getInvoiceItems(String invoiceId) {
    return _firestore
        .collection(_itemsCollection)
        .where('invoiceId', isEqualTo: invoiceId)
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => InvoiceItem.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  // افزودن آیتم به فاکتور
  Future<String> addInvoiceItem(InvoiceItem item) async {
    try {
      final docRef = await _firestore
          .collection(_itemsCollection)
          .add(item.toMap());
      return docRef.id;
    } catch (e) {
      throw Exception('خطا در افزودن آیتم: $e');
    }
  }

  // ویرایش آیتم فاکتور
  Future<void> updateInvoiceItem(InvoiceItem item) async {
    try {
      await _firestore
          .collection(_itemsCollection)
          .doc(item.id)
          .update(item.toMap());
    } catch (e) {
      throw Exception('خطا در ویرایش آیتم: $e');
    }
  }

  // حذف آیتم فاکتور
  Future<void> deleteInvoiceItem(String itemId) async {
    try {
      await _firestore
          .collection(_itemsCollection)
          .doc(itemId)
          .delete();
    } catch (e) {
      throw Exception('خطا در حذف آیتم: $e');
    }
  }

  // محاسبه مجموع فاکتور (فقط آیتم‌ها)
  Future<int> calculateInvoiceTotal(String invoiceId) async {
    try {
      final snapshot = await _firestore
          .collection(_itemsCollection)
          .where('invoiceId', isEqualTo: invoiceId)
          .get();

      int total = 0;
      for (var doc in snapshot.docs) {
        final item = InvoiceItem.fromMap(doc.data(), doc.id);
        total += item.totalPrice;
      }

      return total;
    } catch (e) {
      return 0;
    }
  }

  // محاسبه جمع کل (آیتم‌ها + هزینه ارسال - تخفیف)
  Future<int> calculateGrandTotal(String invoiceId) async {
    try {
      final doc = await _firestore.collection(_invoicesCollection).doc(invoiceId).get();
      if (!doc.exists) return 0;

      final invoice = InvoiceModel.fromMap(doc.data()!, doc.id);

      final itemsTotal = await calculateInvoiceTotal(invoiceId);

      int grandTotal = itemsTotal;
      if (invoice.shippingCost != null) grandTotal += invoice.shippingCost!;
      if (invoice.discount != null) grandTotal -= invoice.discount!;

      return grandTotal > 0 ? grandTotal : 0;
    } catch (e) {
      return 0;
    }
  }
}