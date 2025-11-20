import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../core/constants/colors.dart';
import '../../../data/repositories/appointment_repository.dart';
import '../../widgets/dashboard_card.dart';
import 'add_appointment_screen.dart';
import 'received_appointments_screen.dart';

class AppointmentMenuScreen extends StatefulWidget {
  const AppointmentMenuScreen({super.key});

  @override
  State<AppointmentMenuScreen> createState() => _AppointmentMenuScreenState();
}

class _AppointmentMenuScreenState extends State<AppointmentMenuScreen> {
  final AppointmentRepository _repository = AppointmentRepository();
  int receivedCount = 0;

  @override
  void initState() {
    super.initState();
    _loadReceivedCount();
  }

  Future<void> _loadReceivedCount() async {
    final count = await _repository.getReceivedAppointmentsCount();
    if (mounted) {
      setState(() {
        receivedCount = count;
      });
    }
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
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // ثبت نوبت
                      DashboardCard(
                        title: 'ثبت نوبت',
                        svgAsset: 'assets/images/icons/bag-shopping.svg',
                        backgroundColor: const Color(0xFF9C7DD8),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const AddAppointmentScreen(
                                isNewCustomer: false,
                              ),
                            ),
                          );
                        },
                      ),

                      const SizedBox(height: 16),

                      // نوبت مشتری جدید
                      DashboardCard(
                        title: 'نوبت مشتری جدید',
                        svgAsset: 'assets/images/icons/bag-shopping-plus.svg',
                        backgroundColor: const Color(0xFF5CADD8),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const AddAppointmentScreen(
                                isNewCustomer: true,
                              ),
                            ),
                          );
                        },
                      ),

                      const SizedBox(height: 16),

                      // نوبت‌های دریافتی
                      DashboardCard(
                        title: 'نوبت های دریافتی',
                        svgAsset: 'assets/images/icons/globe.svg',
                        backgroundColor: const Color(0xFF7DD8B8),
                        badgeCount: receivedCount,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const ReceivedAppointmentsScreen(),
                            ),
                          );
                        },
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
          // دکمه برگشت
          IconButton(
            icon: const Icon(
              Icons.arrow_back,
              color: AppColors.textPrimary,
            ),
            onPressed: () => Navigator.pop(context),
          ),

          // عنوان
          const Text(
            'ثبت نوبت',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),

          // آیکون پروفایل
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
                child: FaIcon(
                  FontAwesomeIcons.user,
                  color: Colors.grey,
                  size: 20,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}