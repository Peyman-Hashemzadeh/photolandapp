import 'package:flutter/material.dart';
import 'dart:async';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/colors.dart';
import '../../../core/utils/date_helper.dart';
import '../../../services/firebase_service.dart';
import '../auth/login_screen.dart';
import '../dashboard/dashboard_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _startSplashTimer();
  }

  void _startSplashTimer() {
    Timer(const Duration(seconds: AppConstants.splashDuration), () {
      // بررسی وضعیت لاگین
      if (FirebaseService.isLoggedIn()) {
        // اگه لاگین بود، به Dashboard هدایت کن
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const DashboardScreen()),
        );
      } else {
        // اگه لاگین نبود، به Login هدایت کن
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: Stack(
        children: [
          // چراغ‌های آویزون از بالا
          _buildLightingImage(),

          // محتوای اصلی
          SafeArea(
            child: Column(
              children: [
                // فاصله از بالا
                const SizedBox(height: 60),

                // لوگو
                _buildLogo(),

                const SizedBox(height: 16),

                // عنوان
                _buildTagline(),

                const SizedBox(height: 40),

                // تصویر اصلی (صندلی‌ها)
                Expanded(
                  child: _buildMainImage(),
                ),

                // اطلاعات پایین صفحه
                _buildFooter(),

                const SizedBox(height: 30),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLightingImage() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Opacity(
        opacity: 0.9, // کمی شفاف (۱.۰ = کاملاً واضح)
        child: Image.asset(
          'assets/images/splash_lighting.png',
          fit: BoxFit.contain,
          height: MediaQuery.of(context).size.height * 0.53,
          errorBuilder: (context, error, stackTrace) {
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Image.asset(
        'assets/images/logo.png',
        height: 80,
        // اگه لوگو نداری، موقتاً از Icon استفاده کن:
        errorBuilder: (context, error, stackTrace) {
          return const Icon(
            Icons.camera_alt,
            size: 80,
            color: AppColors.primary,
          );
        },
      ),
    );
  }

  Widget _buildTagline() {
    return Text(
      AppConstants.appTagline,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
    );
  }

  Widget _buildMainImage() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Image.asset(
          'assets/images/splash_image.png',
          fit: BoxFit.contain,
          // اگه عکس نداری، موقتاً از Icon استفاده کن:
          errorBuilder: (context, error, stackTrace) {
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.photo_camera,
                  size: 120,
                  color: AppColors.primary.withOpacity(0.3),
                ),
                const SizedBox(height: 20),
                Icon(
                  Icons.event_seat,
                  size: 60,
                  color: AppColors.primaryDark.withOpacity(0.4),
                ),
                const SizedBox(height: 10),
                Icon(
                  Icons.lightbulb_outline,
                  size: 80,
                  color: AppColors.primary.withOpacity(0.3),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Column(
      children: [
        // تاریخ شمسی
        Text(
          DateHelper.getCurrentPersianDate(),
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 8),

        // نسخه نرم‌افزار
        Text(
          'نسخه ${AppConstants.appVersion}',
          style: const TextStyle(
            fontSize: 14,
            color: AppColors.textLight,
          ),
        ),
      ],
    );
  }
}