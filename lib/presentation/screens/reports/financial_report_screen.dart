import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:shamsi_date/shamsi_date.dart';
import 'package:persian_datetime_picker/persian_datetime_picker.dart';
import '../../../core/constants/colors.dart';
import '../../../core/utils/date_helper.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../core/utils/price_input_formatter.dart';
import '../../../data/models/invoice_model.dart';
import '../../../data/models/expense_document_model.dart';
import '../../../data/models/service_model.dart';
import '../../../data/models/payment_model.dart';
import '../../../data/models/customer_model.dart';
import '../../../data/repositories/invoice_repository.dart';
import '../../../data/repositories/expense_document_repository.dart';
import '../../../data/repositories/payment_repository.dart';
import '../../../data/repositories/customer_repository.dart';
import '../../widgets/loading_widget.dart';
import '../../widgets/custom_button.dart';
import '../invoices/invoice_preview_screen.dart';
import '../invoices/add_invoice_screen.dart';
import '../expenses/add_expense_document_screen.dart';

enum ReportFilter { all, income, expense }

// 🔥 enum جدید برای وضعیت فاکتور
enum InvoiceStatus {
  editing('درصف ویرایش'),
  confirmed('تایید مشتری'),
  printing('ارسال برای چاپ'),
  printed('چاپ شده'),
  delivered('تحویل');

  final String label;
  const InvoiceStatus(this.label);
}

class FinancialReportScreen extends StatefulWidget {
  const FinancialReportScreen({super.key});

  @override
  State<FinancialReportScreen> createState() => _FinancialReportScreenState();
}

class _FinancialReportScreenState extends State<FinancialReportScreen> {
  final InvoiceRepository _invoiceRepository = InvoiceRepository();
  final ExpenseDocumentRepository _expenseRepository = ExpenseDocumentRepository();
  final PaymentRepository _paymentRepository = PaymentRepository();
  final CustomerRepository _customerRepository = CustomerRepository();

  Jalali _selectedDate = Jalali.now();
  ReportFilter _currentFilter = ReportFilter.all;

  List<InvoiceModel> _invoices = [];
  List<ExpenseDocumentModel> _expenses = [];
  Map<String, int> _invoicePayments = {};
  Map<String, int> _invoiceTotals = {};
  Map<String, List<InvoiceItem>> _invoiceItems = {};
  Map<String, List<PaymentModel>> _invoicePaymentsList = {};

  bool _isLoading = true;
  int? _totalIncome;
  int? _totalExpense;

