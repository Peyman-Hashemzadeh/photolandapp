import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:shamsi_date/shamsi_date.dart';
import 'package:persian_datetime_picker/persian_datetime_picker.dart';
import '../../../core/constants/colors.dart';
import '../../../core/utils/date_helper.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../data/models/appointment_model.dart';
import '../../../data/repositories/appointment_repository.dart';
import '../appointments/appointment_menu_screen.dart';
import '../appointments/add_appointment_screen.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  final AppointmentRepository _repository = AppointmentRepository();
  late Jalali _selectedDate;
  final ScrollController _daysScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _selectedDate = Jalali.now();

    // اسکرول به روز جاری بعد از بیلد اولیه
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToSelectedDay();
    });
  }

  @override
  void dispose() {
    _daysScrollController.dispose();
    super.dispose();
  }

  void _scrollToSelectedDay() {
    // هر روز حدود 60 پیکسل عرض داره (با فاصله)
    final dayIndex = _selectedDate.day - 1;
    final scrollPosition = dayIndex * 60.0 - (MediaQuery.of(context).size.width / 2) + 30;

    if (_daysScrollController.hasClients) {
      _daysScrollController.animateTo(
        scrollPosition.clamp(0.0, _daysScrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _selectDate() async {
    final picked = await showPersianDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: Jalali(1400, 1, 1),
      lastDate: Jalali(1410, 12, 29),
      locale: const Locale('fa', 'IR'),
      builder: (context, child) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: Theme(
            data: Theme.of(context).copyWith(
              colorScheme: ColorScheme.light(
                primary: AppColors.primary,
                onPrimary: Colors.white,
                surface: Colors.white,
                onSurface: AppColors.textPrimary,
              ),
              textTheme: Theme.of(context).textTheme.apply(
                fontFamily: 'Vazirmatn',
              ),
            ),
            child: child!,
          ),
        );
      },
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
      _scrollToSelectedDay();
    }
  }

  void _goToToday() {
    setState(() {
      _selectedDate = Jalali.now();
    });
    _scrollToSelectedDay();
  }

  void _selectDay(int day) {
    setState(() {
      _selectedDate = Jalali(_selectedDate.year, _selectedDate.month, day);
    });
  }

  List<Jalali> _getDaysInMonth() {
    final daysInMonth = _selectedDate.monthLength;
    return List.generate(
      daysInMonth,
          (index) => Jalali(_selectedDate.year, _selectedDate.month, index + 1),
    );
  }

  Future<void> _handleCancelAppointment(AppointmentModel appointment) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('لغو نوبت'),
          content: const Text('آیا از لغو این نوبت اطمینان دارید؟'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text(
                'بله، لغو کن',
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
        await _repository.updateAppointmentStatus(appointment.id, 'cancelled');
        if (mounted) {
          SnackBarHelper.showSuccess(context, 'نوبت با موفقیت لغو شد');
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

  void _handleEditAppointment(AppointmentModel appointment) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddAppointmentScreen(
          isNewCustomer: false,
          appointment: appointment,
        ),
      ),
    );
  }

  void _handleSettlement(AppointmentModel appointment) {
    // TODO: صفحه تسویه (بعداً پیاده‌سازی می‌شود)
    SnackBarHelper.showInfo(context, 'صفحه تسویه به زودی...');
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
              _buildDateSelector(),
              _buildDaysRow(),
              Expanded(
                child: _buildAppointmentsList(),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AppointmentMenuScreen(),
            ),
          );
        },
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
          IconButton(
            icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
            onPressed: () => Navigator.pop(context),
          ),
          const Text(
            'تقویم',
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

  Widget _buildDateSelector() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // دکمه انتخاب ماه/سال
          GestureDetector(
            onTap: _selectDate,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
              child: Row(
                children: [
                  const Icon(Icons.arrow_drop_down, color: AppColors.primary),
                  const SizedBox(width: 4),
                  Text(
                    DateHelper.formatMonthYear(_selectedDate),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // دکمه امروز
          GestureDetector(
            onTap: _goToToday,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Text(
                'امروز',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDaysRow() {
    final days = _getDaysInMonth();
    final today = Jalali.now();

    return Container(
      height: 80,
      margin: const EdgeInsets.symmetric(vertical: 12),
      child: ListView.builder(
        controller: _daysScrollController,
        scrollDirection: Axis.horizontal,
        reverse: true, // راست به چپ
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: days.length,
        itemBuilder: (context, index) {
          final day = days[index];
          final isSelected = day.day == _selectedDate.day &&
              day.month == _selectedDate.month &&
              day.year == _selectedDate.year;
          final isToday = day.day == today.day &&
              day.month == today.month &&
              day.year == today.year;

          return GestureDetector(
            onTap: () => _selectDay(day.day),
            child: Container(
              width: 50,
              margin: const EdgeInsets.only(left: 8),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: isToday && !isSelected
                    ? Border.all(color: AppColors.primary, width: 2)
                    : null,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // حرف اول روز هفته
                  Text(
                    day.formatter.wN.substring(0, 1),
                    style: TextStyle(
                      fontSize: 12,
                      color: isSelected ? Colors.white : AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // شماره روز
                  Text(
                    DateHelper.toPersianDigits(day.day.toString()),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.white : AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAppointmentsList() {
    return StreamBuilder<List<AppointmentModel>>(
      stream: _repository.getAppointmentsByDate(_selectedDate.toDateTime()),
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
                  Icons.calendar_today,
                  size: 80,
                  color: Colors.grey.shade300,
                ),
                const SizedBox(height: 16),
                Text(
                  'نوبتی برای این روز ثبت نشده است',
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
            return _AppointmentCard(
              appointment: appointment,
              onEdit: () => _handleEditAppointment(appointment),
              onCancel: () => _handleCancelAppointment(appointment),
              onSettle: () => _handleSettlement(appointment),
            );
          },
        );
      },
    );
  }
}

// ویجت کارت نوبت با expand/collapse
class _AppointmentCard extends StatefulWidget {
  final AppointmentModel appointment;
  final VoidCallback onEdit;
  final VoidCallback onCancel;
  final VoidCallback onSettle;

  const _AppointmentCard({
    required this.appointment,
    required this.onEdit,
    required this.onCancel,
    required this.onSettle,
  });

  @override
  State<_AppointmentCard> createState() => _AppointmentCardState();
}

class _AppointmentCardState extends State<_AppointmentCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final isCancelled = widget.appointment.status == 'cancelled';

    return GestureDetector(
      onTap: () {
        setState(() {
          _isExpanded = !_isExpanded;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: isCancelled ? Colors.red.shade50 : Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // ردیف اول: ساعت و نام
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // ساعت
                  Text(
                    widget.appointment.timeRange,
                    style: TextStyle(
                      fontSize: 14,
                      color: isCancelled
                          ? Colors.red.shade400
                          : AppColors.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  // نام مشتری
                  Expanded(
                    child: Text(
                      widget.appointment.customerName,
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isCancelled
                            ? Colors.red.shade600
                            : AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),

              // ردیف دوم: سن کودک و مدل عکاسی
              if (widget.appointment.childAge != null ||
                  widget.appointment.photographyModel != null) ...[
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // مدل عکاسی
                    if (widget.appointment.photographyModel != null)
                      Expanded(
                        child: Text(
                          widget.appointment.photographyModel!,
                          textAlign: TextAlign.left,
                          style: TextStyle(
                            fontSize: 13,
                            color: isCancelled
                                ? Colors.red.shade400
                                : AppColors.textSecondary,
                          ),
                        ),
                      ),
                    // سن کودک
                    if (widget.appointment.childAge != null)
                      Text(
                        'سن کودک: ${widget.appointment.childAge}',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontSize: 13,
                          color: isCancelled
                              ? Colors.red.shade400
                              : AppColors.textSecondary,
                        ),
                      ),
                  ],
                ),
              ],

              // توضیحات
              if (widget.appointment.notes != null &&
                  widget.appointment.notes!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isCancelled
                        ? Colors.red.shade100
                        : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    widget.appointment.notes!,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 12,
                      color: isCancelled
                          ? Colors.red.shade600
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
              ],

              // دکمه‌های عملیاتی (فقط برای نوبت‌های غیر لغو‌شده)
              if (!isCancelled)
                AnimatedCrossFade(
                  firstChild: const SizedBox(height: 0),
                  secondChild: Column(
                    children: [
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          // دکمه لغو
                          TextButton.icon(
                            onPressed: widget.onCancel,
                            icon: const Icon(Icons.block, size: 16),
                            label: const Text('لغو'),
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.error,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // دکمه تسویه
                          TextButton.icon(
                            onPressed: widget.onSettle,
                            icon: const Icon(Icons.attach_money, size: 16),
                            label: const Text('تسویه'),
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.success,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // دکمه ویرایش
                          TextButton.icon(
                            onPressed: widget.onEdit,
                            icon: const Icon(Icons.edit, size: 16),
                            label: const Text('ویرایش'),
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.primary,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  crossFadeState: _isExpanded
                      ? CrossFadeState.showSecond
                      : CrossFadeState.showFirst,
                  duration: const Duration(milliseconds: 250),
                ),
            ],
          ),
        ),
      ),
    );
  }
}