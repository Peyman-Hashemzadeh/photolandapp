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

  const _InitialDialog({
    required this.customerRepository,
    this.initialCustomer,
    this.initialDate,
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

  void _handleSubmit() {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedCustomer == null) {
      SnackBarHelper.showError(context, 'لطفاً مشتری را انتخاب کنید');
      return;
    }

    if (_selectedDate == null) {
      SnackBarHelper.showError(context, 'لطفاً تاریخ سند را انتخاب کنید');
      return;
    }

    Navigator.pop(context, {
      'customer': _selectedCustomer,
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
  final PaymentRepository _paymentRepository = PaymentRepository(); // 🔥 اضافه شد

  InvoiceModel? _invoice;
  List<InvoiceItem> _items = [];
  List<ServiceModel> _services = [];
  bool _isLoading = true;
  int _totalAmount = 0;
  int _paidAmount = 0; // 🔥 اضافه شد
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

      // 🔥 چک کردن اینکه آیا در حال ویرایش هستیم؟
      if (widget.existingInvoiceId != null) {
        // 🔥 بارگذاری فاکتور موجود با invoiceNumber
        final existingInvoice = await _invoiceRepository.getInvoiceByNumber(widget.invoiceNumber);

        if (existingInvoice != null) {
          // فاکتور موجود پیدا شد - حالت ویرایش
          invoice = existingInvoice;

          // 🔥 بارگذاری کسورات و توضیحات از فاکتور موجود
          setState(() {
            _shippingCost = invoice.shippingCost ?? 0;
            _discount = invoice.discount ?? 0;
            _notes = invoice.notes ?? '';
          });
        } else {
          // اگر فاکتور پیدا نشد، یکی جدید بساز
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

      // بارگذاری آیتم‌های فاکتور
      _invoiceRepository.getInvoiceItems(_invoice!.id).listen((items) {
        if (mounted) {
          setState(() {
            _items = items;
            _calculateTotals();
          });
        }
      });

      // 🔥 بارگذاری دریافتی‌های این فاکتور
      _paymentRepository.getPaymentsByAppointment(_invoice!.id).listen((payments) {
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

  // ... بقیه متدها بدون تغییر ...

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
            SnackBarHelper.showSuccess(context, 'آیتم با موفقیت اضافه شد');
          }
        } else {
          await _invoiceRepository.updateInvoiceItem(result);
          if (mounted) {
            SnackBarHelper.showSuccess(context, 'آیتم با موفقیت ویرایش شد');
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
          SnackBarHelper.showSuccess(context, 'آیتم با موفقیت حذف شد');
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
          SnackBarHelper.showSuccess(context, 'اطلاعات با موفقیت ذخیره شد');
        }
      } catch (e) {
        if (mounted) {
          SnackBarHelper.showError(context, e.toString().replaceAll('Exception: ', ''));
        }
      }
    }
  }

  Future<void> _showEditSpecsDialog() async {
    final customers = await _customerRepository.getActiveCustomers().first;

    if (!mounted) return;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _InitialDialog(
        customerRepository: _customerRepository,
        initialCustomer: widget.customer,
        initialDate: widget.invoiceDate,
      ),
    );

    if (result != null && mounted) {
      try {
        final updatedInvoice = _invoice!.copyWith(
          customerId: result['customer'].id,
          customerName: result['customer'].fullName,
          customerMobile: result['customer'].mobileNumber,
          invoiceDate: result['date'].toDateTime(),
        );
        await _invoiceRepository.updateInvoice(updatedInvoice);

        if (mounted) {
          SnackBarHelper.showSuccess(context, 'مشخصات با موفقیت ویرایش شد');
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => InvoiceFormScreen(
                customer: result['customer'],
                invoiceDate: result['date'],
                invoiceNumber: widget.invoiceNumber,
              ),
            ),
          );
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
                Expanded(child: _buildItemsList()),
                _buildBottomButtons(),
              ],
            ],
          ),
        ),
      ),
      floatingActionButton: _isLoading
          ? null
          : FloatingActionButton(
        onPressed: _showAddItemDialog,
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
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
            'صدور فاکتور',
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

  Widget _buildInvoiceInfo() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            widget.customer.fullName,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            widget.customer.mobileNumber,
            style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          const Divider(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                DateHelper.formatPersianDate(widget.invoiceDate),
                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              Text(
                DateHelper.toPersianDigits(widget.invoiceNumber.toString()),
                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
            ],
          ),
          const Divider(height: 16),
          // 🔥 نمایش جمع کل و مانده
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
                'جمع کل: ${ServiceModel.formatNumber(_grandTotal)}',
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

  Widget _buildItemsList() {
    if (_items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long, size: 80, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              'رکوردی ثبت نشده است',
              style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 8),
            Text(
              'برای افزودن آیتم، دکمه + را بزنید',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _items.length,
      itemBuilder: (context, index) {
        final item = _items[index];
        return _ItemCard(
          item: item,
          onEdit: () => _showAddItemDialog(item: item),
          onDelete: () => _deleteItem(item),
        );
      },
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
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey.shade200,
              foregroundColor: AppColors.textSecondary,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              minimumSize: const Size(double.infinity, 48),
            ),
            child: const Text('برگشت'),
          ),
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
                  '${widget.item.quantity} عدد',
                  style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
                ),
                Text(
                  widget.item.serviceName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  ServiceModel.formatNumber(widget.item.unitPrice),
                  style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
                Text(
                  ServiceModel.formatNumber(widget.item.totalPrice),
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
      _quantityController.text = widget.item!.quantity.toString();
      _priceController.text = ServiceModel.formatNumber(widget.item!.unitPrice);
      _selectedService = widget.services.firstWhere(
            (s) => s.id == widget.item!.serviceId,
        orElse: () => widget.services.first,
      );
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
      if (service != null && service.price != null) {
        _priceController.text = ServiceModel.formatNumber(service.price!);
      }
    });
  }

  void _handleSubmit() {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedService == null) {
      SnackBarHelper.showError(context, 'لطفاً خدمت را انتخاب کنید');
      return;
    }

    final item = InvoiceItem(
      id: widget.item?.id ?? '',
      invoiceId: widget.invoice.id,
      serviceId: _selectedService!.id,
      serviceName: _selectedService!.serviceName,
      quantity: int.parse(_quantityController.text),
      unitPrice: ServiceModel.parsePrice(_priceController.text) ?? 0,
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

                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<ServiceModel>(
                      value: _selectedService,
                      isExpanded: true,
                      icon: const Icon(Icons.arrow_drop_down, color: AppColors.primary),
                      hint: const Text('انتخاب خدمت', textAlign: TextAlign.right),
                      items: widget.services.map((service) {
                        return DropdownMenuItem(
                          value: service,
                          alignment: Alignment.centerRight,
                          child: Text(service.serviceName, textAlign: TextAlign.right),
                        );
                      }).toList(),
                      onChanged: _onServiceChanged,
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                TextFormField(
                  controller: _quantityController,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.right,
                  maxLength: 4,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
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
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.right,
                  inputFormatters: [PriceInputFormatter()],
                  decoration: InputDecoration(
                    hintText: 'مبلغ',
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
                        text: widget.item == null ? 'ثبت' : 'ویرایش',
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
      _shippingController.text = ServiceModel.formatNumber(widget.shippingCost);
    }
    if (widget.discount > 0) {
      _discountController.text = ServiceModel.formatNumber(widget.discount);
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

  void _handleSubmit() {
    Navigator.pop(context, {
      'shippingCost': ServiceModel.parsePrice(_shippingController.text) ?? 0,
      'discount': ServiceModel.parsePrice(_discountController.text) ?? 0,
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
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.right,
                  inputFormatters: [PriceInputFormatter()],
                  decoration: InputDecoration(
                    hintText: 'هزینه ارسال',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                TextFormField(
                  controller: _discountController,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.right,
                  inputFormatters: [PriceInputFormatter()],
                  decoration: InputDecoration(
                    hintText: 'تخفیف',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
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
                      borderSide: BorderSide(color: Colors.grey.shade300),
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