import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shamsi_date/shamsi_date.dart';
import '../../../core/constants/colors.dart';
import '../../../core/utils/date_helper.dart';
import '../../../data/models/invoice_model.dart';
import '../../../data/models/customer_model.dart';
import '../../widgets/empty_state_widget.dart';
import '../invoices/invoice_preview_screen.dart';

class DebtorsReportScreen extends StatefulWidget {
  const DebtorsReportScreen({super.key});

  @override
  State<DebtorsReportScreen> createState() => _DebtorsReportScreenState();
}

class _DebtorsReportScreenState extends State<DebtorsReportScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _searchController = TextEditingController();

  bool _isLoading = true;
  String? _expandedCustomerId;

  List<Map<String, dynamic>> _allDebtors = [];
  List<Map<String, dynamic>> _filteredDebtors = [];

  int _totalDebtors = 0;
  int _totalDebt = 0;

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadReport() async {
    setState(() => _isLoading = true);

    try {
      // 🔥 Query 1: همه فاکتورها (به جز کنسل شده)
      final invoicesSnapshot = await _firestore
          .collection('invoices')
          .get();

      final invoices = invoicesSnapshot.docs
          .map((doc) => InvoiceModel.fromMap(doc.data(), doc.id))
          .where((inv) => inv.status != 'cancelled')
          .toList();

      if (invoices.isEmpty) {
        setState(() {
          _isLoading = false;
          _totalDebtors = 0;
          _totalDebt = 0;
        });
        return;
      }

      final invoiceIds = invoices.map((inv) => inv.id).toList();

      // 🔥 Query 2 & 3: آیتم‌ها و پرداخت‌ها (موازی)
      List<Map<String, dynamic>> itemsList = [];
      List<Map<String, dynamic>> paymentsList = [];

      for (int i = 0; i < invoiceIds.length; i += 10) {
        final batch = invoiceIds.skip(i).take(10).toList();

        final results = await Future.wait([
          _firestore
              .collection('invoice_items')
              .where('invoiceId', whereIn: batch)
              .get(),
          _firestore
              .collection('payments')
              .where('invoiceId', whereIn: batch)
              .get(),
        ]);

        itemsList.addAll(results[0].docs.map((doc) => doc.data()).toList());
        paymentsList.addAll(results[1].docs.map((doc) => doc.data()).toList());
      }

      // 🔥 گروه‌بندی items بر اساس invoiceId
      final Map<String, List<Map<String, dynamic>>> itemsByInvoice = {};
      for (var item in itemsList) {
        final invoiceId = item['invoiceId'] as String;
        itemsByInvoice.putIfAbsent(invoiceId, () => []);
        itemsByInvoice[invoiceId]!.add(item);
      }

      // 🔥 گروه‌بندی payments بر اساس invoiceId
      final Map<String, int> paymentsByInvoice = {};
      for (var payment in paymentsList) {
        final invoiceId = payment['invoiceId'] as String;
        final amount = (payment['amount'] as int?) ?? 0;
        paymentsByInvoice[invoiceId] = (paymentsByInvoice[invoiceId] ?? 0) + amount;
      }

      // 🔥 محاسبه بدهی هر فاکتور
      Map<String, Map<String, dynamic>> debtorsByCustomer = {};

      for (var invoice in invoices) {
        // محاسبه grandTotal
        final items = itemsByInvoice[invoice.id] ?? [];
        int itemsTotal = 0;
        for (var item in items) {
          final quantity = (item['quantity'] as int?) ?? 0;
          final unitPrice = (item['unitPrice'] as int?) ?? 0;
          itemsTotal += quantity * unitPrice;
        }

        int grandTotal = itemsTotal;
        if (invoice.shippingCost != null) grandTotal += invoice.shippingCost!;
        if (invoice.discount != null) grandTotal -= invoice.discount!;
        if (grandTotal < 0) grandTotal = 0;

        final paidAmount = paymentsByInvoice[invoice.id] ?? 0;
        final remaining = grandTotal - paidAmount;

        // فقط اگر مانده داشته باشه
        if (remaining > 0) {
          if (!debtorsByCustomer.containsKey(invoice.customerId)) {
            debtorsByCustomer[invoice.customerId] = {
              'customerId': invoice.customerId,
              'customerName': invoice.customerName,
              'customerMobile': invoice.customerMobile,
              'totalDebt': 0,
              'invoices': <Map<String, dynamic>>[],
            };
          }

          debtorsByCustomer[invoice.customerId]!['totalDebt'] =
              (debtorsByCustomer[invoice.customerId]!['totalDebt'] as int) + remaining;

          (debtorsByCustomer[invoice.customerId]!['invoices'] as List).add({
            'invoice': invoice,
            'grandTotal': grandTotal,
            'paidAmount': paidAmount,
            'remaining': remaining,
          });
        }
      }

      // تبدیل به لیست و مرتب‌سازی
      final debtorsList = debtorsByCustomer.values.toList()
        ..sort((a, b) => (b['totalDebt'] as int).compareTo(a['totalDebt'] as int));

      // محاسبه آمار کلی
      int totalDebt = 0;
      for (var debtor in debtorsList) {
        totalDebt += debtor['totalDebt'] as int;
      }

      setState(() {
        _allDebtors = debtorsList;
        _filteredDebtors = debtorsList;
        _totalDebtors = debtorsList.length;
        _totalDebt = totalDebt;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطا در بارگذاری گزارش: $e')),
        );
      }
    }
  }

  void _filterDebtors(String query) {
    if (query.isEmpty) {
      setState(() => _filteredDebtors = _allDebtors);
      return;
    }

    final searchLower = query.toLowerCase();
    setState(() {
      _filteredDebtors = _allDebtors.where((debtor) {
        final name = (debtor['customerName'] as String).toLowerCase();
        final mobile = debtor['customerMobile'] as String;
        return name.contains(searchLower) || mobile.contains(query);
      }).toList();
    });
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
                _buildStats(),
                _buildSearchBar(),
                Expanded(
                  child: _filteredDebtors.isEmpty
                      ? EmptyStateWidget(
                    icon: Icons.check_circle_outline,
                    message: _searchController.text.isEmpty
                        ? 'بدهکاری وجود ندارد! 🎉'
                        : 'نتیجه‌ای یافت نشد',
                  )
                      : _buildDebtorsList(),
                ),
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
          Container(width: 44, height: 44),
          const Text(
            'گزارش بدهکاران',
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

  Widget _buildStats() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.error.withOpacity(0.1),
            AppColors.primary.withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.error.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Column(
            children: [
              const Text(
                'تعداد بدهکاران',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${DateHelper.toPersianDigits(_totalDebtors.toString())} نفر',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.error,
                ),
              ),
            ],
          ),
          Container(
            width: 1,
            height: 40,
            color: Colors.grey.shade300,
          ),
          Column(
            children: [
              const Text(
                'مجموع بدهی',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${DateHelper.toPersianDigits(_formatNumber(_totalDebt))} تومان',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.error,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
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
      child: TextField(
        controller: _searchController,
        textAlign: TextAlign.right,
        decoration: InputDecoration(
          hintText: 'جستجو بر اساس نام یا شماره...',
          hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
          prefixIcon: Icon(Icons.search, color: Colors.grey.shade400),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        onChanged: _filterDebtors,
      ),
    );
  }

  Widget _buildDebtorsList() {
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _filteredDebtors.length,
      itemBuilder: (context, index) {
        final debtor = _filteredDebtors[index];
        return _buildDebtorCard(debtor);
      },
    );
  }

  Widget _buildDebtorCard(Map<String, dynamic> debtor) {
    final customerId = debtor['customerId'] as String;
    final customerName = debtor['customerName'] as String;
    final customerMobile = debtor['customerMobile'] as String;
    final totalDebt = debtor['totalDebt'] as int;
    final invoices = debtor['invoices'] as List<Map<String, dynamic>>;
    final isExpanded = _expandedCustomerId == customerId;

    // رنگ بر اساس مبلغ بدهی
    Color debtColor = AppColors.error;
    if (totalDebt >= 5000000) {
      debtColor = const Color(0xFFD32F2F); // قرمز تیره
    } else if (totalDebt >= 1000000) {
      debtColor = Colors.orange;
    } else {
      debtColor = Colors.amber.shade700;
    }

    return GestureDetector(
      onTap: () {
        setState(() {
          _expandedCustomerId = isExpanded ? null : customerId;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: debtColor.withOpacity(0.3)),
          boxShadow: [
            BoxShadow(
              color: debtColor.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    color: debtColor,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          customerName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                          textAlign: TextAlign.right,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          DateHelper.toPersianDigits(customerMobile),
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                          ),
                          textDirection: TextDirection.ltr,
                          textAlign: TextAlign.right,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        DateHelper.toPersianDigits(_formatNumber(totalDebt)),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: debtColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${DateHelper.toPersianDigits(invoices.length.toString())} فاکتور',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
                child: isExpanded
                    ? Column(
                  children: [
                    const SizedBox(height: 16),
                    const Divider(height: 1),
                    const SizedBox(height: 12),
                    ...invoices.map((invoiceData) {
                      return _buildInvoiceItem(invoiceData);
                    }).toList(),
                  ],
                )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInvoiceItem(Map<String, dynamic> invoiceData) {
    final invoice = invoiceData['invoice'] as InvoiceModel;
    final grandTotal = invoiceData['grandTotal'] as int;
    final paidAmount = invoiceData['paidAmount'] as int;
    final remaining = invoiceData['remaining'] as int;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.receipt_long, size: 16, color: AppColors.primary),
                  const SizedBox(width: 6),
                  Text(
                    'فاکتور ${DateHelper.toPersianDigits(invoice.invoiceNumber.toString())}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              Text(
                DateHelper.dateTimeToShamsi(invoice.invoiceDate),
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'جمع کل:',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
              ),
              Text(
                DateHelper.toPersianDigits(_formatNumber(grandTotal)),
                style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'پرداخت شده:',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
              ),
              Text(
                DateHelper.toPersianDigits(_formatNumber(paidAmount)),
                style: const TextStyle(fontSize: 13, color: AppColors.success),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'مانده:',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.error),
              ),
              Text(
                DateHelper.toPersianDigits(_formatNumber(remaining)),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.error,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _handleViewInvoice(invoice),
              icon: const Icon(Icons.visibility, size: 16),
              label: const Text('مشاهده فاکتور'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary),
                padding: const EdgeInsets.symmetric(vertical: 8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _handleViewInvoice(InvoiceModel invoice) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      final itemsSnapshot = await _firestore.collection('invoice_items')
          .where('invoiceId', isEqualTo: invoice.id)
          .get();

      final customerDoc = await _firestore.collection('customers')
          .doc(invoice.customerId)
          .get();

      final paymentsSnapshot = await _firestore.collection('payments')
          .where('invoiceId', isEqualTo: invoice.id)
          .get();

      if (!mounted) return;
      Navigator.pop(context);

      if (!customerDoc.exists) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('اطلاعات مشتری یافت نشد')),
        );
        return;
      }

      final customer = CustomerModel.fromMap(customerDoc.data()!, customerDoc.id);
      final items = itemsSnapshot.docs
          .map((doc) => InvoiceItem.fromMap(doc.data(), doc.id))
          .toList();

      int totalAmount = 0;
      for (var item in items) {
        totalAmount += item.totalPrice;
      }

      int grandTotal = totalAmount;
      if (invoice.shippingCost != null) grandTotal += invoice.shippingCost!;
      if (invoice.discount != null) grandTotal -= invoice.discount!;

      int paidAmount = 0;
      for (var doc in paymentsSnapshot.docs) {
        paidAmount += (doc.data()['amount'] as int?) ?? 0;
      }

      final remainingAmount = grandTotal - paidAmount;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => InvoicePreviewScreen(
            invoice: invoice,
            customer: customer,
            items: items,
            totalAmount: totalAmount,
            shippingCost: invoice.shippingCost ?? 0,
            discount: invoice.discount ?? 0,
            grandTotal: grandTotal,
            paidAmount: paidAmount,
            remainingAmount: remainingAmount,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطا در بارگذاری فاکتور: $e')),
        );
      }
    }
  }

  String _formatNumber(int number) {
    if (number == 0) return '۰';
    final str = number.abs().toString();
    final buffer = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) {
        buffer.write(',');
      }
      buffer.write(str[i]);
    }
    return buffer.toString();
  }
}