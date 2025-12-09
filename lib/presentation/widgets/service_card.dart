import 'package:flutter/material.dart';
import '../../../core/constants/colors.dart';
import '../../../data/models/service_model.dart';
import '../../../core/utils/date_helper.dart';


class ServiceCard extends StatefulWidget {
  final ServiceModel service;
  final VoidCallback onEdit;
  final VoidCallback onToggleStatus;

  const ServiceCard({
    super.key,
    required this.service,
    required this.onEdit,
    required this.onToggleStatus,
  });

  @override
  State<ServiceCard> createState() => _ServiceCardState();
}

class _ServiceCardState extends State<ServiceCard> {
  bool _isExpanded = false;  // state برای نمایش/مخفی کردن دکمه‌ها

  @override
  Widget build(BuildContext context) {
    return GestureDetector(  // تاچ روی کل card
      onTap: () {
        setState(() {
          _isExpanded = !_isExpanded;  // toggle
        });
      },
      child: AnimatedContainer(  // انیمیشن کلی card
        duration: const Duration(milliseconds: 250),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: widget.service.isActive
              ? Colors.white
              : Colors.red.shade50,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ردیف اول: نام خدمت (راست‌چین کامل)
              Row(
                mainAxisAlignment: MainAxisAlignment.start, // راست‌چین کل Row
                children: [
                  // نام خدمت
                  Text(
                    widget.service.serviceName,
                    textAlign: TextAlign.right, // راست‌چین
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: widget.service.isActive
                          ? AppColors.textPrimary
                          : Colors.red.shade600,
                    ),
                  ),
                ],
              ),

              // قیمت (در صورت وجود) - ردیف جداگانه، راست‌چین
              if (widget.service.price != null && widget.service.formattedPrice != null) ...[
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: widget.service.isActive
                        ? Colors.grey.shade50
                        : Colors.red.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.start, // راست‌چین کل Row
                    children: [
                      Text(
                        'قیمت پیش فرض: ${DateHelper.toPersianDigits(widget.service.formattedPrice!)} تومان', // ← عنوان + مبلغ فارسی + تومان
                        textAlign: TextAlign.right,
                        textDirection: TextDirection.rtl, // LTR فقط برای اعداد
                        style: TextStyle(
                          fontSize: 13,
                          color: widget.service.isActive
                              ? AppColors.textSecondary
                              : Colors.red.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // دکمه‌ها با AnimatedCrossFade (بدون تغییر)
              AnimatedCrossFade(
                firstChild: const SizedBox(height: 0), // مخفی
                secondChild: Column(
                  children: [
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end, // از راست به چپ در RTL
                      children: [
                        // دکمه ویرایش
                        TextButton.icon(
                          onPressed: () {
                            widget.onEdit();
                            setState(() {
                              _isExpanded = false; // مخفی بعد از edit
                            });
                          },
                          icon: const Icon(Icons.edit, size: 16),
                          label: const Text('ویرایش'),
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                          ),
                        ),

                        const SizedBox(width: 8),

                        // دکمه تعلیق/فعال‌سازی
                        TextButton.icon(
                          onPressed: () {
                            widget.onToggleStatus();
                            setState(() {
                              _isExpanded = false; // مخفی بعد از toggle
                            });
                          },
                          icon: Icon(
                            widget.service.isActive
                                ? Icons.block
                                : Icons.check_circle,
                            size: 16,
                          ),
                          label: Text(widget.service.isActive ? 'تعلیق' : 'فعال'),
                          style: TextButton.styleFrom(
                            foregroundColor: widget.service.isActive
                                ? AppColors.error
                                : AppColors.success,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                crossFadeState: _isExpanded
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                duration: const Duration(milliseconds: 250),
              ),
            ],
          ),
        ),
      ),
    );
  }
}