import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_layout.dart';
import '../theme/app_text.dart';

/// Mirrors web auth.css `.auth-form__field`: bold label, 1.5px grey border, black on focus.
class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    required this.label,
    required this.controller,
    this.focusNode,
    this.obscureText = false,
    this.enabled = true,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.onSubmitted,
    this.suffix,
  });

  final String label;
  final TextEditingController controller;
  final FocusNode? focusNode;
  final bool obscureText;
  final bool enabled;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onSubmitted;

  /// Shown inside the field on the right, e.g. a Show/Hide toggle.
  final Widget? suffix;

  static OutlineInputBorder _border(Color color) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(AppRadius.auth),
    borderSide: BorderSide(color: color, width: 1.5),
  );

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppText.label),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          focusNode: focusNode,
          obscureText: obscureText,
          enabled: enabled,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          autofillHints: autofillHints,
          autocorrect: false,
          enableSuggestions: !obscureText,
          onSubmitted: onSubmitted,
          style: AppText.body.copyWith(fontSize: 15, color: AppColors.textStrong),
          cursorColor: AppColors.textStrong,
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: AppColors.surface,
            contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.s4, vertical: 14),
            border: _border(AppColors.borderStrong),
            enabledBorder: _border(AppColors.borderStrong),
            disabledBorder: _border(AppColors.border),
            focusedBorder: _border(AppColors.textStrong),
            suffixIcon: suffix,
          ),
        ),
      ],
    );
  }
}
