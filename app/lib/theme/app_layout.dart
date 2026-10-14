/// Radius and spacing mirrored from the web app.
/// web/components/products/ui-classes.ts: roundCard / roundBtn / roundInput = rounded-[2rem].
/// web/styles/auth.css: inputs and submit button use 0.625rem.
abstract final class AppRadius {
  static const card = 32.0;
  static const button = 32.0;
  static const input = 32.0;
  static const auth = 10.0;
  static const chip = 12.0;
  static const full = 999.0;
}

/// Tailwind spacing scale (1 unit = 4 px).
abstract final class AppSpacing {
  static const s1 = 4.0;
  static const s2 = 8.0;
  static const s3 = 12.0;
  static const s4 = 16.0;
  static const s5 = 20.0;
  static const s6 = 24.0;
  static const s8 = 32.0;
  static const s10 = 40.0;
}

/// Minimum touch target size for anything tappable.
const double hitTarget = 44;
