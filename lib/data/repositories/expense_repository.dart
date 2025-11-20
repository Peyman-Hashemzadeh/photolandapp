import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/expense_model.dart';

class ExpenseRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'expenses';

  // دریافت همه هزینه‌ها (مرتب‌شده)
  Stream<List<ExpenseModel>> getAllExpenses() {
    return _firestore
        .collection(_collection)
        .snapshots()
        .map((snapshot) {
      final expenses = snapshot.docs
          .map((doc) => ExpenseModel.fromMap(doc.data(), doc.id))
          .toList();

      // مرتب‌سازی در سمت کلاینت
      expenses.sort((a, b) {
        // اول بر اساس وضعیت (فعال‌ها اول)
        if (a.isActive != b.isActive) {
          return b.isActive ? 1 : -1;
        }
        // بعد بر اساس نام (الفبایی)
        return a.expenseName.compareTo(b.expenseName);
      });

      return expenses;
    });
  }

  // دریافت فقط هزینه‌های فعال (برای استفاده در فرم‌ها)
  Stream<List<ExpenseModel>> getActiveExpenses() {
    return _firestore
        .collection(_collection)
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
      final expenses = snapshot.docs
          .map((doc) => ExpenseModel.fromMap(doc.data(), doc.id))
          .toList();

      // مرتب‌سازی الفبایی
      expenses.sort((a, b) => a.expenseName.compareTo(b.expenseName));

      return expenses;
    });
  }

  // افزودن هزینه جدید
  Future<String> addExpense(ExpenseModel expense) async {
    try {
      final docRef = await _firestore.collection(_collection).add(expense.toMap());
      return docRef.id;
    } catch (e) {
      throw Exception('خطا در ثبت هزینه: $e');
    }
  }

  // ویرایش هزینه
  Future<void> updateExpense(ExpenseModel expense) async {
    try {
      await _firestore
          .collection(_collection)
          .doc(expense.id)
          .update(expense.copyWith(updatedAt: DateTime.now()).toMap());
    } catch (e) {
      throw Exception('خطا در ویرایش هزینه: $e');
    }
  }

  // تغییر وضعیت هزینه (فعال/غیرفعال)
  Future<void> toggleExpenseStatus(String expenseId, bool newStatus) async {
    try {
      await _firestore.collection(_collection).doc(expenseId).update({
        'isActive': newStatus,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
    } catch (e) {
      throw Exception('خطا در تغییر وضعیت هزینه: $e');
    }
  }

  // حذف هزینه (فیزیکی - اختیاری)
  Future<void> deleteExpense(String expenseId) async {
    try {
      await _firestore.collection(_collection).doc(expenseId).delete();
    } catch (e) {
      throw Exception('خطا در حذف هزینه: $e');
    }
  }

  // دریافت یک هزینه خاص
  Future<ExpenseModel?> getExpenseById(String expenseId) async {
    try {
      final doc = await _firestore.collection(_collection).doc(expenseId).get();

      if (doc.exists) {
        return ExpenseModel.fromMap(doc.data()!, doc.id);
      }
      return null;
    } catch (e) {
      throw Exception('خطا در دریافت اطلاعات هزینه: $e');
    }
  }
}