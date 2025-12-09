import 'package:flutter/material.dart';
import '../../../core/constants/colors.dart';
import '../../../core/utils/date_helper.dart'; // ← برای toPersianDigits
import '../../../data/models/expense_model.dart';

class ExpenseCard extends StatefulWidget {
  final ExpenseModel expense;
  final VoidCallback onEdit;
  final VoidCallback onToggleStatus;

  const ExpenseCard({
    super.key,
    required this.expense,
    required this.onEdit,
    required this.onToggleStatus,
  });

  @override
  State<ExpenseCard> createState() => _ExpenseCardState();
}

class _ExpenseCardState extends State<ExpenseCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final expense = widget.expense;

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
          color: expense.isActive ? Colors.white : Colors.red.shade50,
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
              // ردیف اول: نام هزینه (راست‌چین)
              Row(
                mainAxisAlignment: MainAxisAlignment.start, // راست‌چین کل Row
                children: [
                  Text(
                    expense.expenseName,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: expense.isActive
                          ? AppColors.textPrimary
                          : Colors.red.shade600,
                    ),
                  ),
                ],
              ),

              // ردیف دوم: قیمت پیش‌فرض (در صورت وجود) - تم خاکستری
              if (expense.price != null && expense.formattedPrice != null) ...[
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50, // تم خاکستری
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.start, // راست‌چین
                    children: [
                      Text(
                        'قیمت پیش ‌فرض: ${DateHelper.toPersianDigits(expense.formattedPrice!)} تومان', // ← عنوان + مبلغ فارسی + تومان
                        textAlign: TextAlign.right,
                        textDirection: TextDirection.ltr, // LTR فقط برای اعداد
                        style: TextStyle(
                          fontSize: 13,
                          color: expense.isActive
                              ? AppColors.textSecondary
                              : Colors.red.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // دکمه‌های عملیاتی
              AnimatedCrossFade(
                firstChild: const SizedBox(height: 0),
                secondChild: Column(
                  children: [
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end, // راست‌چین در RTL
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
                            expense.isActive
                                ? Icons.block
                                : Icons.check_circle,
                            size: 16,
                          ),
                          label: Text(expense.isActive ? 'تعلیق' : 'فعال'),
                          style: TextButton.styleFrom(
                            foregroundColor: expense.isActive
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