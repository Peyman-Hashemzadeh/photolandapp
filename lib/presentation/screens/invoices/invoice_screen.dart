import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../core/constants/colors.dart';
import '../../../core/utils/date_helper.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../core/utils/price_input_formatter.dart';
import '../../../data/models/appointment_model.dart';
import '../../../data/models/invoice_model.dart';
import '../../../data/models/service_model.dart';
import '../../../data/repositories/invoice_repository.dart';
import '../../../data/repositories/service_repository.dart';
import '../../../data/repositories/payment_repository.dart';
import '../../widgets/custom_button.dart';
import '../../../presentation/screens/invoices/payments_screen.dart';

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

class InvoiceScreen extends StatefulWidget {
  final AppointmentModel appointment;

  const InvoiceScreen({
    super.key,
    required this.appointment,
  });

  @override
  State<InvoiceScreen> createState() => _InvoiceScreenState();
}

class _InvoiceScreenState extends State<InvoiceScreen> {
  final InvoiceRepository _invoiceRepository = InvoiceRepository();
  final ServiceRepository _serviceRepository = ServiceRepository();
  final PaymentRepository _paymentRepository = PaymentRepository();

  InvoiceModel? _invoice;
  List<InvoiceItem> _items = [];
  List<ServiceModel> _services = [];
  bool _isLoading = true;
  int _totalAmount = 0;
  int _paidAmount = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  // 🔥 تغییر اصلی: فقط فاکتور موجود رو بارگذاری می‌کنیم
  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      // بارگذاری خدمات
      _serviceRepository.getActiveServices().listen((services) {
        if (mounted) {
          setState(() => _services = services);
        }
      });

      // 🔥 فقط بررسی می‌کنیم که فاکتور وجود داره یا نه (بدون ایجاد)
      var invoice = await _invoiceRepository.getInvoiceByAppointment(widget.appointment.id);

      setState(() {
        _invoice = invoice;
        _isLoading = false;
      });

      // اگر فاکتور وجود داشت، آیتم‌ها و پرداخت‌ها رو بارگذاری کن
      if (_invoice != null) {
        // بارگذاری آیتم‌های فاکتور
        _invoiceRepository.getInvoiceItems(_invoice!.id).listen((items) {
          if (mounted) {
            setState(() {
              _items = items;
              _calculateTotals();
            });
          }
        });

        // بارگذاری مجموع پرداخت‌ها
        _paymentRepository.getPaymentsByAppointment(widget.appointment.id).listen((payments) {
          if (mounted) {
            setState(() {
              _paidAmount = payments.fold(0, (sum, payment) => sum + payment.amount);
            });
          }
        });
      }
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

  int get _remainingAmount => _totalAmount - _paidAmount;

  Future<void> _updateDepositInvoiceId(String invoiceId) async {
    try {
      final payments = await _paymentRepository
          .getPaymentsByAppointment(widget.appointment.id)
          .first;

      for (var payment in payments) {
        if (payment.type == 'deposit' && payment.invoiceId == null) {
          await _paymentRepository.updatePayment(
            payment.copyWith(invoiceId: invoiceId),
          );
        }
      }
    } catch (e) {
      debugPrint('خطا در آپدیت invoiceId: $e');
    }
  }

