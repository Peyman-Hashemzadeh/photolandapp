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
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

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
      // 🔥 انتخاب: PDF یا عکس؟
      final shouldUsePdf = await _showFormatDialog();

      if (shouldUsePdf == null) {
        setState(() => _isSharing = false);
        return;
      }

      if (shouldUsePdf) {
        await _shareAsPdf();
      } else {
        await _shareAsImage();
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

// 🔥 دیالوگ انتخاب فرمت
  Future<bool?> _showFormatDialog() async {
    return showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        elevation: 8,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: [
                Colors.white,
                Colors.grey.shade50,
              ],
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 🎨 هدر
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primary,
                      AppColors.primary.withOpacity(0.8),
                    ],
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.share_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'انتخاب فرمت اشتراک‌گذاری',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 8),

              // 🎨 توضیحات
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                child: Text(
                  'فاکتور به چه صورت  ارسال شود؟',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade700,
                    height: 1.5,
                  ),
                ),
              ),

              const SizedBox(height: 8),

              // 🎨 گزینه‌ها
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    // گزینه PDF
                    _buildFormatOption(
                      context: context,
                      title: 'فایل PDF',
                      subtitle: 'کیفیت بالا، مناسب چاپ',
                      icon: Icons.picture_as_pdf,
                      iconColor: Colors.red.shade600,
                      gradientColors: [
                        Colors.red.shade50,
                        Colors.red.shade100.withOpacity(0.3),
                      ],
                      onTap: () => Navigator.pop(context, true),
                    ),

                    const SizedBox(height: 12),

                    // گزینه عکس
                    _buildFormatOption(
                      context: context,
                      title: 'تصویر PNG',
                      subtitle: 'مناسب ارسال سریع',
                      icon: Icons.image_rounded,
                      iconColor: Colors.blue.shade600,
                      gradientColors: [
                        Colors.blue.shade50,
                        Colors.blue.shade100.withOpacity(0.3),
                      ],
                      onTap: () => Navigator.pop(context, false),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // 🎨 دکمه انصراف
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.grey.shade600,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    minimumSize: const Size(double.infinity, 48),
                  ),
                  child: const Text(
                    'انصراف',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

// 🎨 ویجت گزینه (قابل استفاده مجدد)
  Widget _buildFormatOption({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required List<Color> gradientColors,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradientColors,
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: iconColor.withOpacity(0.3),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: iconColor.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // آیکون
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: iconColor.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                icon,
                color: iconColor,
                size: 28,
              ),
            ),

            const SizedBox(width: 16),

            // متن
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),

            // آیکون فلش
           //Icon(
           //  Icons.arrow_back_ios_rounded,
           //  color: iconColor.withOpacity(0.5),
           //  size: 18,
           //),
          ],
        ),
      ),
    );
  }

// 🔥 اشتراک‌گذاری به صورت عکس (قبلی)
  Future<void> _shareAsImage() async {
    try {
      final RenderRepaintBoundary boundary =
      _invoiceKey.currentContext!.findRenderObject() as RenderRepaintBoundary;

      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final Uint8List pngBytes = byteData!.buffer.asUint8List();

      final tempDir = await getTemporaryDirectory();
      final file = await File('${tempDir.path}/invoice_${widget.invoice.invoiceNumber}.png').create();
      await file.writeAsBytes(pngBytes);

      final message = _getShareMessage();

      // 🔥 مستقیم اشتراک‌گذاری (بدون دیالوگ)
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'image/png')],
        text: message,
        subject: 'فاکتور شماره ${DateHelper.toPersianDigits(widget.invoice.invoiceNumber.toString())}',
      );

      if (mounted) {
        SnackBarHelper.showSuccess(context, 'فاکتور با موفقیت اشتراک‌گذاری شد');
      }
    } catch (e) {
      if (mounted) {
        SnackBarHelper.showError(context, 'خطا در اشتراک‌گذاری: ${e.toString()}');
      }
    }
  }

