import 'package:flutter/material.dart';

import '../../utils/xpedia_tokens.dart';

/// The Xpedia Partners component set (design.md §4).
///
/// Small on purpose: the design system allows four button styles, one card,
/// one chip shape and one empty state. Screens compose these rather than
/// styling Material widgets inline, so a token change lands everywhere.

enum XButtonVariant { primary, secondary, danger, ghost }

enum XButtonSize { small, medium, large }

class XButton extends StatelessWidget {
  const XButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = XButtonVariant.primary,
    this.size = XButtonSize.medium,
    this.icon,
    this.loading = false,
    this.expand = false,
  });

  const XButton.secondary({
    super.key,
    required this.label,
    required this.onPressed,
    this.size = XButtonSize.medium,
    this.icon,
    this.loading = false,
    this.expand = false,
  }) : variant = XButtonVariant.secondary;

  const XButton.danger({
    super.key,
    required this.label,
    required this.onPressed,
    this.size = XButtonSize.medium,
    this.icon,
    this.loading = false,
    this.expand = false,
  }) : variant = XButtonVariant.danger;

  const XButton.ghost({
    super.key,
    required this.label,
    required this.onPressed,
    this.size = XButtonSize.medium,
    this.icon,
    this.loading = false,
    this.expand = false,
  }) : variant = XButtonVariant.ghost;

  final String label;
  final VoidCallback? onPressed;
  final XButtonVariant variant;
  final XButtonSize size;
  final IconData? icon;
  final bool loading;
  final bool expand;

  double get _height => switch (size) {
        XButtonSize.small => XSize.controlSmall,
        XButtonSize.medium => XSize.controlMedium,
        XButtonSize.large => XSize.controlLarge,
      };

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color fg, BorderSide side) = switch (variant) {
      XButtonVariant.primary =>
        (XColors.primary, XColors.textOnBrand, BorderSide.none),
      XButtonVariant.secondary => (
          XColors.surface,
          XColors.textPrimary,
          BorderSide(color: XColors.borderDefault),
        ),
      XButtonVariant.danger =>
        (XColors.danger, XColors.textOnBrand, BorderSide.none),
      XButtonVariant.ghost =>
        (Colors.transparent, XColors.primary, BorderSide.none),
    };
    final disabled = onPressed == null || loading;

    final child = loading
        ? SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2, color: fg),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (icon != null) ...<Widget>[
                Icon(icon, size: 20, color: fg),
                const SizedBox(width: XSpace.s8),
              ],
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: XText.labelL.copyWith(
                    color: fg,
                    fontWeight: size == XButtonSize.large
                        ? FontWeight.w600
                        : FontWeight.w500,
                  ),
                ),
              ),
            ],
          );

    final button = Opacity(
      opacity: disabled && !loading ? 0.45 : 1,
      child: Material(
        color: bg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(XRadius.md),
          side: side,
        ),
        child: InkWell(
          onTap: disabled ? null : onPressed,
          borderRadius: BorderRadius.circular(XRadius.md),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: _height,
              minWidth: XSize.touchTarget,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: XSpace.s16),
              // Both factors: without heightFactor, a Center in a Row with a
              // bounded height (a bottom bar) grows to fill it, and the
              // button swallows the whole screen above.
              child: Center(widthFactor: 1, heightFactor: 1, child: child),
            ),
          ),
        ),
      ),
    );

    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}

/// White surface, radius 8, 1dp border-subtle, padding 16. No gradients.
class XCard extends StatelessWidget {
  const XCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(XSpace.card),
    this.onTap,
    this.color,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color ?? XColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(XRadius.md),
        side: BorderSide(color: XColors.borderSubtle),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

/// Pill, height 24, padding 8 horizontal, Label/M.
class XChip extends StatelessWidget {
  const XChip({
    super.key,
    required this.label,
    this.tone = XTone.neutral,
    this.icon,
  });

