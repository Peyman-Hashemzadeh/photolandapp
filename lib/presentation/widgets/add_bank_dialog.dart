import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/colors.dart';
import '../../../data/models/bank_model.dart';
import 'custom_textfield.dart';
import 'custom_button.dart';

class AddBankDialog extends StatefulWidget {
  final BankModel? bank; // اگه null باشه یعنی افزودن، وگرنه ویرایش

  const AddBankDialog({
    super.key,
    this.bank,
  });

  @override
  State<AddBankDialog> createState() => _AddBankDialogState();
}

class _AddBankDialogState extends State<AddBankDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _accountController;
  late final TextEditingController _ibanController;
  late final TextEditingController _accountOwnerController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.bank?.bankName ?? '');
    _accountController = TextEditingController(text: widget.bank?.accountNumber ?? '');
    _ibanController = TextEditingController(text: widget.bank?.ibanNumber ?? '');
    _accountOwnerController = TextEditingController(text: widget.bank?.accountOwner ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _accountController.dispose();
    _ibanController.dispose();
    _accountOwnerController.dispose();
    super.dispose();
  }

  void _handleSubmit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final bank = BankModel(
      id: widget.bank?.id ?? '',
      bankName: _nameController.text.trim(),
      accountNumber: _accountController.text.trim().isEmpty
          ? null
          : _accountController.text.trim(),
      ibanNumber: _ibanController.text.trim().isEmpty
          ? null
          : _ibanController.text.trim(),
      accountOwner: _accountOwnerController.text.trim().isEmpty
          ? null
          : _accountOwnerController.text.trim(),
      isActive: widget.bank?.isActive ?? true,
      createdAt: widget.bank?.createdAt ?? DateTime.now(),
      updatedAt: widget.bank != null ? DateTime.now() : null,
    );

    Navigator.pop(context, bank);
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.bank != null;

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
                  isEditing ? 'ویرایش بانک' : 'ثبت بانک جدید',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),

                const SizedBox(height: 24),

                // نام بانک
                CustomTextField(
                  controller: _nameController,
                  hint: 'نام بانک',
                  //icon: Icons.account_balance,
                  maxLength: 32,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'لطفا نام بانک را وارد کنید';
                    }
                    if (value.trim().length > 32) {
                      return 'نام بانک نباید بیشتر از ۳۲ کاراکتر باشد';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 16),

                // شماره حساب
                CustomTextField(
                  controller: _accountController,
                  hint: 'شماره حساب/کارت (اختیاری)',
                 // icon: Icons.credit_card,
                  keyboardType: TextInputType.number,
                  maxLength: 16,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  validator: (value) {
                    if (value != null && value.isNotEmpty && value.length > 16) {
                      return 'شماره حساب نباید بیشتر از ۱۶ رقم باشد';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 16),

                // شماره شبا
                TextFormField(
                  controller: _ibanController,
                  textAlign: TextAlign.right,
                  keyboardType: TextInputType.number,
                  maxLength: 24,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  decoration: InputDecoration(
                    hintText: 'شماره شبا (اختیاری)',
                    hintStyle: const TextStyle(
                      color: AppColors.textLight,
                      fontSize: 13,
                    ),
                    prefixText: 'IR',
                    prefixStyle: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  //  icon: Icons.account_balance_wallet,

                   // prefixIcon: const Icon(Icons.account_balance_wallet, color: AppColors.primary),
                    filled: true,
                    fillColor: Colors.grey[100],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: AppColors.primary,
                        width: 2,
                      ),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: AppColors.error,
                        width: 1,
                      ),
                    ),
                    counterText: '',
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                  ),
                  validator: (value) {
                    if (value != null && value.isNotEmpty && value.length != 24) {
                      return 'شماره شبا باید ۲۴ رقمی باشد';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 16),

                // توضیحات
                CustomTextField(
                  controller: _accountOwnerController,
                  hint: 'صاحب حساب (اختباری)',
                 // icon: Icons.note_outlined,
                  maxLength: 200,
                  validator: null,
                ),

                const SizedBox(height: 24),

                // دکمه‌ها
                Row(
                  children: [
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

                    const SizedBox(width: 12),

                    // دکمه ثبت
                    Expanded(
                      child: CustomButton(
                        text: isEditing ? 'ویرایش' : 'ثبت',
                        onPressed: _handleSubmit,
                        useGradient: true,
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