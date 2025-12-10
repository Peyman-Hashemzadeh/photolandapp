import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/colors.dart';
import '../../../core/utils/validators.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../services/firebase_service.dart';
import '../../widgets/custom_textfield.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/curved_header.dart'; // 🔥 اضافه شد

class PersianDigitsInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue,
      TextEditingValue newValue,
      ) {
    // فقط digits رو نگه دار (انگلیسی یا فارسی)
    final filtered = newValue.text.replaceAll(RegExp(r'[^0-9۰-۹]'), '');

    if (filtered.isEmpty) return newValue;

    // تبدیل اعداد انگلیسی به فارسی
    String persian = filtered;
    const english = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    const persianDigits = ['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'];
    for (int i = 0; i < 10; i++) {
      persian = persian.replaceAll(english[i], persianDigits[i]);
    }

    // اگر طول بیشتر از 11 شد، کوتاه کن
    if (persian.length > 11) {
      persian = persian.substring(0, 11);
    }

    return TextEditingValue(
      text: persian,
      selection: TextSelection.collapsed(offset: persian.length),
    );
  }
}

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
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final fullName = _fullNameController.text.trim();
      final mobileNumber = Validators.cleanMobileNumber(_mobileController.text);
      final studioCode = Validators.cleanStudioCode(_studioCodeController.text);
      final password = _passwordController.text;

      await FirebaseService.signUp(
        fullName: fullName,
        mobileNumber: mobileNumber,
        studioCode: studioCode,
        password: password,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ثبت نام با موفقیت انجام شد'),
          backgroundColor: AppColors.success,
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      SnackBarHelper.showError(
        context,
        e.toString().replaceAll('Exception: ', ''),
      );
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
            // 🔥 هدر جدید با دکمه بازگشت
            CurvedHeader(
              height: 180,
              child: Positioned(
                top: MediaQuery.of(context).padding.top + 8,
                left: 8,
                child: IconButton(
                  icon: const Icon(
                    Icons.arrow_forward,
                    color: Colors.white,
                    size: 26,
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),

            const SizedBox(height: 1),

            // محتوای فرم
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 10),
              child: Form(
                key: _formKey,
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

                    const SizedBox(height: 24),

                    const Text(
                      'ثبت حساب جدید',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),

                    const SizedBox(height: 8),

                    const Text(
                      'برای ایجاد حساب کاربری، فیلدهای زیر را تکمیل نمایید.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),

                    const SizedBox(height: 32),

                    // فیلدهای فرم
                    CustomTextField(
                      controller: _fullNameController,
                      hint: 'نام و نام خانوادگی',
                      maxLength: 20,
                      validator: Validators.validateFullName,
                    ),

                    const SizedBox(height: 16),

                    CustomTextField(
                      controller: _mobileController,
                      hint: 'شماره همراه',
                      keyboardType: TextInputType.phone,
                      maxLength: 11,
                      inputFormatters: [
                        PersianDigitsInputFormatter(),
                      ],
                      validator: Validators.validateMobileNumber,
                    ),

                    const SizedBox(height: 16),

                    CustomTextField(
                      controller: _studioCodeController,
                      hint: 'کد آتلیه',
                      keyboardType: TextInputType.number,
                      maxLength: 16,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      validator: Validators.validateStudioCode,
                    ),

                    const SizedBox(height: 16),

                    CustomTextField(
                      controller: _passwordController,
                      hint: 'رمز عبور',
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

                    CustomTextField(
                      controller: _confirmPasswordController,
                      hint: 'تکرار رمز عبور',
                      obscureText: _obscureConfirmPassword,
                      validator: (value) => Validators.validateConfirmPassword(
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
                        const Text(
                          'حساب کاربری دارید؟',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text(
                            'وارد شوید!',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                            ),
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