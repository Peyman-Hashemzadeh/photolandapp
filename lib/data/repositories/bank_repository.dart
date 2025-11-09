import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/bank_model.dart';

class BankRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'banks';

  // دریافت همه بانک‌ها (مرتب‌شده)
  Stream<List<BankModel>> getAllBanks() {
    return _firestore
        .collection(_collection)
        .snapshots()
        .map((snapshot) {
      final banks = snapshot.docs
          .map((doc) => BankModel.fromMap(doc.data(), doc.id))
          .toList();

      // مرتب‌سازی در سمت کلاینت
      banks.sort((a, b) {
        // اول بر اساس وضعیت (فعال‌ها اول)
        if (a.isActive != b.isActive) {
          return b.isActive ? 1 : -1;
        }
        // بعد بر اساس نام (الفبایی)
        return a.bankName.compareTo(b.bankName);
      });

      return banks;
    });
  }

  // دریافت فقط بانک‌های فعال (برای استفاده در فرم‌ها)
  Stream<List<BankModel>> getActiveBanks() {
    return _firestore
        .collection(_collection)
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
      final banks = snapshot.docs
          .map((doc) => BankModel.fromMap(doc.data(), doc.id))
          .toList();

      // مرتب‌سازی الفبایی
      banks.sort((a, b) => a.bankName.compareTo(b.bankName));

      return banks;
    });
  }

  // افزودن بانک جدید
  Future<String> addBank(BankModel bank) async {
    try {
      final docRef = await _firestore.collection(_collection).add(bank.toMap());
      return docRef.id;
    } catch (e) {
      throw Exception('خطا در ثبت بانک: $e');
    }
  }

  // ویرایش بانک
  Future<void> updateBank(BankModel bank) async {
    try {
      await _firestore
          .collection(_collection)
          .doc(bank.id)
          .update(bank.copyWith(updatedAt: DateTime.now()).toMap());
    } catch (e) {
      throw Exception('خطا در ویرایش بانک: $e');
    }
  }

  // تغییر وضعیت بانک (فعال/غیرفعال)
  Future<void> toggleBankStatus(String bankId, bool newStatus) async {
    try {
      await _firestore.collection(_collection).doc(bankId).update({
        'isActive': newStatus,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
    } catch (e) {
      throw Exception('خطا در تغییر وضعیت بانک: $e');
    }
  }

  // حذف بانک (فیزیکی - اختیاری)
  Future<void> deleteBank(String bankId) async {
    try {
      await _firestore.collection(_collection).doc(bankId).delete();
    } catch (e) {
      throw Exception('خطا در حذف بانک: $e');
    }
  }

  // دریافت یک بانک خاص
  Future<BankModel?> getBankById(String bankId) async {
    try {
      final doc = await _firestore.collection(_collection).doc(bankId).get();

      if (doc.exists) {
        return BankModel.fromMap(doc.data()!, doc.id);
      }
      return null;
    } catch (e) {
      throw Exception('خطا در دریافت اطلاعات بانک: $e');
    }
  }
}