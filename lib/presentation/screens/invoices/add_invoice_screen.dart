import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:persian_datetime_picker/persian_datetime_picker.dart';
import 'package:shamsi_date/shamsi_date.dart';
import '../../../core/constants/colors.dart';
import '../../../core/utils/date_helper.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../core/utils/price_input_formatter.dart';
import '../../../data/models/customer_model.dart';
import '../../../data/models/invoice_model.dart';
import '../../../data/models/service_model.dart';
import '../../../data/repositories/customer_repository.dart';
import '../../../data/repositories/invoice_repository.dart';
import '../../../data/repositories/service_repository.dart';
import '../../../data/repositories/payment_repository.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/customer_dropdown.dart';
import 'invoice_payments_screen.dart';
import 'invoice_preview_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';


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

class AddInvoiceScreen extends StatefulWidget {
  const AddInvoiceScreen({super.key});

  @override
  State<AddInvoiceScreen> createState() => _AddInvoiceScreenState();
}

class _AddInvoiceScreenState extends State<AddInvoiceScreen> {
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
      builder: (context) => _InitialDialog(
        customerRepository: _customerRepository,
      ),
    );

    if (result != null && mounted) {
      _navigateToInvoiceForm(
        result['customer'],
        result['date'],
      );
    } else if (mounted) {
      Navigator.pop(context);
    }
  }

  Future<void> _navigateToInvoiceForm(
      CustomerModel customer,
      Jalali invoiceDate,
      ) async {
    final invoiceNumber = await _invoiceRepository.getNextInvoiceNumber();

    if (!mounted) return;

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
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}

// دیالوگ اولیه
class _InitialDialog extends StatefulWidget {
  final CustomerRepository customerRepository;
  final CustomerModel? initialCustomer;
  final Jalali? initialDate;
  final String? existingInvoiceId;

  const _InitialDialog({
    required this.customerRepository,
    this.initialCustomer,
    this.initialDate,
    this.existingInvoiceId,
  });

  @override
  State<_InitialDialog> createState() => _InitialDialogState();
}

class _InitialDialogState extends State<_InitialDialog> {
  final _formKey = GlobalKey<FormState>();
  CustomerModel? _selectedCustomer;
  Jalali? _selectedDate;
  List<CustomerModel> _customers = [];
  bool _isLoadingCustomers = true;

  @override
  void initState() {
    super.initState();
    _selectedCustomer = widget.initialCustomer;
    _selectedDate = widget.initialDate;
    _loadCustomers();
  }

  void _loadCustomers() {
    widget.customerRepository.getActiveCustomers().listen((customers) {
      if (mounted) {
        setState(() {
          _customers = customers;
          _isLoadingCustomers = false;
        });
      }
    });
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

  void _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedCustomer == null) {
      SnackBarHelper.showError(context, 'لطفا مشتری را انتخاب کنید!');
      return;
    }

    if (_selectedDate == null) {
      SnackBarHelper.showError(context, 'لطفا تاریخ فاکتور را انتخاب کنید!');
      return;
    }

    // 🔥 اگر در حال ویرایش هستیم
    if (widget.existingInvoiceId != null) {
      try {
        // دریافت فاکتور فعلی از Firestore
        final doc = await FirebaseFirestore.instance
            .collection('invoices')
            .doc(widget.existingInvoiceId)
            .get();

        if (doc.exists) {
          // 🔥 آپدیت فقط فیلدهای مشتری و تاریخ
          await FirebaseFirestore.instance
              .collection('invoices')
              .doc(widget.existingInvoiceId)
              .update({
            'customerId': _selectedCustomer!.id,
            'customerName': _selectedCustomer!.fullName,
            'customerMobile': _selectedCustomer!.mobileNumber,
            'invoiceDate': Timestamp.fromDate(_selectedDate!.toDateTime()),
            'updatedAt': Timestamp.now(),
          });

          if (mounted) {
            SnackBarHelper.showSuccess(context, 'مشخصات فاکتور ویرایش شد.');
          }
        }
      } catch (e) {
        if (mounted) {
          SnackBarHelper.showError(
            context,
            'خطا در ویرایش: ${e.toString()}',
          );
        }
        return;
      }
    }

