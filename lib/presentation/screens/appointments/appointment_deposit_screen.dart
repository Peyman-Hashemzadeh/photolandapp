import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:persian_datetime_picker/persian_datetime_picker.dart';
import '../../../core/constants/colors.dart';
import '../../../core/utils/price_input_formatter.dart';
import '../../../core/utils/date_helper.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../data/models/appointment_model.dart';
import '../../../data/models/bank_model.dart';
import '../../../data/repositories/appointment_repository.dart';
import '../../../data/repositories/bank_repository.dart';
import '../../../data/models/service_model.dart';
import '../../widgets/custom_button.dart';

class AppointmentDepositScreen extends StatefulWidget {
  final AppointmentModel appointment;

  const AppointmentDepositScreen({
    super.key,
    required this.appointment,
  });

  @override
  State<AppointmentDepositScreen> createState() => _AppointmentDepositScreenState();
}

class PersianPriceInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue,
      TextEditingValue newValue,
      ) {
    // جلوگیری از حذف یکجا
    if (newValue.text.isEmpty) {
      return newValue;
    }

    // حذف جداکننده و تبدیل فارسی → انگلیسی برای پردازش
    String clean = newValue.text
        .replaceAll('٬', '') // کاما فارسی
        .replaceAll(',', '') // کاما انگلیسی
        .replaceAllMapped(RegExp('[۰-۹]'), (Match m) {
      return (m.group(0)!.codeUnitAt(0) - 1776).toString();
    });

    // اگر خالی شد
    if (clean.isEmpty) clean = "0";

    // تبدیل به int
    final number = int.tryParse(clean) ?? 0;

    // جداکننده سه‌رقمی انگلیسی
    String formatted = _formatWithComma(number.toString());

    // تبدیل اعداد انگلیسی به فارسی
    formatted = DateHelper.toPersianDigits(formatted);

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  /// ۳ رقم ۳ رقم جدا می‌کند
  String _formatWithComma(String value) {
    final buffer = StringBuffer();
    int digits = 0;

    for (int i = value.length - 1; i >= 0; i--) {
      buffer.write(value[i]);
      digits++;
      if (digits == 3 && i != 0) {
        buffer.write(',');
        digits = 0;
      }
    }

    return buffer.toString().split('').reversed.join('');
  }
}

class _AppointmentDepositScreenState extends State<AppointmentDepositScreen> {
  final _formKey = GlobalKey<FormState>();
  final AppointmentRepository _appointmentRepository = AppointmentRepository();
  final BankRepository _bankRepository = BankRepository();

  final _depositAmountController = TextEditingController();

  Jalali? _selectedDepositDate;
  BankModel? _selectedBank;
  List<BankModel> _banks = [];
  bool _isLoading = false;
  bool _isLoadingBanks = true;
  bool _isCashPayment = false; // 🔥 چک‌باکس دریافت نقدی

  @override
  void initState() {
    super.initState();
    _loadBanks();
    _loadExistingDeposit(); // 🔥 بارگذاری بیعانه موجود (اگر ویرایشه)
  }

  @override
  void dispose() {
    _depositAmountController.dispose();
    super.dispose();
  }

  void _loadBanks() {
    _bankRepository.getActiveBanks().listen((banks) {
      if (mounted) {
        setState(() {
          _banks = banks;
          _isLoadingBanks = false;
        });
      }
    });
  }

  // 🔥 بارگذاری بیعانه موجود (برای حالت ویرایش)
  void _loadExistingDeposit() {
    if (widget.appointment.depositAmount != null) {
      _depositAmountController.text = ServiceModel.formatNumber(widget.appointment.depositAmount!);
    }

    if (widget.appointment.depositReceivedDate != null) {
      _selectedDepositDate = Jalali.fromDateTime(widget.appointment.depositReceivedDate!);
    }

    if (widget.appointment.bankName == 'نقدی') {
      _isCashPayment = true;
    } else if (widget.appointment.bankId != null && _banks.isNotEmpty) {
      _selectedBank = _banks.firstWhere(
            (b) => b.id == widget.appointment.bankId,
        orElse: () => _banks.first,
      );
    }
  }

