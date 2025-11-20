import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:persian_datetime_picker/persian_datetime_picker.dart';
import 'package:shamsi_date/shamsi_date.dart';
import '../../../core/constants/colors.dart';
import '../../../core/utils/date_helper.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../core/utils/price_input_formatter.dart';
import '../../../data/models/expense_model.dart';
import '../../../data/models/expense_document_model.dart';
import '../../../data/models/bank_model.dart';
import '../../../data/models/service_model.dart';
import '../../../data/repositories/expense_repository.dart';
import '../../../data/repositories/expense_document_repository.dart';
import '../../../data/repositories/bank_repository.dart';
import '../../widgets/custom_button.dart';

class AddExpenseDocumentScreen extends StatefulWidget {
  const AddExpenseDocumentScreen({super.key});

  @override
  State<AddExpenseDocumentScreen> createState() => _AddExpenseDocumentScreenState();
}

class _AddExpenseDocumentScreenState extends State<AddExpenseDocumentScreen> {
  final _formKey = GlobalKey<FormState>();
  final ExpenseRepository _expenseRepository = ExpenseRepository();
  final ExpenseDocumentRepository _documentRepository = ExpenseDocumentRepository();
  final BankRepository _bankRepository = BankRepository();

  final _amountController = TextEditingController();
  final _notesController = TextEditingController();

