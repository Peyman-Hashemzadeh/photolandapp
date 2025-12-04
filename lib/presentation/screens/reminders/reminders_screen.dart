import 'package:flutter/material.dart';
import 'package:shamsi_date/shamsi_date.dart';
import '../../../core/constants/colors.dart';
import '../../../core/utils/date_helper.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../data/models/invoice_model.dart';
import '../../../data/repositories/invoice_repository.dart';
import '../../../data/repositories/customer_repository.dart';
import '../../widgets/empty_state_widget.dart';
import '../invoices/invoice_preview_screen.dart';

// 🔥 استفاده از همون enum که در financial_report استفاده شده
enum InvoiceStatus {
  editing('درصف ویرایش'),
  confirmed('تایید مشتری'),
  printing('ارسال برای چاپ'),
  printed('چاپ شده'),
  delivered('تحویل');

  final String label;
  const InvoiceStatus(this.label);
}

class RemindersScreen extends StatefulWidget {
  const RemindersScreen({super.key});

  @override
  State<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends State<RemindersScreen> {
  final InvoiceRepository _invoiceRepository = InvoiceRepository();
  Stream<List<Map<String, dynamic>>>? _invoicesStream;
  String? _expandedInvoiceId;

  @override
  void initState() {
    super.initState();
    _invoicesStream = _invoiceRepository.getPendingDeliveryInvoices();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/background.png'),
            fit: BoxFit.cover,
            opacity: 0.1,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: _buildRemindersList(),
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
          Container(width: 44, height: 44),
          const Text(
            'یادآوری تحویل',
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

  Widget _buildRemindersList() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _invoicesStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              'خطا در بارگذاری یادآورها: ${snapshot.error}',
              style: TextStyle(color: AppColors.error),
            ),
          );
        }

        final allData = snapshot.data ?? [];

        print('📊 تعداد کل فاکتورهای تسویه شده: ${allData.length}');
        for (var data in allData) {
          final invoice = data['invoice'] as InvoiceModel;
          final lastPaymentDate = data['lastPaymentDate'] as DateTime;
          print('  - فاکتور ${invoice.invoiceNumber}: آخرین پرداخت = $lastPaymentDate');
        }

        final reminders = allData.where((data) {
          final lastPaymentDate = data['lastPaymentDate'] as DateTime;
          final today = DateTime.now();
          final daysSincePayment = today.difference(lastPaymentDate).inDays;

          final invoice = data['invoice'] as InvoiceModel;
          print('📅 فاکتور ${invoice.invoiceNumber}: $daysSincePayment روز از آخرین پرداخت گذشته');

          return daysSincePayment >= 10;
        }).toList();

        reminders.sort((a, b) {
          final dateA = a['lastPaymentDate'] as DateTime;
          final dateB = b['lastPaymentDate'] as DateTime;
          final daysA = _calculateRemainingDays(dateA);
          final daysB = _calculateRemainingDays(dateB);
          return daysA.compareTo(daysB);
        });

