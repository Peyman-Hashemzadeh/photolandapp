import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/constants/colors.dart';
import '../../widgets/dashboard_card.dart';
import 'customers_screen.dart';
import 'banks_screen.dart';
import 'services_screen.dart';
import 'expenses_screen.dart';

class BaseDataMenuScreen extends StatelessWidget {
  const BaseDataMenuScreen({super.key});

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
              _buildHeader(context),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // ردیف اول: مشتری و خدمت
                      Row(
                        children: [
                          // تعریف خدمت
                          Expanded(
                            child: _buildServiceCard(context),
                          ),
                          const SizedBox(width: 16),
                          // تعریف مشتری
                          Expanded(
                            child: _buildCustomerCard(context),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // ردیف دوم: هزینه و بانک
                      Row(
                        children: [
                          // تعریف بانک
                          Expanded(
                            child: _buildBankCard(context),
                          ),
                          const SizedBox(width: 16),
                          // تعریف هزینه
                          Expanded(
                            child: _buildExpenseCard(context),
                          ),
                        ],
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

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(
              Icons.arrow_back,
              color: AppColors.textPrimary,
            ),
            onPressed: () => Navigator.pop(context),
          ),
          const Text(
            'اطلاعات پایه',
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

  Widget _buildCustomerCard(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('customers').snapshots(),
      builder: (context, snapshot) {
        int count = snapshot.hasData ? snapshot.data!.docs.length : 0;

        return Column(
          children: [
            DashboardCard(
              title: 'تعریف مشتری',
              svgAsset: 'assets/images/icons/user-circle-plus.svg',
              backgroundColor: const Color(0xFF5CADD8),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const CustomersScreen(),
                  ),
                );
              },
            ),
            const SizedBox(height: 6),
            Text(
              'تعداد: $count',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildServiceCard(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('services').snapshots(),
      builder: (context, snapshot) {
        int count = snapshot.hasData ? snapshot.data!.docs.length : 0;

        return Column(
          children: [
            DashboardCard(
              title: 'تعریف خدمت',
              svgAsset: 'assets/images/icons/bag-shopping.svg',
              backgroundColor: const Color(0xFF9C7DD8),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ServicesScreen(),
                  ),
                );
              },
            ),
            const SizedBox(height: 6),
            Text(
              'تعداد: $count',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildExpenseCard(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('expenses').snapshots(),
      builder: (context, snapshot) {
        int count = snapshot.hasData ? snapshot.data!.docs.length : 0;

        return Column(
          children: [
            DashboardCard(
              title: 'تعریف هزینه',
              svgAsset: 'assets/images/icons/file-invoice-dollar.svg',
              backgroundColor: const Color(0xFFFF9F6E),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ExpensesScreen(),
                  ),
                );
              },
            ),
            const SizedBox(height: 6),
            Text(
              'تعداد: $count',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildBankCard(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('banks').snapshots(),
      builder: (context, snapshot) {
        int count = snapshot.hasData ? snapshot.data!.docs.length : 0;

        return Column(
          children: [
            DashboardCard(
              title: 'تعریف بانک',
              svgAsset: 'assets/images/icons/building.svg',
              backgroundColor: const Color(0xFF7DD8B8),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const BanksScreen(),
                  ),
                );
              },
            ),
            const SizedBox(height: 6),
            Text(
              'تعداد: $count',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        );
      },
    );
  }
}