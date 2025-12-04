import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:persian_datetime_picker/persian_datetime_picker.dart';
import 'package:shamsi_date/shamsi_date.dart';
import '../../../core/constants/colors.dart';
import '../../../core/utils/date_helper.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../core/utils/price_input_formatter.dart';
import '../../../data/models/customer_model.dart';
import '../../../data/models/invoice_model.dart';
import '../../../data/models/payment_model.dart';
import '../../../data/models/bank_model.dart';
import '../../../data/models/service_model.dart';
import '../../../data/repositories/payment_repository.dart';
import '../../../data/repositories/bank_repository.dart';
import '../../../data/repositories/invoice_repository.dart';
import '../../widgets/custom_button.dart';
import 'package:flutter/services.dart';

class PersianPriceInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue,
      TextEditingValue newValue,
      ) {
    if (newValue.text.isEmpty) {
      return newValue;
    }

    String clean = newValue.text
        .replaceAll('٬', '')
        .replaceAll(',', '')
        .replaceAllMapped(RegExp('[۰-۹]'), (Match m) {
      return (m.group(0)!.codeUnitAt(0) - 1776).toString();
    });

    if (clean.isEmpty) clean = "0";

    final number = int.tryParse(clean) ?? 0;
    String formatted = _formatWithComma(number.toString());
    formatted = DateHelper.toPersianDigits(formatted);

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

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

class InvoicePaymentsScreen extends StatefulWidget {
  final InvoiceModel invoice;
  final CustomerModel customer;

  const InvoicePaymentsScreen({
    super.key,
    required this.invoice,
    required this.customer,
  });

  @override
  State<InvoicePaymentsScreen> createState() => _InvoicePaymentsScreenState();
}

class _InvoicePaymentsScreenState extends State<InvoicePaymentsScreen> {
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

      // بارگذاری دریافتی‌ها (بدون بیعانه نوبت - فقط دریافتی‌های فاکتور)
      _paymentRepository.getPaymentsByAppointment(widget.invoice.id).listen((payments) {
        if (mounted) {
          setState(() {
            _payments = payments;
            _paidAmount = payments.fold(0, (sum, payment) => sum + payment.amount);
          });
        }
      });

      // بارگذاری مجموع فاکتور
      final total = await _invoiceRepository.calculateGrandTotal(widget.invoice.id);

      setState(() {
        _totalAmount = total;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        SnackBarHelper.showError(context, e.toString().replaceAll('Exception: ', ''));
      }
    }
  }

  int get _remainingAmount => _totalAmount - _paidAmount;

  Future<void> _showAddPaymentDialog({PaymentModel? payment}) async {
    final result = await showDialog<PaymentModel>(
      context: context,
      builder: (context) => _AddPaymentDialog(
        invoiceId: widget.invoice.id,
        banks: _banks,
        payment: payment,
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
                _buildInvoiceInfo(),
                Expanded(child: _buildPaymentsList()),
                _buildBottomButton(),
              ],
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
              //  child: FaIcon(FontAwesomeIcons.user, color: Colors.grey, size: 20),
              //),
            ),
          ),
          const Text(
            'دریافت وجه',
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

  Widget _buildInvoiceInfo() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // نام مشتری (سمت راست)
              Expanded(
                child: Text(
                  widget.customer.fullName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                  textAlign: TextAlign.right,
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              const SizedBox(width: 16),

              // شماره همراه (سمت چپ)
              Expanded(
                child: Text(
                  DateHelper.toPersianDigits(widget.customer.mobileNumber),
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.left,
                  textDirection: TextDirection.ltr,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // تاریخ با آیکون تقویم (سمت چپ)
              Row(
                children: [
                  const Icon(
                    Icons.calendar_today,
                    size: 16,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    DateHelper.formatPersianDate(Jalali.fromDateTime(widget.invoice.invoiceDate)),
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),

              // شماره سند با آیکون (سمت راست)
              Row(
                children: [
                  const Icon(
                    Icons.receipt_long,
                    size: 16,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    DateHelper.toPersianDigits(widget.invoice.invoiceNumber.toString()),
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 16),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'جمع کل: ${DateHelper.toPersianDigits(ServiceModel.formatNumber(_totalAmount))}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                'مانده: ${DateHelper.toPersianDigits(ServiceModel.formatNumber(_remainingAmount))}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: _remainingAmount > 0 ? AppColors.success : AppColors.error,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
        ],
      ),
    );
  }

  Widget _buildPaymentsList() {
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _payments.isEmpty ? 1 : _payments.length + 1, // 🔥 +1 برای دکمه
      itemBuilder: (context, index) {
        // 🔥 اگر لیست خالی بود
        if (_payments.isEmpty && index == 0) {
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 60),
              Icon(Icons.account_balance_wallet, size: 80, color: Colors.grey.shade300),
              const SizedBox(height: 16),
              Text(
                'دریافتی ثبت نشده است',
                style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 8),
              Text(
                'برای افزودن دریافتی، دکمه زیر را بزنید',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
              ),
              const SizedBox(height: 24),
              // 🔥 دکمه افزودن دریافتی
              _buildAddButton(),
            ],
          );
        }

        // 🔥 اگر آخرین آیتم بود، دکمه افزودن رو نمایش بده
        if (index == _payments.length) {
          return Padding(
            padding: const EdgeInsets.only(top: 16, bottom: 80),
            child: _buildAddButton(),
          );
        }

        // نمایش دریافتی‌های عادی
        final payment = _payments[index];
        return _PaymentCard(
          payment: payment,
          onEdit: () => _showAddPaymentDialog(payment: payment),
          onDelete: () => _deletePayment(payment),
        );
      },
    );
  }

// 🔥 ویجت دکمه افزودن
  Widget _buildAddButton() {
    return Center(
      child: InkWell(
        onTap: () => _showAddPaymentDialog(),
        borderRadius: BorderRadius.circular(50),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add_circle, color: Colors.blue, size: 24),
              SizedBox(width: 4),
              Text(
                'اضافه کردن دریافتی جدید',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomButton() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: ElevatedButton(
        onPressed: () => Navigator.pop(context),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.grey.shade200,
          foregroundColor: AppColors.textSecondary,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          minimumSize: const Size(double.infinity, 48),
        ),
        child: const Text('برگشت به فاکتور'),
      ),
    );
  }
}

// کارت دریافتی (با قابلیت باز/بسته شدن)
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
      onTap: () {
        setState(() {
          _isExpanded = !_isExpanded;
        });
      },
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
                    DateHelper.toPersianDigits(ServiceModel.formatNumber(widget.payment.amount)),
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
                      DateHelper.formatPersianDate(Jalali.fromDateTime(widget.payment.paymentDate)),
                      //DateHelper.dateTimeToShamsi(widget.payment.paymentDate),
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
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        TextButton.icon(
                          onPressed: widget.onDelete,
                          icon: const Icon(Icons.delete, size: 16),
                          label: const Text('حذف'),
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.error,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
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
  final String invoiceId;
  final List<BankModel> banks;
  final PaymentModel? payment;

  const _AddPaymentDialog({
    required this.invoiceId,
    required this.banks,
    this.payment,
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
  bool _hasDeposit = false;

  @override
  void initState() {
    super.initState();

    // 🔥 بررسی وجود بیعانه
    _checkForDeposit();

    if (widget.payment != null) {
      _amountController.text = DateHelper.toPersianDigits(ServiceModel.formatNumber(widget.payment!.amount)); // 🔥 فارسی
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

  // 🔥 متد بررسی وجود بیعانه
  Future<void> _checkForDeposit() async {
    try {
      final paymentRepo = PaymentRepository();
      final hasDeposit = await paymentRepo.hasDeposit(widget.invoiceId);

      if (mounted) {
        setState(() {
          _hasDeposit = hasDeposit;

          // 🔥 اگر بیعانه وجود داشت و در حال افزودن هستیم، نوع رو تسویه کن
          if (_hasDeposit && widget.payment == null) {
            _selectedType = 'settlement';
          }
        });
      }
    } catch (e) {
      // در صورت خطا، فرض می‌کنیم بیعانه نداریم
      if (mounted) {
        setState(() => _hasDeposit = false);
      }
    }
  }

  // 🔥 متد پارس فارسی
  int _parsePrice(String text) {
    if (text.isEmpty) return 0;

    String clean = text
        .replaceAll('٬', '')
        .replaceAll(',', '')
        .replaceAllMapped(RegExp('[۰-۹]'), (Match m) {
      return (m.group(0)!.codeUnitAt(0) - 1776).toString();
    });

    return int.tryParse(clean) ?? 0;
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
      SnackBarHelper.showError(context, 'لطفا تاریخ دریافت را انتخاب کنید');
      return;
    }

    if (!_isCashPayment && _selectedBank == null) {
      SnackBarHelper.showError(context, 'لطفا بانک را انتخاب کنید');
      return;
    }

    final payment = PaymentModel(
      id: widget.payment?.id ?? '',
      appointmentId: widget.invoiceId,
      amount: _parsePrice(_amountController.text),
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
                  inputFormatters: [PersianPriceInputFormatter()],
                  decoration: InputDecoration(
                    hintText: 'مبلغ دریافتی',
                    suffixText: 'ریال',
                    suffixStyle: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'مبلغ دریافتی اجباری است!';
                    return null;
                  },
                ),

                const SizedBox(height: 16),

                // نوع دریافت
                if (!_hasDeposit || widget.payment?.type == 'deposit')
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
                      items: const [
                        DropdownMenuItem(
                          value: 'deposit',
                          child: Text('بیعانه'),
                        ),
                        DropdownMenuItem(
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
                // 🔥 اگر بیعانه داریم، پیام نمایش بده
                if (_hasDeposit && widget.payment?.type != 'deposit')
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.info.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.info.withOpacity(0.3)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline, color: AppColors.info, size: 20),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'این فاکتور قبلا بیعانه دریافت کرده است.',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.info,
                            ),
                          ),
                        ),
                      ],
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
                        Text(
                          _selectedDate != null
                              ? DateHelper.formatPersianDate(_selectedDate!)
                              : 'تاریخ دریافت',
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            fontSize: 14,
                            color: _selectedDate != null
                                ? AppColors.textPrimary
                                : AppColors.textLight,
                          ),
                        ),
                        const Spacer(),
                        const Icon(Icons.calendar_today, color: AppColors.primary),
                      ],
                    ),
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


                // چک‌باکس نقدی
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 1, vertical: 12),
                  decoration: BoxDecoration(
                    //color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    //border: Border.all(color: Colors.grey.shade300),
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
                            if (_isCashPayment) _selectedBank = null;
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

                const SizedBox(height: 24),

                Row(
                  children: [
                    Expanded(
                      child: CustomButton(
                        text: widget.payment == null ? 'ثبت' : 'ویرایش',
                        onPressed: _handleSubmit,
                        useGradient: true,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
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