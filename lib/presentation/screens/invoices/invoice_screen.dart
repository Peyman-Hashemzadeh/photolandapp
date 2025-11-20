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
import 'payments_screen.dart';

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

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      // بارگذاری خدمات
      _serviceRepository.getActiveServices().listen((services) {
        if (mounted) {
          setState(() => _services = services);
        }
      });

      // بارگذاری یا ایجاد فاکتور
      var invoice = await _invoiceRepository.getInvoiceByAppointment(widget.appointment.id);

      if (invoice == null) {
        // دریافت شماره سند بعدی
        final invoiceNumber = await _invoiceRepository.getNextInvoiceNumber();

        // ایجاد فاکتور جدید
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
        invoice = newInvoice.copyWith(id: invoiceId);
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

      // بارگذاری مجموع پرداخت‌ها
      _paymentRepository.getPaymentsByAppointment(widget.appointment.id).listen((payments) {
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

  int get _remainingAmount => _totalAmount - _paidAmount;

  Future<void> _showAddItemDialog({InvoiceItem? item}) async {
    final result = await showDialog<InvoiceItem>(
      context: context,
      builder: (context) => _AddInvoiceItemDialog(
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

  void _goToPayments() {
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

  Future<void> _handleBack() async {
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
        floatingActionButton: _isLoading
            ? null
            : FloatingActionButton(
          onPressed: () => _showAddItemDialog(),
          backgroundColor: AppColors.primary,
          child: const Icon(Icons.add, color: Colors.white),
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
          IconButton(
            icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
            onPressed: _handleBack,
          ),
          const Text(
            'نمایش صورت حساب',
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
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _items.length,
      itemBuilder: (context, index) {
        final item = _items[index];
        return _InvoiceItemCard(
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
          // دکمه افزودن (بالای دکمه‌های اصلی)
          Align(
            alignment: Alignment.centerLeft,
            child: FloatingActionButton(
              onPressed: () => _showAddItemDialog(),
              backgroundColor: AppColors.primary,
              mini: false,
              child: const Icon(Icons.add, color: Colors.white),
            ),
          ),
          const SizedBox(height: 16),
          // دکمه‌های اصلی
          Row(
            children: [
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
              const SizedBox(width: 12),
              Expanded(
                child: CustomButton(
                  text: 'ادامه و مرحله بعد',
                  onPressed: _goToPayments,
                  useGradient: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// کارت آیتم فاکتور
class _InvoiceItemCard extends StatefulWidget {
  final InvoiceItem item;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _InvoiceItemCard({
    required this.item,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<_InvoiceItemCard> createState() => _InvoiceItemCardState();
}

class _InvoiceItemCardState extends State<_InvoiceItemCard> {
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

// دیالوگ افزودن/ویرایش آیتم
class _AddInvoiceItemDialog extends StatefulWidget {
  final InvoiceModel invoice;
  final List<ServiceModel> services;
  final InvoiceItem? item;

  const _AddInvoiceItemDialog({
    required this.invoice,
    required this.services,
    this.item,
  });

  @override
  State<_AddInvoiceItemDialog> createState() => _AddInvoiceItemDialogState();
}

class _AddInvoiceItemDialogState extends State<_AddInvoiceItemDialog> {
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

  // 🔥 متد جدید: پر کردن قیمت هنگام انتخاب خدمت
  void _onServiceChanged(ServiceModel? service) {
    setState(() {
      _selectedService = service;

      // اگر خدمت قیمت داشته باشه، فیلد قیمت رو پر کن
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
                // خدمت
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
                      onChanged: _onServiceChanged,  // 🔥 استفاده از متد جدید
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // تعداد
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
                // مبلغ
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