  final String label;
  final XTone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: XSpace.s8),
      decoration: BoxDecoration(
        color: tone.background,
        borderRadius: BorderRadius.circular(XRadius.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Icon(icon, size: 14, color: tone.foreground),
            const SizedBox(width: XSpace.s4),
          ],
          Text(
            label,
            maxLines: 1,
            style: XText.labelM.copyWith(color: tone.foreground),
          ),
        ],
      ),
    );
  }
}

/// A full-width notice: privacy, SLA, warnings. Tinted, never a gradient.
class XBanner extends StatelessWidget {
  const XBanner({
    super.key,
    required this.message,
    this.title,
    this.tone = XTone.info,
    this.icon = Icons.info_outline_rounded,
    this.bordered = false,
  });

  final String message;
  final String? title;
  final XTone tone;
  final IconData icon;
  final bool bordered;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(XSpace.s12),
      decoration: BoxDecoration(
        color: tone.background,
        borderRadius: BorderRadius.circular(XRadius.md),
        border: bordered
            ? Border.all(color: tone.foreground.withValues(alpha: 0.25))
            : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 20, color: tone.foreground),
          const SizedBox(width: XSpace.s8),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: <InlineSpan>[
                  if (title != null)
                    TextSpan(
                      text: '$title ',
                      style: XText.titleM.copyWith(
                        color: tone.foreground,
                        fontSize: 12,
                        height: 18 / 12,
                      ),
                    ),
                  TextSpan(text: message),
                ],
              ),
              style: XText.bodyS.copyWith(color: tone.foreground),
            ),
          ),
        ],
      ),
    );
  }
}

/// Section title with an optional trailing action ("Lihat Semua").
class XSectionHeader extends StatelessWidget {
  const XSectionHeader({
    super.key,
    required this.title,
    this.trailing,
    this.count,
    this.onTrailing,
  });

  final String title;
  final String? trailing;
  final int? count;
  final VoidCallback? onTrailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: XSpace.s12),
      child: Row(
        children: <Widget>[
          Flexible(child: Text(title, style: XText.headingM)),
          if (count != null) ...<Widget>[
            const SizedBox(width: XSpace.s8),
            Text('$count', style: XText.titleM),
          ],
          const Spacer(),
          if (trailing != null)
            InkWell(
              onTap: onTrailing,
              borderRadius: BorderRadius.circular(XRadius.sm),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: XSpace.s4,
                  vertical: XSpace.s8,
                ),
                child: Text(
                  trailing!,
                  style: XText.labelL.copyWith(color: XColors.primary),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// A label/value line, as in the earnings breakdown and buyer info panels.
class XKeyValue extends StatelessWidget {
  const XKeyValue({
    super.key,
    required this.label,
    required this.value,
    this.valueStyle,
    this.labelStyle,
    this.padding = const EdgeInsets.symmetric(vertical: XSpace.s4),
  });

  final String label;
  final String value;
  final TextStyle? valueStyle;
  final TextStyle? labelStyle;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Text(
              label,
              style: labelStyle ??
                  XText.bodyM.copyWith(color: XColors.textSecondary),
            ),
          ),
          const SizedBox(width: XSpace.s12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: valueStyle ?? XText.bodyM,
            ),
          ),
        ],
      ),
    );
  }
}

/// Icon, one line of Title/M, one line of Body/S, one Secondary button.
/// Never a large illustration (design.md §4).
class XEmptyState extends StatelessWidget {
  const XEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: XSpace.s24,
        vertical: XSpace.s32,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 32, color: XColors.textTertiary),
          const SizedBox(height: XSpace.s12),
          Text(title, textAlign: TextAlign.center, style: XText.titleM),
          if (message != null) ...<Widget>[
            const SizedBox(height: XSpace.s4),
            Text(message!, textAlign: TextAlign.center, style: XText.bodyS),
          ],
          if (actionLabel != null) ...<Widget>[
            const SizedBox(height: XSpace.s16),
            XButton.secondary(label: actionLabel!, onPressed: onAction),
          ],
        ],
      ),
    );
  }
}

