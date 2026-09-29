import 'package:flutter/material.dart';

import '../../../../../core/utils/xpedia_tokens.dart';

/// The bordered container the older seller screens sit their blocks in.
///
/// Restyled to the Xpedia card (design.md §4): white surface, radius 8, a
/// 1dp border-subtle outline, 16 padding, Title/M heading. The API is
/// unchanged, so every screen still using it follows the design system.
class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.child,
    this.title,
    this.trailing,
    this.accent,
    this.onTap,
    this.padding,
  });

  final Widget child;
  final String? title;
  final Widget? trailing;

  /// Border colour for a card that must stand out (a warning, a selection).
  final Color? accent;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: XColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(XRadius.md),
        side: BorderSide(color: accent ?? XColors.borderSubtle),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: padding ?? const EdgeInsets.all(XSpace.card),
          child: SizedBox(
            width: double.infinity,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (title != null) ...<Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(child: Text(title!, style: XText.titleL)),
                      if (trailing != null) trailing!,
                    ],
                  ),
                  const SizedBox(height: XSpace.s12),
                ],
                child,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A label/value pair. [emphasis] promotes the value for the one number that
/// matters most on a card.
class StatRow extends StatelessWidget {
  const StatRow({
    super.key,
    required this.label,
    required this.value,
    this.valueColor,
    this.emphasis = false,
  });

  final String label;
  final String value;
  final Color? valueColor;
  final bool emphasis;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: XSpace.s4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Text(
              label,
              style: XText.bodyM.copyWith(color: XColors.textSecondary),
            ),
          ),
          const SizedBox(width: XSpace.s8),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: (emphasis ? XText.priceM : XText.bodyM)
                  .copyWith(color: valueColor),
            ),
          ),
        ],
      ),
    );
  }
}