    // بازگشت اطلاعات به صفحه قبل
    if (mounted) {
      Navigator.pop(context, {
        'customer': _selectedCustomer,
        'date': _selectedDate,
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'مشخصات فاکتور',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 24),

              if (_isLoadingCustomers)
                const CircularProgressIndicator()
              else
                CustomerDropdown(
                  customers: _customers,
                  selectedCustomer: _selectedCustomer,
                  onChanged: (customer) {
                    setState(() => _selectedCustomer = customer);
                  },
                ),

              const SizedBox(height: 16),

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
                            : 'تاریخ فاکتور',
                        style: TextStyle(
                          fontSize: 14,
                          color: _selectedDate != null
                              ? AppColors.textPrimary
                              : AppColors.textLight,
                        ),
                      ),
                    //  const Icon(Icons.arrow_drop_down_rounded, color: AppColors.primary),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              Row(
                children: [
                  Expanded(
                    child: CustomButton(
                      text: 'ثبت',
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
    );
  }
}

// صفحه فرم فاکتور اصلی
class InvoiceFormScreen extends StatefulWidget {
  final CustomerModel customer;
  final Jalali invoiceDate;
  final int invoiceNumber;
  final String? existingInvoiceId;

  const InvoiceFormScreen({
    super.key,
    required this.customer,
    required this.invoiceDate,
    required this.invoiceNumber,
    this.existingInvoiceId,
  });

  @override
  State<InvoiceFormScreen> createState() => _InvoiceFormScreenState();
}

class _InvoiceFormScreenState extends State<InvoiceFormScreen> {
  final CustomerRepository _customerRepository = CustomerRepository();
  final InvoiceRepository _invoiceRepository = InvoiceRepository();
  final ServiceRepository _serviceRepository = ServiceRepository();
  final PaymentRepository _paymentRepository = PaymentRepository();

  InvoiceModel? _invoice;
  List<InvoiceItem> _items = [];
  List<ServiceModel> _services = [];
  bool _isLoading = true;
  int _totalAmount = 0;
  int _paidAmount = 0;
  int _shippingCost = 0;
  int _discount = 0;
  String _notes = '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      _serviceRepository.getActiveServices().listen((services) {
        if (mounted) {
          setState(() => _services = services);
        }
      });

      InvoiceModel invoice;

      // 🔥 اگر existingInvoiceId داریم، فقط همون فاکتور رو بارگذاری می‌کنیم
      if (widget.existingInvoiceId != null) {
        // 🔥 دریافت فاکتور موجود با ID
        final doc = await FirebaseFirestore.instance
            .collection('invoices')
            .doc(widget.existingInvoiceId)
            .get();

        if (doc.exists) {
          invoice = InvoiceModel.fromMap(doc.data()!, doc.id);

          // 🔥 بارگذاری کسورات و توضیحات از فاکتور موجود
          setState(() {
            _shippingCost = invoice.shippingCost ?? 0;
            _discount = invoice.discount ?? 0;
            _notes = invoice.notes ?? '';
          });
        } else {
          // اگر فاکتور پیدا نشد، خطا بده
          throw Exception('فاکتور یافت نشد');
        }
      } else {
        // 🔥 حالت عادی: فاکتور جدید
        invoice = InvoiceModel(
          id: '',
          appointmentId: null,
          customerId: widget.customer.id,
          customerName: widget.customer.fullName,
          customerMobile: widget.customer.mobileNumber,
          invoiceNumber: widget.invoiceNumber,
          invoiceDate: widget.invoiceDate.toDateTime(),
          createdAt: DateTime.now(),
        );

        final invoiceId = await _invoiceRepository.createInvoice(invoice);
        invoice = invoice.copyWith(id: invoiceId);
      }

      setState(() {
        _invoice = invoice;
        _isLoading = false;
      });
      // ✅ بارگذاری آیتم‌های فاکتور (برای هر دو حالت)
      _invoiceRepository.getInvoiceItems(_invoice!.id).listen((items) {
        if (mounted) {
          setState(() {
            _items = items;
            _calculateTotals();
          });
        }
      });

