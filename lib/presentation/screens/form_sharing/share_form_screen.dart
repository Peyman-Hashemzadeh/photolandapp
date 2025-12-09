import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../core/constants/colors.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../data/models/studio_model.dart';
import '../../../data/repositories/studio_repository.dart';
import '../../../services/firebase_service.dart';


class ShareFormScreen extends StatefulWidget {
  const ShareFormScreen({super.key});

  @override
  State<ShareFormScreen> createState() => _ShareFormScreenState();
}

class _ShareFormScreenState extends State<ShareFormScreen> {
  final StudioRepository _studioRepository = StudioRepository();
  StudioModel? _studio;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStudioInfo();
  }

  Future<void> _loadStudioInfo() async {
    setState(() => _isLoading = true);

    try {
      // دریافت اطلاعات آتلیه بر اساس studioCode جاری
      // 🔥 فعلاً از کد هاردکد استفاده می‌کنیم
      final studioCode = FirebaseService.VALID_STUDIO_CODE;

      var studio = await _studioRepository.getStudioByCode(studioCode);

      // اگر آتلیه وجود نداره، ایجادش کن
      if (studio == null) {
        await _studioRepository.createOrUpdateStudio(
          studioCode,
          studioName: 'آتلیه فتولند',
          address: 'شیراز، خیابان ملاصدرا',
        );
        studio = await _studioRepository.getStudioByCode(studioCode);
      }

      if (mounted) {
        setState(() {
          _studio = studio;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        SnackBarHelper.showError(
          context,
          e.toString().replaceAll('Exception: ', ''),
        );
      }
    }
  }

  Future<void> _shareLink() async {
    if (_studio == null) return;

    try {
      await Share.share(
        'سلام! 👋\n\n'
            'برای رزرو نوبت عکاسی در ${_studio!.studioName} روی لینک زیر کلیک کنید:\n\n'
            '${_studio!.bookingUrl}\n\n'
            'منتظر دیدارتان هستیم! 📸',
        subject: 'رزرو نوبت آنلاین - ${_studio!.studioName}',
      );

      if (mounted) {
        SnackBarHelper.showSuccess(context, 'لینک با موفقیت اشتراک‌گذاری شد');
      }
    } catch (e) {
      if (mounted) {
        SnackBarHelper.showError(context, 'خطا در اشتراک‌گذاری');
      }
    }
  }

  Future<void> _copyLink() async {
    if (_studio == null) return;

    await Clipboard.setData(ClipboardData(text: _studio!.bookingUrl));

    if (mounted) {
      SnackBarHelper.showSuccess(context, 'لینک کپی شد');
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
              if (_isLoading)
                const Expanded(
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_studio != null)
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        _buildInfoCard(),
                        const SizedBox(height: 24),
                        _buildQRCode(),
                        const SizedBox(height: 24),
                        _buildLinkCard(),
                        const SizedBox(height: 24),
                        _buildActionButtons(),
                        const SizedBox(height: 24),
                        _buildInstructions(),
                      ],
                    ),
                  ),
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
          GestureDetector(
            onTap: () {},
            child: Container(
              width: 44,
              height: 44,
              //decoration: BoxDecoration(
              //  color: Colors.grey.shade300,
              //  shape: BoxShape.circle,
              //),
              //child: const Center(
              //  child: FaIcon(FontAwesomeIcons.user, color: Colors.grey, size: 20),
              //),
            ),
          ),
          const Text(
            'اشتراک گذاری فرم رزرو نوبت',
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

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          const Icon(Icons.qr_code_2, size: 60, color: Colors.white),
          const SizedBox(height: 16),
          Text(
            _studio!.studioName,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          if (_studio!.address != null) ...[
            const SizedBox(height: 8),
            Text(
              _studio!.address!,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.white70,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQRCode() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          const Text(
            'کد QR فرم رزرو',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          QrImageView(
            data: _studio!.bookingUrl,
            version: QrVersions.auto,
            size: 200.0,
            backgroundColor: Colors.white,
          ),
          const SizedBox(height: 12),
          const Text(
            'مشتریان می‌توانند با اسکن این کد وارد فرم رزرو شوند',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildLinkCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              _studio!.bookingUrl,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 12),
          IconButton(
            icon: const Icon(Icons.copy, color: AppColors.primary),
            onPressed: _copyLink,
            tooltip: 'کپی لینک',
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton.icon(
            onPressed: _shareLink,
            icon: const Icon(Icons.share, color: Colors.white),
            label: const Text(
              'اشتراک‌گذاری لینک',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 54,
          child: OutlinedButton.icon(
            onPressed: _copyLink,
            icon: const Icon(Icons.link, color: AppColors.primary),
            label: const Text(
              'کپی لینک',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.primary, width: 2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInstructions() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
              const SizedBox(width: 8),
              Text(
                'راهنما',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildInstructionItem('1. لینک یا کد QR را با مشتریان به اشتراک بگذارید'),
          _buildInstructionItem('2. مشتری فرم رزرو را پر می‌کند'),
          _buildInstructionItem('3. نوبت در بخش "نوبت‌های دریافتی" نمایش داده می‌شود'),
          _buildInstructionItem('4. می‌توانید نوبت را تایید یا رد کنید'),
        ],
      ),
    );
  }

  Widget _buildInstructionItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(fontSize: 16)),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}