import 'package:flutter/material.dart';
import '../../../core/constants/colors.dart';
import '../../../core/utils/price_input_formatter.dart';
import '../../../data/models/service_model.dart';
import 'custom_textfield.dart';
import 'custom_button.dart';
import '../../core/utils/date_helper.dart';

class AddServiceDialog extends StatefulWidget {
  final ServiceModel? service; // اگه null باشه یعنی افزودن، وگرنه ویرایش

  const AddServiceDialog({
    super.key,
    this.service,
  });

  @override
  State<AddServiceDialog> createState() => _AddServiceDialogState();
}

class _AddServiceDialogState extends State<AddServiceDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _priceController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.service?.serviceName ?? '');
    _priceController = TextEditingController(
      text: widget.service != null
          ? DateHelper.toPersianDigits(widget.service!.formattedPrice ?? '') // ← تبدیل به فارسی
          : '',
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

    final service = ServiceModel(
      id: widget.service?.id ?? '',
      serviceName: _nameController.text.trim(),
      price: ServiceModel.parsePrice(_priceController.text.trim()),
      isActive: widget.service?.isActive ?? true,
      createdAt: widget.service?.createdAt ?? DateTime.now(),
      updatedAt: widget.service != null ? DateTime.now() : null,
    );

    Navigator.pop(context, service);
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.service != null;

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
                  isEditing ? 'ویرایش خدمت' : 'ثبت خدمت جدید',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),

                const SizedBox(height: 24),

                // عنوان خدمت
                CustomTextField(
                  controller: _nameController,
                  hint: 'عنوان خدمت',
                  //icon: Icons.camera_alt,
                  maxLength: 32,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'لطفا عنوان خدمت را وارد کنید.';
                    }
                    if (value.trim().length > 32) {
                      return 'عنوان خدمت نباید بیشتر از ۳۲ کاراکتر باشد.';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 16),

                // مبلغ خدمت
                TextFormField(
                  controller: _priceController,
                  textAlign: TextAlign.right,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    PersianPriceInputFormatter(), // ← formatter فارسی (جایگزین PriceInputFormatter)
                  ],
                  decoration: InputDecoration(
                    hintText: 'مبلغ خدمت (اختیاری)',
                    hintStyle: const TextStyle(
                      color: AppColors.textLight,
                      fontSize: 14,
                    ),
                    suffixText: 'تومان',
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