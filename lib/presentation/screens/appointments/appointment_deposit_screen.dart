import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:persian_datetime_picker/persian_datetime_picker.dart';
import '../../../core/constants/colors.dart';
import '../../../core/utils/price_input_formatter.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../data/models/appointment_model.dart';
import '../../../data/models/bank_model.dart';
import '../../../data/models/service_model.dart';
import '../../../data/repositories/appointment_repository.dart';
import '../../../data/repositories/bank_repository.dart';
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
        _selectedBank != null;
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
    if (_selectedBank == null) {
      return 'انتخاب بانک اجباری است';
    }
    return null;
  }

  Future<void> _handleSave() async {
    // بررسی اعتبار فیلدها
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
        bankId: _selectedBank?.id,
        bankName: _selectedBank?.bankName,
        createdAt: widget.appointment.createdAt,
      );

      // ذخیره نوبت
      await _appointmentRepository.addAppointment(finalAppointment);

      if (!mounted) return;

      SnackBarHelper.showSuccess(context, 'نوبت با موفقیت ثبت شد');

      // بازگشت به صفحه اصلی
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

                        // انتخاب بانک
                        Container(
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

                                    // 🔹 این خط باعث می‌شود آیکون سمت راست حذف شود
                                    icon: const SizedBox.shrink(),

                                    // 🔹 این خط باعث می‌شود منو راست‌چین شود
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