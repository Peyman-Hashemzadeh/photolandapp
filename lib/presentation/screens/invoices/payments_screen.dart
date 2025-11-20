import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:persian_datetime_picker/persian_datetime_picker.dart';
import 'package:shamsi_date/shamsi_date.dart';
import '../../../core/constants/colors.dart';
import '../../../core/utils/date_helper.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../core/utils/price_input_formatter.dart';
import '../../../data/models/appointment_model.dart';
import '../../../data/models/invoice_model.dart';
import '../../../data/models/payment_model.dart';
import '../../../data/models/bank_model.dart';
import '../../../data/models/service_model.dart';
import '../../../data/repositories/payment_repository.dart';
import '../../../data/repositories/bank_repository.dart';
import '../../../data/repositories/invoice_repository.dart';
import '../../widgets/custom_button.dart';

class PaymentsScreen extends StatefulWidget {
  final AppointmentModel appointment;
  final InvoiceModel invoice;

  const PaymentsScreen({
    super.key,
    required this.appointment,
    required this.invoice,
  });

  @override
  State<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends State<PaymentsScreen> {
  final PaymentRepository _paymentRepository = PaymentRepository();
  final BankRepository _bankRepository = BankRepository();
  final InvoiceRepository _invoiceRepository = InvoiceRepository();

  List<PaymentModel> _payments = [];
  List<BankModel> _banks = [];
  bool _isLoading = true;
  int _totalAmount = 0;
  int _paidAmount = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      // بارگذاری بانک‌ها
      _bankRepository.getActiveBanks().listen((banks) {
        if (mounted) {
          setState(() => _banks = banks);
        }
      });

      // بارگذاری دریافتی‌ها (شامل بیعانه نوبت)
      _paymentRepository.getPaymentsByAppointment(widget.appointment.id).listen((payments) {
        if (mounted) {
          setState(() {
            _payments = payments;
            _paidAmount = payments.fold(0, (sum, payment) => sum + payment.amount);
          });
        }
      });

      // بارگذاری مجموع فاکتور
      final total = await _invoiceRepository.calculateInvoiceTotal(widget.invoice.id);

      setState(() {
        _totalAmount = total;
        _isLoading = false;
      });

      // اضافه کردن بیعانه به دریافتی‌ها (اگر در نوبت ثبت شده باشد)
      if (widget.appointment.hasDeposit) {
        final hasDepositRecord = await _paymentRepository.hasDeposit(widget.appointment.id);

        if (!hasDepositRecord) {
          // ایجاد رکورد بیعانه از اطلاعات نوبت
          final depositPayment = PaymentModel(
            id: '',
            appointmentId: widget.appointment.id,
            amount: widget.appointment.depositAmount!,
            type: 'deposit',
            paymentDate: widget.appointment.depositReceivedDate!,
            bankId: widget.appointment.bankId,
            bankName: widget.appointment.bankName,
            isCash: widget.appointment.bankName == 'نقدی',
            createdAt: DateTime.now(),
          );

          await _paymentRepository.addPayment(depositPayment);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        SnackBarHelper.showError(context, e.toString().replaceAll('Exception: ', ''));
      }
    }
  }

  int get _remainingAmount => _totalAmount - _paidAmount;

  Future<void> _showAddPaymentDialog({PaymentModel? payment}) async {
    final hasDeposit = await _paymentRepository.hasDeposit(widget.appointment.id);

    if (!mounted) return;

    final result = await showDialog<PaymentModel>(
      context: context,
      builder: (context) => _AddPaymentDialog(
        appointment: widget.appointment,
        banks: _banks,
        payment: payment,
        hasDeposit: hasDeposit,
      ),
    );

    if (result != null) {
      try {
        if (payment == null) {
          await _paymentRepository.addPayment(result);
          if (mounted) {
            SnackBarHelper.showSuccess(context, 'دریافتی با موفقیت ثبت شد');
          }
        } else {
          await _paymentRepository.updatePayment(result);
          if (mounted) {
            SnackBarHelper.showSuccess(context, 'دریافتی با موفقیت ویرایش شد');
          }
        }
      } catch (e) {
        if (mounted) {
          SnackBarHelper.showError(context, e.toString().replaceAll('Exception: ', ''));
        }
      }
    }
  }

