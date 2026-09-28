import 'package:flutter/material.dart';

import '../function/components.dart';
import 'constant.dart';

/// The Xpedia Partners design system, as Dart.
///
/// Source of truth: `assets/stitch_xpedia_seller_project/design.md_1.md`. The
/// token names match its tables so a value can be traced back in one search.
/// That file forbids inventing colours, sizes or spacing — so if a screen needs
/// something not listed here, the answer is to use the nearest token, not to
/// add a literal.
///
/// Colours follow the app's existing convention: light and dark are explicit
/// pairs chosen at the point of use through [isAppDarkMode], not a derived
/// theme. Every getter here does that choice once so screens do not have to.
abstract class XColors {
  static bool get _dark => isAppDarkMode();

  // Brand
  static const Color brandNavy = Color(0xff0F286C);
  static Color get primary => _dark ? kDarkPrimaryColor : kLightPrimaryColor;
  static const Color primaryPressed = Color(0xff0047D1);
  static Color get brandSubtle =>
      _dark ? const Color(0xff0F286C) : const Color(0xffEBF2FF);

  // Surface
  static Color get canvas =>
      _dark ? const Color(0xff0B1220) : const Color(0xffF7F8FA);
  static Color get surface => _dark ? const Color(0xff111827) : Colors.white;
  static Color get sunken =>
      _dark ? const Color(0xff1F2937) : const Color(0xffEFF1F4);

  // Text
  static Color get textPrimary =>
      _dark ? const Color(0xffF7F8FA) : const Color(0xff111827);
  static Color get textSecondary =>
      _dark ? const Color(0xff9CA3AF) : const Color(0xff4B5563);
  static Color get textTertiary =>
      _dark ? const Color(0xff9CA3AF) : const Color(0xff6B7280);
  static const Color textPlaceholder = Color(0xff9CA3AF);
  static const Color textOnBrand = Colors.white;

  // Borders
  static Color get borderSubtle =>
      _dark ? const Color(0xff1F2937) : const Color(0xffE5E7EB);
  static Color get borderDefault =>
      _dark ? const Color(0xff374151) : const Color(0xffD1D5DB);
  static const Color borderStrong = Color(0xff9CA3AF);

  // Feedback
  static Color get danger =>
      _dark ? const Color(0xffFD4258) : const Color(0xffFB132D);
  static const Color dangerSubtle = Color(0xffFFECEE);
  static Color get success =>
      _dark ? const Color(0xff22B268) : const Color(0xff109553);
  static const Color successSubtle = Color(0xffE8F8EF);
  static const Color warning = Color(0xffF59E0B);
  static const Color warningSubtle = Color(0xffFFF6E5);

  /// Foregrounds for text on the subtle backgrounds above. The design system
  /// pairs each status background with a darker foreground; these are those.
  static const Color dangerStrong = Color(0xffD10C22);
  static const Color warningStrong = Color(0xff8C5002);
  static const Color successStrong = Color(0xff0C7A44);
  static const Color infoStrong = Color(0xff0047D1);

  // Xpedia Signature — an award, rendered compact and premium.
  static const Color signatureBlack = Color(0xff101014);
  static const Color signatureGoldLight = Color(0xffE8D08A);
  static const Color signatureGold = Color(0xffC9A227);
  static const Color signatureGoldDark = Color(0xff8C6E12);
}

/// A background/foreground pair for a status chip (design.md §1, "Order
/// status"). Never render the foreground as a bare dot — §4 forbids it.
class XTone {
  const XTone(this.background, this.foreground);

  final Color background;
  final Color foreground;

