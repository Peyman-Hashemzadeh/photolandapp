import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shamsi_date/shamsi_date.dart';
import '../../../core/constants/colors.dart';
import '../../../core/utils/date_helper.dart';
import '../../../data/models/customer_model.dart';
import '../../../data/models/appointment_model.dart';
import '../../../data/models/invoice_model.dart';
import '../../../data/repositories/invoice_repository.dart';
import '../invoices/invoice_screen.dart';

class CustomerDetailReportScreen extends StatefulWidget {
  const CustomerDetailReportScreen({super.key});

  @override
  State<CustomerDetailReportScreen> createState() =>
      _CustomerDetailReportScreenState();
}

class _CustomerDetailReportScreenState
    extends State<CustomerDetailReportScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final InvoiceRepository _invoiceRepository = InvoiceRepository();
  final TextEditingController _searchController = TextEditingController();

  List<CustomerModel> _allCustomers = [];
  List<CustomerModel> _filteredCustomers = [];
  CustomerModel? _selectedCustomer;
  bool _isLoading = false;
  bool _showDropdown = false;

  // داده‌های گزارش
  List<AppointmentWithInvoice> _appointments = [];
  int _futureCount = 0;
  int _pastCount = 0;
  int _cancelledCount = 0;

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

  Future<void> _loadCustomerAppointments() async {
    if (_selectedCustomer == null) return;

    setState(() => _isLoading = true);

    try {
      final customerId = _selectedCustomer!.id;
      final today = DateTime.now();
      final startOfToday = DateTime(today.year, today.month, today.day);

      // دریافت همه نوبت‌های مشتری
      final appointmentsSnapshot = await _firestore
          .collection('appointments')
          .where('customerId', isEqualTo: customerId)
          .get();

      final appointments = appointmentsSnapshot.docs
          .map((doc) => AppointmentModel.fromMap(doc.data(), doc.id))
          .toList();

      // دریافت فاکتور برای هر نوبت
      final appointmentsWithInvoice = <AppointmentWithInvoice>[];

      for (var appointment in appointments) {
        InvoiceModel? invoice;
        int invoiceAmount = 0;

        try {
          invoice = await _invoiceRepository.getInvoiceByAppointment(appointment.id);
          if (invoice != null) {
            invoiceAmount = await _invoiceRepository.calculateGrandTotal(invoice.id);
          }
        } catch (e) {
          // در صورت خطا، فاکتور null می‌ماند
        }

        appointmentsWithInvoice.add(AppointmentWithInvoice(
          appointment: appointment,
          invoice: invoice,
          invoiceAmount: invoiceAmount,
        ));
      }

      // مرتب‌سازی: نزدیک‌ترین نوبت بالا
      appointmentsWithInvoice.sort((a, b) {
        final dateA = a.appointment.requestedDate;
        final dateB = b.appointment.requestedDate;

        // نوبت‌های آینده بالاتر
        final isAfutureA = dateA.isAfter(startOfToday);
        final isFutureB = dateB.isAfter(startOfToday);

        if (isAfutureA && !isFutureB) return -1;
        if (!isAfutureA && isFutureB) return 1;

        // اگر هر دو آینده یا هر دو گذشته، بر اساس تاریخ
        return dateB.compareTo(dateA);
      });

      // محاسبه آمار
      int futureCount = 0;
      int pastCount = 0;
      int cancelledCount = 0;

      for (var item in appointmentsWithInvoice) {
        final apt = item.appointment;

        if (apt.status == 'cancelled') {
          cancelledCount++;
        } else if (apt.requestedDate.isAfter(startOfToday)) {
          futureCount++;
        } else {
          pastCount++;
        }
      }

      setState(() {
        _appointments = appointmentsWithInvoice;
        _futureCount = futureCount;
        _pastCount = pastCount;
        _cancelledCount = cancelledCount;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطا در بارگذاری نوبت‌ها: $e')),
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
              else if (_appointments.isEmpty)
                  _buildEmptyState('نوبتی برای این مشتری ثبت نشده است.')
                else
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          _buildStatisticsCard(),
                          const SizedBox(height: 16),
                          ..._appointments.map((item) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _buildAppointmentCard(item),
                          )),
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
            'گزارش ریز مشتری',
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
                  Expanded(
                    child: _filteredCustomers.isEmpty
                        ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text(
                          'نتیجه‌ای یافت نشد!',
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
                              _appointments = [];
                              _futureCount = 0;
                              _pastCount = 0;
                              _cancelledCount = 0;
                            });
                            _loadCustomerAppointments();
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
                                  DateHelper.toPersianDigits(
                                      customer.mobileNumber),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
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
            Icon(Icons.calendar_month, size: 80, color: Colors.grey.shade300),
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

  Widget _buildStatisticsCard() {
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
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(
            'رزرو آینده',
            _futureCount,
            AppColors.info,
          ),
          Container(
            height: 40,
            width: 1,
            color: Colors.grey.shade200,
          ),
          _buildStatItem(
            'گذشته',
            _pastCount,
            AppColors.success,
          ),
          Container(
            height: 40,
            width: 1,
            color: Colors.grey.shade200,
          ),
          _buildStatItem(
            'کنسلی',
            _cancelledCount,
            AppColors.error,
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, int count, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          DateHelper.toPersianDigits(count.toString()),
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildAppointmentCard(AppointmentWithInvoice item) {
    final appointment = item.appointment;
    final invoice = item.invoice;
    final jalaliDate = Jalali.fromDateTime(appointment.requestedDate);
    final dateStr = DateHelper.toPersianDigits(
        '${jalaliDate.year}/${jalaliDate.month}/${jalaliDate.day}');

    final today = DateTime.now();
    final startOfToday = DateTime(today.year, today.month, today.day);
    final isFuture = appointment.requestedDate.isAfter(startOfToday);
    final isCancelled = appointment.status == 'cancelled';

    Color cardColor = Colors.white;
    if (isCancelled) {
      cardColor = AppColors.error.withOpacity(0.08);
    } else if (isFuture) {
      cardColor = AppColors.info.withOpacity(0.08);
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCancelled
              ? AppColors.error.withOpacity(0.5)
              : isFuture
              ? AppColors.info.withOpacity(0.5)
              : Colors.grey.shade300,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // سطر اول: تاریخ و مبلغ
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.calendar_today,
                    size: 16,
                    color: Colors.grey.shade600,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    dateStr,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              Row(
                children: [

                  Text(
                    DateHelper.toPersianDigits(
                        _formatNumber(item.invoiceAmount)),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'تومان',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(width: 4),
                  // آیکون بیعانه / تسویه
                  _buildDepositIcon(appointment),

                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(color: Colors.grey.shade200, height: 1),
          const SizedBox(height: 12),
          // سطر دوم: وضعیت، آیکون‌ها
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // وضعیت فاکتور
              _buildInvoiceStatus(invoice),
              Row(
                children: [
                  // آیکون نمایش
                  _buildActionButton(
                    'نمایش',
                    Icons.visibility,
                    AppColors.info,
                        () => _handleView(appointment),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
  Widget _buildActionButton(
      String label,
      IconData icon,
      Color color,
      VoidCallback onPressed,
      ) {
    return TextButton.icon(
      onPressed: onPressed,
      icon: Icon(
        icon,
        size: 18,
        color: color,
      ),
      label: Text(
        label,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        backgroundColor: color.withOpacity(0.08),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  Widget _buildDepositIcon(AppointmentModel appointment) {
    if (appointment.hasDeposit) {
      return Container(
        padding: const EdgeInsets.all(8),
        //decoration: BoxDecoration(
        //  color: AppColors.success.withOpacity(0.1),
        //  borderRadius: BorderRadius.circular(8),
        //),
        child: const Icon(
          Icons.check_circle,
          size: 18,
          color: AppColors.success,
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.all(8),
        //decoration: BoxDecoration(
        //  color: AppColors.warning.withOpacity(0.1),
        //  borderRadius: BorderRadius.circular(8),
        //),
        child: const Icon(
          Icons.warning,
          size: 18,
          color: AppColors.warning,
        ),
      );
    }
  }

  Widget _buildInvoiceStatus(InvoiceModel? invoice) {
    if (invoice == null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          'بدون فاکتور',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade700,
          ),
        ),
      );
    }

    String statusText = '';
    Color statusColor = Colors.grey;

    switch (invoice.status) {
      case 'editing':
        statusText = 'درحال ویرایش';
        statusColor = AppColors.warning;
        break;
      case 'confirmed':
        statusText = 'تایید شده';
        statusColor = AppColors.info;
        break;
      case 'printing':
        statusText = 'درحال چاپ';
        statusColor = AppColors.primary;
        break;
      case 'printed':
        statusText = 'چاپ شده';
        statusColor = AppColors.success;
        break;
      case 'delivered':
        statusText = 'تحویل داده شده';
        statusColor = Colors.green;
        break;
      default:
        statusText = 'نامشخص';
        statusColor = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        statusText,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: statusColor,
        ),
      ),
    );
  }

  void _handleView(AppointmentModel appointment) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => InvoiceScreen(appointment: appointment),
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

class AppointmentWithInvoice {
  final AppointmentModel appointment;
  final InvoiceModel? invoice;
  final int invoiceAmount;

  AppointmentWithInvoice({
    required this.appointment,
    this.invoice,
    this.invoiceAmount = 0,
  });
}