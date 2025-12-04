import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants/colors.dart';

class CustomTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData? icon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final List<TextInputFormatter>? inputFormatters;
  final int? maxLength;
  final Widget? suffixIcon;
  final ValueChanged<String>? onChanged;

  /// جدید: امکان تعیین سایز فونت و رنگ متن
  final double fontSize;
  final double labelFontSize;
  final double floatingLabelFontSize;
  final Color? textColor;

  const CustomTextField({
    super.key,
    required this.controller,
    required this.hint,
    this.icon,
    this.obscureText = false,
    this.keyboardType,
    this.validator,
    this.inputFormatters,
    this.maxLength,
    this.suffixIcon,
    this.onChanged,
    this.fontSize = 14,
    this.labelFontSize = 12,
    this.floatingLabelFontSize = 13,
    this.textColor, // اگه null باشه از AppColors.textPrimary استفاده می‌کنیم
  });

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: TextFormField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        validator: validator,
        onChanged: onChanged,
        inputFormatters: inputFormatters,
        maxLength: maxLength,
        textAlign: TextAlign.right,

        /// فونت متن داخل TextField (استفاده از textColor یا fallback به textPrimary)
        style: TextStyle(
          fontSize: fontSize,
          color: textColor ?? AppColors.textPrimary,
        ),

        decoration: InputDecoration(
          labelText: hint,
          labelStyle: TextStyle(
            color: AppColors.textLight,
            fontSize: labelFontSize,
          ),
          floatingLabelStyle: TextStyle(
            color: AppColors.primary,
            fontSize: floatingLabelFontSize,
            fontWeight: FontWeight.bold,
            backgroundColor: Colors.white,
          ),
          floatingLabelBehavior: FloatingLabelBehavior.auto,

          prefixIcon: icon != null
              ? Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Icon(icon, color: AppColors.primary),
          )
              : null,

          suffixIcon: suffixIcon,

          filled: true,
          fillColor: Colors.white,

          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: Colors.grey.shade300,
              width: 1,
            ),
          ),

          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: Colors.grey.shade300,
              width: 1,
            ),
          ),

          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(
              color: AppColors.primary,
              width: 2,
            ),
          ),

          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(
              color: AppColors.error,
              width: 1,
            ),
          ),

          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(
              color: AppColors.error,
              width: 2,
            ),
          ),

          counterText: '',

          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
        ),
      ),
    );
  }
}
