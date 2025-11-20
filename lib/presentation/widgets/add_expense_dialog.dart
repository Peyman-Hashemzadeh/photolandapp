import 'package:flutter/material.dart';
import '../../../core/constants/colors.dart';
import '../../../core/utils/price_input_formatter.dart';
import '../../../data/models/expense_model.dart';
import 'custom_textfield.dart';
import 'custom_button.dart';

class AddExpenseDialog extends StatefulWidget {
  final ExpenseModel? expense; // اگه null باشه یعنی افزودن، وگرنه ویرایش

  const AddExpenseDialog({
    super.key,
    this.expense,
  });

  @override
  State<AddExpenseDialog> createState() => _AddExpenseDialogState();
}

class _AddExpenseDialogState extends State<AddExpenseDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _priceController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.expense?.expenseName ?? '');
    _priceController = TextEditingController(
      text: widget.expense?.formattedPrice ?? '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  void _handleSubmit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final expense = ExpenseModel(
      id: widget.expense?.id ?? '',
      expenseName: _nameController.text.trim(),
      price: ExpenseModel.parsePrice(_priceController.text.trim()),
      isActive: widget.expense?.isActive ?? true,
      createdAt: widget.expense?.createdAt ?? DateTime.now(),
      updatedAt: widget.expense != null ? DateTime.now() : null,
    );

    Navigator.pop(context, expense);
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.expense != null;

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
                  isEditing ? 'ویرایش هزینه' : 'ثبت هزینه جدید',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),

                const SizedBox(height: 24),

                // عنوان هزینه
                CustomTextField(
                  controller: _nameController,
                  hint: 'عنوان هزینه',
                  maxLength: 32,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'لطفاً عنوان هزینه را وارد کنید';
                    }
                    if (value.trim().length > 32) {
                      return 'عنوان هزینه نباید بیشتر از ۳۲ کاراکتر باشد';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 16),

                // مبلغ هزینه
                TextFormField(
                  controller: _priceController,
                  textAlign: TextAlign.right,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    PriceInputFormatter(),
                  ],
                  decoration: InputDecoration(
                    hintText: 'مبلغ هزینه (اختیاری)',
                    hintStyle: const TextStyle(
                      color: AppColors.textLight,
                      fontSize: 14,
                    ),
                    suffixStyle: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                    ),
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
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                  ),
                  validator: null, // اختیاری
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