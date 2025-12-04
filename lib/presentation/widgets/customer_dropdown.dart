import 'package:flutter/material.dart';
import '../../../core/constants/colors.dart';
import '../../../core/utils/date_helper.dart'; // برای toPersianDigits
import '../../../data/models/customer_model.dart';

class CustomerDropdown extends StatefulWidget {
  final List<CustomerModel> customers;
  final CustomerModel? selectedCustomer;
  final Function(CustomerModel?) onChanged;
  final String? Function(CustomerModel?)? validator;

  const CustomerDropdown({
    super.key,
    required this.customers,
    required this.selectedCustomer,
    required this.onChanged,
    this.validator,
  });

  @override
  State<CustomerDropdown> createState() => _CustomerDropdownState();
}

class _CustomerDropdownState extends State<CustomerDropdown>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  List<CustomerModel> _filteredCustomers = [];

  @override
  void initState() {
    super.initState();
    _filteredCustomers = widget.customers;
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _filterCustomers(String query) {
    setState(() {
      List<CustomerModel> filtered = [];
      if (query.isEmpty) {
        filtered = widget.customers;
      } else {
        filtered = widget.customers.where((customer) {
          final nameLower = customer.fullName.toLowerCase();
          final mobile = customer.mobileNumber;
          final queryLower = query.toLowerCase();
          return nameLower.contains(queryLower) || mobile.contains(query);
        }).toList();
      }

      // مشتری انتخاب‌شده رو همیشه اول بذار (اگر وجود داشته باشه)
      if (widget.selectedCustomer != null &&
          (query.isEmpty || filtered.any((c) => c.id == widget.selectedCustomer!.id))) {
        filtered.removeWhere((c) => c.id == widget.selectedCustomer!.id); // حذف اگر تکراری
        filtered.insert(0, widget.selectedCustomer!); // اول قرار بده
      }

      _filteredCustomers = filtered;
      _animationController.forward();
    });
  }

  void _clearSearch() {
    _searchController.clear();
    _filterCustomers('');
  }

  Future<void> _showSearchDialog() async {
    _searchController.clear();
    _filterCustomers('');

    final selected = await showDialog<CustomerModel>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Text(
                'انتخاب مشتری',
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                  fontSize: 18,
                ),
              ),
              content: SizedBox(
                width: 400, // عرض محدود برای مینیمال
                height: 400,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // جستجو مینیمال
                    TextField(
                      controller: _searchController,
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontSize: 16),
                      decoration: InputDecoration(
                        hintText: 'نام یا شماره همراه',
                        hintStyle: TextStyle(color: Colors.grey.shade500),
                        prefixIcon: Icon(Icons.search, color: AppColors.primary, size: 20),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                          icon: Icon(Icons.close, size: 20, color: Colors.grey.shade500),
                          onPressed: _clearSearch,
                        )
                            : null,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: AppColors.primary),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        isDense: true,
                      ),
                      onChanged: (value) {
                        setDialogState(() {
                          _filterCustomers(value);
                        });
                      },
                    ),

                    const SizedBox(height: 16),

                    // لیست مینیمال
                    Expanded(
                      child: FadeTransition(
                        opacity: _fadeAnimation,
                        child: _filteredCustomers.isEmpty
                            ? Center(
                          child: Text(
                            'مشتری یافت نشد.',
                            style: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 14,
                            ),
                          ),
                        )
                            : ListView.separated(
                          padding: EdgeInsets.zero,
                          itemCount: _filteredCustomers.length,
                          separatorBuilder: (context, index) => Divider(
                            height: 1,
                            color: Colors.grey.shade200,
                            thickness: 0.5,
                          ),
                          itemBuilder: (context, index) {
                            final customer = _filteredCustomers[index];
                            final isSelected = widget.selectedCustomer?.id == customer.id;
                            return InkWell(
                              onTap: () => Navigator.pop(context, customer),
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                                color: isSelected ? Colors.grey.shade50 : null,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            customer.fullName,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 16,
                                            ),
                                          ),
                                          const SizedBox(height: 6), // ← فاصله بیشتر
                                          Text(
                                            DateHelper.toPersianDigits(customer.mobileNumber), // ← اعداد فارسی
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: Colors.grey.shade600,
                                              fontStyle: FontStyle.italic,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (isSelected)
                                      Icon(
                                        Icons.check_circle,
                                        color: AppColors.primary,
                                        size: 20,
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'انصراف',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    if (selected != null) {
      widget.onChanged(selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FormField<CustomerModel>(
      initialValue: widget.selectedCustomer,
      validator: widget.validator,
      builder: (field) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            InkWell(
              onTap: _showSearchDialog,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: field.hasError
                      ? Border.all(color: AppColors.error, width: 1.5)
                      : Border.all(color: Colors.transparent),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        widget.selectedCustomer?.fullName ?? 'انتخاب مشتری',
                        style: TextStyle(
                          fontSize: 16,
                          color: widget.selectedCustomer != null
                              ? AppColors.textPrimary
                              : Colors.grey.shade500,
                          fontWeight: widget.selectedCustomer != null
                              ? FontWeight.w500
                              : FontWeight.normal,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Icon(
                      Icons.arrow_drop_down_rounded,
                      color: field.hasError ? AppColors.error : AppColors.primary,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
            if (field.hasError)
              Padding(
                padding: const EdgeInsets.only(top: 8, right: 16),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    field.errorText!,
                    style: TextStyle(
                      color: AppColors.error,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}