import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/customer_model.dart';

class CustomerRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'customers';

  // دریافت همه مشتریان (مرتب‌شده)
  Stream<List<CustomerModel>> getAllCustomers() {
    return _firestore
        .collection(_collection)
        .snapshots()
        .map((snapshot) {
      final customers = snapshot.docs
          .map((doc) => CustomerModel.fromMap(doc.data(), doc.id))
          .toList();

      // مرتب‌سازی در سمت کلاینت
      customers.sort((a, b) {
        // اول بر اساس وضعیت (فعال‌ها اول)
        if (a.isActive != b.isActive) {
          return b.isActive ? 1 : -1;
        }
        // بعد بر اساس نام (الفبایی)
        return a.fullName.compareTo(b.fullName);
      });

      return customers;
    });
  }

  // دریافت فقط مشتریان فعال (برای استفاده در فرم‌ها)
  Stream<List<CustomerModel>> getActiveCustomers() {
    return _firestore
        .collection(_collection)
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
      final customers = snapshot.docs
          .map((doc) => CustomerModel.fromMap(doc.data(), doc.id))
          .toList();

      // مرتب‌سازی الفبایی
      customers.sort((a, b) => a.fullName.compareTo(b.fullName));

      return customers;
    });
  }

  // جستجوی مشتری بر اساس نام یا شماره
  Stream<List<CustomerModel>> searchCustomers(String query) {
    if (query.isEmpty) {
      return getAllCustomers();
    }

    // جستجو در Firestore محدود است، پس همه رو می‌گیریم و فیلتر می‌کنیم
    return getAllCustomers().map((customers) {
      return customers.where((customer) {
        final searchLower = query.toLowerCase();
        final nameLower = customer.fullName.toLowerCase();
        final mobile = customer.mobileNumber;

        return nameLower.contains(searchLower) || mobile.contains(query);
      }).toList();
    });
  }

  // بررسی تکراری بودن شماره موبایل
  Future<bool> isMobileNumberExists(String mobileNumber, {String? excludeId}) async {
    try {
      var query = _firestore
          .collection(_collection)
          .where('mobileNumber', isEqualTo: mobileNumber);

      final snapshot = await query.get();

      // اگه در حال ویرایش هستیم، شماره خود رکورد رو نادیده بگیر
      if (excludeId != null) {
        return snapshot.docs.any((doc) => doc.id != excludeId);
      }

      return snapshot.docs.isNotEmpty;
    } catch (e) {
      throw Exception('خطا در بررسی شماره همراه: $e');
    }
  }

  // افزودن مشتری جدید
  Future<String> addCustomer(CustomerModel customer) async {
    try {
      // بررسی تکراری بودن شماره
      final exists = await isMobileNumberExists(customer.mobileNumber);
      if (exists) {
        throw Exception('این شماره قبلاً در سامانه ثبت شده است');
      }

      final docRef = await _firestore.collection(_collection).add(customer.toMap());
      return docRef.id;
    } catch (e) {
      if (e.toString().contains('Exception:')) {
        rethrow;
      }
      throw Exception('خطا در ثبت مشتری: $e');
    }
  }

  // ویرایش مشتری
  Future<void> updateCustomer(CustomerModel customer) async {
    try {
      // بررسی تکراری بودن شماره (به جز خود رکورد)
      final exists = await isMobileNumberExists(
        customer.mobileNumber,
        excludeId: customer.id,
      );

      if (exists) {
        throw Exception('این شماره قبلاً در سامانه ثبت شده است');
      }

      await _firestore
          .collection(_collection)
          .doc(customer.id)
          .update(customer.copyWith(updatedAt: DateTime.now()).toMap());
    } catch (e) {
      if (e.toString().contains('Exception:')) {
        rethrow;
      }
      throw Exception('خطا در ویرایش مشتری: $e');
    }
  }

  // تغییر وضعیت مشتری (فعال/غیرفعال)
  Future<void> toggleCustomerStatus(String customerId, bool newStatus) async {
    try {
      await _firestore.collection(_collection).doc(customerId).update({
        'isActive': newStatus,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
    } catch (e) {
      throw Exception('خطا در تغییر وضعیت مشتری: $e');
    }
  }

  // حذف مشتری (فیزیکی - اختیاری)
  Future<void> deleteCustomer(String customerId) async {
    try {
      await _firestore.collection(_collection).doc(customerId).delete();
    } catch (e) {
      throw Exception('خطا در حذف مشتری: $e');
    }
  }

  // دریافت یک مشتری خاص
  Future<CustomerModel?> getCustomerById(String customerId) async {
    try {
      final doc = await _firestore.collection(_collection).doc(customerId).get();

      if (doc.exists) {
        return CustomerModel.fromMap(doc.data()!, doc.id);
      }
      return null;
    } catch (e) {
      throw Exception('خطا در دریافت اطلاعات مشتری: $e');
    }
  }
}