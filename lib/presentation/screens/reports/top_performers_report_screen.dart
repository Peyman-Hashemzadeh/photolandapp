import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shamsi_date/shamsi_date.dart';
import '../../../core/constants/colors.dart';
import '../../../core/utils/date_helper.dart';

class TopPerformersReportScreen extends StatefulWidget {
  const TopPerformersReportScreen({super.key});

  @override
  State<TopPerformersReportScreen> createState() => _TopPerformersReportScreenState();
}

class _TopPerformersReportScreenState extends State<TopPerformersReportScreen> with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  late TabController _tabController;
  String? _selectedYear;
  List<String> _availableYears = [];
  bool _isLoading = false;

  // داده‌های Tab 1: مشتریان
  List<CustomerPerformance> _topCustomersByAppointments = [];
  List<CustomerPerformance> _topCustomersByIncome = [];

  // داده‌های Tab 2: زمان‌ها
  List<TimePerformance> _topYears = [];
  List<TimePerformance> _topMonths = [];
  List<TimePerformance> _topDays = [];

  // داده‌های Tab 3: خدمات
  List<ServicePerformance> _topServices = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _generateAvailableYears();
    _selectedYear = 'همه';
    _loadAllData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _generateAvailableYears() {
    final currentYear = Jalali.now().year;
    _availableYears = ['همه'];
    for (int i = 0; i < 10; i++) {
      _availableYears.add((currentYear - i).toString());
    }
  }

  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);

    try {
      // 🔥 بارگذاری موازی
      await Future.wait([
        _loadCustomersData(),
        _loadTimeData(),
        _loadServicesData(),
      ]);

      setState(() => _isLoading = false);
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطا در بارگذاری گزارش: $e')),
        );
      }
    }
  }

  Future<void> _loadCustomersData() async {
    try {
      // دریافت نوبت‌ها با فیلتر سال
      Query appointmentsQuery = _firestore
          .collection('appointments')
          .where('status', whereNotIn: ['cancelled']);

      if (_selectedYear != null && _selectedYear != 'همه') {
        final yearInt = int.parse(_selectedYear!);
        final startOfYear = Jalali(yearInt, 1, 1).toDateTime();
        final endOfYear = Jalali(yearInt, 12, 29, 23, 59, 59).toDateTime();

        appointmentsQuery = appointmentsQuery
            .where('requestedDate', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfYear))
            .where('requestedDate', isLessThanOrEqualTo: Timestamp.fromDate(endOfYear));
      }

      final appointmentsSnapshot = await appointmentsQuery.get();

      // گروه‌بندی بر اساس مشتری
      final customerAppointmentCount = <String, CustomerData>{};

      for (var doc in appointmentsSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>?;
        if (data == null) continue;

        final customerId = data['customerId'] as String? ?? '';
        final customerName = data['customerName'] as String? ?? '';

        if (customerId.isEmpty) continue;

        if (!customerAppointmentCount.containsKey(customerId)) {
          customerAppointmentCount[customerId] = CustomerData(
            customerId: customerId,
            customerName: customerName,
            appointmentCount: 0,
            totalIncome: 0,
          );
        }

        customerAppointmentCount[customerId]!.appointmentCount++;
      }

      // دریافت فاکتورها برای محاسبه درآمد
      Query invoicesQuery = _firestore.collection('invoices');

      if (_selectedYear != null && _selectedYear != 'همه') {
        final yearInt = int.parse(_selectedYear!);
        final startOfYear = Jalali(yearInt, 1, 1).toDateTime();
        final endOfYear = Jalali(yearInt, 12, 29, 23, 59, 59).toDateTime();

        invoicesQuery = invoicesQuery
            .where('invoiceDate', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfYear))
            .where('invoiceDate', isLessThanOrEqualTo: Timestamp.fromDate(endOfYear));
      }

      final invoicesSnapshot = await invoicesQuery.get();
      final invoiceIds = invoicesSnapshot.docs.map((doc) => doc.id).toList();

      // دریافت پرداخت‌ها
      if (invoiceIds.isNotEmpty) {
        for (int i = 0; i < invoiceIds.length; i += 10) {
          final batch = invoiceIds.skip(i).take(10).toList();
          final paymentsSnapshot = await _firestore
              .collection('payments')
              .where('invoiceId', whereIn: batch)
              .get();

          for (var paymentDoc in paymentsSnapshot.docs) {
            final paymentData = paymentDoc.data() as Map<String, dynamic>?;
            if (paymentData == null) continue;

            final invoiceId = paymentData['invoiceId'] as String?;
            final amount = paymentData['amount'] as int? ?? 0;

            if (invoiceId != null) {
              final invoice = invoicesSnapshot.docs.firstWhere(
                    (doc) => doc.id == invoiceId,
                orElse: () => throw Exception('Invoice not found'),
              );

              if (invoice.exists) {
                final invoiceData = invoice.data() as Map<String, dynamic>?;
                if (invoiceData == null) continue;

                final customerId = invoiceData['customerId'] as String? ?? '';
                final customerName = invoiceData['customerName'] as String? ?? '';

                if (customerId.isEmpty) continue;

                if (!customerAppointmentCount.containsKey(customerId)) {
                  customerAppointmentCount[customerId] = CustomerData(
                    customerId: customerId,
                    customerName: customerName,
                    appointmentCount: 0,
                    totalIncome: 0,
                  );
                }

                customerAppointmentCount[customerId]!.totalIncome += amount;
              }
            }
          }
        }
      }

      // مرتب‌سازی
      final sortedByAppointments = customerAppointmentCount.values.toList()
        ..sort((a, b) => b.appointmentCount.compareTo(a.appointmentCount));

      final sortedByIncome = customerAppointmentCount.values.toList()
        ..sort((a, b) => b.totalIncome.compareTo(a.totalIncome));

      setState(() {
        _topCustomersByAppointments = sortedByAppointments.take(10).map((data) {
          return CustomerPerformance(
            name: data.customerName,
            value: data.appointmentCount,
            rank: sortedByAppointments.indexOf(data) + 1,
          );
        }).toList();

        _topCustomersByIncome = sortedByIncome.take(10).map((data) {
          return CustomerPerformance(
            name: data.customerName,
            value: data.totalIncome,
            rank: sortedByIncome.indexOf(data) + 1,
          );
        }).toList();
      });
    } catch (e) {
      debugPrint('خطا در بارگذاری مشتریان: $e');
    }
  }

  Future<void> _loadTimeData() async {
    try {
      Query appointmentsQuery = _firestore
          .collection('appointments')
          .where('status', whereNotIn: ['cancelled']);

      Query invoicesQuery = _firestore.collection('invoices');

      // 🔥 فیلتر سال برای تب دوم
      if (_selectedYear != null && _selectedYear != 'همه') {
        final yearInt = int.parse(_selectedYear!);
        final startOfYear = Jalali(yearInt, 1, 1).toDateTime();
        final endOfYear = Jalali(yearInt, 12, 29, 23, 59, 59).toDateTime();

        appointmentsQuery = appointmentsQuery
            .where('requestedDate', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfYear))
            .where('requestedDate', isLessThanOrEqualTo: Timestamp.fromDate(endOfYear));

        invoicesQuery = invoicesQuery
            .where('invoiceDate', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfYear))
            .where('invoiceDate', isLessThanOrEqualTo: Timestamp.fromDate(endOfYear));
      }

      final appointmentsSnapshot = await appointmentsQuery.get();
      final invoicesSnapshot = await invoicesQuery.get();
      final invoiceIds = invoicesSnapshot.docs.map((doc) => doc.id).toList();

      final incomeByDate = <String, int>{};

      if (invoiceIds.isNotEmpty) {
        for (int i = 0; i < invoiceIds.length; i += 10) {
          final batch = invoiceIds.skip(i).take(10).toList();
          final paymentsSnapshot = await _firestore
              .collection('payments')
              .where('invoiceId', whereIn: batch)
              .get();

          for (var doc in paymentsSnapshot.docs) {
            final paymentData = doc.data() as Map<String, dynamic>?;
            if (paymentData == null) continue;

            final paymentDate = paymentData['paymentDate'] as Timestamp?;
            if (paymentDate == null) continue;

            final jalali = Jalali.fromDateTime(paymentDate.toDate());
            final dateKey = '${jalali.year}-${jalali.month}-${jalali.day}';
            final amount = paymentData['amount'] as int? ?? 0;

            incomeByDate[dateKey] = (incomeByDate[dateKey] ?? 0) + amount;
          }
        }
      }

      // گروه‌بندی بر اساس سال، ماه، روز
      final yearData = <String, TimeData>{};
      final monthData = <String, TimeData>{};
      final dayData = <String, TimeData>{};

      for (var doc in appointmentsSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>?;
        if (data == null) continue;

        final timestamp = data['requestedDate'] as Timestamp?;
        if (timestamp == null) continue;

        final date = timestamp.toDate();
        final jalali = Jalali.fromDateTime(date);

        final yearKey = jalali.year.toString();
        final monthKey = '${jalali.year}-${jalali.month}';
        final dayKey = '${jalali.year}-${jalali.month}-${jalali.day}';

        // سال
        if (!yearData.containsKey(yearKey)) {
          yearData[yearKey] = TimeData(label: yearKey, appointments: 0, income: 0);
        }
        yearData[yearKey]!.appointments++;

        // ماه
        if (!monthData.containsKey(monthKey)) {
          monthData[monthKey] = TimeData(label: monthKey, appointments: 0, income: 0);
        }
        monthData[monthKey]!.appointments++;

        // روز
        if (!dayData.containsKey(dayKey)) {
          dayData[dayKey] = TimeData(label: dayKey, appointments: 0, income: 0);
        }
        dayData[dayKey]!.appointments++;
      }

      // افزودن درآمد
      incomeByDate.forEach((dateKey, income) {
        final parts = dateKey.split('-');
        final yearKey = parts[0];
        final monthKey = '${parts[0]}-${parts[1]}';

        if (yearData.containsKey(yearKey)) {
          yearData[yearKey]!.income += income;
        }
        if (monthData.containsKey(monthKey)) {
          monthData[monthKey]!.income += income;
        }
        if (dayData.containsKey(dateKey)) {
          dayData[dateKey]!.income += income;
        }
      });

      // مرتب‌سازی
      final sortedYears = yearData.values.toList()
        ..sort((a, b) => (b.appointments + b.income).compareTo(a.appointments + a.income));

      final sortedMonths = monthData.values.toList()
        ..sort((a, b) => (b.appointments + b.income).compareTo(a.appointments + a.income));

      final sortedDays = dayData.values.toList()
        ..sort((a, b) => (b.appointments + b.income).compareTo(a.appointments + a.income));

      setState(() {
        _topYears = sortedYears.take(5).map((data) {
          return TimePerformance(
            label: _formatYearLabel(data.label),
            appointments: data.appointments,
            income: data.income,
          );
        }).toList();

        _topMonths = sortedMonths.take(10).map((data) {
          return TimePerformance(
            label: _formatMonthLabel(data.label),
            appointments: data.appointments,
            income: data.income,
          );
        }).toList();

        _topDays = sortedDays.take(10).map((data) {
          return TimePerformance(
            label: _formatDayLabel(data.label),
            appointments: data.appointments,
            income: data.income,
          );
        }).toList();
      });
    } catch (e) {
      debugPrint('خطا در بارگذاری زمان‌ها: $e');
    }
  }

  Future<void> _loadServicesData() async {
    try {
      Query itemsQuery = _firestore.collection('invoice_items');

      if (_selectedYear != null && _selectedYear != 'همه') {
        final yearInt = int.parse(_selectedYear!);
        final startOfYear = Jalali(yearInt, 1, 1).toDateTime();
        final endOfYear = Jalali(yearInt, 12, 29, 23, 59, 59).toDateTime();

        final invoicesSnapshot = await _firestore
            .collection('invoices')
            .where('invoiceDate', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfYear))
            .where('invoiceDate', isLessThanOrEqualTo: Timestamp.fromDate(endOfYear))
            .get();

        final invoiceIds = invoicesSnapshot.docs.map((doc) => doc.id).toList();

        if (invoiceIds.isEmpty) {
          setState(() => _topServices = []);
          return;
        }

        final servicesData = <String, int>{};

        for (var invoiceId in invoiceIds) {
          final itemsSnapshot = await _firestore
              .collection('invoice_items')
              .where('invoiceId', isEqualTo: invoiceId)
              .get();

          for (var doc in itemsSnapshot.docs) {
            final serviceName = doc.data()['serviceName'] as String? ?? 'نامشخص';
            final quantity = doc.data()['quantity'] as int? ?? 0;
            servicesData[serviceName] = (servicesData[serviceName] ?? 0) + quantity;
          }
        }

        final sortedServices = servicesData.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));

        setState(() {
          _topServices = sortedServices.take(10).map((entry) {
            return ServicePerformance(
              name: entry.key,
              count: entry.value,
              rank: sortedServices.indexOf(entry) + 1,
            );
          }).toList();
        });
      } else {
        final itemsSnapshot = await itemsQuery.get();

        final servicesData = <String, int>{};

        for (var doc in itemsSnapshot.docs) {
          final data = doc.data() as Map<String, dynamic>?;
          if (data == null) continue;

          final serviceName = data['serviceName'] as String? ?? 'نامشخص';
          final quantity = data['quantity'] as int? ?? 0;
          servicesData[serviceName] = (servicesData[serviceName] ?? 0) + quantity;
        }

        final sortedServices = servicesData.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));

        setState(() {
          _topServices = sortedServices.take(10).map((entry) {
            return ServicePerformance(
              name: entry.key,
              count: entry.value,
              rank: sortedServices.indexOf(entry) + 1,
            );
          }).toList();
        });
      }
    } catch (e) {
      debugPrint('خطا در بارگذاری خدمات: $e');
    }
  }

  String _formatYearLabel(String yearKey) {
    return 'سال ${DateHelper.toPersianDigits(yearKey)}';
  }

  String _formatMonthLabel(String monthKey) {
    final parts = monthKey.split('-');
    final year = parts[0];
    final month = int.parse(parts[1]);
    const months = ['', 'فروردین', 'اردیبهشت', 'خرداد', 'تیر', 'مرداد', 'شهریور',
      'مهر', 'آبان', 'آذر', 'دی', 'بهمن', 'اسفند'];
    return '${months[month]} ${DateHelper.toPersianDigits(year)}';
  }

  String _formatDayLabel(String dayKey) {
    final parts = dayKey.split('-');
    final year = parts[0];
    final month = int.parse(parts[1]);
    final day = parts[2];
    const months = ['', 'فروردین', 'اردیبهشت', 'خرداد', 'تیر', 'مرداد', 'شهریور',
      'مهر', 'آبان', 'آذر', 'دی', 'بهمن', 'اسفند'];
    return '${DateHelper.toPersianDigits(day)} ${months[month]} ${DateHelper.toPersianDigits(year)}';
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
              _buildYearFilter(),
              _buildTabBar(),
              if (_isLoading)
                const Expanded(
                  child: Center(child: CircularProgressIndicator()),
                )
              else
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildCustomersTab(),
                      _buildTimeTab(),
                      _buildServicesTab(),
                    ],
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
          GestureDetector(
            onTap: () {},
            child: Container(width: 44, height: 44),
          ),
          const Text(
            'گزارش برترین‌ها',
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

  Widget _buildYearFilter() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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
        child: DropdownButton<String>(
          value: _selectedYear,
          isExpanded: true,
          icon: const Icon(Icons.arrow_drop_down_rounded, color: AppColors.primary),
          items: _availableYears.map((year) {
            return DropdownMenuItem(
              value: year,
              alignment: Alignment.centerRight,
              child: Text(
                year == 'همه' ? 'همه سال‌ها' : 'سال ${DateHelper.toPersianDigits(year)}',
                textAlign: TextAlign.right,
                style: const TextStyle(fontSize: 14),
              ),
            );
          }).toList(),
          onChanged: (value) {
            setState(() => _selectedYear = value);
            _loadAllData();
          },
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: TabBar(
        controller: _tabController,
        indicatorSize: TabBarIndicatorSize.tab,
        indicator: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(10),
        ),
        labelColor: Colors.white,
        unselectedLabelColor: AppColors.textSecondary,
        labelStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
        ),
        tabs: const [
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.people_outline, size: 18),
                SizedBox(width: 6),
                Text('مشتریان'),
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.access_time, size: 18),
                SizedBox(width: 6),
                Text('زمان'),
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.category_outlined, size: 18),
                SizedBox(width: 6),
                Text('خدمات'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomersTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          _buildTopCustomersCard(
            title: 'برترین‌ها بر اساس تعداد نوبت',
            data: _topCustomersByAppointments,
            isIncome: false,
            icon: Icons.event_note,
          ),
          const SizedBox(height: 20),
          _buildTopCustomersCard(
            title: 'برترین‌ها بر اساس درآمد',
            data: _topCustomersByIncome,
            isIncome: true,
            icon: Icons.account_balance_wallet,
          ),
        ],
      ),
    );
  }

  Widget _buildTimeTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          _buildTimeCard('برترین سال‌ها', _topYears, Icons.calendar_today),
          const SizedBox(height: 16),
          _buildTimeCard('برترین ماه‌ها', _topMonths, Icons.date_range),
          const SizedBox(height: 16),
          _buildTimeCard('برترین روزها', _topDays, Icons.today),
        ],
      ),
    );
  }

  Widget _buildServicesTab() {
    if (_topServices.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.category, size: 80, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              'داده‌ای یافت نشد',
              style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
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
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.workspace_premium,
                    color: AppColors.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'برترین خدمات',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ..._topServices.take(5).map((service) => _buildServiceCard(service)),
        ],
      ),
    );
  }

  Widget _buildTopCustomersCard({
    required String title,
    required List<CustomerPerformance> data,
    required bool isIncome,
    required IconData icon,
  }) {
    if (data.isEmpty) {
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
            'داده‌ای یافت نشد',
            style: TextStyle(color: Colors.grey.shade600),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    icon,
                    color: AppColors.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: Colors.grey.shade200),
          ...data.take(10).map((customer) => _buildCustomerItem(customer, isIncome)),
        ],
      ),
    );
  }

  Widget _buildCustomerItem(CustomerPerformance customer, bool isIncome) {
    final isFirst = customer.rank == 1;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade100),
        ),
      ),
      child: Row(
        children: [
          if (isFirst)
            Container(
              margin: const EdgeInsets.only(left: 12),
              child: const Icon(
                Icons.workspace_premium,
                color: Color(0xFFFFD700),
                size: 24,
              ),
            )
          else
            const SizedBox(width: 36),
          Expanded(
            child: Text(
              customer.name,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textPrimary,
                fontWeight: isFirst ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
          Row(
            children: [
              Text(
                isIncome
                    ? DateHelper.toPersianDigits(_formatNumber(customer.value))
                    : DateHelper.toPersianDigits(customer.value.toString()),
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: isFirst ? const Color(0xFFFFD700) : AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                isIncome ? 'تومان' : 'نوبت',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTimeCard(String title, List<TimePerformance> data, IconData icon) {
    if (data.isEmpty) {
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
            'داده‌ای یافت نشد',
            style: TextStyle(color: Colors.grey.shade600),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.info.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    icon,
                    color: AppColors.info,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: Colors.grey.shade200),
          ...data.take(5).map((time) => _buildTimeItem(time)),
        ],
      ),
    );
  }

  Widget _buildTimeItem(TimePerformance time) {
    // 🔥 تشخیص برترین بودن
    final isTopInOverall = _isTopPerformer(time);
    final showBadge = (_selectedYear == 'همه' && time == _topYears.first) ||
        (_selectedYear == 'همه' && time == _topMonths.first) ||
        (_selectedYear == 'همه' && time == _topDays.first) ||
        (_selectedYear != 'همه' && isTopInOverall);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade100),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (showBadge)
                Container(
                  margin: const EdgeInsets.only(left: 8),
                  child: const Icon(
                    Icons.workspace_premium,
                    color: Color(0xFFFFD700),
                    size: 20,
                  ),
                ),
              Expanded(
                child: Text(
                  time.label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: showBadge ? FontWeight.bold : FontWeight.normal,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.event, size: 16, color: AppColors.info),
                  const SizedBox(width: 4),
                  Text(
                    '${DateHelper.toPersianDigits(time.appointments.toString())} نوبت',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.info,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  const Icon(Icons.payments, size: 16, color: AppColors.success),
                  const SizedBox(width: 4),
                  Text(
                    DateHelper.toPersianDigits(_formatNumber(time.income)),
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.success,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 2),
                  Text(
                    'تومان',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 🔥 تابع کمکی برای تشخیص برترین بودن در کل
  bool _isTopPerformer(TimePerformance time) {
    // این تابع باید با داده‌های کل (همه سال‌ها) مقایسه کنه
    // فعلاً ساده‌سازی شده - می‌تونید بهینه‌ترش کنید
    return false;
  }

  Widget _buildServiceCard(ServicePerformance service) {
    final isFirst = service.rank == 1;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.grey.shade200,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          if (isFirst)
            Container(
              margin: const EdgeInsets.only(left: 12),
              child: const Icon(
                Icons.workspace_premium,
                color: Color(0xFFFFD700),
                size: 28,
              ),
            )
          else
            const SizedBox(width: 40),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  service.name,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: isFirst ? FontWeight.bold : FontWeight.normal,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.shopping_bag_outlined,
                      size: 14,
                      color: Colors.grey.shade600,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${DateHelper.toPersianDigits(service.count.toString())} عدد',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: isFirst
                  ? const Color(0xFFFFD700).withOpacity(0.15)
                  : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              DateHelper.toPersianDigits(service.count.toString()),
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: isFirst ? const Color(0xFFFFD700) : AppColors.textPrimary,
              ),
            ),
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

// Models
class CustomerPerformance {
  final String name;
  final int value;
  final int rank;

  CustomerPerformance({
    required this.name,
    required this.value,
    required this.rank,
  });
}

class CustomerData {
  final String customerId;
  final String customerName;
  int appointmentCount;
  int totalIncome;

  CustomerData({
    required this.customerId,
    required this.customerName,
    required this.appointmentCount,
    required this.totalIncome,
  });
}

class TimePerformance {
  final String label;
  final int appointments;
  final int income;

  TimePerformance({
    required this.label,
    required this.appointments,
    required this.income,
  });
}

class TimeData {
  final String label;
  int appointments;
  int income;

  TimeData({
    required this.label,
    required this.appointments,
    required this.income,
  });
}

class ServicePerformance {
  final String name;
  final int count;
  final int rank;

  ServicePerformance({
    required this.name,
    required this.count,
    required this.rank,
  });
}