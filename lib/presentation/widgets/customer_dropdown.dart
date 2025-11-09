import 'package:flutter/material.dart';
import '../../../core/constants/colors.dart';
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

class _CustomerDropdownState extends State<CustomerDropdown> {
  final TextEditingController _searchController = TextEditingController();
  List<CustomerModel> _filteredCustomers = [];
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _filteredCustomers = widget.customers;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterCustomers(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredCustomers = widget.customers;
      } else {
        _filteredCustomers = widget.customers.where((customer) {
          final nameLower = customer.fullName.toLowerCase();
          final mobile = customer.mobileNumber;
          final queryLower = query.toLowerCase();

          return nameLower.contains(queryLower) || mobile.contains(query);
        }).toList();
      }
    });
  }

  Future<void> _showSearchDialog() async {
    _searchController.clear();
    _filteredCustomers = widget.customers;

    final selected = await showDialog<CustomerModel>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              title: const Text('انتخاب مشتری'),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // فیلد جستجو
                    TextField(
                      controller: _searchController,
                      textAlign: TextAlign.right,
                      decoration: InputDecoration(
                        hintText: 'جستجو بر اساس نام یا شماره موبایل',
                        prefixIcon: const Icon(Icons.search),
                        filled: true,  // ← اضافه شد: برای white background
                        fillColor: Colors.white,  // ← white برای dialog
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onChanged: (value) {
                        setDialogState(() {
                          _filterCustomers(value);
                        });
                      },
                    ),

                    const SizedBox(height: 16),

                    // لیست مشتریان
                    Flexible(
                      child: _filteredCustomers.isEmpty
                          ? const Center(
                        child: Text('مشتری یافت نشد'),
                      )
                          : ListView.builder(
                        shrinkWrap: true,
                        itemCount: _filteredCustomers.length,
                        itemBuilder: (context, index) {
                          final customer = _filteredCustomers[index];
                          return ListTile(
                            title: Text(customer.fullName),
                            subtitle: Text(customer.mobileNumber),
                            onTap: () => Navigator.pop(context, customer),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('انصراف'),
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
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.white,  // ← key: از grey[100] به white تغییر دادم
                  borderRadius: BorderRadius.circular(12),
                  border: field.hasError
                      ? Border.all(color: AppColors.error)
                      : null,
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.arrow_drop_down,
                      color: AppColors.primary,
                    ),
                    const Spacer(),
                    Text(
                      widget.selectedCustomer?.fullName ?? 'انتخاب مشتری',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: 14,
                        color: widget.selectedCustomer != null
                            ? AppColors.textPrimary
                            : AppColors.textLight,
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                ),
              ),
            ),
            if (field.hasError)
              Padding(
                padding: const EdgeInsets.only(top: 8, right: 16),
                child: Text(
                  field.errorText!,
                  style: const TextStyle(
                    color: AppColors.error,
                    fontSize: 12,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}