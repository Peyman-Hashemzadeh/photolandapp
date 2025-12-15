import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:persian_datetime_picker/persian_datetime_picker.dart';
import 'package:shamsi_date/shamsi_date.dart';
import '../../../core/utils/date_helper.dart';
import '../../../core/constants/colors.dart';
import '../../../core/utils/validators.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../data/models/customer_model.dart';
import '../../../data/models/appointment_model.dart';
import '../../../data/repositories/customer_repository.dart';
import '../../../data/repositories/appointment_repository.dart';
import '../../widgets/custom_textfield.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/customer_dropdown.dart';
import '../../widgets/duration_dropdown.dart';
import 'appointment_deposit_screen.dart';
import 'package:flutter/services.dart';


class PersianDigitsInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue,
      TextEditingValue newValue,
      ) {
    // فقط digits رو نگه دار (انگلیسی یا فارسی)
    final filtered = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');

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
class AddAppointmentScreen extends StatefulWidget {
  final bool isNewCustomer;
  final AppointmentModel? appointment; // برای ویرایش

  const AddAppointmentScreen({
    super.key,
    required this.isNewCustomer,
    this.appointment,
  });

  @override
  State<AddAppointmentScreen> createState() => _AddAppointmentScreenState();
}

class _AddAppointmentScreenState extends State<AddAppointmentScreen> {
  final _formKey = GlobalKey<FormState>();
  final CustomerRepository _customerRepository = CustomerRepository();
  final AppointmentRepository _appointmentRepository = AppointmentRepository();

  // Controllers برای مشتری جدید
  final _newCustomerNameController = TextEditingController();
  final _newCustomerMobileController = TextEditingController();

  // Controllers برای نوبت
  final _childAgeController = TextEditingController();
  final _photographyModelController = TextEditingController();
  final _notesController = TextEditingController();
  final _timeController = TextEditingController();

  // State variables
  CustomerModel? _selectedCustomer;
  List<CustomerModel> _customers = [];
  Jalali? _selectedDate;
  int? _selectedDuration;
  bool _isLoading = false;
  bool _isLoadingCustomers = true;

  @override
  void initState() {
    super.initState();
    if (!widget.isNewCustomer) {
      _loadCustomers();
    } else {
      _isLoadingCustomers = false;
    }
    _loadAppointmentData();
  }

  @override
  void dispose() {
    _newCustomerNameController.dispose();
    _newCustomerMobileController.dispose();
    _childAgeController.dispose();
    _photographyModelController.dispose();
    _notesController.dispose();
    _timeController.dispose();
    super.dispose();
  }

  void _loadCustomers() {
    _customerRepository.getActiveCustomers().listen((customers) {
      if (mounted) {
        setState(() {
          _customers = customers;
          _isLoadingCustomers = false;
        });

        // 🔥 اضافه شد: بعد از لود مشتریان، اگر ویرایشه، مشتری رو پیدا کن
        if (widget.appointment != null && _selectedCustomer == null) {
          _loadAppointmentData();
        }
      }
    });
  }

  void _loadAppointmentData() {
    if (widget.appointment != null) {
      final apt = widget.appointment!;
      _childAgeController.text = apt.childAge ?? '';
      _photographyModelController.text = apt.photographyModel ?? '';
      _notesController.text = apt.notes ?? '';
      _timeController.text = apt.requestedTime;
      _selectedDate = Jalali.fromDateTime(apt.requestedDate);
      _selectedDuration = apt.durationMinutes;

      //   پیدا کردن مشتری در لیست
      if (!widget.isNewCustomer && _customers.isNotEmpty) {
        _selectedCustomer = _customers.firstWhere(
              (c) => c.id == apt.customerId,
          orElse: () => _customers.first,
        );
      }
    }
  }

  Future<void> _selectDate() async {
    final picked = await showPersianDatePicker(
      context: context,
      initialDate: _selectedDate ?? Jalali.now(),
      firstDate: Jalali.now(),
      lastDate: Jalali.now().addYears(3),
      locale: const Locale('fa', 'IR'),
      helpText: null,
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
              // ← بهبود: textTheme کامل برای grid (اعداد روزها bodySmall/labelSmall هستن)
              textTheme: Theme.of(context).textTheme.copyWith(
                bodySmall: const TextStyle(
                  fontFamily: 'Vazirmatn',  // فونت جدید با Persian digits
                  fontSize: 16,  // سایز اعداد روزها
                  fontWeight: FontWeight.w500,
                ),
                labelSmall: const TextStyle(
                  fontFamily: 'Vazirmatn',
                  fontSize: 12,  // نام ماه/روز
                ),
                bodyMedium: const TextStyle(fontFamily: 'Vazirmatn'),  // fallback
              ),
              // اختیاری: برای header و عنوان ماه
              appBarTheme: const AppBarTheme(
                titleTextStyle: TextStyle(fontFamily: 'Vazirmatn', fontSize: 18),
              ),
            ),
            child: child!,
          ),
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }


  Future<void> _selectTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (context, child) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _timeController.text =
        '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      });
    }
  }

  Future<void> _handleContinue() async {
    if (!_formKey.currentState!.validate()) {
      FocusScope.of(context).unfocus();
      return;
    }

    if (_selectedDate == null) {
      SnackBarHelper.showError(context, 'لطفا تاریخ درخواستی را انتخاب کنید');
      return;
    }

    if (_timeController.text.isEmpty) {
      SnackBarHelper.showError(context, 'لطفا ساعت درخواستی را انتخاب کنید');
      return;
    }

    if (_selectedDuration == null) {
      SnackBarHelper.showError(context, 'لطفا مدت رزرو را انتخاب کنید');
      return;
    }

    setState(() => _isLoading = true);

    try {
      CustomerModel customer;

      // مشتری جدید یا موجود
      if (widget.isNewCustomer) {
        final mobileNumber = Validators.cleanMobileNumber(_newCustomerMobileController.text);

        // 🔥 چک کردن تکراری بودن شماره
        final existingCustomer = await _customerRepository.getCustomerByMobile(mobileNumber);

        if (existingCustomer != null) {
          // 🔥 شماره تکراری است - نمایش دیالوگ تایید
          if (!mounted) return;

          final shouldUsExisting = await _showDuplicatePhoneDialog(
            existingCustomer: existingCustomer,
            newName: _newCustomerNameController.text.trim(),
          );

          if (shouldUsExisting == null) {
            // کاربر انصراف داد
            setState(() => _isLoading = false);
            return;
          }

          if (shouldUsExisting) {
            // استفاده از مشتری موجود
            customer = existingCustomer;
          } else {
            // به‌روزرسانی اطلاعات مشتری موجود
            customer = existingCustomer.copyWith(
              fullName: _newCustomerNameController.text.trim(),
              updatedAt: DateTime.now(),
            );
            await _customerRepository.updateCustomer(customer);
          }
        } else {
          // مشتری جدید - ذخیره
          final newCustomer = CustomerModel(
            id: '',
            fullName: _newCustomerNameController.text.trim(),
            mobileNumber: mobileNumber,
            createdAt: DateTime.now(),
          );

          final customerId = await _customerRepository.addCustomer(newCustomer);
          customer = newCustomer.copyWith(id: customerId);
        }
      } else {
        if (_selectedCustomer == null) {
          SnackBarHelper.showError(context, 'لطفا مشتری را انتخاب کنید');
          setState(() => _isLoading = false);
          return;
        }
        customer = _selectedCustomer!;
      }

      // چک تداخل
      final overlapping = await _appointmentRepository.checkOverlap(
        date: _selectedDate!.toDateTime(),
        startTime: _timeController.text,
        durationMinutes: _selectedDuration!,
        excludeId: widget.appointment?.id,
      );

      if (!mounted) return;

      // اگه تداخل داشت
      if (overlapping.isNotEmpty) {
        final confirm = await _showOverlapDialog(overlapping);
        if (confirm != true) {
          setState(() => _isLoading = false);
          return;
        }
      }

      // ساخت مدل نوبت موقت
      final appointment = AppointmentModel(
        id: widget.appointment?.id ?? '',
        customerId: customer.id,
        customerName: customer.fullName,
        customerMobile: customer.mobileNumber,
        childAge: _childAgeController.text.trim().isEmpty
            ? null
            : _childAgeController.text.trim(),
        requestedDate: _selectedDate!.toDateTime(),
        requestedTime: _timeController.text,
        durationMinutes: _selectedDuration!,
        photographyModel: _photographyModelController.text.trim().isEmpty
            ? null
            : _photographyModelController.text.trim(),
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
        createdAt: widget.appointment?.createdAt ?? DateTime.now(),
      );

      setState(() => _isLoading = false);

      // رفتن به مرحله بیعانه
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => AppointmentDepositScreen(
            appointment: appointment,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        SnackBarHelper.showError(
          context,
          e.toString().replaceAll('Exception: ', ''),
        );
      }
    }
  }

  // 🔥 دیالوگ برای شماره تکراری
  Future<bool?> _showDuplicatePhoneDialog({
    required CustomerModel existingCustomer,
    required String newName,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // آیکون هشدار
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.orange.shade700,
                  size: 48,
                ),
              ),

              const SizedBox(height: 20),

              // عنوان
              const Text(
                'شماره همراه تکراری',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 16),

              // متن توضیحات
              RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.6,
                    color: AppColors.textSecondary,
                    fontFamily: 'Vazirmatn',
                  ),
                  children: [
                    const TextSpan(
                      text: 'این شماره همراه قبلاً با نام ',
                    ),
                    TextSpan(
                      text: '"${existingCustomer.fullName}"',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                    const TextSpan(
                      text: ' ثبت شده است.',
                    ),
                  ],
                ),
              ),

              if (newName != existingCustomer.fullName) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.info.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.info.withOpacity(0.3),
                    ),
                  ),
                  child: RichText(
                    textAlign: TextAlign.center,
                    text: TextSpan(
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.5,
                        color: AppColors.info,
                        fontFamily: 'Vazirmatn',
                      ),
                      children: [
                        const TextSpan(
                          text: 'شما نام ',
                        ),
                        TextSpan(
                          text: '"$newName"',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const TextSpan(
                          text: ' را وارد کرده‌اید.',
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 24),

              // دکمه‌ها
              Column(
                children: [
                  // دکمه استفاده از اطلاعات موجود
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.pop(context, true),
                      icon: const Icon(Icons.check_circle_outline, size: 20),
                      label: Text(
                        'ثبت نوبت برای "${existingCustomer.fullName}"',
                        style: const TextStyle(fontSize: 14),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),

                  if (newName != existingCustomer.fullName) ...[
                    const SizedBox(height: 12),

                    // دکمه به‌روزرسانی نام
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => Navigator.pop(context, false),
                        icon: const Icon(Icons.edit_outlined, size: 20),
                        label: Text(
                          'به‌روزرسانی به "$newName"',
                          style: const TextStyle(fontSize: 14),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.info,
                          side: BorderSide(color: AppColors.info.withOpacity(0.5)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 12),

                  // دکمه انصراف
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.grey.shade600,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('انصراف و بازگشت'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<bool?> _showOverlapDialog(List<AppointmentModel> overlapping) {
    return showDialog<bool>(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('تداخل رزرو'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('در این بازه زمانی رزرو دیگری وجود دارد:'),
              const SizedBox(height: 12),
              ...overlapping.map((apt) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  '• ${apt.customerName} - ${apt.timeRange}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              )),
              const SizedBox(height: 12),
              const Text('آیا اطمینان به رزرو نوبت دارید؟'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text(
                'بله، رزرو کن',
                style: TextStyle(color: AppColors.primary),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('خیر'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleCancel() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('انصراف از ثبت'),
          content: const Text('آیا از انصراف ثبت نوبت اطمینان دارید؟'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text(
                'بله',
                style: TextStyle(color: AppColors.error),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('خیر'),
            ),
          ],
        ),
      ),
    );

    if (confirm == true && mounted) {
      Navigator.pop(context);
    }
  }

  // Helper برای BoxShadow مشترک (برای جلوگیری از تکرار)
  BoxShadow _getFieldShadow() {
    return BoxShadow(
      color: Colors.black.withOpacity(0.10),
      blurRadius: 8,
      offset: const Offset(0, 2),
    );
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
                child: _isLoadingCustomers && !widget.isNewCustomer
                    ? const Center(child: CircularProgressIndicator())
                    : SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        // فیلدهای مشتری جدید
                        if (widget.isNewCustomer) ...[
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [_getFieldShadow()],
                            ),
                            child: FormField<String>(
                              autovalidateMode: AutovalidateMode.onUserInteraction,
                              validator: (value) => Validators.validateFullName(value),
                              builder: (field) {
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    CustomTextField(
                                      controller: _newCustomerNameController,
                                      hint: 'نام و نام خانوادگی',
                                      maxLength: 16,
                                      onChanged: (val) => field.didChange(val),
                                    ),
                                    if (field.hasError)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 8, right: 16, bottom: 8),
                                        child: Text(
                                          field.errorText!,
                                          textAlign: TextAlign.right,
                                          style: const TextStyle(
                                            color: AppColors.error,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                  ],
                                );
                              },
                            ),
                          ),

                          const SizedBox(height: 16),
                          Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [_getFieldShadow()],
                              ),
                          child: FormField<String>(
                            initialValue: _newCustomerMobileController.text,
                            validator: (value) => Validators.validateMobileNumber(value),
                            builder: (field) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start, // راست‌چین کردن
                                children: [
                                  Container(
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                     // boxShadow: [_getFieldShadow()],
                                    ),
                                    child: CustomTextField(
                                      controller: _newCustomerMobileController,
                                      hint: 'شماره همراه',
                                      keyboardType: TextInputType.phone,
                                      maxLength: 11,
                                      inputFormatters: [
                                        FilteringTextInputFormatter.digitsOnly,
                                      ],
                                      onChanged: (val) => field.didChange(val), // بروزرسانی فرم
                                    ),
                                  ),
                                  if (field.hasError)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 8, right: 16, bottom: 8), // فاصله بالا و پایین
                                      child: Text(
                                        field.errorText!,
                                        textAlign: TextAlign.right, // راست‌چین
                                        style: const TextStyle(
                                          color: AppColors.error,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                ],
                              );
                            },
                          ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // انتخاب مشتری (برای نوبت عادی)
                        if (!widget.isNewCustomer) ...[
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [_getFieldShadow()],
                            ),
                            child: FormField<CustomerModel?>(  // ← FormField دور CustomerDropdown برای trigger
                              initialValue: _selectedCustomer,
                              autovalidateMode: AutovalidateMode.onUserInteraction,  // پاک شدن خودکار
                              validator: (customer) {
                                if (customer == null) {
                                  return 'لطفا مشتری را انتخاب کنید!';
                                }
                                return null;
                              },
                              builder: (field) {
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    CustomerDropdown(  // بدون validator (چون حالا والد داره)
                                      customers: _customers,
                                      selectedCustomer: field.value,  // از field استفاده کن
                                      onChanged: (customer) {
                                        field.didChange(customer);  // ← key: trigger validator بعد از تغییر
                                        setState(() {
                                          _selectedCustomer = customer;
                                        });
                                      },
                                    ),
                                    if (field.hasError)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 8, right: 16, bottom: 8),
                                        child: Align(
                                          alignment: Alignment.centerRight,
                                        child: Text(
                                          field.errorText!,
                                          style: const TextStyle(color: AppColors.error, fontSize: 12),
                                        ),
                                        ),
                                      ),
                                  ],
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // سن کودک
                        Container(  // ← Container با shadow
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [_getFieldShadow()],
                          ),
                          child: CustomTextField(
                            controller: _childAgeController,
                            hint: 'سن کودک (اختیاری)',
                            maxLength: 30,
                            validator: null,
                          ),
                        ),

                        const SizedBox(height: 16),

                        // تاریخ درخواستی
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [_getFieldShadow()],
                          ),
                          child: FormField<Jalali?>(  // ← FormField جدید برای date
                            initialValue: _selectedDate,
                            autovalidateMode: AutovalidateMode.onUserInteraction,  // پاک شدن خودکار error
                            validator: (date) {
                              if (date == null) {
                                return 'لطفا تاریخ درخواستی را انتخاب کنید!';  // اجباری
                              }
                              return null;
                            },
                            builder: (field) {
                              return Column(  // error message زیر فیلد
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  InkWell(
                                    onTap: () {
                                      _selectDate().then((_) {
                                        field.didChange(_selectedDate);  // trigger validator بعد از select
                                      });
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                      child: Row(
                                        children: [
                                          Text(
                                            DateHelper.formatPersianDate(_selectedDate),  // ← جدید: استفاده از helper (اعداد فارسی می‌شن)
                                            textAlign: TextAlign.right,
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: _selectedDate != null ? AppColors.textPrimary : AppColors.textLight,
                                              fontFamily: 'Vazirmatn',  // force فونت برای smoothness
                                            ),
                                          ),
                                          const Spacer(),
                                          // در Text داخل InkWell (بخش builder FormField)
                                         // const Icon(Icons.calendar_today_rounded, color: AppColors.primary),
                                        ],
                                      ),
                                    ),
                                  ),
                                  if (field.hasError)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 8, right: 16, bottom: 8),
                              child: Align(
                              alignment: Alignment.centerRight,
                                      child: Text(
                                        field.errorText!,
                                        style: const TextStyle(color: AppColors.error, fontSize: 12),
                                      ),
                                    ),
                                    ),
                                ],
                              );
                            },
                          ),
                        ),

                        const SizedBox(height: 16),

                        // ساعت درخواستی
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [_getFieldShadow()],
                          ),
                          child: FormField<String>(
                            initialValue: _timeController.text,
                            autovalidateMode: AutovalidateMode.onUserInteraction,
                            validator: (time) {
                              if (time == null || time.isEmpty) {
                                return 'لطفا ساعت درخواستی را انتخاب کنید!';
                              }
                              return null;
                            },
                            builder: (field) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  InkWell(
                                    onTap: () {
                                      _selectTime().then((_) {
                                        field.didChange(_timeController.text);
                                      });
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                      child: Row(
                                        children: [
                                          Text(
                                            _timeController.text.isEmpty
                                                ? 'ساعت درخواستی'
                                                : DateHelper.toPersianDigits(_timeController.text), // 👈 تبدیل به فارسی
                                            textAlign: TextAlign.right,
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: _timeController.text.isNotEmpty
                                                  ? AppColors.textPrimary
                                                  : AppColors.textLight,
                                            ),
                                          ),
                                          const Spacer(),
                                         // const Icon(Icons.timer_outlined, color: AppColors.primary),
                                        ],
                                      ),
                                    ),
                                  ),
                                  if (field.hasError)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 8, right: 16, bottom: 8),
                                      child: Align(alignment: Alignment.centerRight,
                                      child: Text(
                                        field.errorText!,
                                        style: const TextStyle(color: AppColors.error, fontSize: 12),
                                      ),
                                      ),
                                    ),
                                ],
                              );
                            },
                          ),
                        ),

                        const SizedBox(height: 16),

                        // مدت رزرو
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [_getFieldShadow()],
                          ),
                          child: FormField<int?>(  // ← FormField جدید برای duration (نوع int? فرض کردم)
                            initialValue: _selectedDuration,
                            autovalidateMode: AutovalidateMode.onUserInteraction,  // پاک شدن خودکار
                            validator: (duration) {
                              if (duration == null) {
                                return 'لطفا مدت رزرو را انتخاب کنید!';
                              }
                              return null;
                            },
                            builder: (field) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  DurationDropdown(  // بدون validator (حالا والد داره)
                                    selectedDuration: field.value,  // از field استفاده کن
                                    onChanged: (duration) {
                                      field.didChange(duration);  // ← key: trigger validator بعد از تغییر
                                      setState(() {
                                        _selectedDuration = duration;
                                      });
                                    },
                                  ),
                                  if (field.hasError)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 8, right: 16, bottom: 8),
                                      child: Align(
                                      alignment: Alignment.centerRight,
                                      child: Text(
                                        field.errorText!,
                                        style: const TextStyle(color: AppColors.error, fontSize: 12),
                                      ),
                                    ),
                                    ),
                                ],
                              );
                            },
                          ),
                        ),

                        const SizedBox(height: 16),

                        // مدل عکاسی
                        Container(  // ← Container با shadow
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [_getFieldShadow()],
                          ),
                          child: CustomTextField(
                            controller: _photographyModelController,
                            hint: 'مدل عکاسی (اختیاری)',
                            maxLength: 30,
                            validator: null,
                          ),
                        ),

                        const SizedBox(height: 16),

                        // توضیحات
                        Container(  // ← Container با shadow
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [_getFieldShadow()],
                          ),
                          child: TextFormField(
                            controller: _notesController,
                            maxLength: 150,
                            maxLines: 4,
                            textAlign: TextAlign.right,
                            decoration: InputDecoration(
                              hintText: 'توضیحات (اختیاری)',
                              hintStyle: const TextStyle(
                                color: AppColors.textLight,
                                fontSize: 12,
                              ),
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(
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
                              contentPadding: const EdgeInsets.all(16),
                            ),
                          ),
                        ),

                        const SizedBox(height: 32),

                        // دکمه‌ها
                        Row(
                          children: [
                            Expanded(
                              child: CustomButton(
                                text: 'ادامه و مرحله بعد',
                                onPressed: _handleContinue,
                                isLoading: _isLoading,
                                useGradient: true,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: OutlinedButton(
                                onPressed: _handleCancel,
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
          GestureDetector(
            onTap: () {},
            child: Container(
              width: 44,
              height: 44,
              //decoration: BoxDecoration(
              //  color: Colors.grey.shade300,
              //  shape: BoxShape.circle,
              //),
              //child: const Center(
              //  child: FaIcon(
              //    FontAwesomeIcons.user,
              //    color: Colors.grey,
              //    size: 20,
              //  ),
              //),
            ),
          ),
          Text(
            widget.isNewCustomer ? 'نوبت مشتری جدید' : 'ثبت نوبت',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.arrow_forward, color: AppColors.textPrimary),
            onPressed: _handleCancel,
          ),
        ],
      ),
    );
  }
}