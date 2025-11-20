import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../core/constants/colors.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../data/models/appointment_model.dart';
import '../../../data/models/customer_model.dart';
import '../../../data/repositories/appointment_repository.dart';
import '../../../data/repositories/customer_repository.dart';
import 'edit_received_appointment_screen.dart';

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
      // بارگذاری همه مشتریان (فعال و غیرفعال) یکبار
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

  // پیدا کردن مشتری بر اساس شماره موبایل
  CustomerModel? _findCustomerByMobile(String mobile) {
    return _customerCache[mobile];
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

    // اگر نوبت ویرایش شد، لیست خودکار آپدیت می‌شه (چون Stream است)
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
      // بررسی تداخل زمانی
      final overlapping = await _appointmentRepository.checkOverlap(
        date: appointment.requestedDate,
        startTime: appointment.requestedTime,
        durationMinutes: appointment.durationMinutes,
        excludeId: appointment.id,
      );

      if (!mounted) return;

      // اگر تداخل داره
      if (overlapping.isNotEmpty) {
        final continueConfirm = await _showOverlapDialog(overlapping);
        if (continueConfirm != true) return;
      }

      // 🔥 اگر مشتری جدید است، ابتدا در لیست مشتریان ثبتش کن
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

      // تایید نوبت (تغییر status به confirmed و آپدیت customerId)
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
          IconButton(
            icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
            onPressed: () => Navigator.pop(context),
          ),
          const Text(
            'نوبت‌های دریافتی',
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

  const _ReceivedAppointmentCard({
    required this.appointment,
    required this.existingCustomer,
    required this.onEdit,
    required this.onConfirm,
    required this.onDelete,
  });

  @override
  State<_ReceivedAppointmentCard> createState() => _ReceivedAppointmentCardState();
}

class _ReceivedAppointmentCardState extends State<_ReceivedAppointmentCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    // تعیین نام و رنگ
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
      nameColor = AppColors.textPrimary;
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
            // ردیف اول: ساعت + نام + badge جدید
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // badge "جدید" (سمت چپ)
                  if (isNewCustomer)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.error,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'جدید',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),

                  const Spacer(),

                  // نام و نام خانوادگی
                  Expanded(
                    child: Text(
                      displayName,
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: nameColor,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),

                  const SizedBox(width: 12),

                  // ساعت درخواستی (یا بازه زمانی اگر ویرایش شده)
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
                      // اگر دارای durationMinutes باشه و بیشتر از 60 نباشه، بازه کامل نمایش بده
                      widget.appointment.updatedAt != null
                          ? widget.appointment.timeRange
                          : widget.appointment.requestedTime,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ردیف دوم: سن کودک + مدل عکاسی (باکس طوسی)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(0),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // مدل عکاسی (سمت چپ)
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

                  // سن کودک (سمت راست)
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

            // ردیف سوم: توضیحات (اگر وجود داشت)
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

            // دکمه‌های عملیاتی (نمایش با انیمیشن Slide)
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              child: _isExpanded
                  ? Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    // ویرایش
                    Expanded(
                      child: InkWell(
                        onTap: widget.onEdit,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          alignment: Alignment.center,
                          child: const Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.edit_outlined,
                                size: 20,
                                color: AppColors.primary,
                              ),
                              SizedBox(height: 4),
                              Text(
                                'ویرایش',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 40,
                      color: Colors.grey.shade300,
                    ),

                    // تایید
                    Expanded(
                      child: InkWell(
                        onTap: widget.onConfirm,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          alignment: Alignment.center,
                          child: const Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.check_circle_outline,
                                size: 20,
                                color: AppColors.success,
                              ),
                              SizedBox(height: 4),
                              Text(
                                'تایید',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.success,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 40,
                      color: Colors.grey.shade300,
                    ),

                    // حذف
                    Expanded(
                      child: InkWell(
                        onTap: widget.onDelete,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          alignment: Alignment.center,
                          child: const Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.delete_outline,
                                size: 20,
                                color: AppColors.error,
                              ),
                              SizedBox(height: 4),
                              Text(
                                'حذف',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.error,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
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