  List<ExpenseModel> _expenses = [];
  List<BankModel> _banks = [];
  ExpenseModel? _selectedExpense;
  BankModel? _selectedBank;
  Jalali? _selectedDate;
  bool _isCashPayment = false;
  bool _isLoading = false;
  bool _isLoadingData = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoadingData = true);

    try {
      // بارگذاری هزینه‌های فعال
      _expenseRepository.getActiveExpenses().listen((expenses) {
        if (mounted) {
          setState(() => _expenses = expenses);
        }
      });

      // بارگذاری بانک‌های فعال
      _bankRepository.getActiveBanks().listen((banks) {
        if (mounted) {
          setState(() => _banks = banks);
        }
      });

      setState(() => _isLoadingData = false);
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingData = false);
        SnackBarHelper.showError(context, e.toString().replaceAll('Exception: ', ''));
      }
    }
  }

  Future<void> _selectDate() async {
    final picked = await showPersianDatePicker(
      context: context,
      initialDate: _selectedDate ?? Jalali.now(),
      firstDate: Jalali.now().addYears(-1), // حداکثر 1 سال گذشته
      lastDate: Jalali.now(), // فقط تا امروز
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
              textTheme: Theme.of(context).textTheme.apply(fontFamily: 'Vazirmatn'),
            ),
            child: child!,
          ),
        );
      },
    );

    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedExpense == null) {
      SnackBarHelper.showError(context, 'لطفاً هزینه را انتخاب کنید');
      return;
    }

    if (_selectedDate == null) {
      SnackBarHelper.showError(context, 'لطفاً تاریخ سند را انتخاب کنید');
      return;
    }

    if (!_isCashPayment && _selectedBank == null) {
      SnackBarHelper.showError(context, 'لطفاً بانک را انتخاب کنید یا پرداخت نقدی را فعال کنید');
      return;
    }

    setState(() => _isLoading = true);

    try {
      // دریافت شماره سند بعدی
      final documentNumber = await _documentRepository.getNextDocumentNumber();

      // ساخت مدل سند
      final document = ExpenseDocumentModel(
        id: '',
        documentNumber: documentNumber,
        expenseId: _selectedExpense!.id,
        expenseName: _selectedExpense!.expenseName,
        documentDate: _selectedDate!.toDateTime(),
        amount: ServiceModel.parsePrice(_amountController.text) ?? 0,
        bankId: _isCashPayment ? null : _selectedBank?.id,
        bankName: _isCashPayment ? 'نقدی' : _selectedBank?.bankName,
        isCash: _isCashPayment,
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        createdAt: DateTime.now(),
      );

      // ذخیره در Firestore
      await _documentRepository.createDocument(document);

      setState(() => _isLoading = false);

      if (!mounted) return;

      // نمایش پیام موفقیت
      await _showSuccessDialog(documentNumber);
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        SnackBarHelper.showError(
          context,
          e.toString().replaceAll('Exception: ', ''),
        );
      }
    }
  }

  Future<void> _showSuccessDialog(int documentNumber) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text(
            '✓ ثبت موفق',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.success,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            'سند با شماره ${DateHelper.toPersianDigits(documentNumber.toString())} با موفقیت ثبت شد',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16),
          ),
          actions: [
            Center(
              child: CustomButton(
                text: 'متوجه شدم',
                onPressed: () {
                  Navigator.pop(context); // بستن دیالوگ
                  Navigator.pop(context); // برگشت به منوی صدور سند
                },
                useGradient: true,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleCancel() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('انصراف از ثبت'),
          content: const Text('آیا از انصراف ثبت سند هزینه اطمینان دارید؟'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text(
                'بله',
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

    if (confirm == true && mounted) {
      Navigator.pop(context);
    }
  }

  BoxShadow _getFieldShadow() {
    return BoxShadow(
      color: Colors.black.withOpacity(0.05),
      blurRadius: 8,
      offset: const Offset(0, 2),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        await _handleCancel();
        return false;
      },
      child: Scaffold(
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
                if (_isLoadingData)
                  const Expanded(child: Center(child: CircularProgressIndicator()))
                else
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            // 1. انتخاب هزینه
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [_getFieldShadow()],
                              ),
                              child: FormField<ExpenseModel?>(
                                initialValue: _selectedExpense,
                                autovalidateMode: AutovalidateMode.onUserInteraction,
                                validator: (expense) {
                                  if (expense == null) {
                                    return 'لطفاً هزینه را انتخاب کنید';
                                  }
                                  return null;
                                },
                                builder: (field) {
                                  return Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 16),
                                        child: DropdownButtonHideUnderline(
                                          child: DropdownButton<ExpenseModel>(
                                            value: field.value,
                                            isExpanded: true,
                                            icon: const Icon(Icons.arrow_drop_down, color: AppColors.primary),
                                            hint: const Text('انتخاب هزینه', textAlign: TextAlign.right),
                                            items: _expenses.map((expense) {
                                              return DropdownMenuItem(
                                                value: expense,
                                                alignment: Alignment.centerRight,
                                                child: Text(expense.expenseName, textAlign: TextAlign.right),
                                              );
                                            }).toList(),
                                            onChanged: (expense) {
                                              field.didChange(expense);
                                              setState(() {
                                                _selectedExpense = expense;
                                                // اگر هزینه قیمت داشته باشه، فیلد مبلغ رو پر کن
                                                if (expense?.price != null) {
                                                  _amountController.text = ServiceModel.formatNumber(expense!.price!);
                                                }
                                              });
                                            },
                                          ),
                                        ),
                                      ),
                                      if (field.hasError)
                                        Padding(
                                          padding: const EdgeInsets.only(top: 8, right: 16, bottom: 8),
                                          child: Text(
                                            field.errorText!,
                                            style: const TextStyle(color: AppColors.error, fontSize: 12),
                                          ),
                                        ),
                                    ],
                                  );
                                },
                              ),
                            ),

                            const SizedBox(height: 16),

                            // 2. تاریخ سند
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [_getFieldShadow()],
                              ),
                              child: FormField<Jalali?>(
                                initialValue: _selectedDate,
                                autovalidateMode: AutovalidateMode.onUserInteraction,
                                validator: (date) {
                                  if (date == null) {
                                    return 'لطفاً تاریخ سند را انتخاب کنید';
                                  }
                                  return null;
                                },
                                builder: (field) {
                                  return Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      InkWell(
                                        onTap: () {
                                          _selectDate().then((_) {
                                            field.didChange(_selectedDate);
                                          });
                                        },
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                          child: Row(
                                            children: [
                                              const Icon(Icons.arrow_drop_down, color: AppColors.primary),
                                              const Spacer(),
                                              Text(
                                                _selectedDate != null
                                                    ? DateHelper.formatPersianDate(_selectedDate!)
                                                    : 'تاریخ سند',
                                                textAlign: TextAlign.right,
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  color: _selectedDate != null
                                                      ? AppColors.textPrimary
                                                      : AppColors.textLight,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      if (field.hasError)
                                        Padding(
                                          padding: const EdgeInsets.only(top: 8, right: 16, bottom: 8),
                                          child: Text(
                                            field.errorText!,
                                            style: const TextStyle(color: AppColors.error, fontSize: 12),
                                          ),
                                        ),
                                    ],
                                  );
                                },
                              ),
                            ),

                            const SizedBox(height: 16),

                            // 3. مبلغ هزینه
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [_getFieldShadow()],
                              ),
                              child: TextFormField(
                                controller: _amountController,
                                keyboardType: TextInputType.number,
                                textAlign: TextAlign.right,
                                inputFormatters: [PriceInputFormatter()],
                                decoration: InputDecoration(
                                  hintText: 'مبلغ هزینه',
                                  prefixText: 'ریال',
                                  filled: true,
                                  fillColor: Colors.white,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide.none,
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(color: AppColors.primary, width: 2),
                                  ),
                                  errorBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(color: AppColors.error, width: 1),
                                  ),
                                  contentPadding: const EdgeInsets.all(16),
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) return 'مبلغ اجباری است';
                                  return null;
                                },
                              ),
                            ),

                            const SizedBox(height: 16),

                            // 4. انتخاب بانک
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [_getFieldShadow()],
                              ),
                              child: Opacity(
                                opacity: _isCashPayment ? 0.5 : 1.0,
                                child: IgnorePointer(
                                  ignoring: _isCashPayment,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16),
                                    child: DropdownButtonHideUnderline(
                                      child: DropdownButton<BankModel>(
                                        value: _selectedBank,
                                        isExpanded: true,
                                        icon: const Icon(Icons.arrow_drop_down, color: AppColors.primary),
                                        hint: const Text('انتخاب بانک', textAlign: TextAlign.right),
                                        items: _banks.map((bank) {
                                          return DropdownMenuItem(
                                            value: bank,
                                            alignment: Alignment.centerRight,
                                            child: Text(
                                              '${bank.bankName}${bank.accountNumber != null ? ' (${bank.accountNumber})' : ''}',
                                              textAlign: TextAlign.right,
                                            ),
                                          );
                                        }).toList(),
                                        onChanged: (bank) => setState(() => _selectedBank = bank),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 16),

                            // 5. پرداخت نقدی
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [_getFieldShadow()],
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  const Text('پرداخت نقدی', style: TextStyle(fontSize: 14)),
                                  Checkbox(
                                    value: _isCashPayment,
                                    activeColor: AppColors.primary,
                                    onChanged: (value) {
                                      setState(() {
                                        _isCashPayment = value ?? false;
                                        if (_isCashPayment) _selectedBank = null;
                                      });
                                    },
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 16),

                            // 6. توضیحات
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [_getFieldShadow()],
                              ),
                              child: TextFormField(
                                controller: _notesController,
                                maxLength: 155,
                                maxLines: 4,
                                textAlign: TextAlign.right,
                                decoration: InputDecoration(
                                  hintText: 'توضیحات (اختیاری)',
                                  filled: true,
                                  fillColor: Colors.white,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide.none,
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(color: AppColors.primary, width: 2),
                                  ),
                                  contentPadding: const EdgeInsets.all(16),
                                ),
                              ),
                            ),

                            const SizedBox(height: 32),

                            // دکمه‌ها
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: _handleCancel,
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: AppColors.textSecondary,
                                      side: BorderSide(color: Colors.grey.shade300),
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    child: const Text('انصراف'),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: CustomButton(
                                    text: 'ذخیره سند',
                                    onPressed: _handleSubmit,
                                    isLoading: _isLoading,
                                    useGradient: true,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
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
            onPressed: _handleCancel,
          ),
          const Text(
            'صدور سند هزینه',
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
                child: FaIcon(FontAwesomeIcons.user, color: Colors.grey, size: 20),
              ),
            ),
          ),
        ],
      ),
    );
  }
}