import 'package:flutter/material.dart';
import '../../../core/constants/colors.dart';

class DurationOption {
  final String label;
  final int minutes;

  const DurationOption(this.label, this.minutes);
}

class DurationDropdown extends StatelessWidget {
  final int? selectedDuration;
  final Function(int?) onChanged;
  final String? Function(int?)? validator;

  static const List<DurationOption> durations = [
    DurationOption('نیم ساعت', 30),
    DurationOption('سه ربع', 45),
    DurationOption('یک ساعت', 60),
    DurationOption('یک ساعت و نیم', 90),
    DurationOption('دو ساعت', 120),
  ];

  const DurationDropdown({
    super.key,
    required this.selectedDuration,
    required this.onChanged,
    this.validator,
  });

  String? _getDurationLabel(int? minutes) {
    if (minutes == null) return null;
    return durations
        .firstWhere((d) => d.minutes == minutes, orElse: () => durations[0])
        .label;
  }

  @override
  Widget build(BuildContext context) {
    return FormField<int>(
      initialValue: selectedDuration,
      validator: validator,
      builder: (field) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            InkWell(
              onTap: () {
                // باز کردن منو به‌صورت دستی (درون DropdownButton کار می‌کند)
                FocusScope.of(context).requestFocus(FocusNode());
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: field.hasError
                      ? Border.all(color: AppColors.error)
                      : null,
                ),
                child: Row(
                  children: [
                    // 👇 آیکون سمت چپ
                    const Icon(Icons.arrow_drop_down, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          value: selectedDuration,
                          isExpanded: true,
                          alignment: Alignment.centerRight,
                          icon: const SizedBox.shrink(), // 🚫 آیکون پیش‌فرض حذف شد
                          hint: const Align(
                            alignment: Alignment.centerRight,
                            child: Text(
                              'مدت رزرو',
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                color: AppColors.textLight,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          items: durations.map((duration) {
                            return DropdownMenuItem<int>(
                              value: duration.minutes,
                              alignment: Alignment.centerRight,
                              child: Text(
                                duration.label,
                                textAlign: TextAlign.right,
                              ),
                            );
                          }).toList(),
                          onChanged: (value) {
                            field.didChange(value);
                            onChanged(value);
                          },
                          selectedItemBuilder: (context) {
                            return durations.map((duration) {
                              return Align(
                                alignment: Alignment.centerRight,
                                child: Text(
                                  duration.label,
                                  style: const TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 14,
                                  ),
                                ),
                              );
                            }).toList();
                          },
                        ),
                      ),
                    ),
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
