import 'package:flutter/material.dart';
import '../../../core/constants/colors.dart';
import '../../../data/models/customer_model.dart';

class CustomerCard extends StatefulWidget {
  final CustomerModel customer;
  final VoidCallback onEdit;
  final VoidCallback onToggleStatus;

  const CustomerCard({
    super.key,
    required this.customer,
    required this.onEdit,
    required this.onToggleStatus,
  });

  @override
  State<CustomerCard> createState() => _CustomerCardState();
}

class _CustomerCardState extends State<CustomerCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final customer = widget.customer;

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
          color: customer.isActive ? Colors.white : Colors.red.shade50,
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
              // ردیف اول: نام و شماره
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // شماره موبایل
                  Expanded(
                    child: Text(
                      customer.mobileNumber,
                      textDirection: TextDirection.ltr,
                      textAlign: TextAlign.left,
                      style: TextStyle(
                        fontSize: 14,
                        color: customer.isActive
                            ? AppColors.textSecondary
                            : Colors.red.shade400,
                      ),
                    ),
                  ),

                  const SizedBox(width: 16),

                  // نام و نام خانوادگی
                  Expanded(
                    child: Text(
                      customer.fullName,
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: customer.isActive
                            ? AppColors.textPrimary
                            : Colors.red.shade600,
                      ),
                    ),
                  ),
                ],
              ),

              // توضیحات (در صورت وجود)
              if (customer.notes != null && customer.notes!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: customer.isActive
                        ? Colors.grey.shade50
                        : Colors.red.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    customer.notes!,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 13,
                      color: customer.isActive
                          ? AppColors.textSecondary
                          : Colors.red.shade600,
                    ),
                  ),
                ),
              ],

              // دکمه‌ها فقط وقتی کارت باز شده نمایش داده می‌شوند
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
                            customer.isActive
                                ? Icons.block
                                : Icons.check_circle,
                            size: 16,
                          ),
                          label: Text(customer.isActive ? 'تعلیق' : 'فعال'),
                          style: TextButton.styleFrom(
                            foregroundColor: customer.isActive
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
