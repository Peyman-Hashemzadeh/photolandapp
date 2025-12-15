import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/invoice_model.dart';
import 'package:firebase_auth/firebase_auth.dart';

class InvoiceRepository {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _invoicesCollection = 'invoices';
  final String _itemsCollection = 'invoice_items';

  // =============== فاکتورها ===============

  Future<int> getNextInvoiceNumber() async {
    try {
      final snapshot = await _firestore
          .collection(_invoicesCollection)
          .orderBy('invoiceNumber', descending: true)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        return 1000;
      }

      final lastInvoice = InvoiceModel.fromMap(snapshot.docs.first.data(), snapshot.docs.first.id);
      return lastInvoice.invoiceNumber + 1;
    } catch (e) {
      return 1000;
    }
  }

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

  Future<void> updateDeliveryDate(String invoiceId, DateTime? deliveryDate) async {
    try {
      await _firestore.collection(_invoicesCollection).doc(invoiceId).update({
        'deliveryDate': deliveryDate != null
            ? Timestamp.fromDate(deliveryDate)
            : null,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
    } catch (e) {
      throw Exception('خطا در بروزرسانی تاریخ تحویل: $e');
    }
  }

  DateTime calculateDefaultDeliveryDate(DateTime settlementDate) {
    return settlementDate.add(const Duration(days: 14));
  }

  // 🔥 بهینه‌سازی شده: تنها یک بار همه داده‌ها رو میگیره
  Stream<List<Map<String, dynamic>>> getPendingDeliveryInvoices() {
    return _firestore
        .collection(_invoicesCollection)
        .where('deliveryDate', isNotEqualTo: null)
        .snapshots()
        .asyncMap((invoiceSnapshot) async {

      if (invoiceSnapshot.docs.isEmpty) {
        return [];
      }

      // 🔥 یکجا همه invoiceId ها رو بگیر
      final invoiceIds = invoiceSnapshot.docs.map((doc) => doc.id).toList();

      // 🔥 Query موازی: یکجا همه items و payments رو بگیر
      final itemsFuture = _firestore
          .collection(_itemsCollection)
          .where('invoiceId', whereIn: invoiceIds)
          .get();

      final paymentsFuture = _firestore
          .collection('payments')
          .where('invoiceId', whereIn: invoiceIds)
          .get();

      // 🔥 منتظر هر دو query میمونیم
      final results = await Future.wait([itemsFuture, paymentsFuture]);
      final itemsSnapshot = results[0];
      final paymentsSnapshot = results[1];

      // 🔥 گروه‌بندی items بر اساس invoiceId
      final Map<String, List<Map<String, dynamic>>> itemsByInvoice = {};
      for (var doc in itemsSnapshot.docs) {
        final invoiceId = doc.data()['invoiceId'] as String;
        itemsByInvoice.putIfAbsent(invoiceId, () => []);
        itemsByInvoice[invoiceId]!.add(doc.data());
      }

      // 🔥 گروه‌بندی payments بر اساس invoiceId
      final Map<String, List<Map<String, dynamic>>> paymentsByInvoice = {};
      for (var doc in paymentsSnapshot.docs) {
        final invoiceId = doc.data()['invoiceId'] as String;
        paymentsByInvoice.putIfAbsent(invoiceId, () => []);
        paymentsByInvoice[invoiceId]!.add(doc.data());
      }

      // 🔥 پردازش هر فاکتور (بدون query اضافی!)
      final List<Map<String, dynamic>> result = [];

      for (var doc in invoiceSnapshot.docs) {
        try {
          final invoice = InvoiceModel.fromMap(doc.data(), doc.id);

          // چک وضعیت
          if (invoice.status != null && invoice.status != 'editing') {
            continue;
          }

          // محاسبه grandTotal از items کش شده
          final items = itemsByInvoice[invoice.id] ?? [];
          int itemsTotal = 0;
          for (var item in items) {
            final quantity = (item['quantity'] as int?) ?? 0;
            final unitPrice = (item['unitPrice'] as int?) ?? 0;
            itemsTotal += quantity * unitPrice;
          }

          int grandTotal = itemsTotal;
          if (invoice.shippingCost != null) grandTotal += invoice.shippingCost!;
          if (invoice.discount != null) grandTotal -= invoice.discount!;
          if (grandTotal < 0) grandTotal = 0;

          // محاسبه paidAmount و lastPaymentDate از payments کش شده
          final payments = paymentsByInvoice[invoice.id] ?? [];
          int paidAmount = 0;
          DateTime? lastPaymentDate;

          for (var payment in payments) {
            final amount = (payment['amount'] as int?) ?? 0;
            paidAmount += amount;

            final paymentDate = (payment['paymentDate'] as Timestamp?)?.toDate();
            if (paymentDate != null) {
              if (lastPaymentDate == null || paymentDate.isAfter(lastPaymentDate)) {
                lastPaymentDate = paymentDate;
              }
            }
          }

          // فقط فاکتورهای تسویه شده
          if (paidAmount >= grandTotal && grandTotal > 0 && lastPaymentDate != null) {
            result.add({
              'invoice': invoice,
              'lastPaymentDate': lastPaymentDate,
            });
          }
        } catch (e) {
          print('⚠️ خطا در پردازش فاکتور ${doc.id}: $e');
          continue;
        }
      }

      return result;
    });
  }

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

  Future<void> deleteInvoice(String invoiceId) async {
    try {
      final itemsSnapshot = await _firestore
          .collection(_itemsCollection)
          .where('invoiceId', isEqualTo: invoiceId)
          .get();

      for (var doc in itemsSnapshot.docs) {
        await doc.reference.delete();
      }

      await _firestore
          .collection(_invoicesCollection)
          .doc(invoiceId)
          .delete();

      print('✅ فاکتور $invoiceId و ${itemsSnapshot.docs.length} آیتم حذف شد');
    } catch (e) {
      throw Exception('خطا در حذف فاکتور: $e');
    }
  }

  // =============== آیتم‌های فاکتور ===============

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