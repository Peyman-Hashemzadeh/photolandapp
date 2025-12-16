import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shamsi_date/shamsi_date.dart';
import '../../../core/constants/colors.dart';
import '../../../core/utils/date_helper.dart';
import '../../../data/models/invoice_model.dart';
import '../../../data/models/appointment_model.dart';

class MonthlyPerformanceReportScreen extends StatefulWidget {
  const MonthlyPerformanceReportScreen({super.key});

  @override
  State<MonthlyPerformanceReportScreen> createState() => _MonthlyPerformanceReportScreenState();
}

class _MonthlyPerformanceReportScreenState extends State<MonthlyPerformanceReportScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  int _selectedYear = Jalali.now().year;
  int _selectedMonth = Jalali.now().month;
  bool _isLoading = false;

  int _appointmentsCount = 0;
  int _totalIncome = 0;
  int _totalPayments = 0;
  int _totalExpenses = 0;
  int _netProfit = 0;

  List<Map<String, dynamic>> _topCustomers = [];
  Map<String, int> _bestDay = {};
  Map<String, int> _servicesData = {};
  List<Map<String, dynamic>> _dailyChartData = [];

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  Future<void> _loadReport() async {
    setState(() => _isLoading = true);

    try {
      final startJalali = Jalali(_selectedYear, _selectedMonth, 1);
      final daysInMonth = startJalali.monthLength;
      final endJalali = Jalali(_selectedYear, _selectedMonth, daysInMonth);

      final startDateTime = startJalali.toDateTime();
      final endDateTime = DateTime(
        endJalali.toDateTime().year,
        endJalali.toDateTime().month,
        endJalali.toDateTime().day,
        23, 59, 59,
      );

      List<DateTime> monthDays = [];
      for (int i = 1; i <= daysInMonth; i++) {
        monthDays.add(Jalali(_selectedYear, _selectedMonth, i).toDateTime());
      }

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

      Map<String, Map<String, dynamic>> dailyDataMap = {};
      for (var day in monthDays) {
        final dayKey = '${day.year}-${day.month}-${day.day}';
        dailyDataMap[dayKey] = {
          'date': day,
          'income': 0,
          'expenses': 0,
          'appointments': 0,
        };
      }

      int totalIncome = 0;
      Map<String, int> servicesMap = {};
      Map<String, int> customerIncomeMap = {};

      if (appointmentIds.isNotEmpty) {
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

            final Map<String, List<Map<String, dynamic>>> itemsByInvoice = {};
            for (var doc in itemsSnapshot.docs) {
              final invoiceId = doc.data()['invoiceId'] as String;
              itemsByInvoice.putIfAbsent(invoiceId, () => []);
              itemsByInvoice[invoiceId]!.add(doc.data());
            }

            for (var invoiceDoc in invoicesSnapshot.docs) {
              final invoice = InvoiceModel.fromMap(invoiceDoc.data(), invoiceDoc.id);

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

              customerIncomeMap[invoice.customerName] =
                  (customerIncomeMap[invoice.customerName] ?? 0) + grandTotal;

              final invoiceDate = invoice.invoiceDate;
              final dayKey = '${invoiceDate.year}-${invoiceDate.month}-${invoiceDate.day}';
              if (dailyDataMap.containsKey(dayKey)) {
                dailyDataMap[dayKey]!['income'] =
                    (dailyDataMap[dayKey]!['income'] as int) + grandTotal;
                dailyDataMap[dayKey]!['appointments'] =
                    (dailyDataMap[dayKey]!['appointments'] as int) + 1;
              }
            }
          }
        }
      }

      final expensesSnapshot = await _firestore
          .collection('expense_documents')
          .where('documentDate', isGreaterThanOrEqualTo: Timestamp.fromDate(startDateTime))
          .where('documentDate', isLessThanOrEqualTo: Timestamp.fromDate(endDateTime))
          .get();

      int totalExpenses = 0;
      for (var doc in expensesSnapshot.docs) {
        final amount = (doc.data()['amount'] as int?) ?? 0;
        totalExpenses += amount;

        final expenseDate = (doc.data()['documentDate'] as Timestamp).toDate();
        final dayKey = '${expenseDate.year}-${expenseDate.month}-${expenseDate.day}';
        if (dailyDataMap.containsKey(dayKey)) {
          dailyDataMap[dayKey]!['expenses'] =
              (dailyDataMap[dayKey]!['expenses'] as int) + amount;
        }
      }

      final paymentsSnapshot = await _firestore
          .collection('payments')
          .where('paymentDate', isGreaterThanOrEqualTo: Timestamp.fromDate(startDateTime))
          .where('paymentDate', isLessThanOrEqualTo: Timestamp.fromDate(endDateTime))
          .get();

      int totalPayments = 0;
      for (var doc in paymentsSnapshot.docs) {
        final amount = (doc.data()['amount'] as int?) ?? 0;
        totalPayments += amount;
      }

      final netProfit = totalIncome - totalExpenses;

      final sortedCustomers = customerIncomeMap.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      final topCustomers = sortedCustomers.take(3).map((e) => {
        'name': e.key,
        'amount': e.value,
      }).toList();

      int maxDayIncome = 0;
      String bestDayDate = '';
      for (var entry in dailyDataMap.entries) {
        final income = entry.value['income'] as int;
        if (income > maxDayIncome) {
          maxDayIncome = income;
          bestDayDate = entry.key;
        }
      }

      Map<String, int> bestDay = {};
      if (bestDayDate.isNotEmpty) {
        final parts = bestDayDate.split('-');
        final date = DateTime(
          int.parse(parts[0]),
          int.parse(parts[1]),
          int.parse(parts[2]),
        );
        final jalaliDate = Jalali.fromDateTime(date);
        bestDay = {
          'day': jalaliDate.day,
          'amount': maxDayIncome,
        };
      }

      final dailyList = dailyDataMap.values.toList()
        ..sort((a, b) => (a['date'] as DateTime).compareTo(b['date'] as DateTime));

      final sortedServices = servicesMap.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      setState(() {
        _appointmentsCount = appointments.length;
        _totalIncome = totalIncome;
        _totalPayments = totalPayments;
        _totalExpenses = totalExpenses;
        _netProfit = netProfit;
        _topCustomers = topCustomers;
        _bestDay = bestDay;
        _servicesData = Map.fromEntries(sortedServices);
        _dailyChartData = dailyList;
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
              _buildMonthYearSelector(),
              if (_isLoading)
                const Expanded(child: Center(child: CircularProgressIndicator()))
              else
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        _buildLineChart(),
                        const SizedBox(height: 8),
                        _buildStatsCards(),
                        const SizedBox(height: 8),
                        _buildTopCustomers(),
                        const SizedBox(height: 8),
                        _buildBestDay(),
                        const SizedBox(height: 8),
                        _buildServicesCard(),
                        const SizedBox(height: 8),
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
            'گزارش عملکرد ماهانه',
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

  Widget _buildMonthYearSelector() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
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
      child: Row(
        children: [
          Expanded(
            child: _buildDropdownField(
             // label: 'سال',
              value: _selectedYear,
              items: List.generate(10, (index) {
                final year = Jalali.now().year - index;
                return DropdownMenuItem(
                  value: year,
                  child: Text(
                    DateHelper.toPersianDigits(year.toString()),
                    textAlign: TextAlign.center,
                  ),
                );
              }),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _selectedYear = value);
                  _loadReport();
                }
              },
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _buildDropdownField(
              //label: 'ماه',
              value: _selectedMonth,
              items: List.generate(12, (index) {
                final month = index + 1;
                return DropdownMenuItem(
                  value: month,
                  child: Text(
                    DateHelper.getPersianMonthName(month),
                    textAlign: TextAlign.center,
                  ),
                );
              }),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _selectedMonth = value);
                  _loadReport();
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownField({
   // required String label,
    required int? value,
    required List<DropdownMenuItem<int>> items,
    required ValueChanged<int?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
       //Text(
       //  label,
       //  style: TextStyle(
       //    fontSize: 12,
       //    color: AppColors.textSecondary,
       //  ),
       //),
        //const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: value,
              isExpanded: true,
              icon: const Icon(Icons.arrow_drop_down, color: AppColors.primary),
              //hint: Text(
               // 'انتخاب $label',
                //style: TextStyle(color: AppColors.textLight),
               // textAlign: TextAlign.center,
             // ),
              items: items,
              onChanged: onChanged,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLineChart() {
    if (_dailyChartData.isEmpty) return const SizedBox.shrink();

    int maxIncome = 0, maxExpenses = 0, maxAppointments = 0;

    for (var day in _dailyChartData) {
      final income = day['income'] as int;
      final expenses = day['expenses'] as int;
      final appointments = day['appointments'] as int;

      if (income > maxIncome) maxIncome = income;
      if (expenses > maxExpenses) maxExpenses = expenses;
      if (appointments > maxAppointments) maxAppointments = appointments;
    }

    final maxValue = maxIncome > maxExpenses ? maxIncome : maxExpenses;
    if (maxValue == 0) return const SizedBox.shrink();

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
            'نمودار عملکرد روزانه',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegend('درآمد', AppColors.success),
              const SizedBox(width: 16),
              _buildLegend('هزینه', AppColors.error),
              const SizedBox(width: 16),
              _buildLegend('نوبت', AppColors.info),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 200,
            child: CustomPaint(
              size: Size(MediaQuery.of(context).size.width - 80, 200),
              painter: LineChartPainter(
                data: _dailyChartData,
                maxIncome: maxValue,
                maxExpenses: maxValue,
                maxAppointments: maxAppointments,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegend(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
        ),
      ],
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
                'درآمد ماه',
                '${DateHelper.toPersianDigits(_formatNumber(_totalIncome))} تومان',
                Icons.trending_up,
                AppColors.success,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                'هزینه‌های ماه',
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
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
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
    final label = isProfit ? 'سود ماه:' : 'زیان ماه:';

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

  Widget _buildTopCustomers() {
    if (_topCustomers.isEmpty) return const SizedBox.shrink();

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
          const Row(
            children: [
              //Icon(Icons.emoji_events, color: Colors.amber, size: 20),
              SizedBox(width: 8),
              Text(
                'برترین مشتریان',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ..._topCustomers.asMap().entries.map((entry) {
            final index = entry.key;
            final customer = entry.value;
            final medals = ['🥇', '🥈', '🥉'];

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Text(medals[index], style: const TextStyle(fontSize: 20)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      customer['name'] as String,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  Text(
    '${DateHelper.toPersianDigits(_formatNumber(customer['amount'] as int))} ت',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildBestDay() {
    if (_bestDay.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary.withOpacity(0.1), AppColors.success.withOpacity(0.1)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.star, color: Colors.amber, size: 24),
              SizedBox(width: 8),
              Text(
                'برترین روز ماه',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '${DateHelper.toPersianDigits(_bestDay['day'].toString())} ${DateHelper.getPersianMonthName(_selectedMonth)}',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${DateHelper.toPersianDigits(_formatNumber(_bestDay['amount']!))} تومان',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.success,
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
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
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
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
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

class LineChartPainter extends CustomPainter {
  final List<Map<String, dynamic>> data;
  final int maxIncome;
  final int maxExpenses;
  final int maxAppointments;

  LineChartPainter({
    required this.data,
    required this.maxIncome,
    required this.maxExpenses,
    required this.maxAppointments,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final paintIncome = Paint()
      ..color = AppColors.success
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final paintExpenses = Paint()
      ..color = AppColors.error
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final paintAppointments = Paint()
      ..color = AppColors.info
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final pathIncome = Path();
    final pathExpenses = Path();
    final pathAppointments = Path();

    final stepX = size.width / (data.length - 1);

    for (int i = 0; i < data.length; i++) {
      final income = data[i]['income'] as int;
      final expenses = data[i]['expenses'] as int;
      final appointments = data[i]['appointments'] as int;

      final x = i * stepX;
      final yIncome = size.height - (income / maxIncome * size.height);
      final yExpenses = size.height - (expenses / maxExpenses * size.height);
      final yAppointments = size.height - (appointments / maxAppointments * size.height * 0.3);

      if (i == 0) {
        pathIncome.moveTo(x, yIncome);
        pathExpenses.moveTo(x, yExpenses);
        pathAppointments.moveTo(x, yAppointments);
      } else {
        pathIncome.lineTo(x, yIncome);
        pathExpenses.lineTo(x, yExpenses);
        pathAppointments.lineTo(x, yAppointments);
      }
    }

    canvas.drawPath(pathIncome, paintIncome);
    canvas.drawPath(pathExpenses, paintExpenses);
    canvas.drawPath(pathAppointments, paintAppointments);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}