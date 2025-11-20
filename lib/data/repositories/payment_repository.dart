import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/payment_model.dart';

class PaymentRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'payments';

  // دریافت دریافتی‌های یک نوبت (مرتب‌شده از جدید به قدیم)
  Stream<List<PaymentModel>> getPaymentsByAppointment(String appointmentId) {
    return _firestore
        .collection(_collection)
        .where('appointmentId', isEqualTo: appointmentId)
        .orderBy('paymentDate', descending: true)  // 🔥 جدیدترین اول
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => PaymentModel.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  // بررسی وجود بیعانه برای یک نوبت
  Future<bool> hasDeposit(String appointmentId) async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('appointmentId', isEqualTo: appointmentId)
          .where('type', isEqualTo: 'deposit')
          .limit(1)
          .get();

      return snapshot.docs.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  // افزودن دریافتی جدید
  Future<String> addPayment(PaymentModel payment) async {
    try {
      // بررسی: اگر نوع بیعانه باشه، نباید قبلاً بیعانه ثبت شده باشه
      if (payment.type == 'deposit') {
        final hasExistingDeposit = await hasDeposit(payment.appointmentId);
        if (hasExistingDeposit) {
          throw Exception('قبلاً یک بیعانه برای این نوبت ثبت شده است');
        }
      }

      final docRef = await _firestore.collection(_collection).add(payment.toMap());
      return docRef.id;
    } catch (e) {
      if (e.toString().contains('Exception:')) {
        rethrow;
      }
      throw Exception('خطا در ثبت دریافتی: $e');
    }
  }

  // ویرایش دریافتی
  Future<void> updatePayment(PaymentModel payment) async {
    try {
      await _firestore
          .collection(_collection)
          .doc(payment.id)
          .update(payment.copyWith(updatedAt: DateTime.now()).toMap());
    } catch (e) {
      throw Exception('خطا در ویرایش دریافتی: $e');
    }
  }

  // حذف دریافتی
  Future<void> deletePayment(String paymentId) async {
    try {
      await _firestore.collection(_collection).doc(paymentId).delete();
    } catch (e) {
      throw Exception('خطا در حذف دریافتی: $e');
    }
  }

  // محاسبه مجموع دریافتی‌ها
  Future<int> calculateTotalPayments(String appointmentId) async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('appointmentId', isEqualTo: appointmentId)
          .get();

      int total = 0;
      for (var doc in snapshot.docs) {
        final payment = PaymentModel.fromMap(doc.data(), doc.id);
        total += payment.amount;
      }

      return total;
    } catch (e) {
      return 0;
    }
  }

  // دریافت یک دریافتی خاص
  Future<PaymentModel?> getPaymentById(String paymentId) async {
    try {
      final doc = await _firestore.collection(_collection).doc(paymentId).get();

      if (doc.exists) {
        return PaymentModel.fromMap(doc.data()!, doc.id);
      }
      return null;
    } catch (e) {
      throw Exception('خطا در دریافت اطلاعات: $e');
    }
  }
}