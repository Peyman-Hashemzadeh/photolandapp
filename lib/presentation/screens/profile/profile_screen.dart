import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/constants/colors.dart';
import '../../../core/utils/validators.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../core/utils/date_helper.dart';
import '../../../services/firebase_service.dart';
import '../../widgets/custom_textfield.dart';
import '../../widgets/custom_button.dart';
import 'package:shamsi_date/shamsi_date.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscureCurrentPassword = true;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;
  bool _isLoadingData = true;

  String _mobileNumber = '';
  String _memberSince = '';
  File? _profileImage;
  String? _profileImagePath;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    try {
      final user = FirebaseService.getCurrentUser();
      if (user != null) {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (doc.exists && mounted) {
          final data = doc.data()!;
          setState(() {
            _fullNameController.text = data['fullName'] ?? '';
            _emailController.text = data['email'] ?? '';
            _mobileNumber = data['mobileNumber'] ?? '';
            _profileImagePath = data['profileImagePath'];

            // تاریخ عضویت
            final createdAt = (data['createdAt'] as Timestamp).toDate();
            _memberSince = DateHelper.formatPersianDate(
              Jalali.fromDateTime(createdAt),
            );

            // بارگذاری عکس پروفایل از مسیر ذخیره شده
            if (_profileImagePath != null && _profileImagePath!.isNotEmpty) {
              _profileImage = File(_profileImagePath!);
            }

            _isLoadingData = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingData = false);
        SnackBarHelper.showError(context, 'خطا در بارگذاری اطلاعات کاربر');
      }
    }
  }

  Future<void> _pickImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );

      if (image != null) {
        // ذخیره عکس در دایرکتوری دائمی اپلیکیشن
        final Directory appDir = await getApplicationDocumentsDirectory();
        final String fileName = 'profile_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final String savedPath = '${appDir.path}/$fileName';

        // کپی فایل به مسیر جدید
        final File newImage = await File(image.path).copy(savedPath);

        setState(() {
          _profileImage = newImage;
          _profileImagePath = savedPath;
        });

        // ذخیره مسیر در Firestore
        await _saveProfileImagePath(savedPath);
      }
    } catch (e) {
      if (mounted) {
        SnackBarHelper.showError(context, 'خطا در انتخاب عکس');
      }
    }
  }

  Future<void> _saveProfileImagePath(String path) async {
    try {
      final user = FirebaseService.getCurrentUser();
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({'profileImagePath': path});
      }
    } catch (e) {
      if (mounted) {
        SnackBarHelper.showError(context, 'خطا در ذخیره عکس پروفایل');
      }
    }
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = FirebaseService.getCurrentUser();
      if (user == null) throw Exception('کاربر وارد نشده است');

      // بروزرسانی اطلاعات پایه
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        'fullName': _fullNameController.text.trim(),
        'email': _emailController.text.trim().isEmpty
            ? null
            : _emailController.text.trim(),
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });

      // اگر رمز عبور جدید وارد شده، تغییر بده
      if (_currentPasswordController.text.isNotEmpty) {
        await _changePassword();
      }

      if (!mounted) return;

      SnackBarHelper.showSuccess(context, 'اطلاعات با موفقیت ذخیره شد');

      // پاک کردن فیلدهای رمز عبور
      _currentPasswordController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();
    } catch (e) {
      if (mounted) {
        SnackBarHelper.showError(
          context,
          e.toString().replaceAll('Exception: ', ''),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _changePassword() async {
    final currentPassword = _currentPasswordController.text;
    final newPassword = _newPasswordController.text;

    // احراز هویت مجدد با رمز فعلی
    final user = FirebaseAuth.instance.currentUser!;
    final email = '$_mobileNumber@photoland.app';

    final credential = EmailAuthProvider.credential(
      email: email,
      password: currentPassword,
    );

    try {
      await user.reauthenticateWithCredential(credential);
      await user.updatePassword(newPassword);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'wrong-password') {
        throw Exception('رمز عبور فعلی اشتباه است');
      } else if (e.code == 'weak-password') {
        throw Exception('رمز عبور جدید باید حداقل ۶ کاراکتر باشد');
      }
      throw Exception('خطا در تغییر رمز عبور: ${e.message}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/background.png'),
            fit: BoxFit.cover,
            opacity: 0.1,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: _isLoadingData
                    ? const Center(child: CircularProgressIndicator())
                    : SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        // عکس پروفایل
                        _buildProfileImage(),
                        const SizedBox(height: 32),

                        // اطلاعات کاربر
                        _buildInfoSection(),
                        const SizedBox(height: 24),

                        // بخش تغییر رمز عبور
                        _buildPasswordSection(),
                        const SizedBox(height: 32),

                        // دکمه ذخیره
                        CustomButton(
                          text: 'ذخیره تغییرات',
                          onPressed: _handleSave,
                          isLoading: _isLoading,
                          useGradient: true,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(width: 44, height: 44), // فضای خالی برای تراز مرکزی
          const Text(
            'مشخصات کاربر',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.arrow_forward, color: AppColors.textPrimary),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileImage() {
    return GestureDetector(
      onTap: _pickImage,
      child: Stack(
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.grey.shade200,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipOval(
              child: _profileImage != null && _profileImage!.existsSync()
                  ? Image.file(
                _profileImage!,
                fit: BoxFit.cover,
              )
                  : const Icon(
                Icons.person,
                size: 60,
                color: Colors.grey,
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 3),
              ),
              child: const Icon(
                Icons.camera_alt,
                size: 18,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Align(
            alignment: Alignment.center,
            child: const Text(
              'اطلاعات کاربری',
              textAlign: TextAlign.right, // این رو اضافه کن
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: 20),

          // شماره همراه (غیرقابل ویرایش)
          _buildReadOnlyField(_mobileNumber,'شماره همراه:' ),
          const SizedBox(height: 16),

          // تاریخ عضویت (غیرقابل ویرایش)
          _buildReadOnlyField(_memberSince , 'تاریخ عضویت:'),
          const SizedBox(height: 16),

          // نام و نام خانوادگی
          CustomTextField(
            controller: _fullNameController,
            hint: 'نام و نام خانوادگی',
            maxLength: 20,
            validator: Validators.validateFullName,
          ),
          const SizedBox(height: 16),

          // ایمیل
          CustomTextField(
            controller: _emailController,
            hint: 'ایمیل (اختیاری)',
            keyboardType: TextInputType.emailAddress,
            validator: (value) {
              if (value != null && value.trim().isNotEmpty) {
                return Validators.validateEmail(value);
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Align(
            alignment: Alignment.center,
            child: const Text(
              'تغییر رمز عبور',
              textAlign: TextAlign.right, // این رو اضافه کن
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: 20),

          // رمز عبور فعلی
          CustomTextField(
            controller: _currentPasswordController,
            hint: 'رمز عبور فعلی',
            obscureText: _obscureCurrentPassword,
            validator: (value) {
              // اگر یکی از فیلدهای رمز پر شد، بقیه اجباری می‌شن
              if (_newPasswordController.text.isNotEmpty ||
                  _confirmPasswordController.text.isNotEmpty) {
                if (value == null || value.isEmpty) {
                  return 'لطفا رمز عبور فعلی را وارد کنید';
                }
              }
              return null;
            },
            suffixIcon: IconButton(
              icon: Icon(
                _obscureCurrentPassword
                    ? Icons.visibility_off
                    : Icons.visibility,
                color: AppColors.textLight,
              ),
              onPressed: () {
                setState(() => _obscureCurrentPassword = !_obscureCurrentPassword);
              },
            ),
          ),
          const SizedBox(height: 16),

          // رمز عبور جدید
          CustomTextField(
            controller: _newPasswordController,
            hint: 'رمز عبور جدید',
            obscureText: _obscureNewPassword,
            validator: (value) {
              if (_currentPasswordController.text.isNotEmpty) {
                final validation = Validators.validatePassword(value);
                if (validation != null) return validation;

                // 🔥 چک کردن اینکه رمز جدید با رمز فعلی یکی نباشه
                if (value == _currentPasswordController.text) {
                  return 'رمز عبور جدید نباید با رمز فعلی یکسان باشد';
                }
              }
              return null;
            },
            suffixIcon: IconButton(
              icon: Icon(
                _obscureNewPassword ? Icons.visibility_off : Icons.visibility,
                color: AppColors.textLight,
              ),
              onPressed: () {
                setState(() => _obscureNewPassword = !_obscureNewPassword);
              },
            ),
          ),
          const SizedBox(height: 16),

          // تکرار رمز عبور جدید
          CustomTextField(
            controller: _confirmPasswordController,
            hint: 'تکرار رمز عبور جدید',
            obscureText: _obscureConfirmPassword,
            validator: (value) {
              if (_currentPasswordController.text.isNotEmpty) {
                return Validators.validateConfirmPassword(
                  value,
                  _newPasswordController.text,
                );
              }
              return null;
            },
            suffixIcon: IconButton(
              icon: Icon(
                _obscureConfirmPassword
                    ? Icons.visibility_off
                    : Icons.visibility,
                color: AppColors.textLight,
              ),
              onPressed: () {
                setState(() =>
                _obscureConfirmPassword = !_obscureConfirmPassword);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReadOnlyField(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}