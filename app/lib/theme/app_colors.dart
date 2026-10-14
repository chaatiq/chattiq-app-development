import 'package:flutter/painting.dart';

/// Colour tokens mirrored from the web dashboard (web/app/globals.css,
/// web/components/dashboard/*, web/styles/auth.css). Keep them in sync with
/// the web values; do not introduce colours the web app does not use.
abstract final class AppColors {
  // Surfaces
  static const background = Color(0xFFFFFFFF);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceMuted = Color(0xFFFAFAFA);
  static const surfaceSubtle = Color(0xFFF5F5F7);

  // Text
  static const text = Color(0xFF1A1A1A);
  static const textStrong = Color(0xFF0D0D0D);
  static const textSecondary = Color(0xFF4B5563);
  static const textMuted = Color(0xFF6B7280);
  static const textFaint = Color(0xFF9CA3AF);
  static const textOnDark = Color(0xFFFFFFFF);
  static const label = Color(0xFF333333);

  // Brand violet
  static const primary = Color(0xFF5B4BC4);
  static const primaryDeep = Color(0xFF3D2F8F);
  static const primarySoft = Color(0xFFEDE9FE);
  static const primaryBorder = Color(0xFFC4B5FD);

  // Borders
  static const border = Color(0xFFE5E7EB);
  static const borderSubtle = Color(0xFFF3F4F6);
  static const borderStrong = Color(0xFFD1D5DB);

  // Feedback (auth.css alerts)
  static const warningText = Color(0xFFB45309);
  static const warningBg = Color(0xFFFFFBEB);
  static const warningBorder = Color(0xFFFDE68A);
  static const successText = Color(0xFF15803D);
  static const successBg = Color(0xFFF0FDF4);
  static const successBorder = Color(0xFFBBF7D0);
  static const danger = Color(0xFFDC2626);
  static const dangerBg = Color(0xFFFEF2F2);

  // Buttons (auth.css .auth-form__submit)
  static const buttonPrimary = Color(0xFF0D0D0D);
  static const buttonPrimaryPressed = Color(0xFF252525);

  // Chat inbox and thread (globals.css .cdb-inbox-* / .cdb-chat-*)
  static const chatWallpaper = Color(0xFFE5DDD5);
  static const chatBar = Color(0xFFF0F2F5);
  static const chatBarBorder = Color(0xFFD1D7DB);
  static const bubbleUser = Color(0xFFD9FDD3);
  static const bubbleUserTime = Color(0xFF3F6B4A);
  static const bubbleAi = Color(0xFFFFFFFF);
  static const bubbleText = Color(0xFF111827);
  static const whatsapp = Color(0xFF25D366);
  static const whatsappDark = Color(0xFF128C7E);
  static const avatarGreen = Color(0xFF1B5E20);
  static const avatarGreenLight = Color(0xFF2E7D32);
  static const aiPillBg = Color(0xFFDCF8C6);
  static const aiPillText = Color(0xFF1B5E20);
  static const humanPillBg = Color(0xFFFFE8CC);
  static const humanPillText = Color(0xFF9A3412);
  static const takeoverBg = Color(0xFFA8E6A3);
  static const resumeBg = Color(0xFFECECEC);
  static const windowOpenBg = Color(0xFFECFDF5);
  static const windowOpenText = Color(0xFF047857);
  static const windowClosedBg = Color(0xFFFFF7ED);
  static const windowClosedText = Color(0xFF9A3412);
  static const dateChipBg = Color(0xFFE1F2FA);
  static const dateChipText = Color(0xFF54656F);
  static const statusActive = Color(0xFF059669);
  static const statusDone = Color(0xFF6B7280);
  static const chargeConfirm = Color(0xFFFBBF24);
  static const rowSelected = Color(0xFFF0FDF4);

  // Brand green of the Chattiq logo ("tiq"); notification accent.
  static const brandGreen = Color(0xFF00C158);
}