  // 🔥 تغییر اصلی: فاکتور رو اینجا ایجاد می‌کنیم (اولین بار که آیتم اضافه میشه)
  Future<void> _showAddItemDialog({InvoiceItem? item}) async {
    // 🔥 اگر فاکتور وجود نداره، اول یکی بسازیم
    if (_invoice == null) {
      try {
        final invoiceNumber = await _invoiceRepository.getNextInvoiceNumber();

        final newInvoice = InvoiceModel(
          id: '',
          appointmentId: widget.appointment.id,
          customerId: widget.appointment.customerId,
          customerName: widget.appointment.customerName,
          customerMobile: widget.appointment.customerMobile,
          invoiceNumber: invoiceNumber,
          invoiceDate: DateTime.now(),
          createdAt: DateTime.now(),
        );

        final invoiceId = await _invoiceRepository.createInvoice(newInvoice);

        setState(() {
          _invoice = newInvoice.copyWith(id: invoiceId);
        });

        await _updateDepositInvoiceId(invoiceId);

        // شروع به گوش دادن به آیتم‌ها و پرداخت‌ها
        _invoiceRepository.getInvoiceItems(_invoice!.id).listen((items) {
          if (mounted) {
            setState(() {
              _items = items;
              _calculateTotals();
            });
          }
        });

        _paymentRepository.getPaymentsByAppointment(widget.appointment.id).listen((payments) {
          if (mounted) {
            setState(() {
              _paidAmount = payments.fold(0, (sum, payment) => sum + payment.amount);
            });
          }
        });
      } catch (e) {
        if (mounted) {
          SnackBarHelper.showError(context, 'خطا در ایجاد فاکتور: ${e.toString().replaceAll('Exception: ', '')}');
        }
        return;
      }
    }


    // حالا دیالوگ رو نمایش میدیم
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

  void _goToPayments() {
    // 🔥 حذف چک قبلی
    // اگر فاکتور وجود نداشت، اول بسازیم
    if (_invoice == null) {
      _createInvoiceAndNavigate();
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PaymentsScreen(
            appointment: widget.appointment,
            invoice: _invoice!,
          ),
        ),
      );
    }
  }
  Future<void> _createInvoiceAndNavigate() async {
    try {
      final invoiceNumber = await _invoiceRepository.getNextInvoiceNumber();

      final newInvoice = InvoiceModel(
        id: '',
        appointmentId: widget.appointment.id,
        customerId: widget.appointment.customerId,
        customerName: widget.appointment.customerName,
        customerMobile: widget.appointment.customerMobile,
        invoiceNumber: invoiceNumber,
        invoiceDate: DateTime.now(),
        createdAt: DateTime.now(),
      );

      final invoiceId = await _invoiceRepository.createInvoice(newInvoice);

      setState(() {
        _invoice = newInvoice.copyWith(id: invoiceId);
      });

      await _updateDepositInvoiceId(invoiceId);

      // شروع گوش دادن به تغییرات
      _invoiceRepository.getInvoiceItems(_invoice!.id).listen((items) {
        if (mounted) {
          setState(() {
            _items = items;
            _calculateTotals();
          });
        }
      });

      _paymentRepository.getPaymentsByAppointment(widget.appointment.id).listen((payments) {
        if (mounted) {
          setState(() {
            _paidAmount = payments.fold(0, (sum, payment) => sum + payment.amount);
          });
        }
      });

      // انتقال به صفحه پرداخت
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PaymentsScreen(
              appointment: widget.appointment,
              invoice: _invoice!,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        SnackBarHelper.showError(context, 'خطا در ایجاد فاکتور: ${e.toString().replaceAll('Exception: ', '')}');
      }
    }
  }

  Future<void> _handleBack() async {
    // 🔥 اصلاح شرط: چک کن که واقعاً خالیه
    if (_invoice != null && _items.isEmpty && _paidAmount == 0 && _totalAmount == 0) {
      try {
        await _invoiceRepository.deleteInvoice(_invoice!.id);
        print('✅ فاکتور خالی ${_invoice!.id} حذف شد');
      } catch (e) {
        debugPrint('⚠️ خطا در حذف فاکتور خالی: $e');
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
    return WillPopScope(
      onWillPop: () async {
        await _handleBack();
        return false;
      },
      child: Scaffold(
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
                  Expanded(child: _buildItemsList()),
                  _buildBottomButtons(),
                ],
              ],
            ),
          ),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
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

  Widget _buildAppointmentInfo() {
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
              Expanded(
                child: Text(
                  widget.appointment.customerName,
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
              Expanded(
                child: Text(
                  DateHelper.toPersianDigits(widget.appointment.customerMobile),
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
              Row(
                children: [
                  const Icon(
                    Icons.access_time,
                    size: 16,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 6),
                  Directionality(
                    textDirection: TextDirection.ltr,
                    child: Text(
                      DateHelper.toPersianDigits(widget.appointment.timeRange),
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  const Icon(
                    Icons.calendar_today,
                    size: 16,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    DateHelper.dateTimeToShamsi(widget.appointment.requestedDate),
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

  Widget _buildItemsList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      itemCount: _items.isEmpty ? 1 : _items.length + 1,
      itemBuilder: (context, index) {
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
              _buildAddButton(),
            ],
          );
        }

        if (index == _items.length) {
          return Padding(
            padding: const EdgeInsets.only(top: 16, bottom: 80),
            child: _buildAddButton(),
          );
        }

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
          decoration: BoxDecoration(),
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
                child: CustomButton(
                  text: 'دریافت وجه',
                  onPressed: _goToPayments,
                  useGradient: true,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: _handleBack,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    side: BorderSide(color: Colors.grey.shade300),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('برگشت'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// کارت آیتم
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
                  DateHelper.toPersianDigits(ServiceModel.formatNumber(widget.item.unitPrice)),
                  style: const TextStyle(fontSize: 15, color: AppColors.textSecondary),
                ),
                Text(
                  DateHelper.toPersianDigits(ServiceModel.formatNumber(widget.item.totalPrice)),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
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
      _quantityController.text = DateHelper.toPersianDigits(widget.item!.quantity.toString());
      _priceController.text = DateHelper.toPersianDigits(ServiceModel.formatNumber(widget.item!.unitPrice));
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
      if (service != null && service.price != null && widget.item == null) {
        _priceController.text = DateHelper.toPersianDigits(ServiceModel.formatNumber(service.price!));
      }
    });
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
    if (!_formKey.currentState!.validate()) return;
    if (_selectedService == null) {
      SnackBarHelper.showError(context, 'لطفا خدمت را انتخاب کنید');
      return;
    }

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
      unitPrice: _parsePrice(_priceController.text),
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
                      icon: const Icon(Icons.arrow_drop_down_rounded, color: AppColors.primary),
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
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9۰-۹]')), // اجازه اعداد فارسی و انگلیسی
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
                    PersianPriceInputFormatter(), // فرمت فارسی
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