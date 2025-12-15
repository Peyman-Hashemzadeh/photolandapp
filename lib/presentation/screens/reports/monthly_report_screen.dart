import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shamsi_date/shamsi_date.dart';
import '../../../core/constants/colors.dart';
import '../../../core/utils/date_helper.dart';
import '../../../data/models/invoice_model.dart';
import '../../../data/models/payment_model.dart';
import 'dart:math' as math;

class MonthlyPerformanceReportScreen extends StatefulWidget {
  const MonthlyPerformanceReportScreen({super.key});

  @override
  State<MonthlyPerformanceReportScreen> createState() => _MonthlyPerformanceReportScreenState();
}

class _MonthlyPerformanceReportScreenState extends State<MonthlyPerformanceReportScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  late String _selectedYear;
  bool _isLoading = false;
  List<MonthlyData> _monthlyData = [];
  List<String> _availableYears = [];

  @override
  void initState() {
    super.initState();
    _selectedYear = Jalali.now().year.toString();
    _generateAvailableYears();
    _loadReport();
  }

  void _generateAvailableYears() {
    final currentYear = Jalali.now().year;
    _availableYears = [];
    for (int i = 0; i < 10; i++) {
      _availableYears.add((currentYear - i).toString());
    }
  }

  Future<void> _loadReport() async {
    setState(() => _isLoading = true);

    try {
      final yearInt = int.parse(_selectedYear);

      // محاسبه اول و آخر سال
      final startOfYear = Jalali(yearInt, 1, 1).toDateTime();
      final endOfYear = Jalali(yearInt, 12, 29, 23, 59, 59).toDateTime();

      // 🔥 فقط ۲ Query به جای ۲۴ Query!
      final paymentsSnapshot = await _firestore
          .collection('payments')
          .where('paymentDate', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfYear))
          .where('paymentDate', isLessThanOrEqualTo: Timestamp.fromDate(endOfYear))
          .get();

      final expensesSnapshot = await _firestore
          .collection('expense_documents')
          .where('documentDate', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfYear))
          .where('documentDate', isLessThanOrEqualTo: Timestamp.fromDate(endOfYear))
          .get();

      // 🔥 دسته‌بندی در کلاینت (سریع!)
      final monthlyIncome = <int, int>{};
      final monthlyExpense = <int, int>{};

      // گروه‌بندی درآمدها
      for (var doc in paymentsSnapshot.docs) {
        final paymentDate = (doc.data()['paymentDate'] as Timestamp).toDate();
        final jalaliDate = Jalali.fromDateTime(paymentDate);
        final month = jalaliDate.month;
        final amount = (doc.data()['amount'] as int?) ?? 0;

        monthlyIncome[month] = (monthlyIncome[month] ?? 0) + amount;
      }

      // گروه‌بندی هزینه‌ها
      for (var doc in expensesSnapshot.docs) {
        final documentDate = (doc.data()['documentDate'] as Timestamp).toDate();
        final jalaliDate = Jalali.fromDateTime(documentDate);
        final month = jalaliDate.month;
        final amount = (doc.data()['amount'] as int?) ?? 0;

        monthlyExpense[month] = (monthlyExpense[month] ?? 0) + amount;
      }

      // ساخت لیست ماه‌ها
      final monthlyDataList = <MonthlyData>[];
      for (int month = 1; month <= 12; month++) {
        monthlyDataList.add(MonthlyData(
          month: month,
          monthName: _getMonthName(month),
          income: monthlyIncome[month] ?? 0,
          expense: monthlyExpense[month] ?? 0,
        ));
      }

      setState(() {
        _monthlyData = monthlyDataList;
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

  String _getMonthName(int month) {
    const months = [
      '', 'فروردین', 'اردیبهشت', 'خرداد', 'تیر', 'مرداد', 'شهریور',
      'مهر', 'آبان', 'آذر', 'دی', 'بهمن', 'اسفند'
    ];
    return months[month];
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
              if (_isLoading)
                const Expanded(
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_monthlyData.every((m) => m.income == 0 && m.expense == 0))
                _buildEmptyState()
              else
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        const SizedBox(height: 20),
                        _buildBarChart(),
                        const SizedBox(height: 24),
                        _buildMonthlyTable(),
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
          GestureDetector(
            onTap: () {},
            child: Container(width: 44, height: 44),
          ),
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
                'سال ${DateHelper.toPersianDigits(year)}',
                textAlign: TextAlign.right,
                style: const TextStyle(fontSize: 14),
              ),
            );
          }).toList(),
          onChanged: (value) {
            if (value != null) {
              setState(() => _selectedYear = value);
              _loadReport();
            }
          },
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Expanded(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bar_chart, size: 80, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              'داده‌ای برای نمایش وجود ندارد',
              style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBarChart() {
    final maxValue = _monthlyData.fold<int>(
      0,
          (max, data) => math.max(max, math.max(data.income, data.expense)),
    );

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegendItem('درآمد', AppColors.success),
              const SizedBox(width: 24),
              _buildLegendItem('هزینه', AppColors.error.withOpacity(0.7)),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 280,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              reverse: true,
              child: Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 8, left: 8, right: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: _monthlyData.map((data) {
                    return _buildBarPair(data, maxValue);
                  }).toList(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildBarPair(MonthlyData data, int maxValue) {
    const barWidth = 20.0;
    const spacing = 4.0;
    const pairSpacing = 16.0;

    return Padding(
      padding: const EdgeInsets.only(left: pairSpacing),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          // میله‌ها
          SizedBox(
            height: 220,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // میله درآمد (سبز)
                _buildBar(
                  data.income,
                  maxValue,
                  AppColors.success,
                  barWidth,
                ),
                const SizedBox(width: spacing),
                // میله هزینه (قرمز)
                _buildBar(
                  data.expense,
                  maxValue,
                  AppColors.error.withOpacity(0.7),
                  barWidth,
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // نام ماه
          SizedBox(
            width: barWidth * 2 + spacing,
            child: Text(
              data.monthName,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 10.5,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBar(int value, int maxValue, Color color, double width) {
    final height = maxValue > 0 ? (value / maxValue) * 220 : 0.0;

    return Container(
      width: width,
      height: height > 0 ? height : 0,
      decoration: BoxDecoration(
        color: color,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
      ),
    );
  }

  Widget _buildMonthlyTable() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
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
          // هدر جدول
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.grey.shade200),
              ),
            ),
            child: const Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Text(
                    'ماه',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'درآمد',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'هزینه',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'اختلاف',
                    textAlign: TextAlign.left,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // ردیف‌های جدول
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _monthlyData.length,
            separatorBuilder: (context, index) => Divider(
              height: 1,
              color: Colors.grey.shade100,
            ),
            itemBuilder: (context, index) {
              final data = _monthlyData[index];
              final difference = data.income - data.expense;

              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Text(
                        data.monthName,
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        DateHelper.toPersianDigits(_formatNumber(data.income)),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.success,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        DateHelper.toPersianDigits(_formatNumber(data.expense)),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.error.withOpacity(0.8),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        DateHelper.toPersianDigits(_formatNumber(difference)),
                        textAlign: TextAlign.left,
                        textDirection: TextDirection.ltr,
                        style: TextStyle(
                          fontSize: 13,
                          color: difference >= 0 ? AppColors.success : AppColors.error,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          // جمع کل
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: Colors.grey.shade300, width: 2),
              ),
              color: Colors.grey.shade50,
            ),
            child: Row(
              children: [
                const Expanded(
                  flex: 2,
                  child: Text(
                    'جمع کل',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    DateHelper.toPersianDigits(
                      _formatNumber(_monthlyData.fold(0, (sum, m) => sum + m.income)),
                    ),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.success,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    DateHelper.toPersianDigits(
                      _formatNumber(_monthlyData.fold(0, (sum, m) => sum + m.expense)),
                    ),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.error.withOpacity(0.8),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Builder(
                    builder: (context) {
                      final totalIncome = _monthlyData.fold(0, (sum, m) => sum + m.income);
                      final totalExpense = _monthlyData.fold(0, (sum, m) => sum + m.expense);
                      final totalDiff = totalIncome - totalExpense;

                      return Text(
                        DateHelper.toPersianDigits(_formatNumber(totalDiff)),
                        textAlign: TextAlign.left,
                        textDirection: TextDirection.ltr,
                        style: TextStyle(
                          fontSize: 14,
                          color: totalDiff >= 0 ? AppColors.success : AppColors.error,
                          fontWeight: FontWeight.bold,
                        ),
                      );
                    },
                  ),
                ),
              ],
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

    return number < 0 ? '-${buffer.toString()}' : buffer.toString();
  }
}

class MonthlyData {
  final int month;
  final String monthName;
  final int income;
  final int expense;

  MonthlyData({
    required this.month,
    required this.monthName,
    required this.income,
    required this.expense,
  });

  int get difference => income - expense;
}