import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../data/models/user_model.dart';

class FirebaseService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // کد آتلیه ثابت (فعلاً هاردکد)
  static const String VALID_STUDIO_CODE = '1205136907021368';

  // بررسی کد آتلیه
  static bool validateStudioCode(String code) {
    return code == VALID_STUDIO_CODE;
  }

  // بررسی تکراری بودن شماره همراه
  static Future<bool> isMobileNumberExists(String mobileNumber) async {
    try {
      final querySnapshot = await _firestore
          .collection('users')
          .where('mobileNumber', isEqualTo: mobileNumber)
          .limit(1)
          .get();

      return querySnapshot.docs.isNotEmpty;
    } catch (e) {
      throw Exception('خطا در بررسی شماره همراه: $e');
    }
  }

  // ثبت نام کاربر
  static Future<UserModel> signUp({
    required String fullName,
    required String mobileNumber,
    required String studioCode,
    required String password,
  }) async {
    try {
      // ۱. بررسی کد آتلیه
      if (!validateStudioCode(studioCode)) {
        throw Exception('کد آتلیه معتبر نیست. لطفاً با مدیر آتلیه تماس بگیرید');
      }

      // ۲. بررسی تکراری بودن شماره
      final exists = await isMobileNumberExists(mobileNumber);
      if (exists) {
        throw Exception('این شماره همراه قبلاً ثبت شده است');
      }

      // ۳. ساخت ایمیل موقت از شماره تلفن (برای Firebase Auth)
      final email = '$mobileNumber@photoland.app';

      // ۴. ثبت نام در Firebase Auth
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final userId = userCredential.user!.uid;

      // ۵. ساخت مدل کاربر
      final user = UserModel(
        id: userId,
        fullName: fullName,
        mobileNumber: mobileNumber,
        studioCode: studioCode,
        createdAt: DateTime.now(),
      );

      // ۶. ذخیره در Firestore
      await _firestore.collection('users').doc(userId).set(user.toMap());

      return user;
    } on FirebaseAuthException catch (e) {
      // تبدیل خطاهای Firebase به فارسی
      switch (e.code) {
        case 'email-already-in-use':
          throw Exception('این شماره همراه قبلاً ثبت شده است');
        case 'weak-password':
          throw Exception('رمز عبور باید حداقل ۶ کاراکتر باشد');
        case 'invalid-email':
          throw Exception('شماره موبایل نامعتبر است');
        case 'operation-not-allowed':
          throw Exception('ثبت‌نام غیرفعال است');
        case 'network-request-failed':
          throw Exception('خطا در اتصال به اینترنت');
        default:
          throw Exception('خطا در ثبت‌نام: ${e.message ?? 'خطای ناشناخته'}');
      }
    } catch (e) {
      // اگه خطای دیگه‌ای بود
      if (e.toString().contains('Exception:')) {
        rethrow; // خطاهای خودمون رو دوباره پرتاب کن
      }
      throw Exception('خطا در ثبت‌نام. لطفاً دوباره تلاش کنید');
    }
  }

  // ورود کاربر
  static Future<UserModel> signIn({
    required String mobileNumber,
    required String password,
  }) async {
    try {
      // ۱. ساخت ایمیل از شماره
      final email = '$mobileNumber@photoland.app';

      // ۲. ورود به Firebase Auth
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final userId = userCredential.user!.uid;

      // ۳. دریافت اطلاعات از Firestore
      final doc = await _firestore.collection('users').doc(userId).get();

      if (!doc.exists) {
        throw Exception('اطلاعات کاربر یافت نشد');
      }

      return UserModel.fromMap(doc.data()!, userId);
    } on FirebaseAuthException catch (e) {
      // تبدیل خطاهای Firebase به فارسی
      switch (e.code) {
        case 'user-not-found':
          throw Exception('اطلاعات شما یافت نشد. لطفاً ابتدا ثبت‌نام کنید');
        case 'wrong-password':
          throw Exception('رمز عبور اشتباه است');
        case 'invalid-email':
          throw Exception('شماره موبایل نامعتبر است');
        case 'user-disabled':
          throw Exception('حساب کاربری غیرفعال شده است');
        case 'invalid-credential':
          throw Exception('شماره موبایل یا رمز عبور اشتباه است');
        case 'too-many-requests':
          throw Exception('تعداد تلاش‌های شما زیاد است. لطفاً بعداً امتحان کنید');
        case 'network-request-failed':
          throw Exception('خطا در اتصال به اینترنت');
        default:
          throw Exception('خطا در ورود: ${e.message ?? 'خطای ناشناخته'}');
      }
    } catch (e) {
      // اگه خطای دیگه‌ای بود
      if (e.toString().contains('Exception:')) {
        rethrow; // خطاهای خودمون رو دوباره پرتاب کن
      }
      throw Exception('خطا در ورود به سیستم. لطفاً دوباره تلاش کنید');
    }
  }

  // خروج کاربر
  static Future<void> signOut() async {
    await _auth.signOut();
  }

  // دریافت کاربر فعلی
  static User? getCurrentUser() {
    return _auth.currentUser;
  }

  // بررسی وضعیت لاگین
  static bool isLoggedIn() {
    return _auth.currentUser != null;
  }
}