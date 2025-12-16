import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shamsi_date/shamsi_date.dart';
import 'package:persian_datetime_picker/persian_datetime_picker.dart';
import '../../../core/constants/colors.dart';
import '../../../core/utils/date_helper.dart';
import '../../../data/models/invoice_model.dart';
import '../../../data/models/appointment_model.dart';

class WeeklyPerformanceReportScreen extends StatefulWidget {
  const WeeklyPerformanceReportScreen({super.key});

  @override
  State<WeeklyPerformanceReportScreen> createState() => _WeeklyPerformanceReportScreenState();
}

class _WeeklyPerformanceReportScreenState extends State<WeeklyPerformanceReportScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Jalali _startDate = Jalali.now().addDays(-6); // هفته جاری
  late Jalali _endDate;
  bool _isLoading = false;

  // داده‌های گزارش
  int _appointmentsCount = 0;
  int _totalIncome = 0;
  int _totalPayments = 0;
  int _totalExpenses = 0;
  int _netProfit = 0;

  Map<String, int> _servicesData = {};
  List<Map<String, dynamic>> _dailyData = []; // برای نمودار

  @override
  void initState() {
    super.initState();
    _endDate = _startDate.addDays(6);
    _loadReport();
  }

  void _setCurrentWeek() {
    setState(() {
      _startDate = Jalali.now().addDays(-6);
      _endDate = _startDate.addDays(6);
    });
    _loadReport();
  }

  Future<void> _loadReport() async {
    setState(() => _isLoading = true);

    try {
      final startDateTime = _startDate.toDateTime();
      final endDateTime = DateTime(
        _endDate.toDateTime().year,
        _endDate.toDateTime().month,
        _endDate.toDateTime().day,
        23, 59, 59,
      );

      // 🔥 ساخت لیست ۷ روز
      List<DateTime> weekDays = [];
      for (int i = 0; i < 7; i++) {
        weekDays.add(_startDate.addDays(i).toDateTime());
      }

      // 🔥 Query 1: همه نوبت‌های هفته
      final appointmentsSnapshot = await _firestore
          .collection('appointments')
          .where('requestedDate', isGreaterThanOrEqualTo: Timestamp.fromDate(startDateTime))
          .where('requestedDate', isLessThanOrEqualTo: Timestamp.fromDate(endDateTime))
          .get();

      final appointments = appointmentsSnapshot.docs
          .map((doc) => AppointmentModel.fromMap(doc.data(), doc.id))
          .where((apt) => apt.status != 'cancelled')
          .toList();

      final appointmentIds = appointments.map((apt) => apt.id).toList();

      // 🔥 آماده‌سازی داده‌های روزانه
      Map<String, Map<String, dynamic>> dailyDataMap = {};
      for (var day in weekDays) {
        final dayKey = '${day.year}-${day.month}-${day.day}';
        dailyDataMap[dayKey] = {
          'date': day,
          'income': 0,
          'expenses': 0,
          'payments': 0,
        };
      }

      int totalIncome = 0;
      Map<String, int> servicesMap = {};

      // 🔥 Query 2 & 3: فاکتورها و آیتم‌ها
      if (appointmentIds.isNotEmpty) {
        // پردازش دسته‌ای (batch) برای محدودیت whereIn
        for (int i = 0; i < appointmentIds.length; i += 10) {
          final batch = appointmentIds.skip(i).take(10).toList();

          final invoicesSnapshot = await _firestore
              .collection('invoices')
              .where('appointmentId', whereIn: batch)
              .get();

          final invoiceIds = invoicesSnapshot.docs.map((doc) => doc.id).toList();

          if (invoiceIds.isNotEmpty) {
            final itemsSnapshot = await _firestore
                .collection('invoice_items')
                .where('invoiceId', whereIn: invoiceIds.take(10).toList())
                .get();

            // گروه‌بندی آیتم‌ها
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

                final serviceName = item['serviceName'] as String? ?? 'نامشخص';
                servicesMap[serviceName] = (servicesMap[serviceName] ?? 0) + quantity;
              }

              int grandTotal = itemsTotal;
              if (invoice.shippingCost != null) grandTotal += invoice.shippingCost!;
              if (invoice.discount != null) grandTotal -= invoice.discount!;
              if (grandTotal < 0) grandTotal = 0;

              totalIncome += grandTotal;

              // 🔥 افزودن به داده روزانه
              final invoiceDate = invoice.invoiceDate;
              final dayKey = '${invoiceDate.year}-${invoiceDate.month}-${invoiceDate.day}';
              if (dailyDataMap.containsKey(dayKey)) {
                dailyDataMap[dayKey]!['income'] =
                    (dailyDataMap[dayKey]!['income'] as int) + grandTotal;
              }
            }
          }
        }
      }

      // 🔥 Query 4: هزینه‌های هفته
      final expensesSnapshot = await _firestore
          .collection('expense_documents')
          .where('documentDate', isGreaterThanOrEqualTo: Timestamp.fromDate(startDateTime))
          .where('documentDate', isLessThanOrEqualTo: Timestamp.fromDate(endDateTime))
          .get();

      int totalExpenses = 0;
      for (var doc in expensesSnapshot.docs) {
        final amount = (doc.data()['amount'] as int?) ?? 0;
        totalExpenses += amount;

        // افزودن به داده روزانه
        final expenseDate = (doc.data()['documentDate'] as Timestamp).toDate();
        final dayKey = '${expenseDate.year}-${expenseDate.month}-${expenseDate.day}';
        if (dailyDataMap.containsKey(dayKey)) {
          dailyDataMap[dayKey]!['expenses'] =
              (dailyDataMap[dayKey]!['expenses'] as int) + amount;
        }
      }

      // 🔥 Query 5: دریافتی‌های هفته
      final paymentsSnapshot = await _firestore
          .collection('payments')
          .where('paymentDate', isGreaterThanOrEqualTo: Timestamp.fromDate(startDateTime))
          .where('paymentDate', isLessThanOrEqualTo: Timestamp.fromDate(endDateTime))
          .get();

      int totalPayments = 0;
      for (var doc in paymentsSnapshot.docs) {
        final amount = (doc.data()['amount'] as int?) ?? 0;
        totalPayments += amount;

        // افزودن به داده روزانه
        final paymentDate = (doc.data()['paymentDate'] as Timestamp).toDate();
        final dayKey = '${paymentDate.year}-${paymentDate.month}-${paymentDate.day}';
        if (dailyDataMap.containsKey(dayKey)) {
          dailyDataMap[dayKey]!['payments'] =
              (dailyDataMap[dayKey]!['payments'] as int) + amount;
        }
      }

      // محاسبه سود خالص
      final netProfit = totalIncome - totalExpenses;

      // تبدیل Map به List برای نمایش
      final dailyList = dailyDataMap.values.toList()
        ..sort((a, b) => (a['date'] as DateTime).compareTo(b['date'] as DateTime));

      // مرتب‌سازی خدمات
      final sortedServices = servicesMap.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      setState(() {
        _appointmentsCount = appointments.length;
        _totalIncome = totalIncome;
        _totalPayments = totalPayments;
        _totalExpenses = totalExpenses;
        _netProfit = netProfit;
        _servicesData = Map.fromEntries(sortedServices);
        _dailyData = dailyList;
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

  Future<void> _selectStartDate() async {
    final picked = await showPersianDatePicker(
      context: context,
      initialDate: _startDate,
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
      setState(() {
        _startDate = picked;
        _endDate = picked.addDays(6);
      });
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
                        _buildDailyChart(),
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
            'گزارش عملکرد هفتگی',
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
      child: Column(
        children: [
          InkWell(
            onTap: _selectStartDate, // یا متد مناسب برای انتخاب بازه
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
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'از: ${DateHelper.formatPersianDate(_startDate)}',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Container(
                        width: 1,
                        height: 20,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(width: 16),
                      Text(
                        'تا: ${DateHelper.formatPersianDate(_endDate)}',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                  //const Icon(Icons.calendar_today, color: AppColors.primary, size: 17),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity, // کل عرض سطر
            child: ElevatedButton.icon(
              onPressed: _setCurrentWeek,
              //icon: const Icon(Icons.refresh, size: 18),
              label: const Text('هفته جاری'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary.withOpacity(0.1),
                foregroundColor: AppColors.primary,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14), // ارتفاع بیشتر برای زیبایی
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
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
                'مجموع دریافتی',
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
                'هزینه‌های هفته',
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
    final label = isProfit ? 'سود هفته:' : 'زیان هفته:';

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

  Widget _buildDailyChart() {
    if (_dailyData.isEmpty) {
      return const SizedBox.shrink();
    }

    // پیدا کردن بیشترین مقدار برای scaling
    int maxValue = 0;
    for (var day in _dailyData) {
      final income = day['income'] as int;
      if (income > maxValue) maxValue = income;
    }

    if (maxValue == 0) maxValue = 1; // جلوگیری از division by zero

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'نمودار درآمد روزانه',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 220,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: _dailyData.map((day) {
                final date = day['date'] as DateTime;
                final income = day['income'] as int;
                final jalali = Jalali.fromDateTime(date);
                final dayName = DateHelper.getPersianDayName(date);

                // محاسبه ارتفاع ستون (نسبی)
                final barHeight = maxValue > 0 ? (income / maxValue * 150).toDouble() : 0.0;

                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        // مبلغ
                        if (income > 0)
                          Text(
                            DateHelper.toPersianDigits(
                                income > 1000000
                                    ? '${(income / 1000000).toStringAsFixed(1)} م'
                                    : '${(income / 1000).toStringAsFixed(0)} هزار'
                            ),
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        const SizedBox(height: 4),
                        // ستون
                        Container(
                          height: barHeight < 10 && income > 0 ? 10 : barHeight,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [
                                AppColors.primary,
                                AppColors.primary.withOpacity(0.6),
                              ],
                            ),
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(4),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        // نام روز
                        Text(
                          dayName.substring(0, 1),
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade700,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        // تاریخ
                        Text(
                          DateHelper.toPersianDigits('${jalali.day}'),
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
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