import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shamsi_date/shamsi_date.dart';
import '../../../core/constants/colors.dart';
import '../../../core/utils/date_helper.dart';
import 'dart:math' as math;

class ServicePerformanceReportScreen extends StatefulWidget {
  const ServicePerformanceReportScreen({super.key});

  @override
  State<ServicePerformanceReportScreen> createState() => _ServicePerformanceReportScreenState();
}

class _ServicePerformanceReportScreenState extends State<ServicePerformanceReportScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? _selectedYear;
  bool _isLoading = false;
  Map<String, int> _servicesData = {};
  int _totalCount = 0;

  final List<String> _availableYears = _generateYears();

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  static List<String> _generateYears() {
    final currentYear = Jalali.now().year;
    final years = <String>['همه'];
    for (int i = 0; i < 10; i++) {
      years.add((currentYear - i).toString());
    }
    return years;
  }

  Future<void> _loadReport() async {
    setState(() => _isLoading = true);

    try {
      final servicesData = <String, int>{};

      // دریافت تمام آیتم‌های فاکتور
      Query query = _firestore.collection('invoice_items');

      // اگر سال انتخاب شده باشد، فیلتر کنیم
      if (_selectedYear != null && _selectedYear != 'همه') {
        final selectedYearInt = int.parse(_selectedYear!);

        // محاسبه اول و آخر سال شمسی
        final startOfYear = Jalali(selectedYearInt, 1, 1).toDateTime();
        final endOfYear = Jalali(selectedYearInt, 12, 29).toDateTime();

        // ابتدا فاکتورهای آن سال را بگیریم
        final invoicesSnapshot = await _firestore
            .collection('invoices')
            .where('invoiceDate', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfYear))
            .where('invoiceDate', isLessThanOrEqualTo: Timestamp.fromDate(endOfYear))
            .get();

        final invoiceIds = invoicesSnapshot.docs.map((doc) => doc.id).toList();

        if (invoiceIds.isEmpty) {
          setState(() {
            _servicesData = {};
            _totalCount = 0;
            _isLoading = false;
          });
          return;
        }

        // دریافت آیتم‌های مربوط به این فاکتورها
        for (var invoiceId in invoiceIds) {
          final itemsSnapshot = await _firestore
              .collection('invoice_items')
              .where('invoiceId', isEqualTo: invoiceId)
              .get();

          for (var doc in itemsSnapshot.docs) {
            final data = doc.data();
            final serviceName = data['serviceName'] as String? ?? 'نامشخص';
            final quantity = data['quantity'] as int? ?? 0;

            servicesData[serviceName] = (servicesData[serviceName] ?? 0) + quantity;
          }
        }
      } else {
        // دریافت تمام آیتم‌ها
        final snapshot = await query.get();

        for (var doc in snapshot.docs) {
          final data = doc.data() as Map<String, dynamic>?;
          final serviceName = data?['serviceName'] as String? ?? 'نامشخص';
          final quantity = data?['quantity'] as int? ?? 0;

          servicesData[serviceName] = (servicesData[serviceName] ?? 0) + quantity;
        }
      }

      // مرتب‌سازی بر اساس تعداد (نزولی)
      final sortedEntries = servicesData.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      final sortedMap = Map<String, int>.fromEntries(sortedEntries);

      final total = servicesData.values.fold(0, (sum, count) => sum + count);

      setState(() {
        _servicesData = sortedMap;
        _totalCount = total;
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
              _buildYearFilter(),
              if (_isLoading)
                const Expanded(
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_servicesData.isEmpty)
                _buildEmptyState()
              else
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        const SizedBox(height: 20),
                        _buildPieChart(),
                        const SizedBox(height: 24),
                        _buildServicesList(),
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
            'گزارش عملکرد خدمات',
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
          value: _selectedYear ?? 'همه',
          isExpanded: true,
          icon: const Icon(Icons.arrow_drop_down_rounded, color: AppColors.primary),
          hint: const Text('انتخاب سال', textAlign: TextAlign.right),
          items: _availableYears.map((year) {
            return DropdownMenuItem(
              value: year,
              alignment: Alignment.centerRight,
              child: Text(
                DateHelper.toPersianDigits(year),
                textAlign: TextAlign.right,
                style: const TextStyle(fontSize: 14),
              ),
            );
          }).toList(),
          onChanged: (value) {
            setState(() {
              _selectedYear = value == 'همه' ? null : value;
            });
            _loadReport();
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

  Widget _buildPieChart() {
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
        children: [
          Text(
            'مجموع: ${DateHelper.toPersianDigits(_totalCount.toString())} مورد',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 250,
            child: CustomPaint(
              size: const Size(250, 250),
              painter: _PieChartPainter(
                data: _servicesData,
                totalCount: _totalCount,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServicesList() {
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
                  'نام خدمت',
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
              final percentage = (_totalCount > 0)
                  ? (entry.value / _totalCount * 100).toStringAsFixed(1)
                  : '0.0';

              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: _getColorForIndex(index),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
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
                    Row(
                      children: [
                        Text(
                          '(${DateHelper.toPersianDigits(percentage)}%)',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),

                        const SizedBox(width: 4),
                        Text(
                          DateHelper.toPersianDigits(entry.value.toString()),
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
            },
          ),
        ],
      ),
    );
  }

  Color _getColorForIndex(int index) {
    final colors = [
      AppColors.primary,
      AppColors.success,
      AppColors.warning,
      AppColors.error,
      AppColors.info,
      Colors.purple,
      Colors.orange,
      Colors.teal,
      Colors.pink,
      Colors.indigo,
    ];
    return colors[index % colors.length];
  }
}

class _PieChartPainter extends CustomPainter {
  final Map<String, int> data;
  final int totalCount;

  _PieChartPainter({
    required this.data,
    required this.totalCount,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (totalCount == 0 || data.isEmpty) return;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;

    double startAngle = -math.pi / 2;

    final colors = [
      AppColors.primary,
      AppColors.success,
      AppColors.warning,
      AppColors.error,
      AppColors.info,
      Colors.purple,
      Colors.orange,
      Colors.teal,
      Colors.pink,
      Colors.indigo,
    ];

    int colorIndex = 0;

    for (var entry in data.entries) {
      final sweepAngle = (entry.value / totalCount) * 2 * math.pi;

      final paint = Paint()
        ..color = colors[colorIndex % colors.length]
        ..style = PaintingStyle.fill;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        true,
        paint,
      );

      // 🆕 محاسبه موقعیت وسط هر قسمت برای نمایش متن
      final middleAngle = startAngle + (sweepAngle / 2);
      final textRadius = radius * 0.7; // فاصله از مرکز (70% شعاع)

      final textX = center.dx + textRadius * math.cos(middleAngle);
      final textY = center.dy + textRadius * math.sin(middleAngle);

      // 🆕 رسم متن تعداد
      final textSpan = TextSpan(
        text: entry.value.toString(),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.bold,
          fontFamily: 'Vazirmatn',
        ),
      );

      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.rtl,
        textAlign: TextAlign.center,
      );

      textPainter.layout();

      // قرار دادن متن در وسط بخش
      textPainter.paint(
        canvas,
        Offset(
          textX - (textPainter.width / 2),
          textY - (textPainter.height / 2),
        ),
      );

      startAngle += sweepAngle;
      colorIndex++;
    }

    // دایره سفید وسط برای ایجاد حلقه
   //final innerPaint = Paint()
   //  ..color = Colors.white
   //  ..style = PaintingStyle.fill;

   //canvas.drawCircle(center, radius * 0.5, innerPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}