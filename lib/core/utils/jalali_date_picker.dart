import 'package:flutter/material.dart';
import 'package:shamsi_date/shamsi_date.dart';
import '../../core/constants/colors.dart';

Future<Jalali?> showJalaliDatePicker({
  required BuildContext context,
  required Jalali initialDate,
  required Jalali firstDate,
  required Jalali lastDate,
}) async {
  return await showDialog<Jalali>(
    context: context,
    builder: (context) => _JalaliDatePickerDialog(
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
    ),
  );
}

class _JalaliDatePickerDialog extends StatefulWidget {
  final Jalali initialDate;
  final Jalali firstDate;
  final Jalali lastDate;

  const _JalaliDatePickerDialog({
    required this.initialDate,
    required this.firstDate,
    required this.lastDate,
  });

  @override
  State<_JalaliDatePickerDialog> createState() => _JalaliDatePickerDialogState();
}

class _JalaliDatePickerDialogState extends State<_JalaliDatePickerDialog> {
  late Jalali _selectedDate;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate;
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        title: Text('${_selectedDate.year}/${_selectedDate.month}/${_selectedDate.day}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ماه و سال
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () {
                    setState(() {
                      _selectedDate = _selectedDate.addMonths(1);
                    });
                  },
                ),
                Text(
                  '${_getMonthName(_selectedDate.month)} ${_selectedDate.year}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () {
                    setState(() {
                      _selectedDate = _selectedDate.addMonths(-1);
                    });
                  },
                ),
              ],
            ),
            // TODO: Grid روزها
            const Text('تقویم در حال توسعه...'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('انصراف'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, _selectedDate),
            child: const Text('تایید'),
          ),
        ],
      ),
    );
  }

  String _getMonthName(int month) {
    const months = [
      '', 'فروردین', 'اردیبهشت', 'خرداد', 'تیر', 'مرداد', 'شهریور',
      'مهر', 'آبان', 'آذر', 'دی', 'بهمن', 'اسفند'
    ];
    return months[month];
  }
}