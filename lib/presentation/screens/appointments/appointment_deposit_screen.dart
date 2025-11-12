import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:persian_datetime_picker/persian_datetime_picker.dart';
import '../../../core/constants/colors.dart';
import '../../../core/utils/price_input_formatter.dart';
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

      await _appointmentRepository.addAppointment(finalAppointment);

      if (!mounted) return;

      SnackBarHelper.showSuccess(context, 'نوبت با موفقیت ثبت شد');
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
                            PriceInputFormatter(),
                          ],
                          decoration: InputDecoration(
                            hintText: 'مبلغ بیعانه',
                            hintStyle: const TextStyle(
                              color: AppColors.textLight,
                              fontSize: 14,
                            ),
                            prefixText: 'ریال',
                            prefixStyle: const TextStyle(
                              color: AppColors.textSecondary,
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
                                const Icon(
                                  Icons.arrow_drop_down,
                                  color: AppColors.primary,
                                ),
                                const Spacer(),
                                Text(
                                  _selectedDepositDate != null
                                      ? _selectedDepositDate!.formatCompactDate()
                                      : 'تاریخ واریز',
                                  textAlign: TextAlign.right,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: _selectedDepositDate != null
                                        ? AppColors.textPrimary
                                        : AppColors.textLight,
                                  ),
                                ),
                                const SizedBox(width: 12),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // 🔥 چک‌باکس دریافت نقدی
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              const Text(
                                'دریافت نقدی بیعانه',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: AppColors.textPrimary,
                                ),
                              ),
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
                            ],
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
                                  const Icon(Icons.arrow_drop_down, color: AppColors.primary),
                                  const SizedBox(width: 8),
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
                                ],
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 32),

                        // دکمه ذخیره
                        CustomButton(
                          text: 'ذخیره نوبت',
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
          IconButton(
            icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
            onPressed: () => Navigator.pop(context),
          ),
          const Text(
            'دریافت بیعانه',
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
