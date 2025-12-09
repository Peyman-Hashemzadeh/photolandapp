import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/colors.dart';
import '../../../core/utils/validators.dart';
import '../../../data/models/customer_model.dart';
import 'custom_textfield.dart';
import 'custom_button.dart';


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

class AddCustomerDialog extends StatefulWidget {
  final CustomerModel? customer; // اگه null باشه یعنی افزودن، وگرنه ویرایش

  const AddCustomerDialog({
    super.key,
    this.customer,
  });

  @override
  State<AddCustomerDialog> createState() => _AddCustomerDialogState();
}

class _AddCustomerDialogState extends State<AddCustomerDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _mobileController;
  late final TextEditingController _notesController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.customer?.fullName ?? '');
    _mobileController = TextEditingController(text: widget.customer?.mobileNumber ?? '');
    _notesController = TextEditingController(text: widget.customer?.notes ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _mobileController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _handleSubmit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final customer = CustomerModel(
      id: widget.customer?.id ?? '',
      fullName: _nameController.text.trim(),
      mobileNumber: Validators.cleanMobileNumber(_mobileController.text),
      notes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
      isActive: widget.customer?.isActive ?? true,
      createdAt: widget.customer?.createdAt ?? DateTime.now(),
      updatedAt: widget.customer != null ? DateTime.now() : null,
    );

    Navigator.pop(context, customer);
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.customer != null;

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // عنوان
                Text(
                  isEditing ? 'ویرایش مشتری' : 'ثبت مشتری جدید',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),

                const SizedBox(height: 24),

                // نام و نام خانوادگی
                CustomTextField(
                  controller: _nameController,
                  hint: 'نام و نام خانوادگی',
                  //icon: Icons.person_outline,
                  maxLength: 16,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'لطفا نام و نام خانوادگی را وارد کنید.';
                    }
                    if (value.trim().length > 16) {
                      return 'نام نباید بیشتر از ۱۶ کاراکتر باشد.';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 16),

                // شماره همراه
                CustomTextField(
                  controller: _mobileController,
                  hint: 'شماره همراه',
                  //icon: Icons.phone_iphone,
                  keyboardType: TextInputType.phone,
                  maxLength: 11,
                  inputFormatters: [
                    PersianDigitsInputFormatter(),
                  ],
                  validator: Validators.validateMobileNumber,
                ),

                const SizedBox(height: 16),

                // توضیحات
                CustomTextField(
                  controller: _notesController,
                  hint: 'توضیحات (اختیاری)',
                  //icon: Icons.info_outline,
                  maxLength: 200,
                  validator: null, // اختیاری
                ),

                const SizedBox(height: 24),

                // دکمه‌ها
                Row(
                  children: [
                    // دکمه ثبت
                    Expanded(
                      child: CustomButton(
                        text: isEditing ? 'ویرایش' : 'ثبت',
                        onPressed: _handleSubmit,
                        useGradient: true,
                      ),
                    ),

                    const SizedBox(width: 12),

                    // دکمه انصراف
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.textSecondary,
                          side: BorderSide(color: Colors.grey.shade300),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('انصراف'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}