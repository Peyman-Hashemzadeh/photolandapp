import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/colors.dart';
import '../../../core/utils/validators.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../services/firebase_service.dart';
import '../../widgets/custom_textfield.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/curved_header.dart'; // 🔥 اضافه شد
import '../dashboard/dashboard_screen.dart';
import 'register_screen.dart';
import 'package:firebase_messaging/firebase_messaging.dart';


class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _mobileController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _mobileController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final mobileNumber = Validators.cleanMobileNumber(_mobileController.text);
      final password = _passwordController.text;

      final user = await FirebaseService.signIn(
        mobileNumber: mobileNumber,
        password: password,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.success,
          duration: Duration(seconds: 2),
          content: Text(
            'به مدیریت خدمات فتولند خوش آمدید',
            textAlign: TextAlign.right,
          ),
        ),
      );

      await Future.delayed(const Duration(milliseconds: 500));

      if (!mounted) return;
      await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      final studioCode = user.studioCode;
      await FirebaseMessaging.instance.subscribeToTopic("studio_$studioCode");

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const DashboardScreen(),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      SnackBarHelper.showError(
        context,
        e.toString().replaceAll('Exception: ', ''),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _navigateToRegister() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const RegisterScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                // 🔥 هدر جدید با CustomPaint
                const CurvedHeader(height: 180),

                const SizedBox(height: 1),

                // محتوای فرم
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    children: [
                      // لوگو
                      Image.asset(
                        'assets/images/logo.png',
                        height: 60,
                        errorBuilder: (context, error, stackTrace) {
                          return const Icon(
                            Icons.camera_alt,
                            size: 80,
                            color: AppColors.primary,
                          );
                        },
                      ),

                      const SizedBox(height: 15),

                      // زیرعنوان
                      const Text(
                        'برای ورود اطلاعات خود را وارد کنید.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 15,
                          color: AppColors.textSecondary,
                        ),
                      ),

                      const SizedBox(height: 40),

                      // شماره همراه
                      CustomTextField(
                        controller: _mobileController,
                        hint: 'شماره همراه',
                        icon: Icons.phone_android,
                        keyboardType: TextInputType.phone,
                        maxLength: 11,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        validator: Validators.validateMobileNumber,
                      ),

                      const SizedBox(height: 20),

                      // رمز عبور
                      CustomTextField(
                        controller: _passwordController,
                        hint: 'رمز عبور',
                        icon: Icons.lock_outline,
                        obscureText: _obscurePassword,
                        validator: Validators.validatePassword,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                            color: AppColors.textLight,
                          ),
                          onPressed: () {
                            setState(() =>
                            _obscurePassword = !_obscurePassword);
                          },
                        ),
                      ),

                      const SizedBox(height: 32),

                      // دکمه ورود
                      CustomButton(
                        text: 'ورود',
                        onPressed: _handleLogin,
                        isLoading: _isLoading,
                      ),

                      const SizedBox(height: 240),

                      // لینک ثبت‌نام
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            'حساب کاربری ندارید؟',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 14,
                            ),
                          ),
                          TextButton(
                            onPressed: _navigateToRegister,
                            child: const Text(
                              'ثبت ‌نام کنید!',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}