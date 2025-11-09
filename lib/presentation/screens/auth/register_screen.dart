import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/colors.dart';
import '../../../core/utils/validators.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../services/firebase_service.dart';
import '../../widgets/custom_textfield.dart';
import '../../widgets/custom_button.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _mobileController = TextEditingController();
  final _studioCodeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _fullNameController.dispose();
    _mobileController.dispose();
    _studioCodeController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    // اعتبارسنجی فرم
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      // پاک‌سازی ورودی‌ها
      final fullName = _fullNameController.text.trim();
      final mobileNumber = Validators.cleanMobileNumber(_mobileController.text);
      final studioCode = Validators.cleanStudioCode(_studioCodeController.text);
      final password = _passwordController.text;

      // ثبت نام
      await FirebaseService.signUp(
        fullName: fullName,
        mobileNumber: mobileNumber,
        studioCode: studioCode,
        password: password,
      );

      if (!mounted) return;

      // نمایش پیام موفقیت
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ثبت نام با موفقیت انجام شد'),
          backgroundColor: AppColors.success,
        ),
      );

      // هدایت به صفحه لاگین
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;

      // نمایش پیام خطا
      SnackBarHelper.showError(context, e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
          child: Column(
            children: [
              // 🔹 بخش هدر (عکس + آیکون بازگشت)
              Stack(
                children: [
                  // تصویر هدر
                  Image.asset(
                    'assets/images/auth_header.png',
                    width: double.infinity,
                    fit: BoxFit.cover,
                    height: 120,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: double.infinity,
                        height: 160,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppColors.primary.withOpacity(0.7),
                              AppColors.primaryLight,
                            ],
                          ),
                        ),
                      );
                    },
                  ),

                  // 🔹 آیکون بازگشت روی عکس
                  Positioned(
                    top: MediaQuery.of(context).padding.top + 8,
                    left: 8,
                    child: IconButton(
                      icon: const Icon(
                        Icons.arrow_back,
                        color: Colors.white,
                        size: 26,
                      ),
                      onPressed: () => Navigator.pop(context),
                      //style: IconButton.styleFrom(
                       // backgroundColor: Colors.black26,
                      //),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 30),

              // 🔹 محتوای فرم
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 10),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      // لوگو
                      Image.asset(
                        'assets/images/logo.png',
                        height: 70,
                        errorBuilder: (context, error, stackTrace) {
                          return const Icon(
                            Icons.camera_alt,
                            size: 80,
                            color: AppColors.primary,
                          );
                        },
                      ),

                      const SizedBox(height: 24),

                      const Text(
                        'ثبت حساب جدید',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),

                      const SizedBox(height: 8),

                      const Text(
                        '.برای ایجاد حساب کاربری، فیلدهای زیر را تکمیل نمایید',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),

                      const SizedBox(height: 32),

                      // نام و نام خانوادگی
                      CustomTextField(
                        controller: _fullNameController,
                        hint: 'نام و نام خانوادگی',
                        //icon: Icons.person_outline,
                        maxLength: 20,
                        validator: Validators.validateFullName,
                      ),

                      const SizedBox(height: 16),

                      // شماره همراه
                      CustomTextField(
                        controller: _mobileController,
                        hint: 'شماره همراه',
                        //icon: Icons.phone_android,
                        keyboardType: TextInputType.phone,
                        maxLength: 11,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        validator: Validators.validateMobileNumber,
                      ),

                      const SizedBox(height: 16),

                      // کد آتلیه
                      CustomTextField(
                        controller: _studioCodeController,
                        hint: 'کد آتلیه',
                        //icon: Icons.vpn_key_outlined,
                        keyboardType: TextInputType.number,
                        maxLength: 16,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        validator: Validators.validateStudioCode,
                      ),

                      const SizedBox(height: 16),

                      // رمز عبور
                      CustomTextField(
                        controller: _passwordController,
                        hint: 'رمز عبور',
                        //icon: Icons.lock_outline,
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
                            setState(() => _obscurePassword = !_obscurePassword);
                          },
                        ),
                      ),

                      const SizedBox(height: 16),

                      // تکرار رمز عبور
                      CustomTextField(
                        controller: _confirmPasswordController,
                        hint: 'تکرار رمز عبور',
                        //icon: Icons.lock_outline,
                        obscureText: _obscureConfirmPassword,
                        validator: (value) =>
                            Validators.validateConfirmPassword(
                              value,
                              _passwordController.text,
                            ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureConfirmPassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                            color: AppColors.textLight,
                          ),
                          onPressed: () {
                            setState(() => _obscureConfirmPassword =
                            !_obscureConfirmPassword);
                          },
                        ),
                      ),

                      const SizedBox(height: 32),

                      CustomButton(
                        text: 'ثبت نام',
                        onPressed: _handleRegister,
                        isLoading: _isLoading,
                      ),

                      const SizedBox(height: 24),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text(
                              '!وارد شوید',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const Text(
                            'حساب کاربری دارید؟',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
      ),
    );
  }
}