import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../core/constants/colors.dart';
import 'daily_performance_report_screen.dart';
import 'weekly_performance_report_screen.dart';
import 'monthly_performance_report_screen.dart';
import 'yearly_performance_report_screen.dart';
import 'monthly_report_screen.dart';
import 'yearly_report_screen.dart';

class PerformanceReportsMenuScreen extends StatelessWidget {
  const PerformanceReportsMenuScreen({super.key});

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
              _buildHeader(context),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      // ردیف اول - 2 کارت
                      Row(
                        children: [
                          Expanded(
                            child: _buildReportCard(
                              context: context,
                              title: 'گزارش عملکرد روزانه',
                              svgAsset: 'assets/images/icons/calendar-day.svg',
                              backgroundColor: const Color(0xFF5CADD8),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const DailyPerformanceReportScreen(),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildReportCard(
                              context: context,
                              title: 'گزارش عملکرد هفتگی',
                              svgAsset: 'assets/images/icons/calendar-week.svg',
                              backgroundColor: const Color(0xFF7DD8B8),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const WeeklyPerformanceReportScreen(),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // ردیف دوم - 2 کارت
                      Row(
                        children: [
                          Expanded(
                            child: _buildReportCard(
                              context: context,
                              title: 'گزارش عملکرد ماهانه',
                              svgAsset: 'assets/images/icons/calendar-days.svg',
                              backgroundColor: const Color(0xFF8BA3D8),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const MonthlyPerformanceReportScreen(),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildReportCard(
                              context: context,
                              title: 'گزارش عملکرد سالانه',
                              svgAsset: 'assets/images/icons/calendar-star.svg',
                              backgroundColor: const Color(0xFF9C7DD8),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const YearlyPerformanceReportScreen(),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // ردیف سوم - 2 کارت
                      Row(
                        children: [
                          Expanded(
                            child: _buildReportCard(
                              context: context,
                              title: 'گزارش ماهانه',
                              svgAsset: 'assets/images/icons/calendar.svg',
                              backgroundColor: const Color(0xFFE89CC2),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const MonthlyReportScreen(),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildReportCard(
                              context: context,
                              title: 'گزارش سالانه',
                              svgAsset: 'assets/images/icons/calendar-range.svg',
                              backgroundColor: const Color(0xFFECC454),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const YearlyReportScreen(),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
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

  Widget _buildHeader(BuildContext context) {
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
            'گزارشات عملکردی',
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

  Widget _buildReportCard({
    required BuildContext context,
    required String title,
    required String svgAsset,
    required Color backgroundColor,
    required VoidCallback onTap,
  }) {
    final screenWidth = MediaQuery.of(context).size.width;
    final cardWidth = (screenWidth - 56) / 2;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: cardWidth * 1.1,
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: backgroundColor.withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: SvgPicture.asset(
                  svgAsset,
                  width: 32,
                  height: 32,
                  colorFilter: const ColorFilter.mode(
                    Colors.white,
                    BlendMode.srcIn,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  height: 1.5,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}