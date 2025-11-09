import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../core/constants/colors.dart';

class DashboardCard extends StatelessWidget {
  final String title;
  final String svgAsset; // استفاده از SVG به جای آیکون
  final Color backgroundColor;
  final VoidCallback onTap;
  final int? badgeCount;

  const DashboardCard({
    super.key,
    required this.title,
    required this.svgAsset,
    required this.backgroundColor,
    required this.onTap,
    this.badgeCount,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 160, // عرض ثابت برای کوچک‌تر شدن
        height: 160,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // دایره با آیکون و Badge
            Stack(
              clipBehavior: Clip.none,
              children: [
                // دایره
                Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    color: backgroundColor.withOpacity(0.40),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: SvgPicture.asset(
                      svgAsset,
                      width: 28,
                      height: 28,
                      colorFilter: ColorFilter.mode(
                        backgroundColor,
                        BlendMode.srcIn,
                      ),
                    ),
                  ),
                ),

                // Badge روی گوشه دایره
                if (badgeCount != null && badgeCount! > 0)
                  Positioned(
                    top: -5,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        color: AppColors.badgeRed,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        badgeCount.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 12),

            // عنوان
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}