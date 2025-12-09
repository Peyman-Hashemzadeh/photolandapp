import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../core/constants/colors.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../data/models/bank_model.dart';
import '../../../data/repositories/bank_repository.dart';
import '../../widgets/bank_card.dart';
import '../../widgets/add_bank_dialog.dart';

class BanksScreen extends StatefulWidget {
  const BanksScreen({super.key});

  @override
  State<BanksScreen> createState() => _BanksScreenState();
}

class _BanksScreenState extends State<BanksScreen> {
  final BankRepository _repository = BankRepository();

  Future<void> _showAddBankDialog({BankModel? bank}) async {
    final result = await showDialog<BankModel>(
      context: context,
      builder: (context) => AddBankDialog(bank: bank),
    );

    if (result != null) {
      try {
        if (bank == null) {
          // افزودن بانک جدید
          await _repository.addBank(result);
          if (mounted) {
            SnackBarHelper.showSuccess(context, 'بانک با موفقیت ثبت شد');
          }
        } else {
          // ویرایش بانک
          await _repository.updateBank(result);
          if (mounted) {
            SnackBarHelper.showSuccess(context, 'بانک با موفقیت ویرایش شد');
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

  Future<void> _toggleBankStatus(BankModel bank) async {
    final newStatus = !bank.isActive;
    final action = newStatus ? 'فعال‌سازی مجدد' : 'تعلیق';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Text('$action بانک'),
          content: Text(
            'آیا برای $action این بانک اطمینان دارید؟',
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
        await _repository.toggleBankStatus(bank.id, newStatus);
        if (mounted) {
          SnackBarHelper.showSuccess(
            context,
            newStatus ? 'بانک فعال شد' : 'بانک تعلیق شد',
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
                child: _buildBanksList(),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddBankDialog(),
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
            'لیست بانک ها',
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

  Widget _buildBanksList() {
    return StreamBuilder<List<BankModel>>(
      stream: _repository.getAllBanks(),
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

        final banks = snapshot.data ?? [];

        if (banks.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.account_balance,
                  size: 80,
                  color: Colors.grey.shade300,
                ),
                const SizedBox(height: 16),
                Text(
                  'هنوز بانکی ثبت نشده است',
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
          itemCount: banks.length,
          itemBuilder: (context, index) {
            final bank = banks[index];
            return BankCard(
              bank: bank,
              onEdit: () => _showAddBankDialog(bank: bank),
              onToggleStatus: () => _toggleBankStatus(bank),
            );
          },
        );
      },
    );
  }
}