import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/studio_model.dart';

class StudioRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'studios';

  // ساخت هش SHA-256 از studioCode
  String generateBookingHash(String studioCode) {
    final bytes = utf8.encode(studioCode);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  // دریافت اطلاعات آتلیه بر اساس studioCode
  Future<StudioModel?> getStudioByCode(String studioCode) async {
    try {
      final doc = await _firestore.collection(_collection).doc(studioCode).get();

      if (doc.exists) {
        return StudioModel.fromMap(doc.data()!, doc.id);
      }
      return null;
    } catch (e) {
      throw Exception('خطا در دریافت اطلاعات آتلیه: $e');
    }
  }

  // دریافت اطلاعات آتلیه بر اساس bookingHash
  Future<StudioModel?> getStudioByHash(String bookingHash) async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('bookingHash', isEqualTo: bookingHash)
          .where('isActive', isEqualTo: true)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) return null;

      final doc = snapshot.docs.first;
      return StudioModel.fromMap(doc.data(), doc.id);
    } catch (e) {
      throw Exception('خطا در دریافت اطلاعات آتلیه: $e');
    }
  }

  // ایجاد یا بروزرسانی آتلیه
  Future<void> createOrUpdateStudio(String studioCode, {
    required String studioName,
    String? address,
    String? logoUrl,
  }) async {
    try {
      final bookingHash = generateBookingHash(studioCode);

      final studio = StudioModel(
        id: studioCode,
        studioName: studioName,
        address: address,
        logoUrl: logoUrl,
        bookingHash: bookingHash,
        isActive: true,
        createdAt: DateTime.now(),
      );

      await _firestore
          .collection(_collection)
          .doc(studioCode)
          .set(studio.toMap(), SetOptions(merge: true));
    } catch (e) {
      throw Exception('خطا در ذخیره اطلاعات آتلیه: $e');
    }
  }

  // بروزرسانی لوگو
  Future<void> updateLogo(String studioCode, String logoUrl) async {
    try {
      await _firestore.collection(_collection).doc(studioCode).update({
        'logoUrl': logoUrl,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
    } catch (e) {
      throw Exception('خطا در بروزرسانی لوگو: $e');
    }
  }

  // بروزرسانی آدرس
  Future<void> updateAddress(String studioCode, String address) async {
    try {
      await _firestore.collection(_collection).doc(studioCode).update({
        'address': address,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
    } catch (e) {
      throw Exception('خطا در بروزرسانی آدرس: $e');
    }
  }

  // بروزرسانی نام آتلیه
  Future<void> updateStudioName(String studioCode, String studioName) async {
    try {
      await _firestore.collection(_collection).doc(studioCode).update({
        'studioName': studioName,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
    } catch (e) {
      throw Exception('خطا در بروزرسانی نام آتلیه: $e');
    }
  }
}