// 🔥 اشتراک‌گذاری به صورت PDF (جدید)
  Future<void> _shareAsPdf() async {
    try {
      final RenderRepaintBoundary boundary =
      _invoiceKey.currentContext!.findRenderObject() as RenderRepaintBoundary;

      final size = boundary.size;
      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final Uint8List imageBytes = byteData!.buffer.asUint8List();

      final pdf = pw.Document();
      final pdfImage = pw.MemoryImage(imageBytes);

      final pageFormat = PdfPageFormat(
        size.width * PdfPageFormat.point,
        size.height * PdfPageFormat.point,
        marginAll: 0,
      );

      pdf.addPage(
        pw.Page(
          pageFormat: pageFormat,
          margin: pw.EdgeInsets.zero,
          build: (pw.Context context) {
            return pw.Container(
              width: double.infinity,
              height: double.infinity,
              child: pw.Image(
                pdfImage,
                fit: pw.BoxFit.fill,
              ),
            );
          },
        ),
      );

      final tempDir = await getTemporaryDirectory();
      final pdfFile = File('${tempDir.path}/invoice_${widget.invoice.invoiceNumber}.pdf');
      await pdfFile.writeAsBytes(await pdf.save());

      final message = _getShareMessage();

      // 🔥 مستقیم اشتراک‌گذاری (بدون دیالوگ)
      await Share.shareXFiles(
        [XFile(pdfFile.path, mimeType: 'application/pdf')],
        text: message,
        subject: 'فاکتور شماره ${DateHelper.toPersianDigits(widget.invoice.invoiceNumber.toString())}',
      );

      if (mounted) {
        SnackBarHelper.showSuccess(context, 'فاکتور PDF با موفقیت اشتراک‌گذاری شد');
      }
    } catch (e) {
      if (mounted) {
        SnackBarHelper.showError(context, 'خطا در ساخت PDF: ${e.toString()}');
      }
    }
  }