      // بارگذاری آیتم‌های فاکتور
      final appointmentId = _invoice!.appointmentId ?? _invoice!.id;
      _paymentRepository.getPaymentsByAppointment(appointmentId).listen((payments) {
        if (mounted) {
          setState(() {
            _paidAmount = payments.fold(0, (sum, payment) => sum + payment.amount);
          });
        }
      });

    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        SnackBarHelper.showError(context, e.toString().replaceAll('Exception: ', ''));
      }
    }
  }

  void _calculateTotals() {
    _totalAmount = _items.fold(0, (sum, item) => sum + item.totalPrice);
  }

  // 🔥 محاسبه جمع کل (با هزینه ارسال و تخفیف)
  int get _grandTotal => _totalAmount + _shippingCost - _discount;

  // 🔥 محاسبه مانده
  int get _remainingAmount => _grandTotal - _paidAmount;

  Future<void> _showAddItemDialog({InvoiceItem? item}) async {
    final result = await showDialog<InvoiceItem>(
      context: context,
      builder: (context) => _AddItemDialog(
        invoice: _invoice!,
        services: _services,
        item: item,
      ),
    );

    if (result != null) {
      try {
        if (item == null) {
          await _invoiceRepository.addInvoiceItem(result);
          if (mounted) {
            SnackBarHelper.showSuccess(context, 'آیتم با موفقیت اضافه شد.');
          }
        } else {
          await _invoiceRepository.updateInvoiceItem(result);
          if (mounted) {
            SnackBarHelper.showSuccess(context, 'آیتم با موفقیت ویرایش شد.');
          }
        }
      } catch (e) {
        if (mounted) {
          SnackBarHelper.showError(context, e.toString().replaceAll('Exception: ', ''));
        }
      }
    }
  }

  Future<void> _deleteItem(InvoiceItem item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('حذف آیتم'),
          content: const Text('آیا از حذف این آیتم اطمینان دارید؟'),
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
        await _invoiceRepository.deleteInvoiceItem(item.id);
        if (mounted) {
          SnackBarHelper.showSuccess(context, 'آیتم با موفقیت حذف شد.');
        }
      } catch (e) {
        if (mounted) {
          SnackBarHelper.showError(context, e.toString().replaceAll('Exception: ', ''));
        }
      }
    }
  }

  Future<void> _showDetailsDialog() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _DetailsDialog(
        shippingCost: _shippingCost,
        discount: _discount,
        notes: _notes,
      ),
    );

    if (result != null) {
      setState(() {
        _shippingCost = result['shippingCost'] ?? 0;
        _discount = result['discount'] ?? 0;
        _notes = result['notes'] ?? '';
      });

      try {
        final updatedInvoice = _invoice!.copyWith(
          shippingCost: _shippingCost > 0 ? _shippingCost : null,
          discount: _discount > 0 ? _discount : null,
          notes: _notes.isNotEmpty ? _notes : null,
        );
        await _invoiceRepository.updateInvoice(updatedInvoice);
        if (mounted) {
          SnackBarHelper.showSuccess(context, 'اطلاعات با موفقیت ذخیره شد.');
        }
      } catch (e) {
        if (mounted) {
          SnackBarHelper.showError(context, e.toString().replaceAll('Exception: ', ''));
        }
      }
    }
  }

  Future<void> _showEditSpecsDialog() async {
    if (!mounted) return;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _InitialDialog(
        customerRepository: _customerRepository,
        initialCustomer: widget.customer,
        initialDate: widget.invoiceDate,
        existingInvoiceId: _invoice?.id, // 🔥 پاس دادن ID فاکتور موجود
      ),
    );

    if (result != null && mounted) {
      // 🔥 فقط به صفحه جدید با اطلاعات آپدیت شده بریم
      // به جای pushReplacement از pop و push استفاده می‌کنیم
      Navigator.pop(context); // برگشت از صفحه فعلی

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => InvoiceFormScreen(
            customer: result['customer'],
            invoiceDate: result['date'],
            invoiceNumber: widget.invoiceNumber,
            existingInvoiceId: _invoice?.id, // 🔥 پاس دادن همون ID
          ),
        ),
      );
    }
  }

  Future<void> _handleBack() async {
    // 🔥 چک کنیم آیا فاکتور خالیه (نه آیتم داره نه پرداخت)
    if (_invoice != null && _items.isEmpty && _paidAmount == 0) {
      // فاکتور خالیه، پس حذفش می‌کنیم
      try {
        await _invoiceRepository.deleteInvoice(_invoice!.id);
      } catch (e) {
        // در صورت خطا، فقط لاگ می‌کنیم و ادامه میدیم
        debugPrint('خطا در حذف فاکتور خالی: $e');
      }

      // بدون تاییدیه برمی‌گردیم
      if (mounted) {
        Navigator.pop(context);
      }
      return;
    }
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('بازگشت'),
          content: const Text('آیا از بازگشت به تقویم اطمینان دارید؟'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('بله'),
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
                Expanded(child: _buildItemsList()),
                _buildBottomButtons(),
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
              // decoration: BoxDecoration(
              //   color: Colors.grey.shade300,
              //   shape: BoxShape.circle,
              // ),
              // child: const Center(
              //   child: FaIcon(FontAwesomeIcons.user, color: Colors.grey, size: 20),
              // ),
            ),
          ),
          const Text(
            'صدور فاکتور',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.arrow_forward, color: AppColors.textPrimary),
            onPressed: _handleBack,
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
          // ✅ نام مشتری و شماره همراه در کنار هم
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

          // ✅ تاریخ و شماره سند با آیکون
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
                    DateHelper.formatPersianDate(widget.invoiceDate),
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
                    DateHelper.toPersianDigits(widget.invoiceNumber.toString()),
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

          // جمع کل و مانده
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // جمع کل (سمت راست)
              Text(
                'جمع کل: ${DateHelper.toPersianDigits(ServiceModel.formatNumber(_grandTotal))}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),

              // مانده (سمت چپ)
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

  Widget _buildItemsList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20 , vertical: 10),
      itemCount: _items.isEmpty ? 1 : _items.length + 1, // 🔥 +1 برای دکمه افزودن
      itemBuilder: (context, index) {
        // 🔥 اگر لیست خالی بود
        if (_items.isEmpty && index == 0) {
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 60),
              Icon(Icons.receipt_long, size: 80, color: Colors.grey.shade300),
              const SizedBox(height: 16),
              Text(
                'رکوردی ثبت نشده است',
                style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 8),
              Text(
                'برای افزودن آیتم، دکمه زیر را بزنید',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
              ),
              const SizedBox(height: 24),
              // 🔥 دکمه افزودن آیتم
              _buildAddButton(),
            ],
          );
        }

        // 🔥 اگر آخرین آیتم بود، دکمه افزودن رو نمایش بده
        if (index == _items.length) {
          return Padding(
            padding: const EdgeInsets.only(top: 16, bottom: 80),
            child: _buildAddButton(),
          );
        }

        // نمایش آیتم‌های عادی
        final item = _items[index];
        return _ItemCard(
          item: item,
          onEdit: () => _showAddItemDialog(item: item),
          onDelete: () => _deleteItem(item),
        );
      },
    );
  }

  Widget _buildAddButton() {
    return Center(
      child: InkWell(
        onTap: _showAddItemDialog,
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
                'اضافه کردن آیتم جدید',
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

  Widget _buildBottomButtons() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _showDetailsDialog,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade50,
                    foregroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('توضیحات و کسورات'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _showEditSpecsDialog,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade50,
                    foregroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('ویرایش مشخصات'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => InvoicePaymentsScreen(
                          invoice: _invoice!,
                          customer: widget.customer,
                        ),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade50,
                    foregroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('دریافت وجه'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    // 🔥 رفتن به صفحه نمایش فاکتور
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => InvoicePreviewScreen(
                          invoice: _invoice!,
                          customer: widget.customer,
                          items: _items,
                          totalAmount: _totalAmount,
                          shippingCost: _shippingCost,
                          discount: _discount,
                          grandTotal: _grandTotal,
                          paidAmount: _paidAmount,
                          remainingAmount: _remainingAmount,
                        ),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade50,
                    foregroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('نمایش و ارسال'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
         //ElevatedButton(
         //  onPressed: () => Navigator.pop(context),
         //  style: ElevatedButton.styleFrom(
         //    backgroundColor: Colors.grey.shade200,
         //    foregroundColor: AppColors.textSecondary,
         //    padding: const EdgeInsets.symmetric(vertical: 12),
         //    shape: RoundedRectangleBorder(
         //      borderRadius: BorderRadius.circular(12),
         //    ),
         //    minimumSize: const Size(double.infinity, 48),
         //  ),
         //  child: const Text('برگشت'),
         //),
        ],
      ),
    );
  }
}


// کارت آیتم (با قابلیت باز/بسته شدن)
class _ItemCard extends StatefulWidget {
  final InvoiceItem item;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ItemCard({
    required this.item,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<_ItemCard> createState() => _ItemCardState();
}

class _ItemCardState extends State<_ItemCard> {
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
        padding: const EdgeInsets.all(16),
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.item.serviceName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  '${DateHelper.toPersianDigits(widget.item.quantity.toString())} عدد',
                  style: const TextStyle(fontSize: 15, color: AppColors.textPrimary),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  DateHelper.toPersianDigits(ServiceModel.formatNumber(widget.item.unitPrice)), // 🔥 فارسی
                  style: const TextStyle(fontSize: 15, color: AppColors.textSecondary),
                ),
                Text(
                  DateHelper.toPersianDigits(ServiceModel.formatNumber(widget.item.totalPrice)), // 🔥 فارسی
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ],
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
    );
  }
}

// دیالوگ افزودن آیتم
// دیالوگ افزودن آیتم
class _AddItemDialog extends StatefulWidget {
  final InvoiceModel invoice;
  final List<ServiceModel> services;
  final InvoiceItem? item;

  const _AddItemDialog({
    required this.invoice,
    required this.services,
    this.item,
  });

  @override
  State<_AddItemDialog> createState() => _AddItemDialogState();
}

class _AddItemDialogState extends State<_AddItemDialog> {
  final _formKey = GlobalKey<FormState>();
  final _quantityController = TextEditingController();
  final _priceController = TextEditingController();
  ServiceModel? _selectedService;

  @override
  void initState() {
    super.initState();
    if (widget.item != null) {
      // 🔥 ویرایش: نمایش تعداد و مبلغ ذخیره شده به فارسی
      _quantityController.text = DateHelper.toPersianDigits(widget.item!.quantity.toString());
      _priceController.text = DateHelper.toPersianDigits(ServiceModel.formatNumber(widget.item!.unitPrice));

      _selectedService = widget.services.firstWhere(
            (s) => s.id == widget.item!.serviceId,
        orElse: () => widget.services.first,
      );
    }
  }

  Future<void> _showServiceSearchDialog() async {
    final result = await showDialog<ServiceModel>(
      context: context,
      builder: (context) => _ServiceSearchDialog(
        services: widget.services,
        selectedService: _selectedService,
      ),
    );

    if (result != null) {
      _onServiceChanged(result);
    }
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  void _onServiceChanged(ServiceModel? service) {
    setState(() {
      _selectedService = service;
      // 🔥 فقط در حالت افزودن (نه ویرایش)، مبلغ پیش‌فرض رو نمایش بده
      if (service != null && service.price != null && widget.item == null) {
        _priceController.text = DateHelper.toPersianDigits(ServiceModel.formatNumber(service.price!));
      }
    });
  }

  // 🔥 متد کمکی برای تبدیل اعداد فارسی به انگلیسی و حذف کاما
  int _parsePrice(String text) {
    if (text.isEmpty) return 0;

    // حذف کاما (فارسی و انگلیسی) و تبدیل اعداد فارسی به انگلیسی
    String clean = text
        .replaceAll('٬', '') // کاما فارسی
        .replaceAll(',', '') // کاما انگلیسی
        .replaceAllMapped(RegExp('[۰-۹]'), (Match m) {
      return (m.group(0)!.codeUnitAt(0) - 1776).toString();
    });

    return int.tryParse(clean) ?? 0;
  }

  void _handleSubmit() {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedService == null) {
      SnackBarHelper.showError(context, 'لطفا خدمت را انتخاب کنید');
      return;
    }

    // 🔥 تبدیل تعداد فارسی به انگلیسی
    final quantityText = _quantityController.text.replaceAllMapped(
      RegExp('[۰-۹]'),
          (Match m) => (m.group(0)!.codeUnitAt(0) - 1776).toString(),
    );

    final item = InvoiceItem(
      id: widget.item?.id ?? '',
      invoiceId: widget.invoice.id,
      serviceId: _selectedService!.id,
      serviceName: _selectedService!.serviceName,
      quantity: int.parse(quantityText),
      unitPrice: _parsePrice(_priceController.text), // 🔥 استفاده از متد جدید
      createdAt: widget.item?.createdAt ?? DateTime.now(),
    );

    Navigator.pop(context, item);
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
                  widget.item == null ? 'افزودن آیتم' : 'ویرایش آیتم',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 24),

                // به جای Container با DropdownButton:
                InkWell(
                  onTap: () => _showServiceSearchDialog(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            _selectedService?.serviceName ?? 'انتخاب خدمت',
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              fontSize: 14,
                              color: _selectedService != null
                                  ? AppColors.textPrimary
                                  : AppColors.textLight,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Icon(
                          Icons.search,
                          color: AppColors.primary,
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                TextFormField(
                  controller: _quantityController,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.right,
                  maxLength: 4,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9۰-۹]')), // 🔥 اجازه اعداد فارسی و انگلیسی
                  ],
                  decoration: InputDecoration(
                    hintText: 'تعداد',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    counterText: '',
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'تعداد اجباری است';
                    return null;
                  },
                ),

                const SizedBox(height: 16),

                TextFormField(
                  controller: _priceController,
                  textAlign: TextAlign.right,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    PersianPriceInputFormatter(), // 🔥 فرمت فارسی
                  ],
                  decoration: InputDecoration(
                    hintText: 'مبلغ واحد',
                    suffixText: 'تومان',
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
                    if (value == null || value.isEmpty) return 'مبلغ واحد اجباری است';
                    return null;
                  },
                ),

                const SizedBox(height: 24),

                Row(
                  children: [
                    Expanded(
                      child: CustomButton(
                        text: widget.item == null ? 'ثبت' : 'ویرایش',
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

// 🔥 دیالوگ جستجوی خدمات
class _ServiceSearchDialog extends StatefulWidget {
  final List<ServiceModel> services;
  final ServiceModel? selectedService;

  const _ServiceSearchDialog({
    required this.services,
    this.selectedService,
  });

  @override
  State<_ServiceSearchDialog> createState() => _ServiceSearchDialogState();
}

class _ServiceSearchDialogState extends State<_ServiceSearchDialog> {
  final TextEditingController _searchController = TextEditingController();
  List<ServiceModel> _filteredServices = [];

  @override
  void initState() {
    super.initState();
    _filteredServices = widget.services;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterServices(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredServices = widget.services;
      } else {
        _filteredServices = widget.services
            .where((service) =>
            service.serviceName.toLowerCase().contains(query.toLowerCase()))
            .toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.all(20),
      child: Container(
        constraints: const BoxConstraints(maxHeight: 600),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: Colors.white,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 🎨 هدر
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary,
                    AppColors.primary.withOpacity(0.8),
                  ],
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.search, color: Colors.white, size: 24),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'جستجوی خدمت',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // 🔍 فیلد جستجو
                  TextField(
                    controller: _searchController,
                    autofocus: true,
                    textAlign: TextAlign.right,
                    onChanged: _filterServices,
                    decoration: InputDecoration(
                      hintText: 'جستجو در خدمات...',
                      hintStyle: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 14,
                      ),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.2),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      prefixIcon: Icon(
                        Icons.search,
                        color: Colors.white.withOpacity(0.7),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    style: const TextStyle(color: Colors.white),
                  ),
                ],
              ),
            ),

            // 📊 تعداد نتایج
            if (_filteredServices.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Row(
                  children: [
                    Icon(
                      Icons.filter_list,
                      size: 16,
                      color: Colors.grey.shade600,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${DateHelper.toPersianDigits(_filteredServices.length.toString())} خدمت یافت شد',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),

            // 📋 لیست خدمات
            Expanded(
              child: _filteredServices.isEmpty
                  ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.search_off,
                      size: 64,
                      color: Colors.grey.shade300,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'خدمتی یافت نشد',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'کلمه دیگری جستجو کنید',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              )
                  : ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                itemCount: _filteredServices.length,
                itemBuilder: (context, index) {
                  final service = _filteredServices[index];
                  final isSelected = service.id == widget.selectedService?.id;

                  return InkWell(
                    onTap: () => Navigator.pop(context, service),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primary.withOpacity(0.1)
                            : Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.primary
                              : Colors.grey.shade200,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          // نام خدمت
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  service.serviceName,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.w600,
                                    color: isSelected
                                        ? AppColors.primary
                                        : AppColors.textPrimary,
                                  ),
                                  textAlign: TextAlign.right,
                                ),
                                if (service.price != null) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    '${DateHelper.toPersianDigits(ServiceModel.formatNumber(service.price!))} تومان',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),

                          if (isSelected) const SizedBox(width: 12),

                          // آیکون انتخاب شده
                          if (isSelected)
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.check,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),

                          // آیکون فلش
                         //Icon(
                         //  Icons.arrow_back_ios_rounded,
                         //  size: 16,
                         //  color: isSelected
                         //      ? AppColors.primary
                         //      : Colors.grey.shade400,
                         //),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// دیالوگ توضیحات و کسورات
class _DetailsDialog extends StatefulWidget {
  final int shippingCost;
  final int discount;
  final String notes;

  const _DetailsDialog({
    required this.shippingCost,
    required this.discount,
    required this.notes,
  });

  @override
  State<_DetailsDialog> createState() => _DetailsDialogState();
}

class _DetailsDialogState extends State<_DetailsDialog> {
  final _formKey = GlobalKey<FormState>();
  final _shippingController = TextEditingController();
  final _discountController = TextEditingController();
  final _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.shippingCost > 0) {
      _shippingController.text = DateHelper.toPersianDigits(ServiceModel.formatNumber(widget.shippingCost));
    }
    if (widget.discount > 0) {
      _discountController.text = DateHelper.toPersianDigits(ServiceModel.formatNumber(widget.discount));
    }
    _notesController.text = widget.notes;
  }

  @override
  void dispose() {
    _shippingController.dispose();
    _discountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

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

  void _handleSubmit() {
    Navigator.pop(context, {
      'shippingCost': ServiceModel.parsePrice(_shippingController.text) ,
      'discount': ServiceModel.parsePrice(_discountController.text),
      'notes': _notesController.text.trim(),
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
                  'توضیحات و کسورات',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 24),

                TextFormField(
                  controller: _shippingController,
                  textAlign: TextAlign.right,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    PersianPriceInputFormatter(), // 👈 فرمت جدید
                  ],
                  decoration: InputDecoration(
                    hintText: 'هزینه ارسال',

                    // نمایش "تومان" سمت چپ فیلد
                    suffixText: 'تومان',
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

                TextFormField(
                  controller: _discountController,
                  textAlign: TextAlign.right,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    PersianPriceInputFormatter(), // 👈 فرمت جدید
                  ],
                  decoration: InputDecoration(
                    hintText: 'تخفیف',

                    // نمایش "تومان" سمت چپ فیلد
                    suffixText: 'تومان',
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

                TextFormField(
                  controller: _notesController,
                  maxLength: 155,
                  maxLines: 4,
                  textAlign: TextAlign.right,
                  decoration: InputDecoration(
                    hintText: 'توضیحات فاکتور',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                Row(
                  children: [
                    Expanded(
                      child: CustomButton(
                        text: 'ثبت',
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