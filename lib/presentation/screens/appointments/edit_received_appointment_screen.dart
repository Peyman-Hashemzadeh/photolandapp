import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:persian_datetime_picker/persian_datetime_picker.dart';
import 'package:shamsi_date/shamsi_date.dart';
import '../../../core/utils/date_helper.dart';
import '../../../core/constants/colors.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../data/models/customer_model.dart';
import '../../../data/models/appointment_model.dart';
import '../../../data/repositories/appointment_repository.dart';
import '../../widgets/custom_textfield.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/duration_dropdown.dart';

class EditReceivedAppointmentScreen extends StatefulWidget {
  final AppointmentModel appointment;
  final CustomerModel? existingCustomer;

  const EditReceivedAppointmentScreen({
    super.key,
    required this.appointment,
    required this.existingCustomer,
  });

  @override
  State<EditReceivedAppointmentScreen> createState() =>
      _EditReceivedAppointmentScreenState();
}

class _EditReceivedAppointmentScreenState
    extends State<EditReceivedAppointmentScreen> {
  final _formKey = GlobalKey<FormState>();
  final AppointmentRepository _appointmentRepository = AppointmentRepository();

  // Controllers
  final _childAgeController = TextEditingController();
  final _photographyModelController = TextEditingController();
  final _notesController = TextEditingController();
  final _timeController = TextEditingController();

  // State variables
  Jalali? _selectedDate;
  int? _selectedDuration;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadAppointmentData();
  }

  @override
  void dispose() {
    _childAgeController.dispose();
    _photographyModelController.dispose();
    _notesController.dispose();
    _timeController.dispose();
    super.dispose();
  }

  void _loadAppointmentData() {
    final apt = widget.appointment;
    _childAgeController.text = apt.childAge ?? '';
    _photographyModelController.text = apt.photographyModel ?? '';
    _notesController.text = apt.notes ?? '';
    _timeController.text = apt.requestedTime;
    _selectedDate = Jalali.fromDateTime(apt.requestedDate);
    _selectedDuration = apt.durationMinutes;
  }

  Future<void> _selectDate() async {
    final picked = await showPersianDatePicker(
      context: context,
      initialDate: _selectedDate ?? Jalali.now(),
      firstDate: Jalali.now(),
      lastDate: Jalali.now().addYears(3),
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
              textTheme: Theme.of(context).textTheme.copyWith(
                bodySmall: const TextStyle(
                  fontFamily: 'Vazirmatn',
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
                labelSmall: const TextStyle(
                  fontFamily: 'Vazirmatn',
                  fontSize: 12,
                ),
                bodyMedium: const TextStyle(fontFamily: 'Vazirmatn'),
              ),
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

  Future<void> _handleSave() async {
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
      // چک تداخل
      final overlapping = await _appointmentRepository.checkOverlap(
        date: _selectedDate!.toDateTime(),
        startTime: _timeController.text,
        durationMinutes: _selectedDuration!,
        excludeId: widget.appointment.id,
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

      // اگه مشتری در سیستم هست، customerId رو آپدیت کن
      final String customerId;
      final String customerName;

      if (widget.existingCustomer != null) {
        customerId = widget.existingCustomer!.id;
        customerName = widget.existingCustomer!.fullName;
      } else {
        customerId = '';
        customerName = widget.appointment.customerName;
      }

      // ساخت نوبت آپدیت شده
      final updatedAppointment = widget.appointment.copyWith(
        customerId: customerId,
        customerName: customerName,
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
        updatedAt: DateTime.now(),
      );

      await _appointmentRepository.updateAppointment(updatedAppointment);

      setState(() => _isLoading = false);

      if (!mounted) return;

      SnackBarHelper.showSuccess(context, 'نوبت با موفقیت ویرایش شد');
      Navigator.pop(context, true);
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
              const Text('آیا اطمینان به ذخیره نوبت دارید؟'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text(
                'بله، ذخیره کن',
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
          title: const Text('انصراف از ویرایش'),
          content: const Text('آیا از انصراف ویرایش نوبت اطمینان دارید؟'),
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

  BoxShadow _getFieldShadow() {
    return BoxShadow(
      color: Colors.black.withOpacity(0.05),
      blurRadius: 8,
      offset: const Offset(0, 2),
    );
  }

  @override
  Widget build(BuildContext context) {
    // تعیین نام مشتری برای نمایش
    final String customerLabel = widget.existingCustomer != null
        ? widget.existingCustomer!.fullName
        : 'مشتری جدید';

    final Color customerLabelColor = widget.existingCustomer != null
        ? (widget.existingCustomer!.isActive
        ? AppColors.textPrimary
        : AppColors.error)
        : AppColors.success;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: const AssetImage('assets/images/background.png'),
            fit: BoxFit.cover,
            opacity: 0.1,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        // 🔥 فیلد نام مشتری (Label)
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: customerLabelColor.withOpacity(0.3),
                              width: 2,
                            ),
                            boxShadow: [_getFieldShadow()],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'نام مشتری:',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              Text(
                                customerLabel,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: customerLabelColor,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),

                        // 🔥 نام و نام خانوادگی ثبت شده توسط مشتری
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade300),
                            boxShadow: [_getFieldShadow()],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'نام ثبت شده:',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              Text(
                                widget.appointment.customerName,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),

                        // 🔥 شماره همراه ثبت شده توسط مشتری
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade300),
                            boxShadow: [_getFieldShadow()],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'شماره همراه:',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              Text(
                                widget.appointment.customerMobile,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.textPrimary,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),

                        // سن کودک
                        Container(
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
                          child: FormField<Jalali?>(
                            initialValue: _selectedDate,
                            autovalidateMode: AutovalidateMode.onUserInteraction,
                            validator: (date) {
                              if (date == null) {
                                return 'لطفاً تاریخ درخواستی را انتخاب کنید';
                              }
                              return null;
                            },
                            builder: (field) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  InkWell(
                                    onTap: () {
                                      _selectDate().then((_) {
                                        field.didChange(_selectedDate);
                                      });
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 16),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.arrow_drop_down,
                                              color: AppColors.primary),
                                          const Spacer(),
                                          Text(
                                            DateHelper.formatPersianDate(
                                                _selectedDate),
                                            textAlign: TextAlign.right,
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: _selectedDate != null
                                                  ? AppColors.textPrimary
                                                  : AppColors.textLight,
                                              fontFamily: 'Vazirmatn',
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  if (field.hasError)
                                    Padding(
                                      padding: const EdgeInsets.only(
                                          top: 8, right: 16),
                                      child: Text(
                                        field.errorText!,
                                        style: const TextStyle(
                                            color: AppColors.error, fontSize: 12),
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
                                return 'لطفاً ساعت درخواستی را انتخاب کنید';
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
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 16),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.arrow_drop_down,
                                              color: AppColors.primary),
                                          const Spacer(),
                                          Text(
                                            _timeController.text.isEmpty
                                                ? 'ساعت درخواستی'
                                                : _timeController.text,
                                            textAlign: TextAlign.right,
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: _timeController
                                                  .text.isNotEmpty
                                                  ? AppColors.textPrimary
                                                  : AppColors.textLight,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  if (field.hasError)
                                    Padding(
                                      padding: const EdgeInsets.only(
                                          top: 8, right: 16),
                                      child: Text(
                                        field.errorText!,
                                        style: const TextStyle(
                                            color: AppColors.error, fontSize: 12),
                                      ),
                                    ),
                                ],
                              );
                            },
                          ),
                        ),

                        const SizedBox(height: 16),

                        // 🔥 مدت رزرو (اجباری)
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [_getFieldShadow()],
                          ),
                          child: FormField<int?>(
                            initialValue: _selectedDuration,
                            autovalidateMode: AutovalidateMode.onUserInteraction,
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
                                  DurationDropdown(
                                    selectedDuration: field.value,
                                    onChanged: (duration) {
                                      field.didChange(duration);
                                      setState(() {
                                        _selectedDuration = duration;
                                      });
                                    },
                                  ),
                                  if (field.hasError)
                                    Padding(
                                      padding: const EdgeInsets.only(
                                          top: 8, right: 16),
                                      child: Text(
                                        field.errorText!,
                                        style: const TextStyle(
                                            color: AppColors.error, fontSize: 12),
                                      ),
                                    ),
                                ],
                              );
                            },
                          ),
                        ),

                        const SizedBox(height: 16),

                        // مدل عکاسی
                        Container(
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
                        Container(
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
                                  padding:
                                  const EdgeInsets.symmetric(vertical: 14),
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
                                text: 'ذخیره تغییرات',
                                onPressed: _handleSave,
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
          const Text(
            'ویرایش نوبت دریافتی',
            style: TextStyle(
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