/// The screen's top bar: title (Heading/M-ish), optional subtitle, actions.
/// 56dp tall, surface background, hairline below.
class XAppBar extends StatelessWidget implements PreferredSizeWidget {
  const XAppBar({
    super.key,
    required this.title,
    this.subtitle,
    this.actions = const <Widget>[],
    this.leading,
    this.showBack = true,
    this.bottom,
  });

  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final Widget? leading;
  final bool showBack;
  final PreferredSizeWidget? bottom;

  @override
  Size get preferredSize => Size.fromHeight(
        XSize.appBar + (bottom?.preferredSize.height ?? 0) + 1,
      );

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();
    return Material(
      color: XColors.surface,
      child: SafeArea(
        bottom: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            SizedBox(
              height: XSize.appBar,
              child: Row(
                children: <Widget>[
                  if (leading != null)
                    leading!
                  else if (showBack && canPop)
                    IconButton(
                      tooltip: 'Kembali',
                      icon: Icon(Icons.arrow_back, color: XColors.textPrimary),
                      onPressed: () => Navigator.of(context).maybePop(),
                    )
                  else
                    const SizedBox(width: XSpace.s16),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: XText.headingM,
                        ),
                        if (subtitle != null)
                          Text(
                            subtitle!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: XText.bodyS,
                          ),
                      ],
                    ),
                  ),
                  ...actions,
                  const SizedBox(width: XSpace.s4),
                ],
              ),
            ),
            if (bottom != null) bottom!,
            Divider(height: 1, thickness: 1, color: XColors.borderSubtle),
          ],
        ),
      ),
    );
  }
}

/// A square icon action for [XAppBar], sized to the 48dp touch target, with an
/// optional danger-coloured count badge (design.md §4, bottom navigation).
class XIconAction extends StatelessWidget {
  const XIconAction({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.badge,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final int? badge;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: XBadge(
        count: badge,
        child: Icon(icon, color: XColors.textPrimary),
      ),
    );
  }
}

class XBadge extends StatelessWidget {
  const XBadge({super.key, required this.child, this.count});

  final Widget child;
  final int? count;

  @override
  Widget build(BuildContext context) {
    final n = count ?? 0;
    if (n <= 0) return child;
    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        child,
        Positioned(
          right: -8,
          top: -4,
          child: Container(
            constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
            padding: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: XColors.danger,
              borderRadius: BorderRadius.circular(XRadius.full),
            ),
            child: Center(
              child: Text(
                n > 99 ? '99+' : '$n',
                style: XText.labelS.copyWith(
                  color: XColors.textOnBrand,
                  fontSize: 10,
                  height: 1.4,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// A bordered group of rows separated by hairlines — the "Perlu Tindakan"
/// list on the home screen.
class XListGroup extends StatelessWidget {
  const XListGroup({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return XCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: <Widget>[
          for (var i = 0; i < children.length; i++) ...<Widget>[
            if (i > 0)
              Divider(height: 1, thickness: 1, color: XColors.borderSubtle),
            children[i],
          ],
        ],
      ),
    );
  }
}

class XListRow extends StatelessWidget {
  const XListRow({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.iconColor,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: XSpace.s16,
            vertical: XSpace.s12,
          ),
          child: Row(
            children: <Widget>[
              Icon(icon, size: 22, color: iconColor ?? XColors.textPrimary),
              const SizedBox(width: XSpace.s16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: XText.bodyM,
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: XText.bodyS,
                      ),
                  ],
                ),
              ),
              if (trailing != null) ...<Widget>[
                const SizedBox(width: XSpace.s8),
                trailing!,
              ],
              if (onTap != null) ...<Widget>[
                const SizedBox(width: XSpace.s8),
                Icon(Icons.chevron_right, size: 20, color: XColors.textTertiary),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