  Future<void> _deletePayment(PaymentModel payment) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('حذف دریافتی'),
          content: const Text('آیا از حذف این دریافتی اطمینان دارید؟'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('بله', style: TextStyle(color: AppColors.error)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('خیر'),
            ),
          ],
        ),
      ),
    );

    if (confirm == true) {
      try {
        await _paymentRepository.deletePayment(payment.id);
        if (mounted) {
          SnackBarHelper.showSuccess(context, 'دریافتی با موفقیت حذف شد');
        }
      } catch (e) {
        if (mounted) {
          SnackBarHelper.showError(context, e.toString().replaceAll('Exception: ', ''));
        }
      }
    }
  }

  void _completeAndGoToCalendar() {
    Navigator.of(context).popUntil((route) => route.isFirst);
    SnackBarHelper.showSuccess(context, 'عملیات با موفقیت تکمیل شد');
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
              if (_isLoading)
                const Expanded(child: Center(child: CircularProgressIndicator()))
              else ...[
                _buildAppointmentInfo(),
                Expanded(child: _buildPaymentsList()),
                _buildBottomButton(),
              ],
            ],
          ),
        ),
      ),
      floatingActionButton: _isLoading
          ? null
          : FloatingActionButton(
        onPressed: () => _showAddPaymentDialog(),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
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
            'دریافتی ها',
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
                child: FaIcon(FontAwesomeIcons.user, color: Colors.grey, size: 20),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppointmentInfo() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            widget.appointment.customerName,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                widget.appointment.timeRange,
                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              Text(
                DateHelper.dateTimeToShamsi(widget.appointment.requestedDate),
                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
            ],
          ),
          const Divider(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'مانده: ${ServiceModel.formatNumber(_remainingAmount)}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: _remainingAmount > 0 ? AppColors.error : AppColors.success,
                ),
              ),
              Text(
                'مبلغ کل: ${ServiceModel.formatNumber(_totalAmount)}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentsList() {
    if (_payments.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.account_balance_wallet, size: 80, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              'دریافتی ثبت نشده است',
              style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _payments.length,
      itemBuilder: (context, index) {
        final payment = _payments[index];
        return _PaymentCard(
          payment: payment,
          onEdit: () => _showAddPaymentDialog(payment: payment),
          onDelete: () => _deletePayment(payment),
        );
      },
    );
  }

  Widget _buildBottomButton() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // دکمه افزودن (بالای دکمه اصلی)
          Align(
            alignment: Alignment.centerLeft,
            child: FloatingActionButton(
              onPressed: () => _showAddPaymentDialog(),
              backgroundColor: AppColors.primary,
              mini: false,
              child: const Icon(Icons.add, color: Colors.white),
            ),
          ),
          const SizedBox(height: 16),
          // دکمه اصلی
          CustomButton(
            text: 'تکمیل و نمایش لیست تقویم',
            onPressed: _completeAndGoToCalendar,
            useGradient: true,
          ),
        ],
      ),
    );
  }
}

// کارت دریافتی
class _PaymentCard extends StatefulWidget {
  final PaymentModel payment;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _PaymentCard({
    required this.payment,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<_PaymentCard> createState() => _PaymentCardState();
}

class _PaymentCardState extends State<_PaymentCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => setState(() => _isExpanded = !_isExpanded),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // ردیف اول: نوع و مبلغ
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    ServiceModel.formatNumber(widget.payment.amount),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: widget.payment.type == 'deposit'
                          ? AppColors.info.withOpacity(0.1)
                          : AppColors.success.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      widget.payment.typeLabel,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: widget.payment.type == 'deposit'
                            ? AppColors.info
                            : AppColors.success,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // ردیف دوم: تاریخ و بانک
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      widget.payment.bankDisplay,
                      style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                    ),
                    Text(
                      DateHelper.dateTimeToShamsi(widget.payment.paymentDate),
                      style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              // دکمه‌های عملیاتی
              AnimatedSize(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
                alignment: Alignment.centerRight,
                child: _isExpanded
                    ? Column(
                  children: [
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton.icon(
                          onPressed: widget.onEdit,
                          icon: const Icon(Icons.edit, size: 16),
                          label: const Text('ویرایش'),
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                        ),
                        const SizedBox(width: 8),
                        TextButton.icon(
                          onPressed: widget.onDelete,
                          icon: const Icon(Icons.delete, size: 16),
                          label: const Text('حذف'),
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.error,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                        ),
                      ],
                    ),
                  ],
                )
                    : const SizedBox(height: 0),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// دیالوگ افزودن/ویرایش دریافتی
class _AddPaymentDialog extends StatefulWidget {
  final AppointmentModel appointment;
  final List<BankModel> banks;
  final PaymentModel? payment;
  final bool hasDeposit;

  const _AddPaymentDialog({
    required this.appointment,
    required this.banks,
    this.payment,
    required this.hasDeposit,
  });

