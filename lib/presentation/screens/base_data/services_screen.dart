import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../core/constants/colors.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../data/models/service_model.dart';
import '../../../data/repositories/service_repository.dart';
import '../../widgets/service_card.dart';
import '../../widgets/add_service_dialog.dart';

class ServicesScreen extends StatefulWidget {
  const ServicesScreen({super.key});

  @override
  State<ServicesScreen> createState() => _ServicesScreenState();
}

class _ServicesScreenState extends State<ServicesScreen> {
  final ServiceRepository _repository = ServiceRepository();

  Future<void> _showAddServiceDialog({ServiceModel? service}) async {
    final result = await showDialog<ServiceModel>(
      context: context,
      builder: (context) => AddServiceDialog(service: service),
    );

    if (result != null) {
      try {
        if (service == null) {
          // افزودن خدمت جدید
          await _repository.addService(result);
          if (mounted) {
            SnackBarHelper.showSuccess(context, 'خدمت با موفقیت ثبت شد');
          }
        } else {
          // ویرایش خدمت
          await _repository.updateService(result);
          if (mounted) {
            SnackBarHelper.showSuccess(context, 'خدمت با موفقیت ویرایش شد');
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

  Future<void> _toggleServiceStatus(ServiceModel service) async {
    final newStatus = !service.isActive;
    final action = newStatus ? 'فعال‌سازی مجدد' : 'تعلیق';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Text('$action خدمت'),
          content: Text(
            'آیا برای $action این خدمت اطمینان دارید؟',
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
        await _repository.toggleServiceStatus(service.id, newStatus);
        if (mounted) {
          SnackBarHelper.showSuccess(
            context,
            newStatus ? 'خدمت فعال شد' : 'خدمت تعلیق شد',
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
              Expanded(
                child: _buildServicesList(),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddServiceDialog(),
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
            'لیست خدمات',
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

  Widget _buildServicesList() {
    return StreamBuilder<List<ServiceModel>>(
      stream: _repository.getAllServices(),
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

        final services = snapshot.data ?? [];

        if (services.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.camera_alt_outlined,
                  size: 80,
                  color: Colors.grey.shade300,
                ),
                const SizedBox(height: 16),
                Text(
                  'هنوز خدمتی ثبت نشده است',
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
          itemCount: services.length,
          itemBuilder: (context, index) {
            final service = services[index];
            return ServiceCard(
              service: service,
              onEdit: () => _showAddServiceDialog(service: service),
              onToggleStatus: () => _toggleServiceStatus(service),
            );
          },
        );
      },
    );
  }
}