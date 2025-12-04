import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:photolandapp/presentation/widgets/dashboard_card.dart';
import '../../../core/constants/colors.dart';
import '../appointments/appointment_menu_screen.dart';
import '../../../services/firebase_service.dart';
import '../base_data/base_data_menu_screen.dart';
import '../auth/login_screen.dart';
import '../calendar/calendar_screen.dart';
import '../documents/document_menu_screen.dart';
import '../reports/financial_report_screen.dart';
import '../form_sharing/share_form_screen.dart';
import '../profile/profile_screen.dart';
import '../../../data/repositories/appointment_repository.dart';
import '../reminders/reminders_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String userName = 'کاربر';
  int receivedAppointmentsCount = 0;
  bool isLoading = true;
  File? _profileImage;
  String? _profileImagePath;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadBadgeCount();
  }

  // 🔥 بارگذاری داده‌های کاربر به صورت Realtime
  Future<void> _loadUserData() async {
    try {
      final user = FirebaseService.getCurrentUser();
      if (user != null) {
        // 🔥 استفاده از snapshots برای Realtime
        FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .snapshots()
            .listen((doc) {
          if (doc.exists && mounted) {
            setState(() {
              userName = doc.data()?['fullName'] ?? 'کاربر';
              _profileImagePath = doc.data()?['profileImagePath'];

              // بارگذاری عکس پروفایل
              if (_profileImagePath != null && _profileImagePath!.isNotEmpty) {
                final file = File(_profileImagePath!);
                if (file.existsSync()) {
                  _profileImage = file;
                } else {
                  _profileImage = null;
                }
              } else {
                _profileImage = null;
              }

              isLoading = false;
            });
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> _loadBadgeCount() async {
    final AppointmentRepository repository = AppointmentRepository();

    // گوش دادن به تغییرات realtime
    repository.getReceivedAppointments().listen((appointments) {
      if (mounted) {
        setState(() {
          receivedAppointmentsCount = appointments.length;
        });
      }
    });
  }

  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('خروج از حساب کاربری'),
          content: const Text('آیا برای خروج اطمینان دارید؟'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text(
                'بله',
                style: TextStyle(color: AppColors.error),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('خیر'),
            ),
          ],
        ),
      ),
    );

    if (confirm == true) {
      await FirebaseService.signOut();

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const LoginScreen(),
        ),
      );
    }
  }

  // 🔥 رفتن به صفحه پروفایل
  void _navigateToProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ProfileScreen(),
      ),
    );
  }

  void _navigateToAppointments() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AppointmentMenuScreen(),
      ),
    );
  }

  void _navigateToCalendar() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const CalendarScreen(),
      ),
    );
  }

  void _navigateToInvoice() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const DocumentMenuScreen(),
      ),
    );
  }

  void _navigateToInvoicesList() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const FinancialReportScreen(),
      ),
    );
  }

  void _navigateToFormSharing() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ShareFormScreen(),
      ),
    );
  }

  void _navigateToBaseData() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const BaseDataMenuScreen(),
      ),
    );
  }

  void _navigateToReports() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('صفحه گزارشات به زودی...')),
    );
  }

  void _navigateToReminders() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const RemindersScreen(),
      ),
    );
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
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 16,
                    runSpacing: 16,
                    children: [
                      DashboardCard(
                        title: 'ثبت نوبت',
                        svgAsset: 'assets/images/icons/camera-clock.svg',
                        backgroundColor: const Color(0xFF9C7DD8),
                        badgeCount: receivedAppointmentsCount,
                        onTap: _navigateToAppointments,
                      ),
                      DashboardCard(
                        title: 'تقویم',
                        svgAsset: 'assets/images/icons/calendar.svg',
                        backgroundColor: const Color(0xFF5CADD8),
                        onTap: _navigateToCalendar,
                      ),
                      DashboardCard(
                        title: 'صدور سند',
                        svgAsset: 'assets/images/icons/file-invoice-dollar.svg',
                        backgroundColor: const Color(0xFFFF9F6E),
                        onTap: _navigateToInvoice,
                      ),
                      DashboardCard(
                        title: 'صورت حسابها',
                        svgAsset: 'assets/images/icons/sheet-plastic.svg',
                        backgroundColor: const Color(0xFFE89CC2),
                        onTap: _navigateToInvoicesList,
                      ),
                      DashboardCard(
                        title: 'ارسال فرم',
                        svgAsset: 'assets/images/icons/link-horizontal.svg',
                        backgroundColor: const Color(0xFF7DD8B8),
                        onTap: _navigateToFormSharing,
                      ),
                      DashboardCard(
                        title: 'اطلاعات پایه',
                        svgAsset: 'assets/images/icons/gear-complex.svg',
                        backgroundColor: const Color(0xFF8BA3D8),
                        onTap: _navigateToBaseData,
                      ),
                      DashboardCard(
                        title: 'یادآوری',
                        svgAsset: 'assets/images/icons/bell.svg',
                        backgroundColor: const Color(0xFFFFC107),
                        onTap: _navigateToReminders,
                      ),
                      DashboardCard(
                        title: 'گزارشات',
                        svgAsset: 'assets/images/icons/chart-line.svg',
                        backgroundColor: const Color(0xFF9E9E9E),
                        onTap: _navigateToReports,
                      ),
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
          // 🔥 آیکون پروفایل با عکس
          GestureDetector(
            onTap: _navigateToProfile,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                shape: BoxShape.circle,
              ),
              child: ClipOval(
                child: _profileImage != null && _profileImage!.existsSync()
                    ? Image.file(
                  _profileImage!,
                  fit: BoxFit.cover,
                )
                    : const Center(
                  child: FaIcon(
                    FontAwesomeIcons.user,
                    color: Colors.grey,
                    size: 20,
                  ),
                ),
              ),
            ),
          ),

          // نام کاربر
          isLoading
              ? const CircularProgressIndicator(strokeWidth: 2)
              : Text(
            userName,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),

          // آیکون خروج
          IconButton(
            icon: const FaIcon(
              FontAwesomeIcons.powerOff,
              color: Colors.black87,
              size: 20,
            ),
            onPressed: _handleLogout,
            tooltip: 'خروج',
          ),
        ],
      ),
    );
  }
}