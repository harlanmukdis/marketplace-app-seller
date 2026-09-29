import 'package:flutter/material.dart';

import '../function/components.dart';
import '../function/get_responsive_font_size.dart';
import '../utils/constant.dart';
import '../utils/xpedia_tokens.dart';

class CustomTextFormField extends StatelessWidget {
  const CustomTextFormField({
    super.key,
    this.hintText,
    this.prefix,
    this.suffix,
    this.keyboardType,
    this.obscureText = false,
    this.readOnly = false,
    this.maxLines = 1,
    this.onSaved,
    this.onChanged,
    this.textInputAction = TextInputAction.next,
    this.textDirection,
    this.validator,
    this.hintTextDirection,
    this.onSubmitted,
    this.labelText,
    this.hintStyle,
    this.filled,
    this.borderRadius,
    this.contentPadding,
    this.controller,
    this.fieldStyle,
    this.autovalidateMode,
    this.fillColor,
    this.onTap,
    this.initialValue,
    this.maxLength,
  });

  final Widget? prefix;
  final Widget? suffix;
  final String? hintText;
  final TextInputType? keyboardType;
  final bool? obscureText;
  final bool? readOnly;
  final int? maxLines;
  final TextInputAction? textInputAction;
  final TextDirection? textDirection;
  final TextDirection? hintTextDirection;
  final void Function(String?)? onSaved;
  final void Function(String)? onChanged;
  final String? Function(String?)? validator;
  final void Function(String)? onSubmitted;
  final String? labelText;
  final TextStyle? hintStyle;
  final bool? filled;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry? contentPadding;
  final TextEditingController? controller;
  final TextStyle? fieldStyle;
  final AutovalidateMode? autovalidateMode;
  final Color? fillColor;
  final void Function()? onTap;
  final String? initialValue;
  final int? maxLength;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      initialValue: initialValue,
      style: fieldStyle ??
          TextStyle(
              color: isAppDarkMode() ? kDarkSecondColor : kLightSecondColor),
      controller: controller,
      validator: validator ??
          (text) {
            if (text == null || text.trim().isEmpty) {
              // The kit shipped this in Arabic; the seller app is Indonesian.
              return 'Wajib diisi';
            }
            return null;
          },
      onTap: onTap,
      maxLength: maxLength,
      autovalidateMode: autovalidateMode,
      textDirection: textDirection,
      readOnly: readOnly!,
      onSaved: onSaved,
      onChanged: onChanged,
      onFieldSubmitted: onSubmitted,
      obscureText: obscureText!,
      keyboardType: keyboardType,
      maxLines: maxLines,
      textInputAction: textInputAction,
      // The Xpedia filled field (S-27): sunken fill, no outline, radius 8,
      // a 2dp primary ring on focus.
      decoration: InputDecoration(
          contentPadding: contentPadding ??
              const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          fillColor: fillColor ?? XColors.sunken,
          filled: filled ?? true,
          labelText: labelText,
          hintText: hintText,
          hintStyle: hintStyle ??
              TextStyle(
                fontWeight: FontWeight.normal,
                fontSize: getResponsiveFontSize(context, fontSize: 14),
                color: isAppDarkMode()
                    ? const Color(0xff94A3B8)
                    : kLightThirdColor,
              ),
          hintTextDirection: hintTextDirection,
          suffixIcon: suffix,
          suffixIconColor: kLightThirdColor,
          prefixIcon: prefix,
          prefixIconColor: kLightThirdColor,
          border: customOutlineInputBorder(),
          enabledBorder: customOutlineInputBorder(),
          focusedBorder: OutlineInputBorder(
            borderRadius: borderRadius ?? BorderRadius.circular(XRadius.md),
            borderSide: BorderSide(color: XColors.primary, width: 2),
          )),
    );
  }

  OutlineInputBorder customOutlineInputBorder() {
    return OutlineInputBorder(
      borderRadius: borderRadius ?? BorderRadius.circular(XRadius.md),
      borderSide: BorderSide.none,
    );
  }
}
