import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:persian_datetime_picker/persian_datetime_picker.dart';
import 'package:shamsi_date/shamsi_date.dart';
import '../../../core/constants/colors.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../core/utils/price_input_formatter.dart';
import '../../../core/utils/date_helper.dart';
import '../../../data/models/appointment_model.dart';
import '../../../data/models/customer_model.dart';
import '../../../data/models/service_model.dart';
import '../../../data/models/bank_model.dart';
import '../../../data/repositories/appointment_repository.dart';
import '../../../data/repositories/customer_repository.dart';
import '../../../data/repositories/bank_repository.dart';
import 'edit_received_appointment_screen.dart';
import 'package:flutter/services.dart';

// ==================== دیالوگ ویرایش بیعانه ====================
class _EditDepositDialog extends StatefulWidget {
  final AppointmentModel appointment;

  const _EditDepositDialog({required this.appointment});

  @override
  State<_EditDepositDialog> createState() => _EditDepositDialogState();
}

class _EditDepositDialogState extends State<_EditDepositDialog> {
  final BankRepository _bankRepository = BankRepository();
  final _amountController = TextEditingController();

  Jalali? _selectedDate;
  BankModel? _selectedBank;
  List<BankModel> _banks = [];
  bool _isCash = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    // پر کردن فیلدها با مقادیر فعلی
    if (widget.appointment.depositAmount != null && widget.appointment.depositAmount! > 0) {
      _amountController.text = ServiceModel.formatNumber(widget.appointment.depositAmount!);
      _selectedDate = Jalali.fromDateTime(widget.appointment.depositReceivedDate ?? DateTime.now());
      _isCash = widget.appointment.bankId == null; // اگر bankId null، نقدی
      if (_isCash) {
        _selectedBank = null;
      }
      if (!_isCash && widget.appointment.bankId != null) {
        // پیدا کردن بانک بر اساس ID (در loadBanks چک می‌شه)
      }
    }
    _loadBanks();
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  void _loadBanks() {
    _bankRepository.getActiveBanks().listen((banks) {
      if (mounted) {
        setState(() {
          _banks = banks;
          // انتخاب بانک فعلی اگر وجود داره
          if (!_isCash && widget.appointment.bankId != null) {
            _selectedBank = banks.firstWhere(
                  (bank) => bank.id == widget.appointment.bankId,
              orElse: () => banks.first, // اگر پیدا نشد، اولین بانک
            );
          }
          _isLoading = false;
        });
      }
    });
  }

