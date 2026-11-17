import 'package:flutter/material.dart';

/// Urutau design system card with consistent styling and variants.
class UrutauCard extends StatelessWidget {
  const UrutauCard({
    super.key,
    required this.child,
    this.variant = UrutauCardVariant.elevated,
    this.onTap,
    this.onLongPress,
    this.semanticsLabel,
    this.padding,
    this.margin,
    this.borderRadius,
    this.elevation,
    this.color,
    this.border,
    this.selected = false,
  });

  /// Creates a tappable card with inkwell effect.
  const UrutauCard.tappable({
    super.key,
    required this.child,
    required this.onTap,
    this.variant = UrutauCardVariant.elevated,
    this.semanticsLabel,
    this.padding,
    this.margin,
    this.borderRadius,
    this.elevation,
    this.color,
    this.border,
  }) : onLongPress = null,
       selected = false;

  /// Creates a selectable card with visual selection state.
  const UrutauCard.selectable({
    super.key,
    required this.child,
    required this.selected,
    this.onTap,
    this.variant = UrutauCardVariant.outlined,
    this.semanticsLabel,
    this.padding,
    this.margin,
    this.borderRadius,
    this.elevation,
    this.color,
    this.border,
  }) : onLongPress = null;

  /// Creates a header card for section headers.
  const UrutauCard.header({
    super.key,
    required this.child,
    this.variant = UrutauCardVariant.filled,
    this.semanticsLabel,
    this.padding,
    this.margin,
    this.borderRadius,
    this.elevation,
    this.color,
    this.border,
  }) : onTap = null,
       onLongPress = null,
       selected = false;

  /// Creates a section card for grouped content.
  const UrutauCard.section({
    super.key,
    required this.child,
    this.variant = UrutauCardVariant.elevated,
    this.semanticsLabel,
    this.padding,
    this.margin,
    this.borderRadius,
    this.elevation,
    this.color,
    this.border,
  }) : onTap = null,
       onLongPress = null,
       selected = false;

  final Widget child;
  final UrutauCardVariant variant;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final String? semanticsLabel;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final BorderRadius? borderRadius;
  final double? elevation;
  final Color? color;
  final BoxBorder? border;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final effectiveColor = color ?? _getColor(colorScheme);
    final effectiveElevation = elevation ?? _getElevation();
    final effectiveBorder = border ?? _getBorder(colorScheme);
    final effectiveBorderRadius = borderRadius ?? BorderRadius.circular(12);
    final effectivePadding = padding ?? const EdgeInsets.all(16);
    final effectiveMargin = margin ?? const EdgeInsets.symmetric(vertical: 4, horizontal: 0);

    Widget card = Container(
      margin: effectiveMargin,
      decoration: BoxDecoration(
        color: effectiveColor,
        borderRadius: effectiveBorderRadius,
        border: effectiveBorder,
        boxShadow: effectiveElevation > 0
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: effectiveElevation * 2,
                  offset: Offset(0, effectiveElevation),
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: effectiveBorderRadius,
        child: Padding(padding: effectivePadding, child: child),
      ),
    );

    if (onTap != null || onLongPress != null) {
      card = Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: effectiveBorderRadius,
          child: card,
        ),
      );
    }

    if (selected) {
      card = Container(
        decoration: BoxDecoration(
          border: Border.all(color: colorScheme.primary, width: 2),
          borderRadius: effectiveBorderRadius,
        ),
        child: card,
      );
    }

    if (semanticsLabel != null) {
      card = Semantics(
        label: semanticsLabel,
        button: onTap != null,
        enabled: onTap != null,
        child: card,
      );
    }

    return card;
  }

  Color _getColor(ColorScheme colorScheme) {
    switch (variant) {
      case UrutauCardVariant.elevated:
        return colorScheme.surface;
      case UrutauCardVariant.filled:
        return colorScheme.surfaceContainerHighest;
      case UrutauCardVariant.outlined:
        return colorScheme.surface;
    }
  }

  double _getElevation() {
    switch (variant) {
      case UrutauCardVariant.elevated:
        return 1;
      case UrutauCardVariant.filled:
        return 0;
      case UrutauCardVariant.outlined:
        return 0;
    }
  }

  BoxBorder? _getBorder(ColorScheme colorScheme) {
    switch (variant) {
      case UrutauCardVariant.elevated:
        return null;
      case UrutauCardVariant.filled:
        return null;
      case UrutauCardVariant.outlined:
        return Border.all(color: colorScheme.outline, width: 1);
    }
  }
}

enum UrutauCardVariant {
  elevated,
  filled,
  outlined,
}