import 'package:flutter/material.dart';
import '../../../core/constants/colors.dart';
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
              // ردیف اول: نام و قیمت
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // قیمت (سمت چپ)
                  if (expense.price != null)
                    Text(
                      expense.formattedPrice!,
                      style: TextStyle(
                        fontSize: 14,
                        color: expense.isActive
                            ? AppColors.primary
                            : Colors.red.shade400,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  else
                    Text(
                      '---',
                      style: TextStyle(
                        fontSize: 14,
                        color: expense.isActive
                            ? AppColors.textLight
                            : Colors.red.shade300,
                      ),
                    ),

                  // نام هزینه (سمت راست)
                  Expanded(
                    child: Text(
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
                  ),
                ],
              ),

              // دکمه‌های عملیاتی
              AnimatedCrossFade(
                firstChild: const SizedBox(height: 0),
                secondChild: Column(
                  children: [
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        // دکمه تعلیق/فعال‌سازی
                        TextButton.icon(
                          onPressed: widget.onToggleStatus,
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

                        const SizedBox(width: 8),

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