import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../../core/constants/colors.dart';

class CurvedHeader extends StatelessWidget {
  final double height;
  final Widget? child;

  const CurvedHeader({
    super.key,
    this.height = 200,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      child: Stack(
        children: [
          // 🎨 لایه پس‌زمینه با گرادیانت شاد
          Container(
            height: height,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF89CFF0), // آبی پاستلی
                  Color(0xFF9B59D0), // بنفش ملایم
                  Color(0xFFFF9CEE), // صورتی روشن
                ],
              ),
            ),
          ),

          // ⭐ ستاره‌های تزیینی
          Positioned(
            top: 40,
            right: 30,
            child: _buildStar(20, Colors.white.withOpacity(0.3)),
          ),
          Positioned(
            top: 80,
            right: 100,
            child: _buildStar(15, Colors.white.withOpacity(0.4)),
          ),
          Positioned(
            top: 50,
            left: 50,
            child: _buildStar(18, Colors.white.withOpacity(0.35)),
          ),
          Positioned(
            top: 100,
            left: 120,
            child: _buildStar(12, Colors.white.withOpacity(0.45)),
          ),

          // 🎈 بالن‌های شناور
          Positioned(
            top: 30,
            right: 60,
            child: _buildBalloon(Colors.red.shade300),
          ),
          Positioned(
            top: 70,
            left: 40,
            child: _buildBalloon(Colors.yellow.shade300),
          ),
          Positioned(
            top: 45,
            left: 110,
            child: _buildBalloon(Colors.blue.shade300),
          ),

          // 📸 آیکون دوربین کوچک
          Positioned(
            top: 65,
            right: 150,
            child: Icon(
              Icons.camera_alt_rounded,
              size: 30,
              color: Colors.white.withOpacity(0.4),
            ),
          ),

          // 🎪 موج منحنی پایینی (مثل چادر سیرک)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: CustomPaint(
              size: Size(MediaQuery.of(context).size.width, 60),
              painter: CircusWavePainter(),
            ),
          ),

          // محتوای مرکز (مثل دکمه بازگشت)
          if (child != null) child!,
        ],
      ),
    );
  }

  // ساخت ستاره
  Widget _buildStar(double size, Color color) {
    return Icon(
      Icons.star,
      size: size,
      color: color,
    );
  }

  // ساخت بالن
  Widget _buildBalloon(Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 35,
          height: 40,
          decoration: BoxDecoration(
            color: color.withOpacity(0.7),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(50),
              topRight: Radius.circular(50),
              bottomLeft: Radius.circular(50),
              bottomRight: Radius.circular(5),
            ),
          ),
        ),
        Container(
          width: 2,
          height: 20,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                color.withOpacity(0.5),
                Colors.transparent,
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// 🎪 کلاس رسم موج چادر سیرک
class CircusWavePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final path = Path();

    // شروع از گوشه چپ بالا
    path.moveTo(0, size.height * 0.3);

    // رسم موج‌های متوالی (مثل چادر سیرک)
    final waveCount = 5; // تعداد موج‌ها
    final waveWidth = size.width / waveCount;

    for (int i = 0; i < waveCount; i++) {
      final x1 = i * waveWidth;
      final x2 = (i + 0.5) * waveWidth;
      final x3 = (i + 1) * waveWidth;

      // نقطه بالای موج
      path.quadraticBezierTo(
        x2, 0,  // نقطه کنترل
        x3, size.height * 0.3,  // نقطه پایان
      );
    }

    // بستن مسیر
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();

    canvas.drawPath(path, paint);

    // اضافه کردن خطوط جداکننده راه‌راه (مثل چادر)
    final stripePaint = Paint()
      ..color = Colors.white.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    for (int i = 0; i <= waveCount; i++) {
      final x = i * waveWidth;
      final stripePath = Path();
      stripePath.moveTo(x, size.height * 0.3);
      stripePath.lineTo(x, 0);
      canvas.drawPath(stripePath, stripePaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}