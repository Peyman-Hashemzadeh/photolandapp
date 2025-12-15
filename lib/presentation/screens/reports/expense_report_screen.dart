import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shamsi_date/shamsi_date.dart';
import 'package:persian_datetime_picker/persian_datetime_picker.dart';
import 'dart:math' as math;
import '../../../core/constants/colors.dart';
import '../../../core/utils/date_helper.dart';
import '../../../data/models/expense_document_model.dart';

class ExpenseReportScreen extends StatefulWidget {
  const ExpenseReportScreen({super.key});

  @override
  State<ExpenseReportScreen> createState() => _ExpenseReportScreenState();
}

class _ExpenseReportScreenState extends State<ExpenseReportScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  late Jalali _startDate;
  late Jalali _endDate;
  bool _isLoading = false;

  int _totalExpenses = 0;
  int _expenseCount = 0;
  Map<String, int> _expensesByType = {}; // نام هزینه : مبلغ کل
  List<Color> _chartColors = [];

  @override
  void initState() {
    super.initState();
    // پیش‌فرض: ماه جاری
    final now = Jalali.now();
    _startDate = Jalali(now.year, now.month, 1);
    _endDate = Jalali(now.year, now.month, now.monthLength);
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

      // Query بهینه: فقط یک‌بار از Firestore می‌خونیم
      final snapshot = await _firestore
          .collection('expense_documents')
          .where('documentDate', isGreaterThanOrEqualTo: Timestamp.fromDate(startDateTime))
          .where('documentDate', isLessThanOrEqualTo: Timestamp.fromDate(endDateTime))
          .get();

      // پردازش داده‌ها در سمت کلاینت
      int totalExpenses = 0;
      Map<String, int> expensesByType = {};

      for (var doc in snapshot.docs) {
        final expenseDoc = ExpenseDocumentModel.fromMap(doc.data(), doc.id);

        totalExpenses += expenseDoc.amount;

        // گروه‌بندی بر اساس نام هزینه
        expensesByType[expenseDoc.expenseName] =
            (expensesByType[expenseDoc.expenseName] ?? 0) + expenseDoc.amount;
      }

      // مرتب‌سازی بر اساس مبلغ (نزولی)
      final sortedExpenses = expensesByType.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      // تولید رنگ‌های متنوع برای نمودار
      final colors = _generateColors(sortedExpenses.length);

      setState(() {
        _totalExpenses = totalExpenses;
        _expenseCount = snapshot.docs.length;
        _expensesByType = Map.fromEntries(sortedExpenses);
        _chartColors = colors;
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

  // تولید رنگ‌های متنوع
  List<Color> _generateColors(int count) {
    if (count == 0) return [];

    final baseColors = [
      const Color(0xFF5CADD8),
      const Color(0xFF7DD8B8),
      const Color(0xFF8BA3D8),
      const Color(0xFF9C7DD8),
      const Color(0xFFE89CC2),
      const Color(0xFFECC454),
      const Color(0xFFFF6B6B),
      const Color(0xFF4ECDC4),
      const Color(0xFFFF8B94),
      const Color(0xFFA8E6CF),
    ];

    List<Color> colors = [];
    for (int i = 0; i < count; i++) {
      colors.add(baseColors[i % baseColors.length]);
    }
    return colors;
  }

  // انتخاب بازه ماه جاری
  void _selectCurrentMonth() {
    final now = Jalali.now();
    setState(() {
      _startDate = Jalali(now.year, now.month, 1);
      _endDate = Jalali(now.year, now.month, now.monthLength);
    });
    _loadReport();
  }

  // انتخاب تاریخ شروع
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
              textTheme: Theme.of(context).textTheme.copyWith(
                bodySmall: const TextStyle(
                  fontFamily: 'Vazirmatn',
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
                labelSmall: const TextStyle(
                  fontFamily: 'Vazirmatn',
                  fontSize: 12,
                ),
                bodyMedium: const TextStyle(fontFamily: 'Vazirmatn'),
              ),
              appBarTheme: const AppBarTheme(
                titleTextStyle: TextStyle(fontFamily: 'Vazirmatn', fontSize: 18),
              ),
            ),
            child: child!,
          ),
        );
      },
    );

    if (picked != null) {
      setState(() {
        _startDate = picked;
        // اگر تاریخ شروع بعد از پایان شد، پایان رو تنظیم کن
        if (_startDate.toDateTime().isAfter(_endDate.toDateTime())) {
          _endDate = _startDate;
        }
      });
      _loadReport();
    }
  }

  // انتخاب تاریخ پایان
  Future<void> _selectEndDate() async {
    final picked = await showPersianDatePicker(
      context: context,
      initialDate: _endDate,
      firstDate: _startDate,
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
              textTheme: Theme.of(context).textTheme.copyWith(
                bodySmall: const TextStyle(
                  fontFamily: 'Vazirmatn',
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
                labelSmall: const TextStyle(
                  fontFamily: 'Vazirmatn',
                  fontSize: 12,
                ),
                bodyMedium: const TextStyle(fontFamily: 'Vazirmatn'),
              ),
              appBarTheme: const AppBarTheme(
                titleTextStyle: TextStyle(fontFamily: 'Vazirmatn', fontSize: 18),
              ),
            ),
            child: child!,
          ),
        );
      },
    );

    if (picked != null) {
      setState(() => _endDate = picked);
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
              _buildDateRangeSelector(),
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
                        if (_expensesByType.isNotEmpty) ...[
                          _buildPieChart(),
                          const SizedBox(height: 16),
                          _buildExpensesTable(),
                        ] else
                          _buildEmptyState(),
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
            'گزارش هزینه‌ها',
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

  Widget _buildDateRangeSelector() {
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
      child: Column(
        children: [
          Row(
            children: [
              // تاریخ شروع
              Expanded(
                child: GestureDetector(
                  onTap: _selectStartDate,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Icon(Icons.calendar_today, size: 16, color: AppColors.primary),
                        Expanded(
                          child: Text(
                            DateHelper.formatPersianDate(_startDate),
                            textAlign: TextAlign.left,
                            style: const TextStyle(fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Text('تا', style: TextStyle(fontSize: 13)),
              ),
              // تاریخ پایان
              Expanded(
                child: GestureDetector(
                  onTap: _selectEndDate,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Icon(Icons.calendar_today, size: 16, color: AppColors.primary),
                        Expanded(
                          child: Text(
                            DateHelper.formatPersianDate(_endDate),
                            textAlign: TextAlign.left,
                            style: const TextStyle(fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // دکمه ماه جاری
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _selectCurrentMonth,
              icon: const Icon(Icons.update, size: 18),
              label: const Text('ماه جاری'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary.withOpacity(0.1),
                foregroundColor: AppColors.primary,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCards() {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            'تعداد هزینه',
            '${DateHelper.toPersianDigits(_expenseCount.toString())} مورد',
            Icons.receipt_long,
            AppColors.info,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            'مجموع هزینه',
            '${DateHelper.toPersianDigits(_formatNumber(_totalExpenses))} تومان',
            Icons.trending_down,
            AppColors.error,
          ),
        ),
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

  Widget _buildPieChart() {
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
            'نمودار تفکیک هزینه‌ها',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 20),
          // نمودار دایره‌ای
          Center(
            child: SizedBox(
              width: 200,
              height: 200,
              child: CustomPaint(
                painter: PieChartPainter(
                  data: _expensesByType,
                  colors: _chartColors,
                  total: _totalExpenses,
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          // راهنمای رنگ‌ها
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: _expensesByType.entries.toList().asMap().entries.map((entry) {
              final index = entry.key;
              final expenseEntry = entry.value;
              final percentage = (_totalExpenses > 0)
                  ? ((expenseEntry.value / _totalExpenses) * 100).toStringAsFixed(1)
                  : '0';

              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: _chartColors[index],
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${expenseEntry.key} (${DateHelper.toPersianDigits(percentage)}%)',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildExpensesTable() {
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
          // هدر جدول
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                Expanded(
                  flex: 2,
                  child: Text(
                    'نوع هزینه',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    'مبلغ',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    'درصد',
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
            itemCount: _expensesByType.length,
            separatorBuilder: (context, index) => Divider(
              height: 1,
              color: Colors.grey.shade100,
            ),
            itemBuilder: (context, index) {
              final entry = _expensesByType.entries.elementAt(index);
              final percentage = (_totalExpenses > 0)
                  ? ((entry.value / _totalExpenses) * 100).toStringAsFixed(1)
                  : '0';

              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // نام هزینه
                    Expanded(
                      flex: 2,
                      child: Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: _chartColors[index],
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              entry.key,
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textPrimary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // مبلغ
                    Expanded(
                      child: Text(
                        DateHelper.toPersianDigits(_formatNumber(entry.value)),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppColors.error,
                        ),
                      ),
                    ),
                    // درصد
                    Expanded(
                      child: Text(
                        '${DateHelper.toPersianDigits(percentage)}%',
                        textAlign: TextAlign.left,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: _chartColors[index],
                        ),
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

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(40),
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
          Icon(Icons.receipt_long, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            'هزینه‌ای در این بازه زمانی ثبت نشده است',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
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

// نقاش نمودار دایره‌ای
class PieChartPainter extends CustomPainter {
  final Map<String, int> data;
  final List<Color> colors;
  final int total;

  PieChartPainter({
    required this.data,
    required this.colors,
    required this.total,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty || total == 0) return;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;

    double startAngle = -math.pi / 2; // شروع از بالا

    data.entries.toList().asMap().entries.forEach((entry) {
      final index = entry.key;
      final expenseEntry = entry.value;

      final sweepAngle = (expenseEntry.value / total) * 2 * math.pi;

      final paint = Paint()
        ..color = colors[index]
        ..style = PaintingStyle.fill;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        true,
        paint,
      );

      // خط جداکننده سفید
      final borderPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        true,
        borderPaint,
      );

      startAngle += sweepAngle;
    });

    // دایره سفید وسط (برای Donut Chart)
    final innerPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, radius * 0.5, innerPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}