        if (reminders.isEmpty) {
          return const EmptyStateWidget(
            icon: Icons.notifications_active,
            message: 'فاکتوری نزدیک به تحویل نیست',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: reminders.length,
          itemBuilder: (context, index) {
            final data = reminders[index];
            final invoice = data['invoice'] as InvoiceModel;
            final lastPaymentDate = data['lastPaymentDate'] as DateTime;
            return _buildReminderCard(invoice, lastPaymentDate);
          },
        );
      },
    );
  }

  Widget _buildReminderCard(InvoiceModel invoice, DateTime lastPaymentDate) {
    final remainingDays = _calculateRemainingDays(lastPaymentDate);
    final isOverdue = remainingDays < 0;

    return GestureDetector(
      onTap: () {
        setState(() {
          if (_expandedInvoiceId == invoice.id) {
            _expandedInvoiceId = null;
          } else {
            _expandedInvoiceId = invoice.id;
          }
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isOverdue ? AppColors.error : AppColors.primary,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: (isOverdue ? AppColors.error : AppColors.primary).withOpacity(0.1),
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
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: isOverdue ? AppColors.error : AppColors.success,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isOverdue ? Icons.warning : Icons.access_time,
                          size: 14,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _formatRemainingDays(remainingDays),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Text(
                      invoice.customerName,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 24),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.payment, size: 14, color: AppColors.textSecondary),
                        const SizedBox(width: 4),
                        Text(
                          DateHelper.dateTimeToShamsi(lastPaymentDate),
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          DateHelper.dateTimeToShamsi(invoice.invoiceDate),
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.calendar_today, size: 14, color: AppColors.textSecondary),
                      ],
                    ),
                  ],
                ),
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
                alignment: Alignment.centerRight,
                child: _expandedInvoiceId == invoice.id
                    ? Column(
                  children: [
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton.icon(
                          onPressed: () => _handleChangeStatus(invoice),
                          icon: const Icon(Icons.edit, size: 16),
                          label: const Text('وضعیت'),
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        TextButton.icon(
                          onPressed: () => _handleViewInvoice(invoice),
                          icon: const Icon(Icons.visibility, size: 16),
                          label: const Text('نمایش'),
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.success,
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

  int _calculateRemainingDays(DateTime lastPaymentDate) {
    final deliveryDate = lastPaymentDate.add(const Duration(days: 14));
    final today = DateTime.now();
    return deliveryDate.difference(today).inDays;
  }

  String _formatRemainingDays(int days) {
    if (days < 0) {
      return '${DateHelper.toPersianDigits(days.abs().toString())} روز تاخیر';
    } else if (days == 0) {
      return 'امروز تحویل';
    } else {
      return '${DateHelper.toPersianDigits(days.toString())} روز مانده';
    }
  }

  void _handleViewInvoice(InvoiceModel invoice) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      final invoiceRepository = InvoiceRepository();
      final itemsSnapshot = await invoiceRepository.getInvoiceItems(invoice.id).first;
      final totalAmount = await invoiceRepository.calculateInvoiceTotal(invoice.id);
      final grandTotal = await invoiceRepository.calculateGrandTotal(invoice.id);
      final customerRepository = CustomerRepository();
      final customer = await customerRepository.getCustomerById(invoice.customerId);

      if (!mounted) return;
      Navigator.pop(context);

      if (customer == null) {
        SnackBarHelper.showError(context, 'اطلاعات مشتری یافت نشد');
        return;
      }

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => InvoicePreviewScreen(
            invoice: invoice,
            customer: customer,
            items: itemsSnapshot,
            totalAmount: totalAmount,
            shippingCost: invoice.shippingCost ?? 0,
            discount: invoice.discount ?? 0,
            grandTotal: grandTotal,
            paidAmount: 0,
            remainingAmount: grandTotal,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        SnackBarHelper.showError(context, 'خطا در بارگذاری فاکتور');
      }
    }
  }

  void _handleChangeStatus(InvoiceModel invoice) async {
    final selectedStatus = await showDialog<InvoiceStatus>(
      context: context,
      builder: (context) => _ChangeStatusDialog(
        currentStatus: invoice.status,
      ),
    );

    if (selectedStatus != null) {
      try {
        await _invoiceRepository.updateInvoiceStatus(invoice.id, selectedStatus.name);

        if (mounted) {
          SnackBarHelper.showSuccess(context, 'وضعیت به "${selectedStatus.label}" تغییر یافت');

          // 🔥 اگر وضعیت از "editing" تغییر کرد، stream خودش refresh می‌شه
          // و فاکتور از لیست یادآوری حذف می‌شه
        }
      } catch (e) {
        if (mounted) {
          SnackBarHelper.showError(
            context,
            e.toString().replaceAll('Exception: ', ''),
          );
        }
      }
    }
  }
}

// 🔥 دیالوگ تغییر وضعیت
class _ChangeStatusDialog extends StatefulWidget {
  final String? currentStatus;

  const _ChangeStatusDialog({this.currentStatus});

  @override
  State<_ChangeStatusDialog> createState() => _ChangeStatusDialogState();
}

class _ChangeStatusDialogState extends State<_ChangeStatusDialog> {
  InvoiceStatus? _selectedStatus;

  @override
  void initState() {
    super.initState();
    // یافتن وضعیت فعلی
    if (widget.currentStatus != null) {
      try {
        _selectedStatus = InvoiceStatus.values.firstWhere(
              (status) => status.name == widget.currentStatus,
          orElse: () => InvoiceStatus.editing,
        );
      } catch (e) {
        _selectedStatus = InvoiceStatus.editing;
      }
    } else {
      _selectedStatus = InvoiceStatus.editing;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'تغییر وضعیت',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 24),

            // لیست وضعیت‌ها با Radio
            ...InvoiceStatus.values.map((status) {
              return ListTile(
                title: Text(
                  status.label,
                  textAlign: TextAlign.right,
                ),
                leading: Radio<InvoiceStatus>(
                  value: status,
                  groupValue: _selectedStatus,
                  onChanged: (value) {
                    setState(() => _selectedStatus = value);
                  },
                ),
                onTap: () {
                  setState(() => _selectedStatus = status);
                },
              );
            }).toList(),

            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('انصراف'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      if (_selectedStatus != null) {
                        Navigator.pop(context, _selectedStatus);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('ثبت'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}