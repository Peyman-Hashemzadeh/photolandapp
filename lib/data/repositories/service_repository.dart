import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/service_model.dart';

class ServiceRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'services';

  // دریافت همه خدمات (مرتب‌شده)
  Stream<List<ServiceModel>> getAllServices() {
    return _firestore
        .collection(_collection)
        .snapshots()
        .map((snapshot) {
      final services = snapshot.docs
          .map((doc) => ServiceModel.fromMap(doc.data(), doc.id))
          .toList();

      // مرتب‌سازی در سمت کلاینت
      services.sort((a, b) {
        // اول بر اساس وضعیت (فعال‌ها اول)
        if (a.isActive != b.isActive) {
          return b.isActive ? 1 : -1;
        }
        // بعد بر اساس نام (الفبایی)
        return a.serviceName.compareTo(b.serviceName);
      });

      return services;
    });
  }

  // دریافت فقط خدمات فعال (برای استفاده در فرم‌ها)
  Stream<List<ServiceModel>> getActiveServices() {
    return _firestore
        .collection(_collection)
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
      final services = snapshot.docs
          .map((doc) => ServiceModel.fromMap(doc.data(), doc.id))
          .toList();

      // مرتب‌سازی الفبایی
      services.sort((a, b) => a.serviceName.compareTo(b.serviceName));

      return services;
    });
  }

  // افزودن خدمت جدید
  Future<String> addService(ServiceModel service) async {
    try {
      final docRef = await _firestore.collection(_collection).add(service.toMap());
      return docRef.id;
    } catch (e) {
      throw Exception('خطا در ثبت خدمت: $e');
    }
  }

  // ویرایش خدمت
  Future<void> updateService(ServiceModel service) async {
    try {
      await _firestore
          .collection(_collection)
          .doc(service.id)
          .update(service.copyWith(updatedAt: DateTime.now()).toMap());
    } catch (e) {
      throw Exception('خطا در ویرایش خدمت: $e');
    }
  }

  // تغییر وضعیت خدمت (فعال/غیرفعال)
  Future<void> toggleServiceStatus(String serviceId, bool newStatus) async {
    try {
      await _firestore.collection(_collection).doc(serviceId).update({
        'isActive': newStatus,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
    } catch (e) {
      throw Exception('خطا در تغییر وضعیت خدمت: $e');
    }
  }

  // حذف خدمت (فیزیکی - اختیاری)
  Future<void> deleteService(String serviceId) async {
    try {
      await _firestore.collection(_collection).doc(serviceId).delete();
    } catch (e) {
      throw Exception('خطا در حذف خدمت: $e');
    }
  }

  // دریافت یک خدمت خاص
  Future<ServiceModel?> getServiceById(String serviceId) async {
    try {
      final doc = await _firestore.collection(_collection).doc(serviceId).get();

      if (doc.exists) {
        return ServiceModel.fromMap(doc.data()!, doc.id);
      }
      return null;
    } catch (e) {
      throw Exception('خطا در دریافت اطلاعات خدمت: $e');
    }
  }
}