  final ScrollController _monthsScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadData();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToSelectedMonth();
    });
  }

  @override
  void dispose() {
    _monthsScrollController.dispose();
    super.dispose();
  }

  void _scrollToSelectedMonth() {
    final monthIndex = _selectedDate.month - 1;
    final scrollPosition = (12 - 1 - monthIndex) * 88.0 - (MediaQuery.of(context).size.width / 2) + 44;

    if (_monthsScrollController.hasClients) {
      _monthsScrollController.animateTo(
        scrollPosition.clamp(0.0, _monthsScrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      // 🔥 بهینه‌سازی: بارگذاری همزمان به جای ترتیبی
      final startOfMonth = Jalali(_selectedDate.year, _selectedDate.month, 1).toDateTime();
      final endOfMonth = Jalali(_selectedDate.year, _selectedDate.month, _selectedDate.monthLength).toDateTime();

      // 🔥 بارگذاری موازی فاکتورها و هزینه‌ها
      await Future.wait([
        // بارگذاری فاکتورها
        _loadInvoices(),

        // بارگذاری هزینه‌ها
        Future(() {
          _expenseRepository.getDocumentsByDateRange(startOfMonth, endOfMonth).listen((expenses) {
            if (mounted) {
              setState(() {
                _expenses = expenses;
                _totalExpense = expenses.isEmpty
                    ? null
                    : expenses.fold<int>(0, (sum, expense) => sum + expense.amount);
              });
            }
          });
        }),
      ]);

      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        SnackBarHelper.showError(context, e.toString().replaceAll('Exception: ', ''));
      }
    }
  }

  // 🔥 متد جداگانه برای بارگذاری فاکتورها
  Future<void> _loadInvoices() async {
    _invoiceRepository.getAllInvoices().listen((invoices) async {
      final filteredInvoices = invoices.where((invoice) {
        final invoiceDate = Jalali.fromDateTime(invoice.invoiceDate);
        return invoiceDate.year == _selectedDate.year &&
            invoiceDate.month == _selectedDate.month;
      }).toList();

      if (filteredInvoices.isEmpty) {
        if (mounted) {
          setState(() {
            _invoices = [];
            _totalIncome = null;
          });
        }
        return;
      }

      // 🔥 بارگذاری موازی داده‌های تمام فاکتورها
      await Future.wait(
        filteredInvoices.map((invoice) => _loadInvoiceDetails(invoice)),
      );

      if (mounted) {
        setState(() {
          _invoices = filteredInvoices;
          _totalIncome = _invoiceTotals.values.fold<int>(0, (sum, total) => sum + total);
        });
      }
    });
  }

  // 🔥 بارگذاری جزئیات یک فاکتور
  Future<void> _loadInvoiceDetails(InvoiceModel invoice) async {
    try {
      // 🔥 بارگذاری موازی payments, total, items
      final results = await Future.wait([
        _paymentRepository.getPaymentsByAppointment(invoice.id).first,
        _invoiceRepository.calculateGrandTotal(invoice.id),
        _invoiceRepository.getInvoiceItems(invoice.id).first,
      ]);

      final payments = results[0] as List<PaymentModel>;
      final total = results[1] as int;
      final items = results[2] as List<InvoiceItem>;

      _invoicePayments[invoice.id] = payments.fold(0, (sum, payment) => sum + payment.amount);
      _invoicePaymentsList[invoice.id] = payments;
      _invoiceTotals[invoice.id] = total;
      _invoiceItems[invoice.id] = items;
    } catch (e) {
      // در صورت خطا، مقادیر پیش‌فرض
      _invoicePayments[invoice.id] = 0;
      _invoicePaymentsList[invoice.id] = [];
      _invoiceTotals[invoice.id] = 0;
      _invoiceItems[invoice.id] = [];
    }
  }

  void _selectMonth(int month) {
    setState(() {
      _selectedDate = Jalali(_selectedDate.year, month, 1);
    });
    _loadData();
    _scrollToSelectedMonth();
  }

  Future<void> _selectYear() async {
    final currentYear = Jalali.now().year;
    final years = List.generate(10, (i) => currentYear - i);

    final selected = await showDialog<int>(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('انتخاب سال'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: years.length,
              itemBuilder: (context, index) {
                final year = years[index];
                return ListTile(
                  title: Text(
                    DateHelper.toPersianDigits(year.toString()),
                    textAlign: TextAlign.center,
                  ),
                  selected: year == _selectedDate.year,
                  onTap: () => Navigator.pop(context, year),
                );
              },
            ),
          ),
        ),
      ),
    );

    if (selected != null) {
      setState(() {
        _selectedDate = Jalali(selected, _selectedDate.month, 1);
      });
      _loadData();
    }
  }

  int? get _difference {
    // اگر هیچ دیتایی نداریم، null برگردون
    if (_totalIncome == null && _totalExpense == null) return null;

    // در غیر این صورت، null ها رو به عنوان 0 در نظر بگیر
    final income = _totalIncome ?? 0;
    final expense = _totalExpense ?? 0;

    return income - expense;
  }

  List<dynamic> get _filteredItems {
    final List<dynamic> items = [];

    if (_currentFilter == ReportFilter.all || _currentFilter == ReportFilter.income) {
      items.addAll(_invoices);
    }
    if (_currentFilter == ReportFilter.all || _currentFilter == ReportFilter.expense) {
      items.addAll(_expenses);
    }

    items.sort((a, b) {
      final dateA = a is InvoiceModel ? a.invoiceDate : (a as ExpenseDocumentModel).documentDate;
      final dateB = b is InvoiceModel ? b.invoiceDate : (b as ExpenseDocumentModel).documentDate;
      return dateB.compareTo(dateA);
    });

    return items;
  }

  // 🔥 حذف فاکتور
  Future<void> _deleteInvoice(InvoiceModel invoice) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('حذف فاکتور'),
          content: const Text('آیا از حذف این فاکتور اطمینان دارید؟'),
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
        await _invoiceRepository.deleteInvoice(invoice.id);
        if (mounted) {
          SnackBarHelper.showSuccess(context, 'فاکتور با موفقیت حذف شد');
          _loadData();
        }
      } catch (e) {
        if (mounted) {
          SnackBarHelper.showError(context, e.toString().replaceAll('Exception: ', ''));
        }
      }
    }
  }

  // 🔥 حذف هزینه
  Future<void> _deleteExpense(ExpenseDocumentModel expense) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('حذف هزینه'),
          content: const Text('آیا از حذف این هزینه اطمینان دارید؟'),
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
        await _expenseRepository.deleteDocument(expense.id);
        if (mounted) {
          SnackBarHelper.showSuccess(context, 'هزینه با موفقیت حذف شد');
          _loadData();
        }
      } catch (e) {
        if (mounted) {
          SnackBarHelper.showError(context, e.toString().replaceAll('Exception: ', ''));
        }
      }
    }
  }

  // 🔥 ویرایش فاکتور - مستقیم به فرم فاکتور با فاکتور موجود
  Future<void> _editInvoice(InvoiceModel invoice) async {
    try {
      // دریافت مشتری
      final customer = await _customerRepository.getCustomerById(invoice.customerId);
      if (customer == null) {
        if (mounted) {
          SnackBarHelper.showError(context, 'مشتری یافت نشد');
        }
        return;
      }

      if (!mounted) return;

      // 🔥 رفتن به صفحه فرم فاکتور با داده‌های موجود
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => InvoiceFormScreen(
            customer: customer,
            invoiceDate: Jalali.fromDateTime(invoice.invoiceDate),
            invoiceNumber: invoice.invoiceNumber,
            existingInvoiceId: invoice.id, // 🔥 پاس دادن ID فاکتور موجود
          ),
        ),
      );

      // 🔥 رفرش بعد از برگشت
      _loadData();
    } catch (e) {
      if (mounted) {
        SnackBarHelper.showError(context, e.toString().replaceAll('Exception: ', ''));
      }
    }
  }

  // 🔥 ویرایش هزینه
  Future<void> _editExpense(ExpenseDocumentModel expense) async {
    final result = await showDialog<ExpenseDocumentModel>(
      context: context,
      builder: (context) => _EditExpenseDialog(expense: expense),
    );

    if (result != null) {
      try {
        await _expenseRepository.updateDocument(result);
        if (mounted) {
          SnackBarHelper.showSuccess(context, 'هزینه با موفقیت ویرایش شد');
          _loadData();
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
              _buildFilters(),
              _buildMonthsRow(),
              _buildStatsBox(),
              Expanded(child: _buildItemsList()),
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
            'صورت حساب',
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

  Widget _buildFilters() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              setState(() {
                _selectedDate = Jalali.now();
              });
              _loadData();
              _scrollToSelectedMonth();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'ماه جاری',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
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
            child: DropdownButtonHideUnderline(
              child: DropdownButton<ReportFilter>(
                value: _currentFilter,
                icon: const Icon(Icons.arrow_drop_down, color: AppColors.primary, size: 20),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
                items: const [
                  DropdownMenuItem(
                    value: ReportFilter.all,
                    child: Text('درآمد و هزینه'),
                  ),
                  DropdownMenuItem(
                    value: ReportFilter.income,
                    child: Text('درآمد'),
                  ),
                  DropdownMenuItem(
                    value: ReportFilter.expense,
                    child: Text('هزینه'),
                  ),
                ],
                onChanged: (filter) {
                  if (filter != null) {
                    setState(() => _currentFilter = filter);
                  }
                },
              ),
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: _selectYear,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
              child: Row(
                children: [
                  Text(
                    DateHelper.toPersianDigits(_selectedDate.year.toString()),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.arrow_drop_down, color: AppColors.primary, size: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthsRow() {
    final months = ['فروردین', 'اردیبهشت', 'خرداد', 'تیر', 'مرداد', 'شهریور',
      'مهر', 'آبان', 'آذر', 'دی', 'بهمن', 'اسفند'];

    return Container(
      height: 70,
      margin: const EdgeInsets.symmetric(vertical: 12),
      child: ListView.builder(
        controller: _monthsScrollController,
        scrollDirection: Axis.horizontal,
        reverse: true,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: 12,
        itemBuilder: (context, index) {
          final month = 12 - index;
          final isSelected = month == _selectedDate.month;

          return GestureDetector(
            onTap: () => _selectMonth(month),
            child: Container(
              width: 80,
              margin: const EdgeInsets.only(left: 8),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  months[month - 1],
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? Colors.white : AppColors.textPrimary,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatsBox() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem('درآمد:', _totalIncome, AppColors.success),
          Container(width: 1, height: 40, color: Colors.grey.shade300),
          _buildStatItem('هزینه:', _totalExpense, AppColors.error),
          Container(width: 1, height: 40, color: Colors.grey.shade300),
          _buildStatItem(
            'اختلاف:',
            _difference,
            _difference == null
                ? AppColors.textPrimary
                : (_difference! > 0 ? AppColors.success : (_difference! < 0 ? AppColors.error : AppColors.textPrimary)),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, int? amount, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          amount == null ? '---' : DateHelper.toPersianDigits(ServiceModel.formatNumber(amount)),
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildItemsList() {
    if (_isLoading) {
      return const LoadingWidget();
    }

    final items = _filteredItems;

    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long, size: 80, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              'رکوردی یافت نشد',
              style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        if (item is InvoiceModel) {
          return _InvoiceCard(
            invoice: item,
            paidAmount: _invoicePayments[item.id] ?? 0,
            grandTotal: _invoiceTotals[item.id] ?? 0,
            items: _invoiceItems[item.id] ?? [],
            payments: _invoicePaymentsList[item.id] ?? [],
            onRefresh: _loadData,
            onDelete: () => _deleteInvoice(item),
            onEdit: () => _editInvoice(item),
            onView: (invoice) async {
              final customer = await _customerRepository.getCustomerById(invoice.customerId);
              if (customer != null && mounted) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => InvoicePreviewScreen(
                      invoice: invoice,
                      customer: customer,
                      items: _invoiceItems[invoice.id] ?? [],
                      totalAmount: _invoiceItems[invoice.id]?.fold<int>(0, (sum, item) => sum + item.totalPrice) ?? 0,
                      shippingCost: invoice.shippingCost ?? 0,
                      discount: invoice.discount ?? 0,
                      grandTotal: _invoiceTotals[invoice.id] ?? 0,
                      paidAmount: _invoicePayments[invoice.id] ?? 0,
                      remainingAmount: (_invoiceTotals[invoice.id] ?? 0) - (_invoicePayments[invoice.id] ?? 0),
                    ),
                  ),
                );
              }
            },
          );
        } else {
          return _ExpenseCard(
            expense: item as ExpenseDocumentModel,
            onRefresh: _loadData,
            onDelete: () => _deleteExpense(item),
            onEdit: () => _editExpense(item),
          );
        }
      },
    );
  }
}

// 🔥 کارت فاکتور (درآمد)
class _InvoiceCard extends StatefulWidget {
  final InvoiceModel invoice;
  final int paidAmount;
  final int grandTotal;
  final List<InvoiceItem> items;
  final List<PaymentModel> payments;
  final VoidCallback onRefresh;
  final VoidCallback onDelete;
  final VoidCallback onEdit;
  final Function(InvoiceModel) onView;

  const _InvoiceCard({
    required this.invoice,
    required this.paidAmount,
    required this.grandTotal,
    required this.items,
    required this.payments,
    required this.onRefresh,
    required this.onDelete,
    required this.onEdit,
    required this.onView,
  });

  @override
  State<_InvoiceCard> createState() => _InvoiceCardState();
}

class _InvoiceCardState extends State<_InvoiceCard> {
  bool _isExpanded = false;

  void _showPaymentStatusDialog() {
    final hasDeposit = widget.paidAmount > 0 && widget.paidAmount < widget.grandTotal;
    final isFullyPaid = widget.paidAmount >= widget.grandTotal;

    String message;
    if (isFullyPaid) {
      final lastPayment = widget.payments.isNotEmpty ? widget.payments.first : null;
      final lastDate = lastPayment != null
          ? DateHelper.dateTimeToShamsi(lastPayment.paymentDate)
          : 'نامشخص';
      message = 'در تاریخ $lastDate فاکتور تسویه شده است.';
    } else if (hasDeposit) {
      final depositPayment = widget.payments.firstWhere(
            (p) => p.type == 'deposit',
        orElse: () => widget.payments.first,
      );
      final depositDate = DateHelper.dateTimeToShamsi(depositPayment.paymentDate);
      final depositAmount = ServiceModel.formatNumber(depositPayment.amount);
      message = 'مشتری در تاریخ $depositDate مبلغ $depositAmount ریال پرداخت کرده است ولی هنوز فاکتور تسویه نشده است.';
    } else {
      message = 'هیچ دریافتی ثبت نشده است.';
    }

    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('وضعیت دریافتی'),
          content: Text(message, textAlign: TextAlign.right),
          actions: [
            Center(
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('متوجه شدم', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 🔥 تغییر وضعیت فاکتور
  Future<void> _changeInvoiceStatus() async {
    final result = await showDialog<InvoiceStatus>(
      context: context,
      builder: (context) => _ChangeStatusDialog(
        currentStatus: widget.invoice.status, // 🔥 استفاده از فیلد status
      ),
    );

    if (result != null) {
      try {
        // 🔥 ذخیره وضعیت در فیلد status جدید
        final updatedInvoice = widget.invoice.copyWith(
          status: result.name, // ذخیره enum name (مثلاً 'editing')
          updatedAt: DateTime.now(),
        );

        await InvoiceRepository().updateInvoice(updatedInvoice);

        if (context.mounted) {
          SnackBarHelper.showSuccess(context, 'وضعیت به "${result.label}" تغییر یافت');
          widget.onRefresh();
        }
      } catch (e) {
        if (context.mounted) {
          SnackBarHelper.showError(context, e.toString().replaceAll('Exception: ', ''));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasDeposit = widget.paidAmount > 0 && widget.paidAmount < widget.grandTotal;
    final isFullyPaid = widget.paidAmount >= widget.grandTotal;
    final itemCount = widget.items.fold<int>(0, (sum, item) => sum + item.quantity);

    // 🔥 گرفتن label وضعیت
    String statusLabel = 'بدون وضعیت';
    Color statusColor = AppColors.textSecondary;

    if (widget.invoice.status != null) {
      try {
        final status = InvoiceStatus.values.firstWhere(
              (s) => s.name == widget.invoice.status,
          orElse: () => InvoiceStatus.editing,
        );
        statusLabel = status.label;

        // رنگ بر اساس وضعیت
        switch (status) {
          case InvoiceStatus.editing:
            statusColor = AppColors.warning;
            break;
          case InvoiceStatus.confirmed:
            statusColor = AppColors.info;
            break;
          case InvoiceStatus.printing:
            statusColor = AppColors.primary;
            break;
          case InvoiceStatus.printed:
            statusColor = Colors.purple;
            break;
          case InvoiceStatus.delivered:
            statusColor = AppColors.success;
            break;
        }
      } catch (e) {
        // اگه status نامعتبر بود
        statusLabel = 'نامشخص';
      }
    }

    return GestureDetector(
      onTap: () => setState(() => _isExpanded = !_isExpanded),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border(right: BorderSide(color: AppColors.success, width: 4)),
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
            // 🔥 ردیف اول: نام مشتری، تاریخ، آیکون
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween, // 🔥 فاصله بین دو طرف
                children: [
                  // بخش راست: نام مشتری (ثابت در سمت راست)
                  Flexible(
                    child: Text(
                      widget.invoice.customerName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                    ),
                  ),

                  const SizedBox(width: 12), // 🔥 فاصله بین دو بخش

                  // بخش چپ: تاریخ + آیکون (ثابت در سمت چپ)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // تاریخ
                      Text(
                        DateHelper.formatPersianDate(Jalali.fromDateTime(widget.invoice.invoiceDate)),
                        //DateHelper.toPersianDigits(DateHelper.dateTimeToShamsi(widget.invoice.invoiceDate)),
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),

                      const SizedBox(width: 12),

                      // آیکون وضعیت دریافتی (کلیک‌دار)
                      GestureDetector(
                        onTap: _showPaymentStatusDialog,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          child: isFullyPaid
                              ? const Icon(Icons.check_circle, color: AppColors.success, size: 22)
                              : hasDeposit
                              ? const Icon(Icons.attach_money, color: AppColors.info, size: 22)
                              : const SizedBox(width: 22),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // 🔥 بخش پایین با background طوسی
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(12),
                  bottomRight: Radius.circular(12),
                ),
              ),
              child: Column(
                children: [
                  // 🔥 ردیف دوم: جمع کل و جمع اقلام
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'جمع کل: ${DateHelper.toPersianDigits(ServiceModel.formatNumber(widget.grandTotal))}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.success,
                        ),
                      ),
                      Text(
                        'جمع اقلام: ${DateHelper.toPersianDigits(itemCount.toString())}',
                        style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // 🔥 ردیف سوم: وضعیت
                  Align(
                    alignment: Alignment.centerRight,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: statusColor.withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            statusLabel,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: statusColor,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '',
                            style: TextStyle(
                              fontSize: 12,
                              color: statusColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // دکمه‌های عملیاتی
                  AnimatedSize(
                    duration: const Duration(milliseconds: 250),
                    child: _isExpanded
                        ? Column(
                      children: [
                        const Divider(height: 20),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          alignment: WrapAlignment.end,
                          children: [
                            _buildActionButton('ویرایش', Icons.edit, AppColors.primary, widget.onEdit),
                            _buildActionButton('نمایش', Icons.visibility, AppColors.info, () {
                              widget.onView(widget.invoice);
                            }),
                            _buildActionButton('وضعیت', Icons.swap_horiz, AppColors.warning, _changeInvoiceStatus),
                            _buildActionButton('حذف', Icons.delete, AppColors.error, widget.onDelete),
                          ],
                        ),
                      ],
                    )
                        : const SizedBox(height: 0),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(String label, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
            ),
          ],
        ),
      ),
    );
  }
}

// 🔥 کارت هزینه
class _ExpenseCard extends StatefulWidget {
  final ExpenseDocumentModel expense;
  final VoidCallback onRefresh;
  final VoidCallback onDelete;
  final VoidCallback onEdit;

  const _ExpenseCard({
    required this.expense,
    required this.onRefresh,
    required this.onDelete,
    required this.onEdit,
  });

  @override
  State<_ExpenseCard> createState() => _ExpenseCardState();
}

class _ExpenseCardState extends State<_ExpenseCard> {
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
          border: Border(right: BorderSide(color: AppColors.error, width: 4)),
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
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // عنوان هزینه - سمت راست
                      Flexible(
                        child: Text(
                          widget.expense.expenseName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.right,
                        ),
                      ),

                      // تاریخ سند - سمت چپ
                      Text(
                        DateHelper.formatPersianDate(Jalali.fromDateTime(widget.expense.documentDate)),
                        //DateHelper.toPersianDigits(DateHelper.dateTimeToShamsi(widget.expense.documentDate)),
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(12),
                  bottomRight: Radius.circular(12),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'مبلغ: ${DateHelper.toPersianDigits(ServiceModel.formatNumber(widget.expense.amount))}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.error,
                        ),
                      ),
                      Text(
                        ' ${widget.expense.paymentTypeLabel}',
                        style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                  if (widget.expense.notes != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      '${widget.expense.notes}',
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                  AnimatedSize(
                    duration: const Duration(milliseconds: 250),
                    child: _isExpanded
                        ? Column(
                      children: [
                        const Divider(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton.icon(
                              onPressed: widget.onEdit,
                              icon: const Icon(Icons.edit, size: 16),
                              label: const Text('ویرایش'),
                              style: TextButton.styleFrom(foregroundColor: AppColors.primary),
                            ),
                            const SizedBox(width: 8),
                            TextButton.icon(
                              onPressed: widget.onDelete,
                              icon: const Icon(Icons.delete, size: 16),
                              label: const Text('حذف'),
                              style: TextButton.styleFrom(foregroundColor: AppColors.error),
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
          ],
        ),
      ),
    );
  }
}

// 🔥 دیالوگ تغییر وضعیت فاکتور
class _ChangeStatusDialog extends StatefulWidget {
  final String? currentStatus;

  const _ChangeStatusDialog({this.currentStatus});

  @override
  State<_ChangeStatusDialog> createState() => _ChangeStatusDialogState();
}

class _ChangeStatusDialogState extends State<_ChangeStatusDialog> {
  InvoiceStatus? _selectedStatus;

  @override
  void initState() {
    super.initState();
    // 🔥 تلاش برای یافتن وضعیت فعلی از enum name
    if (widget.currentStatus != null) {
      try {
        _selectedStatus = InvoiceStatus.values.firstWhere(
              (status) => status.name == widget.currentStatus,
          orElse: () => InvoiceStatus.editing,
        );
      } catch (e) {
        _selectedStatus = InvoiceStatus.editing;
      }
    } else {
      _selectedStatus = InvoiceStatus.editing;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'تغییر وضعیت',
              style: TextStyle(
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
                child: DropdownButton<InvoiceStatus>(
                  value: _selectedStatus,
                  isExpanded: true,
                  icon: const Icon(Icons.arrow_drop_down, color: AppColors.primary),
                  hint: const Text('انتخاب وضعیت', textAlign: TextAlign.right),
                  items: InvoiceStatus.values.map((status) {
                    return DropdownMenuItem(
                      value: status,
                      alignment: Alignment.centerRight,
                      child: Text(status.label, textAlign: TextAlign.right),
                    );
                  }).toList(),
                  onChanged: (status) {
                    setState(() => _selectedStatus = status);
                  },
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
                    onPressed: () {
                      if (_selectedStatus != null) {
                        Navigator.pop(context, _selectedStatus);
                      }
                    },
                    useGradient: true,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// 🔥 دیالوگ ویرایش هزینه
class _EditExpenseDialog extends StatefulWidget {
  final ExpenseDocumentModel expense;

  const _EditExpenseDialog({required this.expense});

  @override
  State<_EditExpenseDialog> createState() => _EditExpenseDialogState();
}

class _EditExpenseDialogState extends State<_EditExpenseDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();

  Jalali? _selectedDate;

  @override
  void initState() {
    super.initState();
    _amountController.text = ServiceModel.formatNumber(widget.expense.amount);
    _notesController.text = widget.expense.notes ?? '';
    _selectedDate = Jalali.fromDateTime(widget.expense.documentDate);
  }

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
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

    if (_selectedDate == null) {
      SnackBarHelper.showError(context, 'لطفا تاریخ سند را انتخاب کنید');
      return;
    }

    final updatedExpense = widget.expense.copyWith(
      amount: ServiceModel.parsePrice(_amountController.text) ?? 0,
      documentDate: _selectedDate!.toDateTime(),
      notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      updatedAt: DateTime.now(),
    );

    Navigator.pop(context, updatedExpense);
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
                  'ویرایش هزینه',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 24),

                // نام هزینه (غیرقابل ویرایش)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'نام هزینه:',
                        style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
                      ),
                      Text(
                        widget.expense.expenseName,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // تاریخ سند
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
                              : 'تاریخ سند',
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

                // مبلغ
                TextFormField(
                  controller: _amountController,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.right,
                  inputFormatters: [PriceInputFormatter()],
                  decoration: InputDecoration(
                    hintText: 'مبلغ هزینه',
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

                // توضیحات
                TextFormField(
                  controller: _notesController,
                  maxLength: 155,
                  maxLines: 4,
                  textAlign: TextAlign.right,
                  decoration: InputDecoration(
                    hintText: 'توضیحات (اختیاری)',
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
                        text: 'ذخیره',
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