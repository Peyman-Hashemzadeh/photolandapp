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
      return;
    }
    if (!_formKey.currentState!.validate()) {
      FocusScope.of(context).unfocus();
      return;
    }

    if (_selectedDate == null) {
      SnackBarHelper.showError(context, 'لطفاً تاریخ درخواستی را انتخاب کنید');
      return;
    }

    if (_timeController.text.isEmpty) {
      SnackBarHelper.showError(context, 'لطفاً ساعت درخواستی را انتخاب کنید');
      return;
    }

    if (_selectedDuration == null) {
      SnackBarHelper.showError(context, 'لطفاً مدت رزرو را انتخاب کنید');
      return;
    }

    setState(() => _isLoading = true);

    try {
      CustomerModel customer;

      // مشتری جدید یا موجود
      if (widget.isNewCustomer) {
        // ثبت مشتری جدید
        final newCustomer = CustomerModel(
          id: '',
          fullName: _newCustomerNameController.text.trim(),
          mobileNumber: Validators.cleanMobileNumber(_newCustomerMobileController.text),
          createdAt: DateTime.now(),
        );

        final customerId = await _customerRepository.addCustomer(newCustomer);
        customer = newCustomer.copyWith(id: customerId);
      } else {
        if (_selectedCustomer == null) {
          SnackBarHelper.showError(context, 'لطفاً مشتری را انتخاب کنید');
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
      color: Colors.black.withOpacity(0.05),
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
                            child: CustomTextField(
                              controller: _newCustomerNameController,
                              hint: 'نام و نام خانوادگی',
                              maxLength: 16,
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'لطفاً نام و نام خانوادگی را وارد کنید';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(height: 16),
                          Container(  // ← Container با shadow
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [_getFieldShadow()],
                            ),
                            child: CustomTextField(
                              controller: _newCustomerMobileController,
                              hint: 'شماره همراه',
                              keyboardType: TextInputType.phone,
                              maxLength: 11,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              validator: Validators.validateMobileNumber,
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
                                  return 'لطفاً مشتری را انتخاب کنید';
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
                                        padding: const EdgeInsets.only(top: 8, right: 16),
                                        child: Text(
                                          field.errorText!,
                                          style: const TextStyle(color: AppColors.error, fontSize: 12),
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
                                return 'لطفاً تاریخ درخواستی را انتخاب کنید';  // اجباری
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
                                          const Icon(Icons.arrow_drop_down, color: AppColors.primary),
                                          const Spacer(),
                                          // در Text داخل InkWell (بخش builder FormField)
                                          Text(
                                            DateHelper.formatPersianDate(_selectedDate),  // ← جدید: استفاده از helper (اعداد فارسی می‌شن)
                                            textAlign: TextAlign.right,
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: _selectedDate != null ? AppColors.textPrimary : AppColors.textLight,
                                              fontFamily: 'Vazirmatn',  // force فونت برای smoothness
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  if (field.hasError)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 8, right: 16),
                                      child: Text(
                                        field.errorText!,
                                        style: const TextStyle(color: AppColors.error, fontSize: 12),
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
                          child: FormField<String>(  // ← FormField جدید برای time
                            initialValue: _timeController.text,
                            autovalidateMode: AutovalidateMode.onUserInteraction,  // پاک شدن خودکار error
                            validator: (time) {
                              if (time == null || time.isEmpty) {
                                return 'لطفاً ساعت درخواستی را انتخاب کنید';  // اجباری
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
                                        field.didChange(_timeController.text);  // trigger validator بعد از select
                                      });
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.arrow_drop_down, color: AppColors.primary),
                                          const Spacer(),
                                          Text(
                                            _timeController.text.isEmpty ? 'ساعت درخواستی' : _timeController.text,
                                            textAlign: TextAlign.right,
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: _timeController.text.isNotEmpty ? AppColors.textPrimary : AppColors.textLight,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  if (field.hasError)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 8, right: 16),
                                      child: Text(
                                        field.errorText!,
                                        style: const TextStyle(color: AppColors.error, fontSize: 12),
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
                                return 'لطفاً مدت رزرو را انتخاب کنید';
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
                                      padding: const EdgeInsets.only(top: 8, right: 16),
                                      child: Text(
                                        field.errorText!,
                                        style: const TextStyle(color: AppColors.error, fontSize: 12),
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
                                fontSize: 14,
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
                            const SizedBox(width: 12),
                            Expanded(
                              child: CustomButton(
                                text: 'ادامه و مرحله بعد',
                                onPressed: _handleContinue,
                                isLoading: _isLoading,
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
          IconButton(
            icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
            onPressed: _handleCancel,
          ),
          Text(
            widget.isNewCustomer ? 'نوبت مشتری جدید' : 'ثبت سفارش',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          GestureDetector(
            onTap: () {},
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: FaIcon(
                  FontAwesomeIcons.user,
                  color: Colors.grey,
                  size: 20,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}