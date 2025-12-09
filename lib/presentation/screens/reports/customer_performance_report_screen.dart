import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shamsi_date/shamsi_date.dart';
import '../../../core/constants/colors.dart';
import '../../../core/utils/date_helper.dart';
import '../../../data/models/customer_model.dart';
import '../../../data/models/appointment_model.dart';

class CustomerPerformanceReportScreen extends StatefulWidget {
  const CustomerPerformanceReportScreen({super.key});

  @override
  State<CustomerPerformanceReportScreen> createState() =>
      _CustomerPerformanceReportScreenState();
}

class _CustomerPerformanceReportScreenState
    extends State<CustomerPerformanceReportScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _searchController = TextEditingController();

  List<CustomerModel> _allCustomers = [];
  List<CustomerModel> _filteredCustomers = [];
  CustomerModel? _selectedCustomer;
  bool _isLoading = false;
  bool _showDropdown = false;

  // داده‌های گزارش
  int _totalAppointments = 0;
  int _totalIncome = 0;
  Map<String, int> _servicesData = {}; // نام خدمت : تعداد
  AppointmentModel? _lastAppointment;
  AppointmentModel? _nextAppointment;

  @override
  void initState() {
    super.initState();
    _loadCustomers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCustomers() async {
    try {
      final snapshot = await _firestore
          .collection('customers')
          .where('isActive', isEqualTo: true)
          .get();

      final customers = snapshot.docs
          .map((doc) => CustomerModel.fromMap(doc.data(), doc.id))
          .toList();

      // مرتب‌سازی الفبایی
      customers.sort((a, b) => a.fullName.compareTo(b.fullName));

      setState(() {
        _allCustomers = customers;
        _filteredCustomers = customers;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطا در بارگذاری مشتریان: $e')),
        );
      }
    }
  }

  void _filterCustomers(String query) {
    if (query.isEmpty) {
      setState(() {
        _filteredCustomers = _allCustomers;
      });
      return;
    }

    final searchLower = query.toLowerCase();
    setState(() {
      _filteredCustomers = _allCustomers.where((customer) {
        final nameLower = customer.fullName.toLowerCase();
        final mobile = customer.mobileNumber;
        return nameLower.contains(searchLower) || mobile.contains(query);
      }).toList();
    });
  }

  Future<void> _loadCustomerReport() async {
    if (_selectedCustomer == null) return;

    setState(() => _isLoading = true);

    try {
      final customerId = _selectedCustomer!.id;
      final today = DateTime.now();
      final startOfToday = DateTime(today.year, today.month, today.day);

      // 🔥 Query 1: همه نوبت‌های تاییدشده مشتری
      final appointmentsSnapshot = await _firestore
          .collection('appointments')
          .where('customerId', isEqualTo: customerId)
          .where('status', isEqualTo: 'confirmed')
          .get();

      final allAppointments = appointmentsSnapshot.docs
          .map((doc) => AppointmentModel.fromMap(doc.data(), doc.id))
          .toList();

      // 🔥 Query 2: تمام فاکتورهای مشتری
      final invoicesSnapshot = await _firestore
          .collection('invoices')
          .where('customerId', isEqualTo: customerId)
          .get();

      final invoiceIds = invoicesSnapshot.docs.map((doc) => doc.id).toList();

      // 🔥 Query 3: تمام آیتم‌های فاکتورهای مشتری
      Map<String, int> servicesMap = {};
      for (var invoiceId in invoiceIds) {
        final itemsSnapshot = await _firestore
            .collection('invoice_items')
            .where('invoiceId', isEqualTo: invoiceId)
            .get();

        for (var doc in itemsSnapshot.docs) {
          final data = doc.data();
          final serviceName = data['serviceName'] as String? ?? 'نامشخص';
          final quantity = data['quantity'] as int? ?? 0;

          servicesMap[serviceName] = (servicesMap[serviceName] ?? 0) + quantity;
        }
      }

      // 🔥 Query 4: تمام پرداخت‌های مشتری (اصلاح شده)
      int totalIncome = 0;
      if (invoiceIds.isNotEmpty) {
        // 🔥 تغییر: از appointmentId به invoiceId
        final paymentsSnapshot = await _firestore
            .collection('payments')
            .where('invoiceId', whereIn: invoiceIds.take(10).toList()) // محدودیت Firestore
            .get();

        for (var doc in paymentsSnapshot.docs) {
          final amount = (doc.data()['amount'] as int?) ?? 0;
          totalIncome += amount;
        }

        // 🔥 اگر بیشتر از 10 فاکتور داریم، بقیه رو هم بگیریم
        if (invoiceIds.length > 10) {
          for (int i = 10; i < invoiceIds.length; i += 10) {
            final batch = invoiceIds.skip(i).take(10).toList();
            final batchPayments = await _firestore
                .collection('payments')
                .where('invoiceId', whereIn: batch)
                .get();

            for (var doc in batchPayments.docs) {
              final amount = (doc.data()['amount'] as int?) ?? 0;
              totalIncome += amount;
            }
          }
        }
      }

      // 🔥 پردازش نوبت‌ها در کلاینت
      final pastAppointments = allAppointments
          .where((apt) =>
      apt.requestedDate.isBefore(startOfToday) ||
          apt.requestedDate.isAtSameMomentAs(startOfToday))
          .toList();

      final futureAppointments = allAppointments
          .where((apt) => apt.requestedDate.isAfter(startOfToday))
          .toList();

      // مرتب‌سازی
      pastAppointments.sort((a, b) => b.requestedDate.compareTo(a.requestedDate));
      futureAppointments
          .sort((a, b) => a.requestedDate.compareTo(b.requestedDate));

      // مرتب‌سازی خدمات بر اساس تعداد (نزولی)
      final sortedServices = servicesMap.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      setState(() {
        _totalAppointments = pastAppointments.length;
        _totalIncome = totalIncome;
        _servicesData = Map.fromEntries(sortedServices);
        _lastAppointment =
        pastAppointments.isNotEmpty ? pastAppointments.first : null;
        _nextAppointment =
        futureAppointments.isNotEmpty ? futureAppointments.first : null;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطا در بارگذاری گزارش: $e')),
        );
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
              _buildSearchableDropdown(),
              if (_isLoading)
                const Expanded(
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_selectedCustomer == null)
                _buildEmptyState('لطفاً یک مشتری انتخاب کنید!')
              else
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        _buildCustomerInfoCard(),
                        const SizedBox(height: 16),
                        _buildAppointmentsCard(),
                        const SizedBox(height: 16),
                        _buildIncomeCard(),
                        const SizedBox(height: 16),
                        _buildServicesCard(),
                        const SizedBox(height: 20),
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
            child: Container(width: 44, height: 44),
          ),
          const Text(
            'گزارش عملکرد مشتری',
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

  Widget _buildSearchableDropdown() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // فیلد جستجو / نمایش انتخاب شده
          InkWell(
            onTap: () {
              setState(() {
                _showDropdown = !_showDropdown;
                if (_showDropdown) {
                  _searchController.clear();
                  _filteredCustomers = _allCustomers;
                }
              });
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _selectedCustomer?.fullName ?? 'انتخاب مشتری',
                    style: TextStyle(
                      fontSize: 14,
                      color: _selectedCustomer != null
                          ? AppColors.textPrimary
                          : Colors.grey.shade600,
                    ),
                  ),
                  Icon(
                    _showDropdown ? Icons.arrow_drop_up : Icons.arrow_drop_down_rounded,
                    color: AppColors.primary,
                  ),
                ],
              ),
            ),
          ),

          // لیست Dropdown با جستجو
          if (_showDropdown)
            Container(
              constraints: const BoxConstraints(maxHeight: 300),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: Colors.grey.shade200),
                ),
              ),
              child: Column(
                children: [
                  // فیلد جستجو داخل Dropdown
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: TextField(
                      controller: _searchController,
                      textAlign: TextAlign.right,
                      decoration: InputDecoration(
                        hintText: 'جستجو بر اساس نام یا شماره',
                        hintStyle: TextStyle(
                          color: Colors.grey.shade400,
                          fontSize: 13,
                        ),
                        prefixIcon: Icon(
                          Icons.search,
                          color: Colors.grey.shade400,
                          size: 20,
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        isDense: true,
                      ),
                      onChanged: _filterCustomers,
                    ),
                  ),

                  // لیست مشتریان
                  Expanded(
                    child: _filteredCustomers.isEmpty
                        ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text(
                          'نتیجه‌ای یافت نشد',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    )
                        : ListView.builder(
                      shrinkWrap: true,
                      itemCount: _filteredCustomers.length,
                      itemBuilder: (context, index) {
                        final customer = _filteredCustomers[index];
                        final isSelected =
                            _selectedCustomer?.id == customer.id;

                        return InkWell(
                          onTap: () {
                            setState(() {
                              _selectedCustomer = customer;
                              _showDropdown = false;
                              _searchController.clear();
                              // ریست داده‌ها
                              _totalAppointments = 0;
                              _totalIncome = 0;
                              _servicesData = {};
                              _lastAppointment = null;
                              _nextAppointment = null;
                            });
                            _loadCustomerReport();
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.primary.withOpacity(0.1)
                                  : null,
                              border: Border(
                                bottom: BorderSide(
                                  color: Colors.grey.shade100,
                                ),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment:
                              MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  customer.fullName,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: isSelected
                                        ? AppColors.primary
                                        : AppColors.textPrimary,
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                ),
                                Text(
                                  DateHelper.toPersianDigits(
                                      customer.mobileNumber),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Expanded(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person_search, size: 80, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              message,
              style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomerInfoCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _selectedCustomer!.fullName,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                DateHelper.toPersianDigits(_selectedCustomer!.mobileNumber),
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Divider(color: Colors.grey.shade200),
          const SizedBox(height: 12),
          _buildInfoRow(
            _lastAppointment != null
                ? _formatAppointmentDate(_lastAppointment!)
                : 'ندارد',
            'آخرین نوبت:',
          ),
          const SizedBox(height: 8),
          _buildInfoRow(
            _nextAppointment != null
                ? _formatAppointmentDate(_nextAppointment!)
                : 'ندارد',
            'نوبت بعدی:',
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey.shade700,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  String _formatAppointmentDate(AppointmentModel appointment) {
    final jalali = Jalali.fromDateTime(appointment.requestedDate);
    return DateHelper.toPersianDigits(
        '${jalali.year}/${jalali.month}/${jalali.day}');
  }

  Widget _buildAppointmentsCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'تعداد رزرو:',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
          Text(
            '${DateHelper.toPersianDigits(_totalAppointments.toString())} نوبت',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIncomeCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'میزان درآمد:',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
          Text(
            '${DateHelper.toPersianDigits(_formatNumber(_totalIncome))} تومان',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.success,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServicesCard() {
    if (_servicesData.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          child: Text(
            'خدمتی ثبت نشده است.',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // هدر
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.grey.shade200),
              ),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'عنوان خدمت',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textSecondary,
                  ),
                ),
                Text(
                  'تعداد',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          // ردیف‌ها
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _servicesData.length,
            separatorBuilder: (context, index) => Divider(
              height: 1,
              color: Colors.grey.shade100,
            ),
            itemBuilder: (context, index) {
              final entry = _servicesData.entries.elementAt(index);
              return Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        entry.key,
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      DateHelper.toPersianDigits(entry.value.toString()),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  String _formatNumber(int number) {
    if (number == 0) return '۰';

    final str = number.abs().toString();
    final buffer = StringBuffer();

    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) {
        buffer.write(',');
      }
      buffer.write(str[i]);
    }

    return buffer.toString();
  }
}