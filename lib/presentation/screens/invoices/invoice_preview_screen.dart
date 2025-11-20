import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/constants/colors.dart';
import '../../../core/utils/date_helper.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../data/models/customer_model.dart';
import '../../../data/models/invoice_model.dart';
import '../../../data/models/service_model.dart';

class InvoicePreviewScreen extends StatefulWidget {
  final InvoiceModel invoice;
  final CustomerModel customer;
  final List<InvoiceItem> items;
  final int totalAmount;
  final int shippingCost;
  final int discount;
  final int grandTotal;
  final int paidAmount;
  final int remainingAmount;

  const InvoicePreviewScreen({
    super.key,
    required this.invoice,
    required this.customer,
    required this.items,
    required this.totalAmount,
    required this.shippingCost,
    required this.discount,
    required this.grandTotal,
    required this.paidAmount,
    required this.remainingAmount,
  });

  @override
  State<InvoicePreviewScreen> createState() => _InvoicePreviewScreenState();
}

class _InvoicePreviewScreenState extends State<InvoicePreviewScreen> {
  final GlobalKey _invoiceKey = GlobalKey();
  bool _isSharing = false;

  Future<void> _shareInvoice() async {
    setState(() => _isSharing = true);

    try {
      // 1. گرفتن Screenshot از فاکتور
      final RenderRepaintBoundary boundary =
      _invoiceKey.currentContext!.findRenderObject() as RenderRepaintBoundary;

      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final Uint8List pngBytes = byteData!.buffer.asUint8List();

      // 2. ذخیره عکس در دایرکتوری موقت
      final tempDir = await getTemporaryDirectory();
      final file = await File('${tempDir.path}/invoice_${widget.invoice.invoiceNumber}.png').create();
      await file.writeAsBytes(pngBytes);

      // 3. اشتراک‌گذاری
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'فاکتور شماره ${widget.invoice.invoiceNumber}\n'
            'مشتری: ${widget.customer.fullName}\n'
            'جمع کل: ${ServiceModel.formatNumber(widget.grandTotal)} ریال',
      );

      if (mounted) {
        SnackBarHelper.showSuccess(context, 'فاکتور با موفقیت اشتراک‌گذاری شد');
      }
    } catch (e) {
      if (mounted) {
        SnackBarHelper.showError(context, 'خطا در اشتراک‌گذاری: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() => _isSharing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: const AssetImage('assets/images/background.png'),
            fit: BoxFit.cover,
            opacity: 0.1,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      // بخش فاکتور که Screenshot می‌شه
                      RepaintBoundary(
                        key: _invoiceKey,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 20,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              _buildInvoiceHeader(),
                              _buildItemsTable(),
                              _buildTotalsSection(),
                              if (widget.invoice.notes != null) _buildNotesSection(),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // دکمه اشتراک‌گذاری
                      _buildShareButton(),
                    ],
                  ),
                ),
              ),
              _buildBottomButton(),
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
          IconButton(
            icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
            onPressed: () => Navigator.pop(context),
          ),
          const Text(
            'نمایش فاکتور',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          GestureDetector(
            onTap: () {},
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: FaIcon(FontAwesomeIcons.user, color: Colors.grey, size: 20),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInvoiceHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.lightBlue.shade50,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
      ),
      child: Column(
        children: [
          // نام مشتری
          Text(
            widget.customer.fullName,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          // شماره موبایل
          Text(
            widget.customer.mobileNumber,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
          const Divider(height: 24, thickness: 1),
          // شماره سند و تاریخ
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                DateHelper.dateTimeToShamsi(widget.invoice.invoiceDate),
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
              Text(
                DateHelper.toPersianDigits(widget.invoice.invoiceNumber.toString()),
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildItemsTable() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // عنوان‌های جدول
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  flex: 2,
                  child: Text(
                    'مبلغ کل',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'قیمت',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Text(
                    'تعداد',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    'عنوان',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // آیتم‌های فاکتور
          ...widget.items.map((item) => Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: Colors.grey.shade200),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  flex: 2,
                  child: Text(
                    ServiceModel.formatNumber(item.totalPrice),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    ServiceModel.formatNumber(item.unitPrice),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Text(
                    DateHelper.toPersianDigits(item.quantity.toString()),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    item.serviceName,
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildTotalsSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
      ),
      child: Column(
        children: [
          // جمع کل آیتم‌ها
          _buildTotalRow(
            'جمع کل',
            ServiceModel.formatNumber(widget.totalAmount),
            isBold: false,
          ),

          const SizedBox(height: 8),

          // هزینه ارسال
          if (widget.shippingCost > 0) ...[
            _buildTotalRow(
              'هزینه ارسال:',
              ServiceModel.formatNumber(widget.shippingCost),
              isBold: false,
            ),
            const SizedBox(height: 8),
          ],

          // تخفیف
          if (widget.discount > 0) ...[
            _buildTotalRow(
              'تخفیف:',
              ServiceModel.formatNumber(widget.discount),
              isBold: false,
              isDiscount: true,
            ),
            const SizedBox(height: 8),
          ],

          const Divider(height: 16),

          // مجموع دریافتی
          _buildTotalRow(
            'مجموع دریافتی:',
            ServiceModel.formatNumber(widget.paidAmount),
            isBold: false,
          ),

          const SizedBox(height: 16),

          // جمع خالص
          _buildTotalRow(
            'جمع خالص',
            '${ServiceModel.formatNumber(widget.grandTotal)} ریال',
            isBold: true,
          ),

          const Divider(height: 16),

          // مانده
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: widget.remainingAmount > 0
                  ? Colors.red.shade50
                  : Colors.green.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  ServiceModel.formatNumber(widget.remainingAmount),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: widget.remainingAmount > 0
                        ? AppColors.error
                        : AppColors.success,
                  ),
                ),
                Text(
                  'مانده:',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: widget.remainingAmount > 0
                        ? AppColors.error
                        : AppColors.success,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalRow(String label, String value, {required bool isBold, bool isDiscount = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: isBold ? 16 : 14,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            color: isDiscount ? AppColors.error : AppColors.textPrimary,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: isBold ? 16 : 14,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildNotesSection() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          const Text(
            'توضیحات',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.invoice.notes!,
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShareButton() {
    return ElevatedButton.icon(
      onPressed: _isSharing ? null : _shareInvoice,
      icon: _isSharing
          ? const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          color: Colors.white,
          strokeWidth: 2,
        ),
      )
          : const Icon(Icons.share, color: Colors.white),
      label: Text(
        _isSharing ? 'در حال اشتراک‌گذاری...' : 'اشتراک گذاری فاکتور',
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        minimumSize: const Size(double.infinity, 54),
      ),
    );
  }

  Widget _buildBottomButton() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: ElevatedButton(
        onPressed: () => Navigator.pop(context),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.grey.shade200,
          foregroundColor: AppColors.textSecondary,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          minimumSize: const Size(double.infinity, 48),
        ),
        child: const Text('برگشت'),
      ),
    );
  }
}