  static const XTone processing = XTone(Color(0xffFFF6E5), Color(0xff8C5002));
  static const XTone shipping = XTone(Color(0xffEBF2FF), Color(0xff0047D1));
  static const XTone received = XTone(Color(0xffE6F7FA), Color(0xff08677B));
  static const XTone completed = XTone(Color(0xffE8F8EF), Color(0xff0C7A44));
  static const XTone cancelled = XTone(Color(0xffEFF1F4), Color(0xff4B5563));
  static const XTone actionNeeded = XTone(Color(0xffFFECEE), Color(0xffD10C22));
  static const XTone preOrder = XTone(Color(0xffF1EEFE), Color(0xff6344D6));
  static const XTone customOrder = XTone(Color(0xffE0D9FD), Color(0xff4E34AB));
  static const XTone securePlus = XTone(Color(0xffEBF2FF), Color(0xff0047D1));

  /// Neutral and success aliases for chips that are not order statuses.
  static const XTone neutral = cancelled;
  static const XTone success = completed;
  static const XTone warning = processing;
  static const XTone danger = actionNeeded;
  static const XTone info = shipping;
}

/// The type scale (design.md §2). Inter only, fixed sizes: the spec sets a
/// floor of 11 px, which a responsive scale-down would break.
abstract class XText {
  static TextStyle _s(
    double size,
    double height,
    FontWeight weight, {
    double letterSpacing = 0,
  }) =>
      TextStyle(
        fontFamily: kFontFamily,
        fontSize: size,
        height: height / size,
        fontWeight: weight,
        letterSpacing: letterSpacing,
        color: XColors.textPrimary,
      );

  static TextStyle get headingXL => _s(24, 32, FontWeight.w700);
  static TextStyle get headingL => _s(20, 28, FontWeight.w600);
  static TextStyle get headingM => _s(18, 26, FontWeight.w600);
  static TextStyle get titleL => _s(16, 24, FontWeight.w600);
  static TextStyle get titleM => _s(14, 20, FontWeight.w600);
  static TextStyle get bodyL => _s(16, 24, FontWeight.w400);
  static TextStyle get bodyM => _s(14, 20, FontWeight.w400);
  static TextStyle get bodyS =>
      _s(12, 18, FontWeight.w400).copyWith(color: XColors.textSecondary);
  static TextStyle get labelL => _s(14, 20, FontWeight.w500);
  static TextStyle get labelM => _s(12, 16, FontWeight.w500);
  static TextStyle get labelS => _s(11, 14, FontWeight.w500);
  static TextStyle get caption =>
      _s(11, 14, FontWeight.w400).copyWith(color: XColors.textTertiary);
  static TextStyle get overline => _s(10, 14, FontWeight.w600,
          letterSpacing: 0.6)
      .copyWith(color: XColors.textTertiary);
  static TextStyle get priceL => _s(18, 24, FontWeight.w700);
  static TextStyle get priceM => _s(16, 22, FontWeight.w700);
  static TextStyle get priceS => _s(14, 20, FontWeight.w600);
  static TextStyle get stat => _s(22, 28, FontWeight.w700);
}

/// Spacing scale (design.md §3): 0, 2, 4, 6, 8, 12, 16, 20, 24, 32, 40, 48, 64.
abstract class XSpace {
  static const double s2 = 2;
  static const double s4 = 4;
  static const double s6 = 6;
  static const double s8 = 8;
  static const double s12 = 12;
  static const double s16 = 16;
  static const double s20 = 20;
  static const double s24 = 24;
  static const double s32 = 32;
  static const double s40 = 40;
  static const double s48 = 48;
  static const double s64 = 64;

  /// Screen horizontal padding and card inner padding.
  static const double screen = 16;
  static const double card = 16;

  /// Between cards, and between sections.
  static const double cardGap = 12;
  static const double sectionGap = 24;
}

abstract class XRadius {
  static const double xs = 4;
  static const double sm = 6;
  static const double md = 8;
  static const double lg = 12;
  static const double xl = 16;
  static const double xxl = 24;
  static const double full = 999;
}

abstract class XSize {
  static const double controlSmall = 36;
  static const double controlMedium = 44;
  static const double controlLarge = 52;
  static const double appBar = 56;
  static const double bottomNav = 64;
  static const double storeLogo = 44;

  /// §3: "Minimum touch target 48 × 48 dp, always."
  static const double touchTarget = 48;
}
