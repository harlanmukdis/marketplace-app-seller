import 'package:flutter/material.dart';

import '../utils/app_styles.dart';
import '../utils/constant.dart';
import '../utils/xpedia_tokens.dart';
import '../utils/extensions.dart';

/// A labelled dropdown styled to match [CustomTextFormField], so forms that mix
/// free text and fixed choices read as one form.
///
/// Fixed choices matter more than usual in this app: several backend fields
/// accept only a closed list (cancellation reasons, doc types, fleet codes) and
/// a free-text box would just produce 422s.
class AppDropdownField<T> extends StatelessWidget {
  const AppDropdownField({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.itemLabel,
    required this.onChanged,
    this.hint,
    this.helperText,
    this.validator,
  });

  final String label;
  final T? value;
  final List<T> items;
  final String Function(T item) itemLabel;
  final ValueChanged<T?> onChanged;
  final String? hint;
  final String? helperText;
  final String? Function(T?)? validator;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label, style: XText.labelL),
        8.sbh,
        DropdownButtonFormField<T>(
          initialValue: value,
          isExpanded: true,
          hint: hint == null ? null : Text(hint!),
          validator: validator,
          // Same filled style as CustomTextFormField (S-27).
          decoration: InputDecoration(
            filled: true,
            fillColor: XColors.sunken,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(XRadius.md),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(XRadius.md),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(XRadius.md),
              borderSide: BorderSide(color: XColors.primary, width: 2),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
          items: items
              .map(
                (item) => DropdownMenuItem<T>(
                  value: item,
                  child: Text(itemLabel(item), overflow: TextOverflow.ellipsis),
                ),
              )
              .toList(),
          onChanged: onChanged,
        ),
        if (helperText != null) ...<Widget>[
          4.sbh,
          Text(
            helperText!,
            style: AppStyles.styleRegular10(context)
                .copyWith(color: kLightThirdColor),
          ),
        ],
      ],
    );
  }
}
