import 'package:flutter/material.dart';
import '../../../core/constants/colors.dart';
import '../../../data/models/bank_model.dart';
import 'package:flutter/services.dart';

class BankCard extends StatefulWidget {
  final BankModel bank;
  final VoidCallback onEdit;
  final VoidCallback onToggleStatus;

  const BankCard({
    super.key,
    required this.bank,
    required this.onEdit,
    required this.onToggleStatus,
  });

  @override
  State<BankCard> createState() => _BankCardState();
}

class _BankCardState extends State<BankCard> {
  bool _isExpanded = false; // state برای نمایش/مخفی کردن دکمه‌ها (مثل customer)

  // Helper برای فرمت ایمن فیلدهای عادی
  String _safeValue(String? value) {
    if (value == null || value.isEmpty) return '---';
    return value;
  }

  // Helper برای فرمت شبا با ساختار استاندارد (۲۴ رقم بدنه)
  String _formatIban(String? ibanWithPrefix) {
    if (ibanWithPrefix == null || ibanWithPrefix.isEmpty) return '---';

    String s = ibanWithPrefix.toUpperCase().replaceAll(' ', ''); // پاک‌سازی
    if (!s.startsWith('IR') || s.length != 26) return '---'; // IR + 24 digits = 26

    String digits = s.substring(2); // 24 digits
    if (!RegExp(r'^\d{24}$').hasMatch(digits)) return '---'; // فقط digits

    String checksum = digits.substring(0, 2); // دو رقم اول (checksum)
    String body = digits.substring(2); // 22 digits باقی (برای 5*4 + 2)

    List<String> groups = <String>[];
    for (int i = 0; i < 20; i += 4) { // 5 گروه 4 رقمی (20 رقم اول)
      groups.add(body.substring(i, i + 4));
    }
    groups.add(body.substring(20, 22)); // 2 رقم آخر جدا

    return 'IR$checksum ${groups.join(' ')}';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector( // تاچ روی کل card
      onTap: () {
        setState(() {
          _isExpanded = !_isExpanded; // toggle
        });
      },
      child: AnimatedContainer( // انیمیشن کلی card (مثل customer)
        duration: const Duration(milliseconds: 250),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: widget.bank.isActive
              ? Colors.white
              : Colors.red.shade50,
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ردیف اول: شماره حساب (سمت چپ) و نام بانک (سمت راست)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween, // شماره چپ، نام راست
                children: [
                  // نام بانک (Expanded برای right align)
                  Expanded(
                    child: Text(
                      widget.bank.bankName,
                      textAlign: TextAlign.right, // راست‌چین (سمت راست باکس)
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: widget.bank.isActive
                            ? AppColors.textPrimary
                            : Colors.red.shade600,
                      ),
                    ),
                  ),

                  const SizedBox(width: 16), // فاصله کوچک

                  // شماره حساب (Expanded برای left align در RTL)
                  Expanded(
                    child: Text(
                      _safeValue(widget.bank.accountNumber),
                      textDirection: TextDirection.ltr, // LTR برای اعداد
                      textAlign: TextAlign.left, // چپ‌چین (سمت چپ باکس)
                      style: TextStyle(
                        fontSize: 14,
                        color: widget.bank.isActive
                            ? AppColors.textSecondary
                            : Colors.red.shade400,
                      ),
                    ),
                  ),
                ],
              ),

              // ردیف دوم: شماره شبا
              if (widget.bank.ibanNumber != null && widget.bank.ibanNumber!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: widget.bank.isActive
                        ? Colors.grey.shade50
                        : Colors.red.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _formatIban(widget.bank.ibanWithPrefix),
                    textDirection: TextDirection.ltr,
                    textAlign: TextAlign.left,
                    style: TextStyle(
                      fontSize: 13,
                      fontFamily: 'monospace',
                      color: widget.bank.isActive
                          ? AppColors.textSecondary
                          : Colors.red.shade600,
                    ),
                  ),
                ),
              ],

              // صاحب حساب
              if (widget.bank.accountOwner != null && widget.bank.accountOwner!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: widget.bank.isActive
                        ? Colors.blue.shade50
                        : Colors.red.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    widget.bank.accountOwner!,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 12,
                      color: widget.bank.isActive
                          ? AppColors.textSecondary
                          : Colors.red.shade600,
                    ),
                  ),
                ),
              ],

              // دکمه‌ها با AnimatedCrossFade (مثل customer)
              AnimatedCrossFade(
                firstChild: const SizedBox(height: 0), // مخفی
                secondChild: Column(
                  children: [
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end, // از راست به چپ در RTL
                      children: [
                        // دکمه کپی
                        TextButton.icon(
                          icon: const Icon(Icons.copy, color: Colors.blueAccent),
                          label: const Text('کپی'),
                          onPressed: () {
                            final formattedIban = _formatIban(widget.bank.ibanWithPrefix);

                            final bankInfo = '''
بانک: ${_safeValue(widget.bank.bankName)}
شماره حساب/کارت: ${_safeValue(widget.bank.accountNumber)}
شماره شبا: $formattedIban
بنام: ${_safeValue(widget.bank.accountOwner)}
''';

                            Clipboard.setData(ClipboardData(text: bankInfo));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('اطلاعات حساب کپی شد')),
                            );
                          },
                        ),

                        const SizedBox(width: 8),

                        // دکمه ویرایش
                        TextButton.icon(
                          onPressed: () {
                            widget.onEdit();
                            setState(() {
                              _isExpanded = false; // مخفی بعد از edit
                            });
                          },
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

                        const SizedBox(width: 8),

                        // دکمه تعلیق/فعال‌سازی
                        TextButton.icon(
                          onPressed: () {
                            widget.onToggleStatus();
                            setState(() {
                              _isExpanded = false; // مخفی بعد از toggle
                            });
                          },
                          icon: Icon(
                            widget.bank.isActive
                                ? Icons.block
                                : Icons.check_circle,
                            size: 16,
                          ),
                          label: Text(widget.bank.isActive ? 'تعلیق' : 'فعال'),
                          style: TextButton.styleFrom(
                            foregroundColor: widget.bank.isActive
                                ? AppColors.error
                                : AppColors.success,
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
                duration: const Duration(milliseconds: 250), // نرم مثل customer
              ),
            ],
          ),
        ),
      ),
    );
  }
}