  Future<void> _selectDate() async {
    final picked = await showPersianDatePicker(
      context: context,
      initialDate: _selectedDate ?? Jalali.now(),
      firstDate: Jalali.now().addDays(-365),
      lastDate: Jalali.now(),
      locale: const Locale('fa', 'IR'),
    );

    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  void _handleSave() {
    if (_amountController.text.isEmpty) {
      SnackBarHelper.showError(context, 'لطفا مبلغ بیعانه را وارد کنید!');
      return;
    }

    if (_selectedDate == null) {
      SnackBarHelper.showError(context, 'لطفا تاریخ دریافت را انتخاب کنید!');
      return;
    }

    if (!_isCash && _selectedBank == null) {
      SnackBarHelper.showError(context, 'لطفا بانک را انتخاب کنید!');
      return;
    }

    final amount = ServiceModel.parsePrice(_amountController.text);
    if (amount == null || amount <= 0) {
      SnackBarHelper.showError(context, 'مبلغ نامعتبر است.');
      return;
    }

    Navigator.pop(context, {
      'amount': amount,
      'date': _selectedDate!.toDateTime(),
      'isCash': _isCash,
      'bankId': _isCash ? null : _selectedBank?.id,        // ✅ اگه نقدی بود، null
      'bankName': _isCash ? null : _selectedBank?.bankName, // ✅ اگه نقدی بود، null
    });
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        backgroundColor: Colors.grey[300],
        title: const Center(child: Text('ویرایش بیعانه')),
        content: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // مبلغ بیعانه (مشابه ثبت)
              TextFormField(
                controller: _amountController,
                textAlign: TextAlign.right,
                keyboardType: TextInputType.number,
                inputFormatters: [PersianPriceInputFormatter()],
                decoration: InputDecoration(
                  hintText: 'مبلغ بیعانه',
                  suffixText: 'تومان',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // تاریخ دریافت (مشابه)
              InkWell(
                onTap: _selectDate,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _selectedDate != null
                            ? DateHelper.toPersianDigits(_selectedDate!.formatCompactDate())
                            : 'تاریخ دریافت',
                        style: TextStyle(
                          color: _selectedDate != null
                              ? AppColors.textPrimary
                              : AppColors.textLight,
                        ),
                      ),
                      const Icon(Icons.calendar_today, size: 20),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // انتخاب بانک (مشابه)
              DropdownButtonFormField<BankModel>(
                value: _selectedBank,
                decoration: InputDecoration(
                  hintText: 'انتخاب بانک',
                  filled: true,
                  fillColor: _isCash ? Colors.grey.shade200 : Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                items: _banks.map((bank) {
                  return DropdownMenuItem(
                    value: bank,
                    child: Text(bank.bankName),
                  );
                }).toList(),
                onChanged: _isCash
                    ? null
                    : (bank) {
                  setState(() => _selectedBank = bank);
                },
                disabledHint: _selectedBank != null
                    ? Text(_selectedBank!.bankName)
                    : const Text('انتخاب بانک'),
              ),

              const SizedBox(height: 8),

              // گزینه نقدی (مشابه)
              Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  Checkbox(
                    value: _isCash,
                    onChanged: (value) {
                      setState(() {
                        _isCash = value ?? false;
                        if (_isCash) _selectedBank = null;
                      });
                    },
                  ),
                  const Text('بیعانه را به صورت نقدی دریافت کردم.'),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: _handleSave,
            child: const Text(
              'ویرایش بیعانه',
              style: TextStyle(color: AppColors.success),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('انصراف'),
          ),
        ],
      ),
    );
  }
}


class ReceivedAppointmentsScreen extends StatefulWidget {
  const ReceivedAppointmentsScreen({super.key});

  @override
  State<ReceivedAppointmentsScreen> createState() => _ReceivedAppointmentsScreenState();
}

class _ReceivedAppointmentsScreenState extends State<ReceivedAppointmentsScreen> {
  final AppointmentRepository _appointmentRepository = AppointmentRepository();
  final CustomerRepository _customerRepository = CustomerRepository();

  Map<String, CustomerModel?> _customerCache = {};
  bool _isLoadingCustomers = true;

  @override
  void initState() {
    super.initState();
    _loadCustomers();
  }

  Future<void> _loadCustomers() async {
    try {
      _customerRepository.getAllCustomers().listen((customers) {
        if (mounted) {
          setState(() {
            _customerCache.clear();
            for (var customer in customers) {
              _customerCache[customer.mobileNumber] = customer;
            }
            _isLoadingCustomers = false;
          });
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingCustomers = false);
      }
    }
  }

  CustomerModel? _findCustomerByMobile(String mobile) {
    return _customerCache[mobile];
  }

  int _timeToMinutes(String time) {
    try {
      final parts = time.split(':');
      if (parts.length == 2) {
        final hour = int.parse(parts[0]);
        final minute = int.parse(parts[1]);
        return (hour * 60) + minute;
      }
    } catch (e) {
      // در صورت خطا، 0 برمی‌گردونه
    }
    return 0;
  }

  Future<void> _handleEdit(AppointmentModel appointment) async {
    final customer = _findCustomerByMobile(appointment.customerMobile);

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditReceivedAppointmentScreen(
          appointment: appointment,
          existingCustomer: customer,
        ),
      ),
    );
  }

