import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../core/constants/colors.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../data/models/customer_model.dart';
import '../../../data/repositories/customer_repository.dart';
import '../../widgets/customer_card.dart';
import '../../widgets/add_customer_dialog.dart';

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key});

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  final CustomerRepository _repository = CustomerRepository();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _showAddCustomerDialog({CustomerModel? customer}) async {
    final result = await showDialog<CustomerModel>(
      context: context,
      builder: (context) => AddCustomerDialog(customer: customer),
    );

    if (result != null) {
      try {
        if (customer == null) {
          // افزودن مشتری جدید
          await _repository.addCustomer(result);
          if (mounted) {
            SnackBarHelper.showSuccess(context, 'مشتری با موفقیت ثبت شد.');
          }
        } else {
          // ویرایش مشتری
          await _repository.updateCustomer(result);
          if (mounted) {
            SnackBarHelper.showSuccess(context, 'مشتری با موفقیت ویرایش شد.');
          }
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

  Future<void> _toggleCustomerStatus(CustomerModel customer) async {
    final newStatus = !customer.isActive;
    final action = newStatus ? 'فعال‌سازی مجدد' : 'تعلیق';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Text('$action مشتری'),
          content: Text(
            'آیا برای $action این مشتری اطمینان دارید؟',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(
                'بله',
                style: TextStyle(
                  color: newStatus ? AppColors.success : AppColors.error,
                ),
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
      try {
        await _repository.toggleCustomerStatus(customer.id, newStatus);
        if (mounted) {
          SnackBarHelper.showSuccess(
            context,
            newStatus ? 'مشتری فعال شد.' : 'مشتری تعلیق شد.',
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
              _buildSearchBar(),
              Expanded(
                child: _buildCustomersList(),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddCustomerDialog(),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
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
              //  child: FaIcon(
              //    FontAwesomeIcons.user,
              //    color: Colors.grey,
              //    size: 20,
              //  ),
              //),
            ),
          ),
          const Text(
            'لیست مشتریان',
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

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: TextField(
        controller: _searchController,
        textAlign: TextAlign.right,
        decoration: InputDecoration(
          hintText: 'جستجو بر اساس نام یا شماره موبایل',
          hintStyle: TextStyle(color: Colors.grey.shade400),
          prefixIcon: Icon(Icons.search, color: Colors.grey.shade400),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
        ),
        onChanged: (value) {
          setState(() {
            _searchQuery = value;
          });
        },
      ),
    );
  }

  Widget _buildCustomersList() {
    return StreamBuilder<List<CustomerModel>>(
      stream: _searchQuery.isEmpty
          ? _repository.getAllCustomers()
          : _repository.searchCustomers(_searchQuery),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              'خطا در بارگذاری اطلاعات',
              style: TextStyle(color: AppColors.error),
            ),
          );
        }

        final customers = snapshot.data ?? [];

        if (customers.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.people_outline,
                  size: 80,
                  color: Colors.grey.shade300,
                ),
                const SizedBox(height: 16),
                Text(
                  _searchQuery.isEmpty
                      ? 'هنوز مشتری‌ای ثبت نشده است!'
                      : 'نتیجه‌ای یافت نشد!',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: customers.length,
          itemBuilder: (context, index) {
            final customer = customers[index];
            return CustomerCard(
              customer: customer,
              onEdit: () => _showAddCustomerDialog(customer: customer),
              onToggleStatus: () => _toggleCustomerStatus(customer),
            );
          },
        );
      },
    );
  }
}