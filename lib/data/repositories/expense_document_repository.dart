import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/expense_document_model.dart';

class ExpenseDocumentRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'expense_documents';

  // دریافت شماره سند بعدی (از 1 شروع)
  Future<int> getNextDocumentNumber() async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .orderBy('documentNumber', descending: true)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        return 1; // اولین شماره
      }

      final lastDoc = ExpenseDocumentModel.fromMap(
        snapshot.docs.first.data(),
        snapshot.docs.first.id,
      );
      return lastDoc.documentNumber + 1;
    } catch (e) {
      return 1; // در صورت خطا، از 1 شروع کن
    }
  }

  // دریافت همه اسناد هزینه
  Stream<List<ExpenseDocumentModel>> getAllDocuments() {
    return _firestore
        .collection(_collection)
        .orderBy('documentDate', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => ExpenseDocumentModel.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  // دریافت اسناد هزینه بر اساس بازه تاریخی
  Stream<List<ExpenseDocumentModel>> getDocumentsByDateRange(
      DateTime startDate,
      DateTime endDate,
      ) {
    return _firestore
        .collection(_collection)
        .where('documentDate', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
        .where('documentDate', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
        .orderBy('documentDate', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => ExpenseDocumentModel.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  // ایجاد سند هزینه جدید
  Future<String> createDocument(ExpenseDocumentModel document) async {
    try {
      final docRef = await _firestore
          .collection(_collection)
          .add(document.toMap());
      return docRef.id;
    } catch (e) {
      throw Exception('خطا در ثبت سند هزینه: $e');
    }
  }

  // ویرایش سند هزینه
  Future<void> updateDocument(ExpenseDocumentModel document) async {
    try {
      await _firestore
          .collection(_collection)
          .doc(document.id)
          .update(document.copyWith(updatedAt: DateTime.now()).toMap());
    } catch (e) {
      throw Exception('خطا در ویرایش سند هزینه: $e');
    }
  }

  // حذف سند هزینه
  Future<void> deleteDocument(String documentId) async {
    try {
      await _firestore.collection(_collection).doc(documentId).delete();
    } catch (e) {
      throw Exception('خطا در حذف سند هزینه: $e');
    }
  }

  // دریافت یک سند خاص
  Future<ExpenseDocumentModel?> getDocumentById(String documentId) async {
    try {
      final doc = await _firestore.collection(_collection).doc(documentId).get();

      if (doc.exists) {
        return ExpenseDocumentModel.fromMap(doc.data()!, doc.id);
      }
      return null;
    } catch (e) {
      throw Exception('خطا در دریافت سند: $e');
    }
  }

  // محاسبه مجموع هزینه‌ها در یک بازه زمانی
  Future<int> calculateTotalExpenses(DateTime startDate, DateTime endDate) async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('documentDate', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .where('documentDate', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
          .get();

      int total = 0;
      for (var doc in snapshot.docs) {
        final expenseDoc = ExpenseDocumentModel.fromMap(doc.data(), doc.id);
        total += expenseDoc.amount;
      }

      return total;
    } catch (e) {
      return 0;
    }
  }
}