  Future<void> _handleConfirm(AppointmentModel appointment) async {
    final customer = _findCustomerByMobile(appointment.customerMobile);
    final displayName = customer?.fullName ?? appointment.customerName;
    final isNewCustomer = customer == null;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('تایید نوبت'),
          content: Text('آیا از تایید نوبت "$displayName" اطمینان دارید؟'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text(
                'بله، تایید کن',
                style: TextStyle(color: AppColors.success),
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

    if (confirm != true) return;

    try {
      final overlapping = await _appointmentRepository.checkOverlap(
        date: appointment.requestedDate,
        startTime: appointment.requestedTime,
        durationMinutes: appointment.durationMinutes,
        excludeId: appointment.id,
      );

      if (!mounted) return;

      if (overlapping.isNotEmpty) {
        final continueConfirm = await _showOverlapDialog(overlapping);
        if (continueConfirm != true) return;
      }

      String customerId = appointment.customerId;
      if (isNewCustomer) {
        final newCustomer = CustomerModel(
          id: '',
          fullName: appointment.customerName,
          mobileNumber: appointment.customerMobile,
          notes: 'مشتری از طریق فرم آنلاین ثبت شده',
          createdAt: DateTime.now(),
        );

        customerId = await _customerRepository.addCustomer(newCustomer);
      }

      final confirmedAppointment = appointment.copyWith(
        customerId: customerId,
        status: 'confirmed',
        updatedAt: DateTime.now(),
      );

      await _appointmentRepository.updateAppointment(confirmedAppointment);

      if (mounted) {
        SnackBarHelper.showSuccess(
          context,
          isNewCustomer
              ? 'نوبت تایید و مشتری در سامانه ثبت شد'
              : 'نوبت با موفقیت تایید شد',
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

  Future<void> _handleDelete(AppointmentModel appointment) async {
    final customer = _findCustomerByMobile(appointment.customerMobile);
    final displayName = customer?.fullName ?? appointment.customerName;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('حذف نوبت'),
          content: Text('آیا از حذف نوبت "$displayName" اطمینان دارید؟'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text(
                'بله، حذف کن',
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
      try {
        await _appointmentRepository.deleteAppointment(appointment.id);
        if (mounted) {
          SnackBarHelper.showSuccess(context, 'نوبت با موفقیت حذف شد');
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

  Future<void> _handleDeposit(AppointmentModel appointment) async {
    Map<String, dynamic>? result;

    if (appointment.hasDeposit) {
      // ویرایش بیعانه موجود
      result = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (context) => _EditDepositDialog(appointment: appointment),
      );
    } else {
      // ثبت بیعانه جدید
      result = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (context) => _DepositDialog(appointment: appointment),
      );
    }

    if (result != null && mounted) {
      try {
        final updatedAppointment = appointment.copyWith(
          depositAmount: result['amount'],
          depositReceivedDate: result['date'],
          bankId: result['isCash'] ? null : result['bankId'],
          bankName: result['isCash'] ? null : result['bankName'],
          clearBankId: result['isCash'],   // ✅ اگه نقدی بود، پاک کن
          clearBankName: result['isCash'], // ✅ اگه نقدی بود، پاک کن
          updatedAt: DateTime.now(),
        );

        await _appointmentRepository.updateAppointment(updatedAppointment);
        appointment = updatedAppointment;
        if (mounted) {
          SnackBarHelper.showSuccess(
            context,
            appointment.hasDeposit ? 'بیعانه با موفقیت ویرایش شد' : 'بیعانه با موفقیت ثبت شد',
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

  Future<bool?> _showOverlapDialog(List<AppointmentModel> overlapping) {
    return showDialog<bool>(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('تداخل رزرو'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('در این بازه زمانی رزرو دیگری وجود دارد:'),
              const SizedBox(height: 12),
              ...overlapping.map((apt) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  '• ${apt.customerName} - ${apt.timeRange}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              )),
              const SizedBox(height: 12),
              const Text('آیا اطمینان به تایید نوبت دارید؟'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text(
                'بله، تایید کن',
                style: TextStyle(color: AppColors.primary),
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
              if (_isLoadingCustomers)
                const Expanded(
                  child: Center(child: CircularProgressIndicator()),
                )
              else
                Expanded(
                  child: _buildAppointmentsList(),
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
              //  child: FaIcon(
              //    FontAwesomeIcons.user,
              //    color: Colors.grey,
              //    size: 20,
              //  ),
              //),
            ),
          ),
          const Text(
            'نوبت‌های دریافتی',
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

  Widget _buildAppointmentsList() {
    return StreamBuilder<List<AppointmentModel>>(
      stream: _appointmentRepository.getReceivedAppointments(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              'خطا در بارگذاری نوبت‌ها',
              style: TextStyle(color: AppColors.error),
            ),
          );
        }

        final appointments = snapshot.data ?? [];

        if (appointments.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.inbox_outlined,
                  size: 80,
                  color: Colors.grey.shade300,
                ),
                const SizedBox(height: 16),
                Text(
                  'نوبت دریافتی جدیدی وجود ندارد',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          );
        }
        appointments.sort((a, b) {
          final dateCompare = a.requestedDate.compareTo(b.requestedDate);

          if (dateCompare == 0) {
            final aTime = _timeToMinutes(a.requestedTime);
            final bTime = _timeToMinutes(b.requestedTime);
            return aTime.compareTo(bTime);
          }

          return dateCompare;
        });
        return ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: appointments.length,
          itemBuilder: (context, index) {
            final appointment = appointments[index];
            final customer = _findCustomerByMobile(appointment.customerMobile);
            return _ReceivedAppointmentCard(
              appointment: appointment,
              existingCustomer: customer,
              onEdit: () => _handleEdit(appointment),
              onConfirm: () => _handleConfirm(appointment),
              onDelete: () => _handleDelete(appointment),
              onDeposit: () => _handleDeposit(appointment),
            );
          },
        );
      },
    );
  }
}

// ==================== کارت نوبت ====================
class _ReceivedAppointmentCard extends StatefulWidget {
  final AppointmentModel appointment;
  final CustomerModel? existingCustomer;
  final VoidCallback onEdit;
  final VoidCallback onConfirm;
  final VoidCallback onDelete;
  final VoidCallback onDeposit;

  const _ReceivedAppointmentCard({
    required this.appointment,
    required this.existingCustomer,
    required this.onEdit,
    required this.onConfirm,
    required this.onDelete,
    required this.onDeposit,
  });

  @override
  State<_ReceivedAppointmentCard> createState() => _ReceivedAppointmentCardState();
}

class _ReceivedAppointmentCardState extends State<_ReceivedAppointmentCard> {
  bool _isExpanded = false;

  // تابع تبدیل تاریخ به شمسی
  String _getFormattedDate() {
    final jalaliDate = Jalali.fromDateTime(widget.appointment.requestedDate);

    // نام روزهای هفته
    const persianDays = ['یکشنبه', 'دوشنبه', 'سه‌شنبه', 'چهارشنبه', 'پنجشنبه', 'جمعه', 'شنبه'];

    // نام ماه‌های شمسی
    const persianMonths = [
      'فروردین', 'اردیبهشت', 'خرداد', 'تیر', 'مرداد', 'شهریور',
      'مهر', 'آبان', 'آذر', 'دی', 'بهمن', 'اسفند'
    ];

    final dayOfWeek = widget.appointment.requestedDate.weekday % 7;
    final persianDayName = persianDays[dayOfWeek];
    final persianMonthName = persianMonths[jalaliDate.month - 1];

    return '$persianDayName ${jalaliDate.day} $persianMonthName ${jalaliDate.year}';
  }

  @override
  Widget build(BuildContext context) {
    final String displayName;
    final Color nameColor;
    final bool isNewCustomer = widget.existingCustomer == null;

    if (widget.existingCustomer != null) {
      displayName = widget.existingCustomer!.fullName;
      nameColor = widget.existingCustomer!.isActive
          ? AppColors.textPrimary
          : AppColors.error;
    } else {
      displayName = widget.appointment.customerName;
      nameColor = AppColors.success; // رنگ سبز برای مشتری جدید
    }

    return GestureDetector(
      onTap: () {
        setState(() {
          _isExpanded = !_isExpanded;
        });
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            // ========== ردیف اول: تاریخ و ساعت ==========
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // تاریخ
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _getFormattedDate(),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ),

                  // ساعت
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),

                    // 🔥 جلوگیری از برعکس شدن نمایش ساعت در RTL
                    child: Directionality(
                      textDirection: TextDirection.ltr,
                      child: Text(
                        DateHelper.toPersianDigits(
                          widget.appointment.updatedAt != null
                              ? widget.appointment.timeRange   // مثال: "10:00 - 11:00"
                              : widget.appointment.requestedTime,
                        ),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ),

                ],
              ),
            ),

            // خط جداکننده
            Divider(height: 1, thickness: 1, color: Colors.grey.shade200),

            // ========== ردیف دوم: نام مشتری و آیکون بیعانه ==========
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // نام مشتری (وسط - گسترده)
                  Expanded(
                    child: Text(
                      displayName,
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: nameColor,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),

                  if (widget.appointment.hasDeposit)
                    const SizedBox(width: 12),

                  // آیکون بیعانه (سمت راست)
                  if (widget.appointment.hasDeposit)
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFA726).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(
                        Icons.attach_money,
                        size: 18,
                        color: Color(0xFFFFA726),
                      ),
                    ),

                ],
              ),
            ),

            // ========== ردیف سوم: سن کودک و مدل عکاسی ==========
            if (widget.appointment.childAge != null ||
                widget.appointment.photographyModel != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // مدل عکاسی
                    if (widget.appointment.photographyModel != null)
                      Expanded(
                        child: Row(
                          children: [
                            const Icon(
                              Icons.camera_alt_outlined,
                              size: 16,
                              color: AppColors.textSecondary,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                widget.appointment.photographyModel!,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textSecondary,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      const SizedBox.shrink(),

                    const SizedBox(width: 12),

                    // سن کودک
                    if (widget.appointment.childAge != null)
                      Row(
                        children: [
                          const Icon(
                            Icons.child_care_outlined,
                            size: 16,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            widget.appointment.childAge!,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),

            // ========== ردیف چهارم: توضیحات ==========
            if (widget.appointment.notes != null)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    widget.appointment.notes!,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade700,
                      height: 1.5,
                    ),
                  ),
                ),
              ),

            // ========== دکمه‌های عملیاتی ==========
            AnimatedSize(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              child: _isExpanded
                  ? Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                ),
                child: IntrinsicHeight(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Flexible(
                        child: InkWell(
                          onTap: widget.onDeposit,
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: const Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.attach_money, size: 22, color: Color(0xFFFFA726)),
                                SizedBox(height: 4),
                                Text('بیعانه', style: TextStyle(fontSize: 11, color: Color(0xFFFFA726))),
                              ],
                            ),
                          ),
                        ),
                      ),

                      VerticalDivider(width: 1, thickness: 1, color: Colors.grey.shade300),

                      Flexible(
                        child: InkWell(
                          onTap: widget.onEdit,
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: const Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.edit_outlined, size: 22, color: AppColors.primary),
                                SizedBox(height: 4),
                                Text('ویرایش', style: TextStyle(fontSize: 11, color: AppColors.primary)),
                              ],
                            ),
                          ),
                        ),
                      ),

                      VerticalDivider(width: 1, thickness: 1, color: Colors.grey.shade300),

                      Flexible(
                        child: InkWell(
                          onTap: widget.onConfirm,
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: const Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.check_circle_outline, size: 22, color: AppColors.success),
                                SizedBox(height: 4),
                                Text('تایید', style: TextStyle(fontSize: 11, color: AppColors.success)),
                              ],
                            ),
                          ),
                        ),
                      ),

                      VerticalDivider(width: 1, thickness: 1, color: Colors.grey.shade300),

                      Flexible(
                        child: InkWell(
                          onTap: widget.onDelete,
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: const Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.delete_outline, size: 22, color: AppColors.error),
                                SizedBox(height: 4),
                                Text('حذف', style: TextStyle(fontSize: 11, color: AppColors.error)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

// ==================== دیالوگ ثبت بیعانه ====================
class _DepositDialog extends StatefulWidget {
  final AppointmentModel appointment;

  const _DepositDialog({required this.appointment});

  @override
  State<_DepositDialog> createState() => _DepositDialogState();
}

class _DepositDialogState extends State<_DepositDialog> {
  final BankRepository _bankRepository = BankRepository();
  final _amountController = TextEditingController();

  Jalali? _selectedDate;
  BankModel? _selectedBank;
  List<BankModel> _banks = [];
  bool _isCash = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBanks();
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  void _loadBanks() {
    _bankRepository.getActiveBanks().listen((banks) {
      if (mounted) {
        setState(() {
          _banks = banks;
          _isLoading = false;
        });
      }
    });
  }

  Future<void> _selectDate() async {
    final picked = await showPersianDatePicker(
      context: context,
      initialDate: _selectedDate ?? Jalali.now(),
      firstDate: Jalali.now().addDays(-365),
      lastDate: Jalali.now(),
      locale: const Locale('fa', 'IR'),
    );

    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  void _handleSave() {
    if (_amountController.text.isEmpty) {
      SnackBarHelper.showError(context, 'لطفا مبلغ بیعانه را وارد کنید!');
      return;
    }

    if (_selectedDate == null) {
      SnackBarHelper.showError(context, 'لطفا تاریخ دریافت را انتخاب کنید!');
      return;
    }

    if (!_isCash && _selectedBank == null) {
      SnackBarHelper.showError(context, 'لطفا بانک را انتخاب کنید!');
      return;
    }

    // دیباگ: لاگ ورودی خام
    print('=== DEBUG DEPOSIT ===');
    print('Raw input text: "${_amountController.text}" (length: ${_amountController.text.length})');

    final amount = ServiceModel.parsePrice(_amountController.text);
    print('Parsed amount: $amount (type: ${amount.runtimeType})');

    if (amount == null || amount <= 0) {
      print('ERROR: Amount is null or <=0 – skipping save');
      SnackBarHelper.showError(context, 'مبلغ نامعتبر است. (مقدار پارس‌شده: $amount)'); // خطای دیباگ‌دار
      return;
    }

    print('SUCCESS: Amount valid, proceeding...');

    Navigator.pop(context, {
      'amount': amount,
      'date': _selectedDate!.toDateTime(),
      'isCash': _isCash,
      'bankId': _selectedBank?.id,
      'bankName': _selectedBank?.bankName,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        backgroundColor: Colors.grey[300], // ← بک‌گراند آبی روشن
        title: Center(
          child: const Text('ثبت بیعانه'),
        ),
        content: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // مبلغ بیعانه با اعداد فارسی و جداکننده هزارگان
              TextFormField(
                controller: _amountController,
                textAlign: TextAlign.right,
                keyboardType: TextInputType.number,
                inputFormatters: [PersianPriceInputFormatter()],
                decoration: InputDecoration(
                  hintText: 'مبلغ بیعانه',
                  suffixText: 'تومان',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // تاریخ دریافت
              InkWell(
                onTap: _selectDate,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _selectedDate != null
                            ? DateHelper.toPersianDigits(
                            _selectedDate!.formatCompactDate())
                            : 'تاریخ دریافت',
                        style: TextStyle(
                          color: _selectedDate != null
                              ? AppColors.textPrimary
                              : AppColors.textLight,
                        ),
                      ),
                      const Icon(Icons.calendar_today, size: 20),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // انتخاب بانک (غیرفعال وقتی نقدی انتخاب شد)
            DropdownButtonFormField<BankModel>(
              value: _selectedBank,
              decoration: InputDecoration(
                hintText: 'انتخاب بانک',
                filled: true,
                fillColor: _isCash ? Colors.grey.shade200 : Colors.white, // ← رنگ زمینه بسته به فعال/غیرفعال
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              items: _banks.map((bank) {
                return DropdownMenuItem(
                  value: bank,
                  child: Text(bank.bankName),
                );
              }).toList(),
              onChanged: _isCash
                  ? null // ← غیرفعال می‌شود
                  : (bank) {
                setState(() => _selectedBank = bank);
              },
              // اضافه کردن این گزینه باعث می‌شود ظاهر غیرفعال هم به خوبی نمایش داده شود
              disabledHint: _selectedBank != null
                  ? Text(_selectedBank!.bankName)
                  : Text('انتخاب بانک'),
            ),

            const SizedBox(height: 8),

              // گزینه دریافت نقدی
              Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  Checkbox(
                    value: _isCash,
                    onChanged: (value) {
                      setState(() {
                        _isCash = value ?? false;
                        if (_isCash) _selectedBank = null;
                      });
                    },
                  ),
                  const Text('بیعانه را به صورت نقدی دریافت کردم.'),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: _handleSave,
            child: const Text(
              'ثبت',
              style: TextStyle(color: AppColors.success),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('انصراف'),
          ),
        ],
      ),
    );
  }
}