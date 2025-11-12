import 'package:flutter/material.dart';
import 'package:shamsi_date/shamsi_date.dart';

class CalendarHeader extends StatelessWidget {
  final Jalali selectedDate;
  final VoidCallback onTodayTap;
  final VoidCallback onDateTap;

  const CalendarHeader({
    Key? key,
    required this.selectedDate,
    required this.onTodayTap,
    required this.onDateTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final formatter = selectedDate.formatter;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: onDateTap,
            child: Row(
              children: [
                Text(
                  "${formatter.mN} ${formatter.yyyy}",
                  style: const TextStyle(
                    fontFamily: 'Vazirmatn',
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const Icon(Icons.keyboard_arrow_down),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: onTodayTap,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueAccent,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('امروز'),
          ),
        ],
      ),
    );
  }
}