// 🔥 متن اشتراک‌گذاری (جدا شده برای استفاده مجدد)
  String _getShareMessage() {
    return '${widget.customer.fullName} عزیز\n'
        'با سلام و احترام\n'
        'فاکتور خدمات عکاسی شما با شماره '
        '${DateHelper.toPersianDigits(widget.invoice.invoiceNumber.toString())} '
        'از آتلیه کودک فتولند برای شما ارسال می‌گردد.\n\n'
        'مبلغ قابل پرداخت: '
        '${DateHelper.toPersianDigits(ServiceModel.formatNumber(widget.grandTotal))} تومان\n\n'
        'از اینکه آتلیه فتولند را برای ثبت لحظات زیبای خود انتخاب کردید، صمیمانه سپاسگزاریم.\n'
        'در صورت نیاز به راهنمایی یا توضیحات بیشتر، با افتخار در خدمت شما هستیم.\n\n'
        'با آرزوی لحظاتی شاد و ماندگار 🌸';
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
                      RepaintBoundary(
                        key: _invoiceKey,
                        child: Container(
                          // 🔥 حذف padding اضافی
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.08),
                                blurRadius: 30,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min, // 🔥 اضافه شد
                            children: [
                              _buildInvoiceHeader(),
                              _buildCustomerInfo(),
                              const Divider(height: 1, thickness: 1),
                              _buildItemsSection(),
                              const Divider(height: 1, thickness: 1),
                              _buildCalculationsSection(),
                              if (widget.invoice.notes != null) _buildNotesSection(),
                              _buildBankInfo(),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
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
          Container(width: 44, height: 44),
          const Text(
            'پیش‌نمایش فاکتور',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: AppColors.textPrimary),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  // 🎨 هدر فاکتور با گرادیانت زیبا
  Widget _buildInvoiceHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary,
            AppColors.primary.withOpacity(0.8),
          ],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        children: [
          // لوگو یا نام شرکت
      Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center, // ردیف‌ها از چپ شروع بشن
        children: const [
          Text(
            'آتلیه کودک فتولند',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 1,
            ),
          ),
          SizedBox(height: 4), // فاصله بین عنوان و آدرس
          Text(
            'شیراز، کوچه ۵ ملاصدرا، طاها و پارسا ۷',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white70,
            ),
          ),
        ],
      ),
    ),

    const SizedBox(height: 20),
          // شماره و تاریخ فاکتور
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildHeaderInfo(
                label: 'تاریخ',
                value: DateHelper.toPersianDigits(
                  DateHelper.dateTimeToShamsi(widget.invoice.invoiceDate),
                ),
              ),
              Container(
                width: 1,
                height: 40,
                color: Colors.white.withOpacity(0.6),
              ),
              _buildHeaderInfo(
                label: 'شماره فاکتور',
                value: DateHelper.toPersianDigits(
                  widget.invoice.invoiceNumber.toString(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderInfo({
    required String label,
    required String value,
  }) {
    return Column(
      children: [
        //Icon(icon, color: Colors.white.withOpacity(0.9), size: 20),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.white.withOpacity(0.8),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  // 🎨 اطلاعات مشتری
  Widget _buildCustomerInfo() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [

          /// --- آیکون مشتری
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.person,
              color: AppColors.primary,
              size: 20,
            ),
          ),

          const SizedBox(width: 12),

          /// --- نام مشتری
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'مشتری',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.customer.fullName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),

          /// فاصله بین نام و موبایل
          const SizedBox(width: 20),

          /// --- شماره موبایل
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.info.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.phone,
                  color: AppColors.info,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'شماره تماس',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    DateHelper.toPersianDigits(widget.customer.mobileNumber),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                    textDirection: TextDirection.ltr,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }


  // 🎨 بخش آیتم‌های فاکتور
  Widget _buildItemsSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // عنوان بخش
         Row(
           mainAxisAlignment: MainAxisAlignment.center,
           children: [
             const Text(
               'اقلام فاکتور',
               style: TextStyle(
                 fontSize: 16,
                 fontWeight: FontWeight.bold,
                 color: AppColors.textPrimary,
               ),
             ),
             const SizedBox(width: 8),
             //Container(
             //  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
             //  decoration: BoxDecoration(
             //    color: AppColors.primary.withOpacity(0.1),
             //    borderRadius: BorderRadius.circular(12),
             //  ),
             //  child: Text(
             //    DateHelper.toPersianDigits(widget.items.length.toString()),
             //    style: const TextStyle(
             //      fontSize: 13,
             //      fontWeight: FontWeight.bold,
             //      color: AppColors.primary,
             //    ),
             //  ),
             //),
           ],
         ),
          const SizedBox(height: 16),
          // آیتم‌ها
          ...widget.items.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            return _buildInvoiceItem(item, index + 1);
          }),
        ],
      ),
    );
  }

  Widget _buildInvoiceItem(InvoiceItem item, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          // ردیف اول: شماره و نام خدمت
          Row(
            children: [
              // شماره ردیف
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    DateHelper.toPersianDigits(index.toString()),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // نام خدمت
              Expanded(
                child: Text(
                  item.serviceName,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
         // const Divider(height: 1),
          const SizedBox(height: 8),
          // ردیف دوم: تعداد، قیمت واحد، جمع
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildItemDetail(
                label: 'تعداد',
                value: DateHelper.toPersianDigits(item.quantity.toString()),
                color: AppColors.textSecondary,
              ),
              _buildItemDetail(
                label: 'قیمت واحد',
                value: DateHelper.toPersianDigits(
                  ServiceModel.formatNumber(item.unitPrice),
                ),
                color: AppColors.textSecondary,
              ),
              _buildItemDetail(
                label: 'جمع',
                value: DateHelper.toPersianDigits(
                  ServiceModel.formatNumber(item.totalPrice),
                ),
                color: AppColors.success,
                isBold: true,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildItemDetail({
    required String label,
    required String value,
    required Color color,
    bool isBold = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.textLight,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: isBold ? 15 : 13,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }

  // 🎨 بخش محاسبات
  Widget _buildCalculationsSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // جمع کل آیتم‌ها
          _buildCalcRow(
            'جمع اقلام:',
            DateHelper.toPersianDigits(ServiceModel.formatNumber(widget.totalAmount)),
            Colors.grey.shade700,
          ),
          const SizedBox(height: 12),

          // هزینه ارسال
          if (widget.shippingCost > 0) ...[
            _buildCalcRow(
              'هزینه ارسال:',
              '${DateHelper.toPersianDigits(ServiceModel.formatNumber(widget.shippingCost))} +',
              AppColors.info,
            ),
            const SizedBox(height: 12),
          ],

          // تخفیف
          if (widget.discount > 0) ...[
            _buildCalcRow(
              'تخفیف:',
              '${DateHelper.toPersianDigits(ServiceModel.formatNumber(widget.discount))} -',
              AppColors.error,
            ),
            const SizedBox(height: 12),
          ],

          const SizedBox(height: 16),

          // خط جداکننده
         // Container(
         //   margin: const EdgeInsets.symmetric(vertical: 12),
         //   child: const Divider(thickness: 2),
         // ),

          // جمع نهایی
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary.withOpacity(0.1),
                  AppColors.primary.withOpacity(0.05),
                ],
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  ' قابل پرداخت:',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                Row(
                  children: [
                    Text(
                      DateHelper.toPersianDigits(
                        ServiceModel.formatNumber(widget.grandTotal),
                      ),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'تومان',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // دریافتی
          _buildCalcRow(
            'مبلغ دریافت شده:',
            DateHelper.toPersianDigits(ServiceModel.formatNumber(widget.paidAmount)),
            AppColors.success,
          ),

          const SizedBox(height: 16),

          // مانده
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: widget.remainingAmount > 0
                  ? AppColors.error.withOpacity(0.1)
                  : AppColors.success.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: widget.remainingAmount > 0
                    ? AppColors.error.withOpacity(0.3)
                    : AppColors.success.withOpacity(0.3),
                width: 2,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      widget.remainingAmount > 0 ? 'مانده:' : 'تسویه شده',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: widget.remainingAmount > 0
                            ? AppColors.error
                            : AppColors.success,
                      ),
                    ),
                    const SizedBox(width: 8),
                   // Icon(
                   //   widget.remainingAmount > 0
                   //       ? Icons.pending_outlined
                   //       : Icons.check_circle,
                   //   color: widget.remainingAmount > 0
                   //       ? AppColors.error
                   //       : AppColors.success,
                   //   size: 24,
                   // ),
                  ],
                ),
                Row(
                  children: [
                    Text(
                      DateHelper.toPersianDigits(
                        ServiceModel.formatNumber(widget.remainingAmount.abs()),
                      ),
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: widget.remainingAmount > 0
                            ? AppColors.error
                            : AppColors.success,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'تومان',
                      style: TextStyle(
                        fontSize: 13,
                        color: widget.remainingAmount > 0
                            ? AppColors.error
                            : AppColors.success,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalcRow(String label, String value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            color: AppColors.textSecondary,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  // 🎨 بخش توضیحات
  Widget _buildNotesSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 1),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Icon(
                Icons.note_alt_outlined,
                color: Colors.amber.shade700,
                size: 20,
              ),
              const SizedBox(width: 8),
              const Text(
                'یادداشت',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            widget.invoice.notes!,
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textPrimary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }


  // 🎨 بخش اطلاعات بانکی
  Widget _buildBankInfo() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.blue.shade50,
            Colors.blue.shade100.withOpacity(0.3),
          ],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.blue.shade200,
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // آیکون و عنوان
          Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.blue.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.account_balance,
                  color: Colors.blue.shade700,
                  size: 18,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'اطلاعات واریز',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),
          // متن اطلاعات بانکی
          RichText(
            textAlign: TextAlign.right,
            text: TextSpan(
              style: const TextStyle(
                fontSize: 13,
                height: 1.8,
                color: AppColors.textPrimary,
                fontFamily: 'Vazirmatn',
              ),
              children: [
                const TextSpan(
                  text: 'لطفا مبلغ فاکتور را به حساب ',
                ),
                TextSpan(
                  text: DateHelper.toPersianDigits('1190 0405 8618 6219'),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                    fontSize: 14,
                  ),
                ),
                const TextSpan(
                  text: ' بانک ',
                ),
                const TextSpan(
                  text: 'سامان',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
                const TextSpan(
                  text: ' به نام ',
                ),
                const TextSpan(
                  text: 'فاطمه گرامی تبار',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
                const TextSpan(
                  text: ' واریز نمایید.',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShareButton() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.primary.withOpacity(0.8)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ElevatedButton.icon(
        onPressed: _isSharing ? null : _shareInvoice,
        icon: _isSharing
            ? const SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(
            color: Colors.white,
            strokeWidth: 2.5,
          ),
        )
            : const Icon(Icons.share_rounded, color: Colors.white, size: 22),
        label: Text(
          _isSharing ? 'در حال اشتراک‌گذاری...' : 'اشتراک‌گذاری فاکتور',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          minimumSize: const Size(double.infinity, 56),
        ),
      ),
    );
  }

  Widget _buildBottomButton() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: OutlinedButton(
        onPressed: () => Navigator.pop(context),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          side: BorderSide(color: Colors.grey.shade300, width: 2),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          minimumSize: const Size(double.infinity, 52),
        ),
        child: const Text(
          'بستن',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}