import 'package:flutter/painting.dart';

import 'app_colors.dart';

/// The web app uses "Product Sans" (web/app/globals.css). Only the regular
/// and bold faces ship, so web font-light/normal use the regular face and
/// font-semibold/bold use the bold face, same as on web.
abstract final class AppFonts {
  static const family = 'ProductSans';
}

/// Named text styles that map to how the web dashboard sets type.
/// Web body text has letter-spacing 0.01em.
abstract final class AppText {
  static TextStyle _make(double size, FontWeight weight, Color color, double lineHeight) => TextStyle(
    fontFamily: AppFonts.family,
    fontSize: size,
    fontWeight: weight,
    height: lineHeight / size,
    letterSpacing: size * 0.01,
    color: color,
  );

  /// Page title (text-2xl font-semibold text-[#3d2f8f]).
  static final title = _make(24, FontWeight.w700, AppColors.primaryDeep, 30);

  /// Auth page title ("Log in"): 700 weight, #0d0d0d.
  static final authTitle = _make(28, FontWeight.w700, AppColors.textStrong, 34);

  /// Card heading (text-base font-semibold).
  static final heading = _make(16, FontWeight.w700, AppColors.text, 22);

  /// Section heading (text-sm font-semibold).
  static final subheading = _make(14, FontWeight.w700, AppColors.text, 20);

  /// Body copy (text-sm).
  static final body = _make(14, FontWeight.w400, AppColors.text, 20);

  /// Secondary body copy (text-sm text-gray-500).
  static final bodyMuted = _make(14, FontWeight.w400, AppColors.textMuted, 20);

  /// Small text (text-xs text-gray-500).
  static final caption = _make(12, FontWeight.w400, AppColors.textMuted, 16);

  /// Link text (text-xs text-[#5b4bc4]).
  static final link = _make(12, FontWeight.w400, AppColors.primary, 16);

  /// Uppercase section label (text-[10px] font-semibold uppercase tracking-wider).
  static final overline = _make(10, FontWeight.w700, AppColors.textMuted, 14).copyWith(letterSpacing: 0.5);

  /// Form label (auth.css: 14px / 600 / #333).
  static final label = _make(14, FontWeight.w700, AppColors.label, 20);

  /// Button text (auth.css submit: 15px / 700).
  static final button = _make(15, FontWeight.w700, AppColors.textOnDark, 20);

  /// Bottom tab label.
  static final tab = _make(12, FontWeight.w400, AppColors.text, 16);
}