  Future<void> _selectDepositDate() async {
    final picked = await showPersianDatePicker(
      context: context,
      initialDate: _selectedDepositDate ?? Jalali.now(),
      firstDate: Jalali.now().addDays(-365),
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
              textTheme: Theme.of(context).textTheme.apply(
                fontFamily: 'Vazir',
              ),
            ),
            child: child!,
          ),
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedDepositDate = picked;
      });
    }
  }

  bool _hasAnyDepositField() {
    return _depositAmountController.text.isNotEmpty ||
        _selectedDepositDate != null ||
        _selectedBank != null ||
        _isCashPayment;
  }

  String? _validateDepositFields(String? value) {
    if (!_hasAnyDepositField()) {
      return null; // همه اختیاری هستند
    }

    // اگر یکی پر شده، همه باید پر باشند
    if (_depositAmountController.text.isEmpty) {
      return 'مبلغ بیعانه اجباری است';
    }
    if (_selectedDepositDate == null) {
      return 'تاریخ دریافت اجباری است';
    }

    // 🔥 اگر نقدی نیست، بانک اجباریه
    if (!_isCashPayment && _selectedBank == null) {
      return 'انتخاب بانک اجباری است';
    }

    return null;
  }

  Future<void> _handleSave() async {
    final depositError = _validateDepositFields(null);

    if (depositError != null) {
      SnackBarHelper.showError(context, depositError);
      return;
    }

    setState(() => _isLoading = true);

    try {
      // ساخت نوبت نهایی
      final finalAppointment = widget.appointment.copyWith(
        depositAmount: _depositAmountController.text.isEmpty
            ? null
            : ServiceModel.parsePrice(_depositAmountController.text),
        depositReceivedDate: _selectedDepositDate?.toDateTime(),
        // 🔥 اگر نقدی باشه، بانک null میشه
        bankId: _isCashPayment ? null : _selectedBank?.id,
        bankName: _isCashPayment ? 'نقدی' : _selectedBank?.bankName,
        createdAt: widget.appointment.createdAt,
      );

      // 🔥 اصلاح شده: بررسی ویرایش یا ایجاد جدید
      if (widget.appointment.id.isNotEmpty) {
        // حالت ویرایش - آپدیت کن
        await _appointmentRepository.updateAppointment(finalAppointment);

        if (!mounted) return;
        SnackBarHelper.showSuccess(context, 'نوبت با موفقیت ویرایش شد');
      } else {
        // حالت جدید - اضافه کن
        await _appointmentRepository.addAppointment(finalAppointment);

        if (!mounted) return;
        SnackBarHelper.showSuccess(context, 'نوبت با موفقیت ثبت شد');
      }

      // برگشت به صفحه اول
      Navigator.of(context).popUntil((route) => route.isFirst);
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

  @override
  Widget build(BuildContext context) {
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
                child: _isLoadingBanks
                    ? const Center(child: CircularProgressIndicator())
                    : SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        // مبلغ بیعانه
                        TextFormField(
                          controller: _depositAmountController,
                          textAlign: TextAlign.right,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            PersianPriceInputFormatter(), // 👈 فرمت جدید
                          ],
                          decoration: InputDecoration(
                            hintText: 'مبلغ بیعانه',

                            // نمایش "ریال" سمت چپ فیلد
                            suffixText: 'ریال',
                            suffixStyle: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 14,
                            ),

                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // تاریخ دریافت
                        InkWell(
                          onTap: _selectDepositDate,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 16,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Text(
                                  _selectedDepositDate != null
                                      ? DateHelper.toPersianDigits(
                                    _selectedDepositDate!.formatCompactDate(),
                                  )
                                      : 'تاریخ دریافت',
                                  textAlign: TextAlign.right,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: _selectedDepositDate != null
                                        ? AppColors.textPrimary
                                        : AppColors.textLight,
                                  ),
                                ),
                                const Spacer(),
                                const Icon(
                                  Icons.calendar_today,
                                  color: AppColors.primary,
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // انتخاب بانک (غیرفعال اگر نقدی باشه)
                        Opacity(
                          opacity: _isCashPayment ? 0.5 : 1.0,
                          child: IgnorePointer(
                            ignoring: _isCashPayment,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: DropdownButtonHideUnderline(
                                      child: DropdownButton<BankModel>(
                                        value: _selectedBank,
                                        isExpanded: true,
                                        icon: const SizedBox.shrink(),
                                        alignment: Alignment.centerRight,
                                        hint: const Align(
                                          alignment: Alignment.centerRight,
                                          child: Text(
                                            'انتخاب بانک',
                                            textAlign: TextAlign.right,
                                            style: TextStyle(
                                              color: AppColors.textLight,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ),
                                        items: _banks.map((bank) {
                                          return DropdownMenuItem<BankModel>(
                                            value: bank,
                                            alignment: Alignment.centerRight,
                                            child: Text(
                                              '${bank.bankName}${bank.accountNumber != null ? ' - ${bank.accountNumber}' : ''}',
                                              textAlign: TextAlign.right,
                                              style: const TextStyle(fontSize: 14),
                                            ),
                                          );
                                        }).toList(),
                                        onChanged: (bank) {
                                          setState(() {
                                            _selectedBank = bank;
                                          });
                                        },
                                      ),
                                    ),
                                  ),
                                  const Icon(Icons.arrow_drop_down, color: AppColors.primary),
                                ],
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // 🔥 چک‌باکس دریافت نقدی
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 1, vertical: 12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.start,
                            children: [
                              Checkbox(
                                value: _isCashPayment,
                                activeColor: AppColors.primary,
                                onChanged: (value) {
                                  setState(() {
                                    _isCashPayment = value ?? false;
                                    if (_isCashPayment) {
                                      _selectedBank = null; // پاک کردن بانک انتخابی
                                    }
                                  });
                                },
                              ),
                              const Text(
                                'بیعانه را به صورت نقدی دریافت کردم.',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 32),

                        // دکمه ذخیره
                        CustomButton(
                          text: widget.appointment.id.isNotEmpty ? 'ویرایش نوبت' : 'ذخیره نوبت',
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
          GestureDetector(
            onTap: () {},
            child: Container(
              width: 44,
              height: 44,
            ),
          ),
          const Text(
            'دریافت بیعانه',
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
}