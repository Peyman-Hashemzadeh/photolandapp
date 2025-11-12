import 'package:flutter/material.dart';

class BookingCard extends StatelessWidget {
  final Map<String, dynamic> booking;

  const BookingCard({Key? key, required this.booking}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(booking['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    // TODO: پیاده‌سازی عملکرد منو
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'edit', child: Text('ویرایش')),
                    const PopupMenuItem(value: 'receive', child: Text('دریافت')),
                    PopupMenuItem(
                      value: 'cancel',
                      child: Text('لغو', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(booking['time'], style: const TextStyle(color: Colors.teal)),
            Text(booking['type']),
            Text(booking['desc']),
          ],
        ),
      ),
    );
  }
}
