import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/appointment_model.dart';

class AppointmentRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'appointments';

  // دریافت همه نوبت‌ها
  Stream<List<AppointmentModel>> getAllAppointments() {
    return _firestore
        .collection(_collection)
        .orderBy('requestedDate', descending: false)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => AppointmentModel.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  // دریافت نوبت‌های یک روز خاص
  Stream<List<AppointmentModel>> getAppointmentsByDate(DateTime date) {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);

    return _firestore
        .collection(_collection)
        .where('requestedDate', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('requestedDate', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
        .orderBy('requestedDate')
        .orderBy('requestedTime')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => AppointmentModel.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  // بررسی تداخل نوبت
  Future<List<AppointmentModel>> checkOverlap({
    required DateTime date,
    required String startTime,
    required int durationMinutes,
    String? excludeId,
  }) async {
    try {
      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);

      final snapshot = await _firestore
          .collection(_collection)
          .where('requestedDate', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('requestedDate', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
          .where('status', whereIn: ['confirmed', 'pending'])
          .get();

      final appointments = snapshot.docs
          .map((doc) => AppointmentModel.fromMap(doc.data(), doc.id))
          .where((apt) => excludeId == null || apt.id != excludeId)
          .toList();

      // بررسی تداخل زمانی
      final overlapping = <AppointmentModel>[];

      for (final apt in appointments) {
        if (_hasTimeOverlap(
          startTime,
          durationMinutes,
          apt.requestedTime,
          apt.durationMinutes,
        )) {
          overlapping.add(apt);
        }
      }

      return overlapping;
    } catch (e) {
      throw Exception('خطا در بررسی تداخل: $e');
    }
  }

  // بررسی تداخل زمانی دو نوبت
  bool _hasTimeOverlap(
      String time1,
      int duration1,
      String time2,
      int duration2,
      ) {
    final start1 = _timeToMinutes(time1);
    final end1 = start1 + duration1;

    final start2 = _timeToMinutes(time2);
    final end2 = start2 + duration2;

    return (start1 < end2) && (start2 < end1);
  }

  // تبدیل زمان به دقیقه
  int _timeToMinutes(String time) {
    final parts = time.split(':');
    return int.parse(parts[0]) * 60 + int.parse(parts[1]);
  }

  // افزودن نوبت جدید
  Future<String> addAppointment(AppointmentModel appointment) async {
    try {
      final docRef = await _firestore.collection(_collection).add(appointment.toMap());
      return docRef.id;
    } catch (e) {
      throw Exception('خطا در ثبت نوبت: $e');
    }
  }

  // ویرایش نوبت
  Future<void> updateAppointment(AppointmentModel appointment) async {
    try {
      await _firestore
          .collection(_collection)
          .doc(appointment.id)
          .update(appointment.copyWith(updatedAt: DateTime.now()).toMap());
    } catch (e) {
      throw Exception('خطا در ویرایش نوبت: $e');
    }
  }

  // تغییر وضعیت نوبت
  Future<void> updateAppointmentStatus(String appointmentId, String status) async {
    try {
      await _firestore.collection(_collection).doc(appointmentId).update({
        'status': status,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
    } catch (e) {
      throw Exception('خطا در تغییر وضعیت نوبت: $e');
    }
  }

  // حذف نوبت
  Future<void> deleteAppointment(String appointmentId) async {
    try {
      await _firestore.collection(_collection).doc(appointmentId).delete();
    } catch (e) {
      throw Exception('خطا در حذف نوبت: $e');
    }
  }

  // دریافت یک نوبت خاص
  Future<AppointmentModel?> getAppointmentById(String appointmentId) async {
    try {
      final doc = await _firestore.collection(_collection).doc(appointmentId).get();

      if (doc.exists) {
        return AppointmentModel.fromMap(doc.data()!, doc.id);
      }
      return null;
    } catch (e) {
      throw Exception('خطا در دریافت نوبت: $e');
    }
  }

  // دریافت نوبت‌های دریافتی (آنلاین)
  Stream<List<AppointmentModel>> getReceivedAppointments() {
    return _firestore
        .collection(_collection)
        .where('source', isEqualTo: 'online_form')
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => AppointmentModel.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  // شمارش نوبت‌های دریافتی
  Future<int> getReceivedAppointmentsCount() async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('source', isEqualTo: 'online_form')
          .where('status', isEqualTo: 'pending')
          .get();

      return snapshot.docs.length;
    } catch (e) {
      return 0;
    }
  }
}