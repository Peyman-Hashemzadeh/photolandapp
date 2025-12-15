import 'package:flutter/material.dart';
import 'package:shamsi_date/shamsi_date.dart';
import 'package:persian_datetime_picker/persian_datetime_picker.dart';
import '../../../core/constants/colors.dart';
import '../../../core/utils/date_helper.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../data/models/invoice_model.dart';
import '../../../data/models/customer_model.dart';
import '../../../data/models/payment_model.dart';
import '../../../data/repositories/invoice_repository.dart';
import '../../../data/repositories/payment_repository.dart';
import '../../../data/repositories/customer_repository.dart';
import '../../widgets/empty_state_widget.dart';
import '../invoices/invoice_preview_screen.dart';

enum ReminderFilter {
  overdue('رد شده'),
  editList('لیست ادیت'),
  all('همه');

  final String label;
  const ReminderFilter(this.label);
}

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
  final PaymentRepository _paymentRepository = PaymentRepository();

  Stream<List<Map<String, dynamic>>>? _invoicesStream;
  String? _expandedInvoiceId;
  ReminderFilter _selectedFilter = ReminderFilter.all;

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
        final today = DateTime.now();

        List<Map<String, dynamic>> filteredData = [];

        if (_selectedFilter == ReminderFilter.overdue) {
          filteredData = allData.where((data) {
            final invoice = data['invoice'] as InvoiceModel;
            return invoice.deliveryDate != null &&
                invoice.deliveryDate!.isBefore(DateTime(today.year, today.month, today.day));
          }).toList();

          filteredData.sort((a, b) {
            final dateA = (a['invoice'] as InvoiceModel).deliveryDate!;
            final dateB = (b['invoice'] as InvoiceModel).deliveryDate!;
            return dateA.compareTo(dateB);
          });
        } else if (_selectedFilter == ReminderFilter.editList) {
          filteredData = allData.where((data) {
            final invoice = data['invoice'] as InvoiceModel;
            return invoice.deliveryDate != null &&
                !invoice.deliveryDate!.isBefore(DateTime(today.year, today.month, today.day));
          }).toList();

          filteredData.sort((a, b) {
            final dateA = (a['invoice'] as InvoiceModel).deliveryDate!;
            final dateB = (b['invoice'] as InvoiceModel).deliveryDate!;
            return dateA.compareTo(dateB);
          });
        } else {
          final overdue = allData.where((data) {
            final invoice = data['invoice'] as InvoiceModel;
            return invoice.deliveryDate != null &&
                invoice.deliveryDate!.isBefore(DateTime(today.year, today.month, today.day));
          }).toList();

          final editList = allData.where((data) {
            final invoice = data['invoice'] as InvoiceModel;
            return invoice.deliveryDate != null &&
                !invoice.deliveryDate!.isBefore(DateTime(today.year, today.month, today.day));
          }).toList();

          overdue.sort((a, b) {
            final dateA = (a['invoice'] as InvoiceModel).deliveryDate!;
            final dateB = (b['invoice'] as InvoiceModel).deliveryDate!;
            return dateA.compareTo(dateB);
          });

          editList.sort((a, b) {
            final dateA = (a['invoice'] as InvoiceModel).deliveryDate!;
            final dateB = (b['invoice'] as InvoiceModel).deliveryDate!;
            return dateA.compareTo(dateB);
          });

          filteredData = [...overdue, ...editList];
        }

        final editListCount = allData.where((data) {
          final invoice = data['invoice'] as InvoiceModel;
          return invoice.deliveryDate != null &&
              !invoice.deliveryDate!.isBefore(DateTime(today.year, today.month, today.day));
        }).length;

        final overdueCount = allData.where((data) {
          final invoice = data['invoice'] as InvoiceModel;
          return invoice.deliveryDate != null &&
              invoice.deliveryDate!.isBefore(DateTime(today.year, today.month, today.day));
        }).length;

        return Column(
          children: [
            _buildStatsFilter(editListCount, overdueCount, allData.length),
            Expanded(
              child: filteredData.isEmpty
                  ? EmptyStateWidget(
                icon: Icons.notifications_active,
                message: _selectedFilter == ReminderFilter.overdue
                    ? 'رکورد رد شده‌ای وجود ندارد!'
                    : _selectedFilter == ReminderFilter.editList
                    ? 'رکوردی در لیست ادیت نیست!'
                    : 'فاکتوری نزدیک به تحویل نیست!',
              )
                  : ListView.builder(
                padding: const EdgeInsets.all(20),
                itemCount: filteredData.length,
                itemBuilder: (context, index) {
                  final data = filteredData[index];
                  final invoice = data['invoice'] as InvoiceModel;
                  final lastPaymentDate = data['lastPaymentDate'] as DateTime;
                  return _buildReminderCard(invoice, lastPaymentDate);
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatsFilter(int editListCount, int overdueCount, int allCount) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.4),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildStatItem(
              label: 'رد شده',
              value: overdueCount,
              selected: _selectedFilter == ReminderFilter.overdue,
              onTap: () => setState(() => _selectedFilter = ReminderFilter.overdue),
            ),
          ),
          _buildDivider(),
          Expanded(
            child: _buildStatItem(
              label: 'همه',
              value: allCount,
              selected: _selectedFilter == ReminderFilter.all,
              onTap: () => setState(() => _selectedFilter = ReminderFilter.all),
            ),
          ),
          _buildDivider(),
          Expanded(
            child: _buildStatItem(
              label: 'لیست ادیت',
              value: editListCount,
              selected: _selectedFilter == ReminderFilter.editList,
              onTap: () => setState(() => _selectedFilter = ReminderFilter.editList),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required String label,
    required int value,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: selected ? AppColors.primary.withOpacity(0.08) : Colors.transparent,
        ),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                color: selected ? AppColors.primary : Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              DateHelper.toPersianDigits(value.toString()),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: selected ? AppColors.primary : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      width: 1,
      height: 25,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      color: Colors.grey.shade300,
    );
  }

  Widget _buildReminderCard(InvoiceModel invoice, DateTime lastPaymentDate) {
    final today = DateTime.now();
    final deliveryDate = invoice.deliveryDate!;
    final daysRemaining = deliveryDate.difference(DateTime(today.year, today.month, today.day)).inDays;
    final isOverdue = daysRemaining < 0;

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
            width: 1,
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      invoice.customerName,
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
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
                          _formatRemainingDays(daysRemaining),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
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
                        const Icon(Icons.camera_alt, size: 14, color: AppColors.textSecondary),
                        const SizedBox(width: 4),
                        Text(
                          DateHelper.dateTimeToShamsi(invoice.invoiceDate),
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
                        const Icon(Icons.credit_card, size: 14, color: AppColors.textSecondary),
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
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isOverdue ? AppColors.error.withOpacity(0.1) : AppColors.info.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.local_shipping,
                      size: 16,
                      color: isOverdue ? AppColors.error : AppColors.info,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'تاریخ تحویل: ${DateHelper.dateTimeToShamsi(deliveryDate)}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: isOverdue ? AppColors.error : AppColors.info,
                      ),
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
                    Wrap(
                      alignment: WrapAlignment.start,
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        TextButton.icon(
                          onPressed: () => _handleEditDeliveryDate(invoice),
                          icon: const Icon(Icons.edit_calendar, size: 16),
                          label: const Text('ویرایش'),
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () => _handleChangeStatus(invoice),
                          icon: const Icon(Icons.edit, size: 16),
                          label: const Text('وضعیت'),
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.info,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                          ),
                        ),
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

  String _formatRemainingDays(int days) {
    if (days < 0) {
      return '${DateHelper.toPersianDigits(days.abs().toString())} روز تاخیر';
    } else if (days == 0) {
      return 'تحویل امروز';
    } else {
      return '${DateHelper.toPersianDigits(days.toString())} روز مانده';
    }
  }

  void _handleEditDeliveryDate(InvoiceModel invoice) async {
    final currentDate = invoice.deliveryDate != null
        ? Jalali.fromDateTime(invoice.deliveryDate!)
        : Jalali.now();

    final picked = await showPersianDatePicker(
      context: context,
      initialDate: currentDate,
      firstDate: Jalali.now().addDays(-365),
      lastDate: Jalali.now().addYears(1),
      locale: const Locale('fa', 'IR'),
      builder: (context, child) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: Theme(
            data: Theme.of(context).copyWith(
              colorScheme: ColorScheme.light(
                primary: AppColors.primary,
                onPrimary: Colors.white,
                surface: Colors.white,
                onSurface: AppColors.textPrimary,
              ),
              textTheme: Theme.of(context).textTheme.apply(fontFamily: 'Vazirmatn'),
            ),
            child: child!,
          ),
        );
      },
    );

    if (picked != null) {
      try {
        await _invoiceRepository.updateDeliveryDate(
          invoice.id,
          picked.toDateTime(),
        );

        if (mounted) {
          SnackBarHelper.showSuccess(
            context,
            'تاریخ تحویل به ${DateHelper.formatPersianDate(picked)} تغییر یافت',
          );
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

  // 🔥 اصلاح شده: با Future.wait سریعتر شده
  void _handleViewInvoice(InvoiceModel invoice) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      // 🔥 همه query ها رو موازی اجرا کن
      final results = await Future.wait([
        _invoiceRepository.getInvoiceItems(invoice.id).first,
        _invoiceRepository.calculateGrandTotal(invoice.id),
        CustomerRepository().getCustomerById(invoice.customerId),
        _paymentRepository.getPaymentsByInvoice(invoice.id).first,
      ]);

      final itemsSnapshot = results[0] as List<InvoiceItem>;
      final grandTotal = results[1] as int;
      final customer = results[2] as CustomerModel?;
      final payments = results[3] as List<PaymentModel>;

      final paidAmount = payments.fold<int>(0, (sum, p) => sum + p.amount);
      final remainingAmount = grandTotal - paidAmount;

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
            totalAmount: grandTotal - (invoice.shippingCost ?? 0) + (invoice.discount ?? 0),
            shippingCost: invoice.shippingCost ?? 0,
            discount: invoice.discount ?? 0,
            grandTotal: grandTotal,
            paidAmount: paidAmount,
            remainingAmount: remainingAmount,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        SnackBarHelper.showError(context, 'خطا در بارگذاری فاکتور: $e');
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
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('انصراف'),
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