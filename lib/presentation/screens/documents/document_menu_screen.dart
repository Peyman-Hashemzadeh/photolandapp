import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../core/constants/colors.dart';
import '../../widgets/dashboard_card.dart';
import '../invoices/add_invoice_screen.dart';
import '../invoices/add_invoice_new_customer_screen.dart';
import '../expenses/add_expense_document_screen.dart';

class DocumentMenuScreen extends StatelessWidget {
  const DocumentMenuScreen({super.key});

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
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // صدور فاکتور
                      DashboardCard(
                        title: 'صدور فاکتور',
                        svgAsset: 'assets/images/icons/file-invoice-dollar.svg',
                        backgroundColor: const Color(0xFF9C7DD8),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const AddInvoiceScreen(),
                            ),
                          );
                        },
                      ),

                      const SizedBox(height: 16),

                      // فاکتور دستی
                      DashboardCard(
                        title: 'فاکتور دستی',
                        svgAsset: 'assets/images/icons/sheet-plastic.svg',
                        backgroundColor: const Color(0xFF5CADD8),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const AddInvoiceNewCustomerScreen(),
                            ),
                          );
                        },
                      ),

                      const SizedBox(height: 16),

                      // ثبت هزینه
                      DashboardCard(
                        title: 'ثبت هزینه',
                        svgAsset: 'assets/images/icons/receipt.svg',
                        backgroundColor: const Color(0xFFFF9F6E),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const AddExpenseDocumentScreen(),
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
            'صدور سند',
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
}