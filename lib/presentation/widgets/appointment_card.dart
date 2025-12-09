import 'package:flutter/material.dart';
import '../../../core/constants/colors.dart';
import '../../../core/utils/date_helper.dart';
import '../../../data/models/appointment_model.dart';
import '../../../data/models/service_model.dart';
import '../../../data/repositories/invoice_repository.dart';
import '../../../data/repositories/payment_repository.dart';

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
  final InvoiceRepository _invoiceRepository = InvoiceRepository();
  final PaymentRepository _paymentRepository = PaymentRepository();

  bool _isExpanded = false;
  bool _isSettled = false;
  bool _hasInvoice = false;
  int _totalInvoice = 0;
  int _totalPayments = 0;
  DateTime? _latestPaymentDate;
  int? _depositAmount;
  DateTime? _depositDate;

  @override
  void initState() {
    super.initState();
    _checkSettlementStatus();
  }

  Future<void> _checkSettlementStatus() async {
    try {
      // بررسی فاکتور
      final invoice = await _invoiceRepository.getInvoiceByAppointment(widget.appointment.id);

      if (invoice != null) {
        final invoiceTotal = await _invoiceRepository.calculateGrandTotal(invoice.id);
        final paymentsTotal = await _paymentRepository.calculateTotalPayments(widget.appointment.id);

        // 🔥 دریافت لیست پرداخت‌ها
        final payments = await _paymentRepository.getPaymentsByAppointment(widget.appointment.id).first;

        // 🔥 چک کردن نوع پرداخت‌ها
        final hasDeposit = payments.any((p) => p.type == 'deposit');
        final depositPayment = payments.where((p) => p.type == 'deposit').firstOrNull;

        if (mounted) {
          setState(() {
            _hasInvoice = invoiceTotal > 0;
            _totalInvoice = invoiceTotal;
            _totalPayments = paymentsTotal;

            // 🔥 لاجیک جدید:
            // 1️⃣ اگه تسویه کامل شده → آیکون تسویه ✅
            if (paymentsTotal >= invoiceTotal && invoiceTotal > 0) {
              _isSettled = true;
              _depositAmount = null;
              _depositDate = null;
            }
            // 2️⃣ اگه بیعانه داره ولی هنوز تسویه نشده → آیکون بیعانه 💰
            else if (hasDeposit && depositPayment != null) {
              _isSettled = false;
              _depositAmount = depositPayment.amount;
              _depositDate = depositPayment.paymentDate;
            }
            // 3️⃣ در غیر این صورت → هیچ آیکونی نمایش نده
            else {
              _isSettled = false;
              _depositAmount = null;
              _depositDate = null;
            }
          });
        }
      } else {
        // 🔥 اگه فاکتور نداره، فقط چک کن بیعانه از نوبت داره یا نه
        if (widget.appointment.hasDeposit) {
          setState(() {
            _depositAmount = widget.appointment.depositAmount;
            _depositDate = widget.appointment.depositReceivedDate;
            _isSettled = false;
          });
        }
      }

      // یافتن آخرین تاریخ پرداخت
      final payments = await _paymentRepository.getPaymentsByAppointment(widget.appointment.id).first;
      if (payments.isNotEmpty) {
        final sortedPayments = payments..sort((a, b) => b.paymentDate.compareTo(a.paymentDate));
        setState(() {
          _latestPaymentDate = sortedPayments.first.paymentDate;
        });
      }
    } catch (e) {
      debugPrint('⚠️ خطا در چک وضعیت: $e');
    }
  }

  void _showStatusDialog() {
    String message;

    if (_isSettled) {
      // آیکون چک - تسویه شده
      message = 'در تاریخ ${DateHelper.dateTimeToShamsi(_latestPaymentDate!)} '
          'مجموعا ${ServiceModel.formatNumber(_totalPayments)} تومان دریافت شد '
          'و فاکتور تسویه شده است.';
    } else if (_depositAmount != null) {
      // آیکون پول - بیعانه
      message = 'در تاریخ ${DateHelper.dateTimeToShamsi(_depositDate!)} '
          'مبلغ ${ServiceModel.formatNumber(_depositAmount!)} تومان بیعانه دریافت شد';

      // 🔥 اضافه کردن اطلاعات بیشتر اگه فاکتور هم داره
      if (_hasInvoice && _totalInvoice > 0) {
        final remaining = _totalInvoice - _totalPayments;
        message += '\n\nجمع فاکتور: ${ServiceModel.formatNumber(_totalInvoice)} تومان\n'
            'مانده: ${ServiceModel.formatNumber(remaining)} تومان';
      }
    } else {
      return; // هیچ آیکونی نداریم، دیالوگ نمایش نده
    }

    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Text(_isSettled ? 'تسویه شده' : 'بیعانه دریافتی'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('متوجه شدم'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isCancelled = widget.appointment.status == 'cancelled';
    final showIcon = _isSettled || (_depositAmount != null && !_hasInvoice);

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
              // ردیف اول: ساعت، نام (وسط‌چین)، آیکون
              Row(
                children: [
                  // ساعت (سمت چپ)
                  Directionality(
                    textDirection: TextDirection.ltr, // LTR رو نگه دار، چون ساعت از چپ به راست خونده می‌شه
                    child: Text(
                      DateHelper.toPersianDigits(widget.appointment.timeRange), // ← تبدیل اعداد به فارسی
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

                  // آیکون (سمت راست)
                  SizedBox(
                    width: 24,
                    child: (_isSettled || _depositAmount != null)
                        ? GestureDetector(
                      onTap: _showStatusDialog,
                      child: Icon(
                        _isSettled ? Icons.check_circle : Icons.attach_money,
                        size: 20,
                        color: isCancelled
                            ? Colors.red.shade400
                            : (_isSettled ? AppColors.success : AppColors.success),
                      ),
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
                      // مدل عکاسی
                      if (widget.appointment.photographyModel != null)
                        Expanded(
                          child: Row(
                            children: [
                              const Icon(
                                Icons.camera_alt_outlined,
                                size: 16,
                                color: AppColors.textSecondary,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  widget.appointment.photographyModel!,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: AppColors.textSecondary,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        const SizedBox.shrink(),

                      const SizedBox(width: 12),

                      // سن کودک
                      if (widget.appointment.childAge != null)
                        Row(
                          children: [
                            const Icon(
                              Icons.child_care_outlined,
                              size: 16,
                              color: AppColors.textSecondary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              widget.appointment.childAge!,
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
                        : Colors.grey.shade100,
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

              // دکمه‌های عملیاتی
              AnimatedSize(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
                alignment: Alignment.centerRight,
                child: _isExpanded
                    ? Column(
                  children: [
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        // دکمه ویرایش (همیشه نمایش)
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

                        // اگر لغو نشده: صورت حساب + لغو
                        if (!isCancelled) ...[
                          // دکمه صورت حساب
                          TextButton.icon(
                            onPressed: widget.onSettle,
                            icon: const Icon(Icons.receipt_long, size: 16),
                            label: const Text('صورت حساب'),
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

                        // اگر لغو شده: رزرو مجدد
                        if (isCancelled)
                          TextButton.icon(
                            onPressed: widget.onSettle,
                            icon: const Icon(Icons.refresh, size: 16),
                            label: const Text('رزرو مجدد'),
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
}