  @override
  State<_AddPaymentDialog> createState() => _AddPaymentDialogState();
}

class _AddPaymentDialogState extends State<_AddPaymentDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();

  Jalali? _selectedDate;
  String _selectedType = 'settlement';
  BankModel? _selectedBank;
  bool _isCashPayment = false;

  @override
  void initState() {
    super.initState();
    if (widget.payment != null) {
      _amountController.text = ServiceModel.formatNumber(widget.payment!.amount);
      _selectedDate = Jalali.fromDateTime(widget.payment!.paymentDate);
      _selectedType = widget.payment!.type;
      _isCashPayment = widget.payment!.isCash;

      if (!_isCashPayment && widget.payment!.bankId != null) {
        _selectedBank = widget.banks.firstWhere(
              (b) => b.id == widget.payment!.bankId,
          orElse: () => widget.banks.first,
        );
      }
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final picked = await showPersianDatePicker(
      context: context,
      initialDate: _selectedDate ?? Jalali.now(),
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
              textTheme: Theme.of(context).textTheme.apply(fontFamily: 'Vazir'),
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
      SnackBarHelper.showError(context, 'لطفاً تاریخ دریافت را انتخاب کنید');
      return;
    }

    if (!_isCashPayment && _selectedBank == null) {
      SnackBarHelper.showError(context, 'لطفاً بانک را انتخاب کنید');
      return;
    }

    final payment = PaymentModel(
      id: widget.payment?.id ?? '',
      appointmentId: widget.appointment.id,
      amount: ServiceModel.parsePrice(_amountController.text) ?? 0,
      type: _selectedType,
      paymentDate: _selectedDate!.toDateTime(),
      bankId: _isCashPayment ? null : _selectedBank?.id,
      bankName: _isCashPayment ? 'نقدی' : _selectedBank?.bankName,
      accountNumber: _isCashPayment ? null : _selectedBank?.accountNumber,
      isCash: _isCashPayment,
      createdAt: widget.payment?.createdAt ?? DateTime.now(),
    );

    Navigator.pop(context, payment);
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
                Text(
                  widget.payment == null ? 'افزودن دریافتی' : 'ویرایش دریافتی',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 24),
                // مبلغ
                TextFormField(
                  controller: _amountController,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.right,
                  inputFormatters: [PriceInputFormatter()],
                  decoration: InputDecoration(
                    hintText: 'مبلغ دریافتی',
                    prefixText: 'ریال',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'مبلغ اجباری است';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                // نوع دریافت
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedType,
                      isExpanded: true,
                      icon: const Icon(Icons.arrow_drop_down, color: AppColors.primary),
                      items: [
                        DropdownMenuItem(
                          value: 'deposit',
                          enabled: !widget.hasDeposit || widget.payment?.type == 'deposit',
                          child: Text(
                            'بیعانه',
                            style: TextStyle(
                              color: !widget.hasDeposit || widget.payment?.type == 'deposit'
                                  ? AppColors.textPrimary
                                  : AppColors.textLight,
                            ),
                          ),
                        ),
                        const DropdownMenuItem(
                          value: 'settlement',
                          child: Text('تسویه'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _selectedType = value);
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // تاریخ دریافت
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
                              ? _selectedDate!.formatCompactDate()
                              : 'تاریخ دریافت',
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
                const SizedBox(height: 16),
                // چک‌باکس نقدی
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      const Text('دریافت نقدی', style: TextStyle(fontSize: 14)),
                      Checkbox(
                        value: _isCashPayment,
                        activeColor: AppColors.primary,
                        onChanged: (value) {
                          setState(() {
                            _isCashPayment = value ?? false;
                            if (_isCashPayment) _selectedBank = null;
                          });
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // بانک
                Opacity(
                  opacity: _isCashPayment ? 0.5 : 1.0,
                  child: IgnorePointer(
                    ignoring: _isCashPayment,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<BankModel>(
                          value: _selectedBank,
                          isExpanded: true,
                          icon: const Icon(Icons.arrow_drop_down, color: AppColors.primary),
                          hint: const Text('انتخاب بانک', textAlign: TextAlign.right),
                          items: widget.banks.map((bank) {
                            return DropdownMenuItem(
                              value: bank,
                              alignment: Alignment.centerRight,
                              child: Text(
                                '${bank.bankName}${bank.accountNumber != null ? ' (${bank.accountNumber})' : ''}',
                                textAlign: TextAlign.right,
                              ),
                            );
                          }).toList(),
                          onChanged: (bank) => setState(() => _selectedBank = bank),
                        ),
                      ),
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
                        text: widget.payment == null ? 'ثبت' : 'ویرایش',
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