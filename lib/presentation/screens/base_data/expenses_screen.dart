import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../core/constants/colors.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../data/models/expense_model.dart';
import '../../../data/repositories/expense_repository.dart';
import '../../widgets/expense_card.dart';
import '../../widgets/add_expense_dialog.dart';

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key});

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  final ExpenseRepository _repository = ExpenseRepository();

  Future<void> _showAddExpenseDialog({ExpenseModel? expense}) async {
    final result = await showDialog<ExpenseModel>(
      context: context,
      builder: (context) => AddExpenseDialog(expense: expense),
    );

    if (result != null) {
      try {
        if (expense == null) {
          // افزودن هزینه جدید
          await _repository.addExpense(result);
          if (mounted) {
            SnackBarHelper.showSuccess(context, 'هزینه با موفقیت ثبت شد');
          }
        } else {
          // ویرایش هزینه
          await _repository.updateExpense(result);
          if (mounted) {
            SnackBarHelper.showSuccess(context, 'هزینه با موفقیت ویرایش شد');
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

  Future<void> _toggleExpenseStatus(ExpenseModel expense) async {
    final newStatus = !expense.isActive;
    final action = newStatus ? 'فعال‌سازی مجدد' : 'تعلیق';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Text('$action هزینه'),
          content: Text(
            'آیا برای $action این هزینه اطمینان دارید؟',
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
        await _repository.toggleExpenseStatus(expense.id, newStatus);
        if (mounted) {
          SnackBarHelper.showSuccess(
            context,
            newStatus ? 'هزینه فعال شد' : 'هزینه تعلیق شد',
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
            image: const AssetImage('assets/images/background.png'),
            fit: BoxFit.cover,
            opacity: 0.1,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: _buildExpensesList(),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddExpenseDialog(),
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
          // دکمه برگشت
          IconButton(
            icon: const Icon(
              Icons.arrow_back,
              color: AppColors.textPrimary,
            ),
            onPressed: () => Navigator.pop(context),
          ),

          // عنوان
          const Text(
            'لیست هزینه‌ها',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),

          // آیکون پروفایل
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

  Widget _buildExpensesList() {
    return StreamBuilder<List<ExpenseModel>>(
      stream: _repository.getAllExpenses(),
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

        final expenses = snapshot.data ?? [];

        if (expenses.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.receipt,
                  size: 80,
                  color: Colors.grey.shade300,
                ),
                const SizedBox(height: 16),
                Text(
                  'هنوز هزینه‌ای ثبت نشده است',
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
          itemCount: expenses.length,
          itemBuilder: (context, index) {
            final expense = expenses[index];
            return ExpenseCard(
              expense: expense,
              onEdit: () => _showAddExpenseDialog(expense: expense),
              onToggleStatus: () => _toggleExpenseStatus(expense),
            );
          },
        );
      },
    );
  }
}