import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:navy_wear/core/utils/extensions.dart';

import '../function/components.dart';
import 'constant.dart';
import 'xpedia_tokens.dart';

/// Light Theme
///
/// Most widgets in this app pick colours inline through [isAppDarkMode] rather
/// than reading the theme, so this mainly governs the Material widgets that are
/// used as-is — buttons, inputs, app bars, dialogs — and makes them follow the
/// Xpedia Partners component rules (design.md §4): radius 8, 1dp borders, no
/// heavy shadows, Inter throughout.
final ThemeData lightTheme = _buildTheme(
  brightness: Brightness.light,
  primary: kLightPrimaryColor,
  canvas: const Color(0xffF7F8FA),
  surface: kWhiteColor,
  text: kLightSecondColor,
  muted: kLightThirdColor,
  border: const Color(0xffD1D5DB),
  appBar: kWhiteColor,
  statusBarIconBrightness: Brightness.dark,
);

/// Dark Theme
final ThemeData darkTheme = _buildTheme(
  brightness: Brightness.dark,
  primary: kDarkPrimaryColor,
  canvas: kBlackColor,
  surface: kDarkColor,
  text: kDarkSecondColor,
  muted: kDarkThirdColor,
  border: const Color(0xff374151),
  appBar: kDarkColor,
  statusBarIconBrightness: Brightness.light,
);

ThemeData _buildTheme({
  required Brightness brightness,
  required Color primary,
  required Color canvas,
  required Color surface,
  required Color text,
  required Color muted,
  required Color border,
  required Color appBar,
  required Brightness statusBarIconBrightness,
}) {
  const radius = BorderRadius.all(Radius.circular(XRadius.md));
  const buttonText = TextStyle(
    fontFamily: kFontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w500,
  );
  const minSize = Size(64, XSize.controlMedium);

  return ThemeData(
    useMaterial3: false,
    brightness: brightness,
    primarySwatch: (isAppDarkMode() ? kDarkPrimaryColor : kLightPrimaryColor)
        .toMaterialColor(),
    primaryColor: primary,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primary,
      brightness: brightness,
      primary: primary,
      surface: surface,
      error: brightness == Brightness.dark
          ? const Color(0xffFD4258)
          : kErrorColor,
    ),
    scaffoldBackgroundColor: canvas,
    cardColor: surface,
    canvasColor: surface,
    dividerColor: brightness == Brightness.dark
        ? const Color(0xff1F2937)
        : kBorderColor,
    fontFamily: kFontFamily,
    appBarTheme: AppBarTheme(
      backgroundColor: appBar,
      foregroundColor: text,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontFamily: kFontFamily,
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: text,
      ),
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: statusBarIconBrightness,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        minimumSize: minSize,
        shape: const RoundedRectangleBorder(borderRadius: radius),
        textStyle: buttonText,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 0,
        minimumSize: minSize,
        shape: const RoundedRectangleBorder(borderRadius: radius),
        textStyle: buttonText,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: text,
        backgroundColor: surface,
        minimumSize: minSize,
        side: BorderSide(color: border),
        shape: const RoundedRectangleBorder(borderRadius: radius),
        textStyle: buttonText,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: primary,
        textStyle: buttonText,
        shape: const RoundedRectangleBorder(borderRadius: radius),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surface,
      hintStyle: const TextStyle(color: XColors.textPlaceholder, fontSize: 14),
      labelStyle: TextStyle(color: muted, fontSize: 14),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: primary, width: 2),
      ),
    ),
    cardTheme: CardThemeData(
      color: surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(
          color: brightness == Brightness.dark
              ? const Color(0xff1F2937)
              : kBorderColor,
        ),
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: surface,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(XRadius.xl)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(XRadius.lg)),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: const RoundedRectangleBorder(borderRadius: radius),
      contentTextStyle: TextStyle(
        fontFamily: kFontFamily,
        fontSize: 14,
        color: brightness == Brightness.dark ? kBlackColor : kWhiteColor,
      ),
    ),
  );
}
