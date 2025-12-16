import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shamsi_date/shamsi_date.dart';
import 'package:persian_datetime_picker/persian_datetime_picker.dart';
import '../../../core/constants/colors.dart';
import '../../../core/utils/date_helper.dart';
import '../../../data/models/invoice_model.dart';
import '../../../data/models/appointment_model.dart';

class DailyPerformanceReportScreen extends StatefulWidget {
  const DailyPerformanceReportScreen({super.key});

  @override
  State<DailyPerformanceReportScreen> createState() => _DailyPerformanceReportScreenState();
}

class _DailyPerformanceReportScreenState extends State<DailyPerformanceReportScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Jalali _selectedDate = Jalali.now();
  bool _isLoading = false;

  // داده‌های گزارش
  int _appointmentsCount = 0;
  int _totalIncome = 0;
  int _totalExpenses = 0;
  int _totalPayments = 0;
  int _netProfit = 0;

  List<Map<String, dynamic>> _appointmentsList = [];
  Map<String, int> _servicesData = {};

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  Future<void> _loadReport() async {
    setState(() => _isLoading = true);

    try {
      final selectedDateTime = _selectedDate.toDateTime();
      final startOfDay = DateTime(selectedDateTime.year, selectedDateTime.month, selectedDateTime.day);
      final endOfDay = DateTime(selectedDateTime.year, selectedDateTime.month, selectedDateTime.day, 23, 59, 59);

      // 🔥 Query 1: نوبت‌های روز (غیر از کنسل شده)
      final appointmentsSnapshot = await _firestore
          .collection('appointments')
          .where('requestedDate', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('requestedDate', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
          .get();

      final appointments = appointmentsSnapshot.docs
          .map((doc) => AppointmentModel.fromMap(doc.data(), doc.id))
          .where((apt) => apt.status != 'cancelled')
          .toList();

      final appointmentIds = appointments.map((apt) => apt.id).toList();

      // 🔥 Query 2 & 3: فاکتورها و آیتم‌ها (موازی)
      int totalIncome = 0;
      List<Map<String, dynamic>> appointmentsList = [];
      Map<String, int> servicesMap = {};

      if (appointmentIds.isNotEmpty) {
        // یکجا همه فاکتورهای روز رو بگیر
        final invoicesSnapshot = await _firestore
            .collection('invoices')
            .where('appointmentId', whereIn: appointmentIds.take(10).toList())
            .get();

        final invoiceIds = invoicesSnapshot.docs.map((doc) => doc.id).toList();

        // یکجا همه آیتم‌های فاکتورها رو بگیر
        if (invoiceIds.isNotEmpty) {
          final itemsSnapshot = await _firestore
              .collection('invoice_items')
              .where('invoiceId', whereIn: invoiceIds.take(10).toList())
              .get();

          // گروه‌بندی آیتم‌ها بر اساس invoiceId
          final Map<String, List<Map<String, dynamic>>> itemsByInvoice = {};
          for (var doc in itemsSnapshot.docs) {
            final invoiceId = doc.data()['invoiceId'] as String;
            itemsByInvoice.putIfAbsent(invoiceId, () => []);
            itemsByInvoice[invoiceId]!.add(doc.data());
          }

          // محاسبه مبالغ
          for (var invoiceDoc in invoicesSnapshot.docs) {
            final invoice = InvoiceModel.fromMap(invoiceDoc.data(), invoiceDoc.id);

            // محاسبه grandTotal
            final items = itemsByInvoice[invoice.id] ?? [];
            int itemsTotal = 0;
            for (var item in items) {
              final quantity = (item['quantity'] as int?) ?? 0;
              final unitPrice = (item['unitPrice'] as int?) ?? 0;
              itemsTotal += quantity * unitPrice;

              // جمع‌آوری خدمات
              final serviceName = item['serviceName'] as String? ?? 'نامشخص';
              servicesMap[serviceName] = (servicesMap[serviceName] ?? 0) + quantity;
            }

            int grandTotal = itemsTotal;
            if (invoice.shippingCost != null) grandTotal += invoice.shippingCost!;
            if (invoice.discount != null) grandTotal -= invoice.discount!;
            if (grandTotal < 0) grandTotal = 0;

            totalIncome += grandTotal;

            // لیست نوبت‌ها
            appointmentsList.add({
              'customerName': invoice.customerName,
              'amount': grandTotal,
            });
          }

          // 🔥 اگر بیشتر از 10 نوبت داریم، بقیه رو هم پردازش کن
          if (appointmentIds.length > 10) {
            for (int i = 10; i < appointmentIds.length; i += 10) {
              final batch = appointmentIds.skip(i).take(10).toList();
              final batchInvoices = await _firestore
                  .collection('invoices')
                  .where('appointmentId', whereIn: batch)
                  .get();

              final batchInvoiceIds = batchInvoices.docs.map((doc) => doc.id).toList();

              if (batchInvoiceIds.isNotEmpty) {
                final batchItems = await _firestore
                    .collection('invoice_items')
                    .where('invoiceId', whereIn: batchInvoiceIds.take(10).toList())
                    .get();

                final batchItemsByInvoice = <String, List<Map<String, dynamic>>>{};
                for (var doc in batchItems.docs) {
                  final invoiceId = doc.data()['invoiceId'] as String;
                  batchItemsByInvoice.putIfAbsent(invoiceId, () => []);
                  batchItemsByInvoice[invoiceId]!.add(doc.data());
                }

                for (var invoiceDoc in batchInvoices.docs) {
                  final invoice = InvoiceModel.fromMap(invoiceDoc.data(), invoiceDoc.id);

                  final items = batchItemsByInvoice[invoice.id] ?? [];
                  int itemsTotal = 0;
                  for (var item in items) {
                    final quantity = (item['quantity'] as int?) ?? 0;
                    final unitPrice = (item['unitPrice'] as int?) ?? 0;
                    itemsTotal += quantity * unitPrice;

                    final serviceName = item['serviceName'] as String? ?? 'نامشخص';
                    servicesMap[serviceName] = (servicesMap[serviceName] ?? 0) + quantity;
                  }

                  int grandTotal = itemsTotal;
                  if (invoice.shippingCost != null) grandTotal += invoice.shippingCost!;
                  if (invoice.discount != null) grandTotal -= invoice.discount!;
                  if (grandTotal < 0) grandTotal = 0;

                  totalIncome += grandTotal;

                  appointmentsList.add({
                    'customerName': invoice.customerName,
                    'amount': grandTotal,
                  });
                }
              }
            }
          }
        }
      }

      // 🔥 Query 4: هزینه‌های روز
      final expensesSnapshot = await _firestore
          .collection('expense_documents')
          .where('documentDate', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('documentDate', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
          .get();

      int totalExpenses = 0;
      for (var doc in expensesSnapshot.docs) {
        final amount = (doc.data()['amount'] as int?) ?? 0;
        totalExpenses += amount;
      }

      // 🔥 Query 5: دریافتی‌های روز
      final paymentsSnapshot = await _firestore
          .collection('payments')
          .where('paymentDate', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('paymentDate', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
          .get();

      int totalPayments = 0;
      for (var doc in paymentsSnapshot.docs) {
        final amount = (doc.data()['amount'] as int?) ?? 0;
        totalPayments += amount;
      }

      // محاسبه سود خالص
      final netProfit = totalIncome - totalExpenses;

      // مرتب‌سازی خدمات
      final sortedServices = servicesMap.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      setState(() {
        _appointmentsCount = appointments.length;
        _totalIncome = totalIncome;
        _totalExpenses = totalExpenses;
        _totalPayments = totalPayments;
        _netProfit = netProfit;
        _appointmentsList = appointmentsList;
        _servicesData = Map.fromEntries(sortedServices);
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

  Future<void> _selectDate() async {
    final picked = await showPersianDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: Jalali(1400, 1, 1),
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
      _loadReport();
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
              _buildDateSelector(),
              if (_isLoading)
                const Expanded(child: Center(child: CircularProgressIndicator()))
              else
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        _buildStatsCards(),
                        const SizedBox(height: 16),
                        _buildAppointmentsList(),
                        const SizedBox(height: 16),
                        _buildServicesCard(),
                        const SizedBox(height: 20),
                      ],
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
          Container(width: 44, height: 44),
          const Text(
            'گزارش عملکرد روزانه',
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

  Widget _buildDateSelector() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: InkWell(
        onTap: _selectDate,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                DateHelper.formatPersianDate(_selectedDate),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              //const Icon(Icons.calendar_today, color: AppColors.primary, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatsCards() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'تعداد نوبت',
                DateHelper.toPersianDigits(_appointmentsCount.toString()),
                Icons.camera_alt_outlined,
                AppColors.info,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                'مبلغ دریافتی',
                '${DateHelper.toPersianDigits(_formatNumber(_totalPayments))} تومان',
                Icons.account_balance_wallet_outlined,
                AppColors.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'میزان درآمد',
                '${DateHelper.toPersianDigits(_formatNumber(_totalIncome))} تومان',
                Icons.trending_up,
                AppColors.success,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                'جمع هزینه‌ها',
                '${DateHelper.toPersianDigits(_formatNumber(_totalExpenses))} تومان',
                Icons.trending_down,
                AppColors.error,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildProfitCard(),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
              Icon(icon, color: color, size: 20),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfitCard() {
    final isProfit = _netProfit >= 0;
    final color = isProfit ? AppColors.success : AppColors.error;
    final icon = isProfit ? Icons.arrow_upward : Icons.arrow_downward;
    final label = isProfit ? 'سود خالص' : 'زیان خالص';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          Text(
            '${DateHelper.toPersianDigits(_formatNumber(_netProfit.abs()))} تومان',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppointmentsList() {
    if (_appointmentsList.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          child: Text(
            'نوبتی در این روز ثبت نشده است.',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.grey.shade200),
              ),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'نام مشتری',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textSecondary,
                  ),
                ),
                Text(
                  'مبلغ فاکتور',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _appointmentsList.length,
            separatorBuilder: (context, index) => Divider(
              height: 1,
              color: Colors.grey.shade100,
            ),
            itemBuilder: (context, index) {
              final apt = _appointmentsList[index];
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        apt['customerName'] as String,
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      DateHelper.toPersianDigits(_formatNumber(apt['amount'] as int)),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildServicesCard() {
    if (_servicesData.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          child: Text(
            'خدمتی ثبت نشده است.',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.grey.shade200),
              ),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'عنوان خدمت',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textSecondary,
                  ),
                ),
                Text(
                  'تعداد',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _servicesData.length,
            separatorBuilder: (context, index) => Divider(
              height: 1,
              color: Colors.grey.shade100,
            ),
            itemBuilder: (context, index) {
              final entry = _servicesData.entries.elementAt(index);
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        entry.key,
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      DateHelper.toPersianDigits(entry.value.toString()),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
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