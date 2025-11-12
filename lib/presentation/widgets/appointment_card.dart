import 'package:flutter/material.dart';
import '../../../core/constants/colors.dart';
import '../../../data/models/appointment_model.dart';

class AppointmentCard extends StatefulWidget {
  final AppointmentModel appointment;
  final VoidCallback onEdit;
  final VoidCallback onCancel;
  final VoidCallback onSettle;

  const AppointmentCard({
    super.key,
    required this.appointment,
    required this.onEdit,
    required this.onCancel,
    required this.onSettle,
  });

  @override
  State<AppointmentCard> createState() => _AppointmentCardState();
}

class _AppointmentCardState extends State<AppointmentCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final isCancelled = widget.appointment.status == 'cancelled';
    final hasDeposit = widget.appointment.hasDeposit;

    return GestureDetector(
      onTap: () {
        setState(() {
          _isExpanded = !_isExpanded;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: isCancelled ? Colors.red.shade50 : Colors.white,
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
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // ردیف اول: ساعت، نام (وسط‌چین)، آیکون بیعانه
              Row(
                children: [
                  // ساعت (سمت چپ) - با textDirection برای درست نمایش دادن
                  Directionality(
                    textDirection: TextDirection.ltr,
                    child: Text(
                      widget.appointment.timeRange,
                      style: TextStyle(
                        fontSize: 14,
                        color: isCancelled
                            ? Colors.red.shade400
                            : AppColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  // نام مشتری (وسط)
                  Expanded(
                    child: Text(
                      widget.appointment.customerName,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isCancelled
                            ? Colors.red.shade600
                            : AppColors.textPrimary,
                      ),
                    ),
                  ),

                  // آیکون بیعانه (سمت راست)
                  SizedBox(
                    width: 24,
                    child: hasDeposit
                        ? Icon(
                      Icons.attach_money,
                      size: 20,
                      color: isCancelled
                          ? Colors.red.shade400
                          : AppColors.success,
                    )
                        : const SizedBox(),
                  ),
                ],
              ),

              // ردیف دوم: سن کودک و مدل عکاسی (با بک‌گراند)
              if (widget.appointment.childAge != null ||
                  widget.appointment.photographyModel != null) ...[
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isCancelled
                        ? Colors.red.shade100
                        : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // مدل عکاسی (سمت چپ)
                      if (widget.appointment.photographyModel != null)
                        Expanded(
                          child: Text(
                            widget.appointment.photographyModel!,
                            textAlign: TextAlign.left,
                            style: TextStyle(
                              fontSize: 13,
                              color: isCancelled
                                  ? Colors.red.shade400
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ),
                      // سن کودک (سمت راست)
                      if (widget.appointment.childAge != null)
                        Text(
                          'سن کودک: ${widget.appointment.childAge}',
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            fontSize: 13,
                            color: isCancelled
                                ? Colors.red.shade400
                                : AppColors.textSecondary,
                          ),
                        ),
                    ],
                  ),
                ),
              ],

              // توضیحات
              if (widget.appointment.notes != null &&
                  widget.appointment.notes!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isCancelled
                        ? Colors.red.shade100
                        : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    widget.appointment.notes!,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 12,
                      color: isCancelled
                          ? Colors.red.shade600
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
              ],

              // دکمه‌های عملیاتی (فقط برای نوبت‌های غیر لغو‌شده)
              if (!isCancelled)
                AnimatedSize(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeInOut,
                  alignment: Alignment.centerRight, // 🔥 انیمیشن از راست به چپ
                  child: _isExpanded
                      ? Column(
                    children: [
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          // دکمه ویرایش
                          TextButton.icon(
                            onPressed: widget.onEdit,
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
                          // دکمه تسویه
                          TextButton.icon(
                            onPressed: widget.onSettle,
                            icon: const Icon(Icons.attach_money, size: 16),
                            label: const Text('تسویه'),
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.success,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // دکمه لغو
                          TextButton.icon(
                            onPressed: widget.onCancel,
                            icon: const Icon(Icons.block, size: 16),
                            label: const Text('لغو'),
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.error,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  )
                      : const SizedBox(height: 0),
                ),
            ],
          ),
        ),
      ),
    );
  }
}