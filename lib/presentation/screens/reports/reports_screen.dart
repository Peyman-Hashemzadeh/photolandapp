import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../core/constants/colors.dart';
import 'performance_reports_menu_screen.dart';
import 'customer_reports_menu_screen.dart';
import 'service_performance_report_screen.dart';
import 'top_performers_report_screen.dart';
import 'expense_report_screen.dart'; // فرض می‌کنیم این فایل وجود دارد

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

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
                  child: Wrap(
                    alignment: WrapAlignment.start,
                    spacing: 16,
                    runSpacing: 16,
                    children: [
                      // گزارشات عملکردی (با badge)
                      _buildReportCard(
                        context: context,
                        title: 'گزارشات عملکردی',
                        svgAsset: 'assets/images/icons/chart-line.svg',
                        backgroundColor: const Color(0xFF5CADD8),
                        badgeCount: 6,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const PerformanceReportsMenuScreen(),
                            ),
                          );
                        },
                      ),

                      // گزارشات مشتری (با badge)
                      _buildReportCard(
                        context: context,
                        title: 'گزارشات مشتری',
                        svgAsset: 'assets/images/icons/chart-user.svg',
                        backgroundColor: const Color(0xFF9C7DD8),
                        badgeCount: 3,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const CustomerReportsMenuScreen(),
                            ),
                          );
                        },
                      ),

                      // گزارش عملکرد خدمات (مستقیم)
                      _buildReportCard(
                        context: context,
                        title: 'گزارش عملکرد خدمات',
                        svgAsset: 'assets/images/icons/camera.svg',
                        backgroundColor: const Color(0xFF7DD8B8),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const ServicePerformanceReportScreen(),
                            ),
                          );
                        },
                      ),

                      // گزارش برترین‌ها (مستقیم)
                      _buildReportCard(
                        context: context,
                        title: 'گزارش برترین‌ها',
                        svgAsset: 'assets/images/icons/trophy.svg',
                        backgroundColor: const Color(0xFFECC454),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const TopPerformersReportScreen(),
                            ),
                          );
                        },
                      ),

                      // گزارش هزینه‌ها (مستقیم)
                      _buildReportCard(
                        context: context,
                        title: 'گزارش هزینه‌ها',
                        svgAsset: 'assets/images/icons/coins.svg',
                        backgroundColor: const Color(0xFFE89CC2),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const ExpenseReportScreen(),
                            ),
                          );
                        },
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
            'گزارشات',
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
    int? badgeCount, // برای نمایش تعداد گزارشات
  }) {
    final screenWidth = MediaQuery.of(context).size.width;
    final cardWidth = (screenWidth - 56) / 2;

    return GestureDetector(
      onTap: onTap,
      child: Stack(
        children: [
          Container(
            width: cardWidth,
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

          // Badge برای نمایش تعداد گزارشات
          if (badgeCount != null)
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  '$badgeCount گزارش',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: backgroundColor,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}