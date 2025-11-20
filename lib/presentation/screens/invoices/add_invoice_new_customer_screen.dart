import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:persian_datetime_picker/persian_datetime_picker.dart';
import 'package:shamsi_date/shamsi_date.dart';
import '../../../core/constants/colors.dart';
import '../../../core/utils/date_helper.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../core/utils/validators.dart';
import '../../../data/models/customer_model.dart';
import '../../../data/repositories/customer_repository.dart';
import '../../../data/repositories/invoice_repository.dart';
import '../../widgets/custom_textfield.dart';
import '../../widgets/custom_button.dart';
import 'add_invoice_screen.dart';

class AddInvoiceNewCustomerScreen extends StatefulWidget {
  const AddInvoiceNewCustomerScreen({super.key});

  @override
  State<AddInvoiceNewCustomerScreen> createState() => _AddInvoiceNewCustomerScreenState();
}

class _AddInvoiceNewCustomerScreenState extends State<AddInvoiceNewCustomerScreen> {
  final CustomerRepository _customerRepository = CustomerRepository();
  final InvoiceRepository _invoiceRepository = InvoiceRepository();

  @override
  void initState() {
    super.initState();
    _showInitialDialog();
  }

  Future<void> _showInitialDialog() async {
    await Future.delayed(Duration.zero);
    if (!mounted) return;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const _NewCustomerDialog(),
    );

    if (result != null && mounted) {
      _navigateToInvoiceForm(
        result['fullName'],
        result['mobileNumber'],
        result['date'],
      );
    } else if (mounted) {
      Navigator.pop(context);
    }
  }

  Future<void> _navigateToInvoiceForm(
      String fullName,
      String mobileNumber,
      Jalali invoiceDate,
      ) async {
    try {
      // ایجاد مشتری جدید
      final newCustomer = CustomerModel(
        id: '',
        fullName: fullName,
        mobileNumber: mobileNumber,
        createdAt: DateTime.now(),
      );

      final customerId = await _customerRepository.addCustomer(newCustomer);
      final customer = newCustomer.copyWith(id: customerId);

      // دریافت شماره سند بعدی
      final invoiceNumber = await _invoiceRepository.getNextInvoiceNumber();

      if (!mounted) return;

      // هدایت به صفحه فاکتور
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => InvoiceFormScreen(
            customer: customer,
            invoiceDate: invoiceDate,
            invoiceNumber: invoiceNumber,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        SnackBarHelper.showError(
          context,
          e.toString().replaceAll('Exception: ', ''),
        );
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}

// دیالوگ ثبت مشتری جدید
class _NewCustomerDialog extends StatefulWidget {
  const _NewCustomerDialog();

  @override
  State<_NewCustomerDialog> createState() => _NewCustomerDialogState();
}

class _NewCustomerDialogState extends State<_NewCustomerDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _mobileController = TextEditingController();
  Jalali? _selectedDate;

  @override
  void dispose() {
    _nameController.dispose();
    _mobileController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final picked = await showPersianDatePicker(
      context: context,
      initialDate: _selectedDate ?? Jalali.now(),
      firstDate: Jalali.now().addYears(-1),
      lastDate: Jalali.now(),
      locale: const Locale('fa', 'IR'),
      builder: (context, child) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: Theme(
            data: Theme.of(context).copyWith(
              colorScheme: ColorScheme.light(
                primary: AppColors.primary,
                onPrimary: Colors.white,
                surface: Colors.white,
                onSurface: AppColors.textPrimary,
              ),
              textTheme: Theme.of(context).textTheme.apply(fontFamily: 'Vazirmatn'),
            ),
            child: child!,
          ),
        );
      },
    );

    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  void _handleSubmit() {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedDate == null) {
      SnackBarHelper.showError(context, 'لطفاً تاریخ سند را انتخاب کنید');
      return;
    }

    Navigator.pop(context, {
      'fullName': _nameController.text.trim(),
      'mobileNumber': Validators.cleanMobileNumber(_mobileController.text),
      'date': _selectedDate,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'ویرایش مشخصات',
                  style: TextStyle(
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
                  maxLength: 16,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'لطفاً نام و نام خانوادگی را وارد کنید';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 16),

                // شماره همراه
                CustomTextField(
                  controller: _mobileController,
                  hint: 'شماره همراه',
                  keyboardType: TextInputType.phone,
                  maxLength: 11,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  validator: Validators.validateMobileNumber,
                ),

                const SizedBox(height: 16),

                // تاریخ فاکتور
                InkWell(
                  onTap: _selectDate,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Icon(Icons.arrow_drop_down, color: AppColors.primary),
                        Text(
                          _selectedDate != null
                              ? DateHelper.formatPersianDate(_selectedDate!)
                              : 'تاریخ فاکتور',
                          style: TextStyle(
                            fontSize: 14,
                            color: _selectedDate != null
                                ? AppColors.textPrimary
                                : AppColors.textLight,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('انصراف'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: CustomButton(
                        text: 'ثبت',
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