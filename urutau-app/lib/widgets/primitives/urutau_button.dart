import 'package:flutter/material.dart';

/// Urutau design system button with semantic variants and consistent styling.
class UrutauButton extends StatelessWidget {
  const UrutauButton({
    super.key,
    required this.onPressed,
    required this.label,
    this.variant = UrutauButtonVariant.primary,
    this.size = UrutauButtonSize.medium,
    this.icon,
    this.isLoading = false,
    this.isFullWidth = false,
    this.semanticsLabel,
    this.tooltip,
  });

  /// Creates a primary button.
  const UrutauButton.primary({
    super.key,
    required this.onPressed,
    required this.label,
    this.size = UrutauButtonSize.medium,
    this.icon,
    this.isLoading = false,
    this.isFullWidth = false,
    this.semanticsLabel,
    this.tooltip,
  }) : variant = UrutauButtonVariant.primary;

  /// Creates a secondary button.
  const UrutauButton.secondary({
    super.key,
    required this.onPressed,
    required this.label,
    this.size = UrutauButtonSize.medium,
    this.icon,
    this.isLoading = false,
    this.isFullWidth = false,
    this.semanticsLabel,
    this.tooltip,
  }) : variant = UrutauButtonVariant.secondary;

  /// Creates an outline button.
  const UrutauButton.outline({
    super.key,
    required this.onPressed,
    required this.label,
    this.size = UrutauButtonSize.medium,
    this.icon,
    this.isLoading = false,
    this.isFullWidth = false,
    this.semanticsLabel,
    this.tooltip,
  }) : variant = UrutauButtonVariant.outline;

  /// Creates a text button.
  const UrutauButton.text({
    super.key,
    required this.onPressed,
    required this.label,
    this.size = UrutauButtonSize.medium,
    this.icon,
    this.isLoading = false,
    this.isFullWidth = false,
    this.semanticsLabel,
    this.tooltip,
  }) : variant = UrutauButtonVariant.text;

  /// Creates a destructive button (for dangerous actions).
  const UrutauButton.destructive({
    super.key,
    required this.onPressed,
    required this.label,
    this.size = UrutauButtonSize.medium,
    this.icon,
    this.isLoading = false,
    this.isFullWidth = false,
    this.semanticsLabel,
    this.tooltip,
  }) : variant = UrutauButtonVariant.destructive;

  /// Creates a success button.
  const UrutauButton.success({
    super.key,
    required this.onPressed,
    required this.label,
    this.size = UrutauButtonSize.medium,
    this.icon,
    this.isLoading = false,
    this.isFullWidth = false,
    this.semanticsLabel,
    this.tooltip,
  }) : variant = UrutauButtonVariant.success;

  /// Creates a warning button.
  const UrutauButton.warning({
    super.key,
    required this.onPressed,
    required this.label,
    this.size = UrutauButtonSize.medium,
    this.icon,
    this.isLoading = false,
    this.isFullWidth = false,
    this.semanticsLabel,
    this.tooltip,
  }) : variant = UrutauButtonVariant.warning;

  /// Creates an info button.
  const UrutauButton.info({
    super.key,
    required this.onPressed,
    required this.label,
    this.size = UrutauButtonSize.medium,
    this.icon,
    this.isLoading = false,
    this.isFullWidth = false,
    this.semanticsLabel,
    this.tooltip,
  }) : variant = UrutauButtonVariant.info;

  final VoidCallback? onPressed;
  final String label;
  final UrutauButtonVariant variant;
  final UrutauButtonSize size;
  final Widget? icon;
  final bool isLoading;
  final bool isFullWidth;
  final String? semanticsLabel;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDisabled = onPressed == null || isLoading;

    final buttonStyle = _getButtonStyle(context, colorScheme, isDisabled);
    final labelStyle = _getLabelStyle(theme, colorScheme, isDisabled);
    final iconColor = _getIconColor(context, colorScheme, isDisabled);

    Widget child = Row(
      mainAxisSize: isFullWidth ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (isLoading)
          SizedBox(
            width: _getLoadingSize(size),
            height: _getLoadingSize(size),
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(iconColor),
            ),
          )
        else if (icon != null) ...[
          IconTheme(
            data: IconThemeData(color: iconColor, size: _getIconSize(size)),
            child: icon!,
          ),
          SizedBox(width: _getIconSpacing(size)),
        ],
        Text(label, style: labelStyle),
      ],
    );

    if (semanticsLabel != null) {
      child = Semantics(
        label: semanticsLabel,
        button: true,
        enabled: !isDisabled,
        child: child,
      );
    }

    final button = _buildButton(context, buttonStyle, child, isDisabled);

    if (tooltip != null) {
      return Tooltip(message: tooltip!, child: button);
    }

    return button;
  }

  Widget _buildButton(
    BuildContext context,
    ButtonStyle style,
    Widget child,
    bool isDisabled,
  ) {
    switch (variant) {
      case UrutauButtonVariant.primary:
      case UrutauButtonVariant.destructive:
      case UrutauButtonVariant.success:
      case UrutauButtonVariant.warning:
      case UrutauButtonVariant.info:
        return SizedBox(
          width: isFullWidth ? double.infinity : null,
          height: _getHeight(size),
          child: FilledButton(
            onPressed: isDisabled ? null : onPressed,
            style: style,
            child: child,
          ),
        );
      case UrutauButtonVariant.secondary:
        return SizedBox(
          width: isFullWidth ? double.infinity : null,
          height: _getHeight(size),
          child: FilledButton.tonal(
            onPressed: isDisabled ? null : onPressed,
            style: style,
            child: child,
          ),
        );
      case UrutauButtonVariant.outline:
        return SizedBox(
          width: isFullWidth ? double.infinity : null,
          height: _getHeight(size),
          child: OutlinedButton(
            onPressed: isDisabled ? null : onPressed,
            style: style,
            child: child,
          ),
        );
      case UrutauButtonVariant.text:
        return SizedBox(
          height: _getHeight(size),
          child: TextButton(
            onPressed: isDisabled ? null : onPressed,
            style: style,
            child: child,
          ),
        );
    }
  }

  ButtonStyle _getButtonStyle(
    BuildContext context,
    ColorScheme colorScheme,
    bool isDisabled,
  ) {
    final baseStyle = ButtonStyle(
      minimumSize: WidgetStateProperty.all(Size(_getMinWidth(size), _getHeight(size))),
      padding: WidgetStateProperty.all(_getPadding(size)),
      shape: WidgetStateProperty.all(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      textStyle: WidgetStateProperty.all(_getTextStyle(size)),
    );

    switch (variant) {
      case UrutauButtonVariant.primary:
        return baseStyle.copyWith(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return colorScheme.primary.withValues(alpha: 0.38);
            }
            return colorScheme.primary;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return colorScheme.onPrimary.withValues(alpha: 0.38);
            }
            return colorScheme.onPrimary;
          }),
        );
      case UrutauButtonVariant.destructive:
        return baseStyle.copyWith(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return colorScheme.error.withValues(alpha: 0.38);
            }
            return colorScheme.error;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return colorScheme.onError.withValues(alpha: 0.38);
            }
            return colorScheme.onError;
          }),
        );
      case UrutauButtonVariant.success:
        return baseStyle.copyWith(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            final successColor = colorScheme.tertiary;
            if (states.contains(WidgetState.disabled)) {
              return successColor.withValues(alpha: 0.38);
            }
            return successColor;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            final onSuccessColor = colorScheme.onTertiary;
            if (states.contains(WidgetState.disabled)) {
              return onSuccessColor.withValues(alpha: 0.38);
            }
            return onSuccessColor;
          }),
        );
      case UrutauButtonVariant.warning:
        return baseStyle.copyWith(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            final warningColor = colorScheme.secondary;
            if (states.contains(WidgetState.disabled)) {
              return warningColor.withValues(alpha: 0.38);
            }
            return warningColor;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            final onWarningColor = colorScheme.onSecondary;
            if (states.contains(WidgetState.disabled)) {
              return onWarningColor.withValues(alpha: 0.38);
            }
            return onWarningColor;
          }),
        );
      case UrutauButtonVariant.info:
        return baseStyle.copyWith(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            final infoColor = colorScheme.primary;
            if (states.contains(WidgetState.disabled)) {
              return infoColor.withValues(alpha: 0.38);
            }
            return infoColor;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            final onInfoColor = colorScheme.onPrimary;
            if (states.contains(WidgetState.disabled)) {
              return onInfoColor.withValues(alpha: 0.38);
            }
            return onInfoColor;
          }),
        );
      case UrutauButtonVariant.secondary:
        return baseStyle.copyWith(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return colorScheme.secondaryContainer.withValues(alpha: 0.38);
            }
            return colorScheme.secondaryContainer;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return colorScheme.onSecondaryContainer.withValues(alpha: 0.38);
            }
            return colorScheme.onSecondaryContainer;
          }),
        );
      case UrutauButtonVariant.outline:
        return baseStyle.copyWith(
          side: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return BorderSide(color: colorScheme.outline.withValues(alpha: 0.38));
            }
            return BorderSide(color: colorScheme.outline, width: 1.5);
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return colorScheme.outline.withValues(alpha: 0.38);
            }
            return colorScheme.primary;
          }),
        );
      case UrutauButtonVariant.text:
        return baseStyle.copyWith(
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return colorScheme.onSurface.withValues(alpha: 0.38);
            }
            return colorScheme.primary;
          }),
        );
    }
  }

  TextStyle _getLabelStyle(
    ThemeData theme,
    ColorScheme colorScheme,
    bool isDisabled,
  ) {
    Color color;
    switch (variant) {
      case UrutauButtonVariant.primary:
      case UrutauButtonVariant.destructive:
      case UrutauButtonVariant.success:
      case UrutauButtonVariant.warning:
      case UrutauButtonVariant.info:
        color = isDisabled ? colorScheme.onPrimary.withValues(alpha: 0.38) : colorScheme.onPrimary;
        break;
      case UrutauButtonVariant.secondary:
        color = isDisabled
            ? colorScheme.onSecondaryContainer.withValues(alpha: 0.38)
            : colorScheme.onSecondaryContainer;
        break;
      case UrutauButtonVariant.outline:
        color = isDisabled ? colorScheme.outline.withValues(alpha: 0.38) : colorScheme.primary;
        break;
      case UrutauButtonVariant.text:
        color = isDisabled ? colorScheme.onSurface.withValues(alpha: 0.38) : colorScheme.primary;
        break;
    }
    return _getTextStyle(size).copyWith(color: color);
  }

  Color _getIconColor(
    BuildContext context,
    ColorScheme colorScheme,
    bool isDisabled,
  ) {
    switch (variant) {
      case UrutauButtonVariant.primary:
      case UrutauButtonVariant.destructive:
      case UrutauButtonVariant.success:
      case UrutauButtonVariant.warning:
      case UrutauButtonVariant.info:
        return isDisabled ? colorScheme.onPrimary.withValues(alpha: 0.38) : colorScheme.onPrimary;
      case UrutauButtonVariant.secondary:
        return isDisabled
            ? colorScheme.onSecondaryContainer.withValues(alpha: 0.38)
            : colorScheme.onSecondaryContainer;
      case UrutauButtonVariant.outline:
      case UrutauButtonVariant.text:
        return isDisabled ? colorScheme.outline.withValues(alpha: 0.38) : colorScheme.primary;
    }
  }

  double _getHeight(UrutauButtonSize size) {
    switch (size) {
      case UrutauButtonSize.small:
        return 36;
      case UrutauButtonSize.medium:
        return 48;
      case UrutauButtonSize.large:
        return 56;
    }
  }

  double _getMinWidth(UrutauButtonSize size) {
    switch (size) {
      case UrutauButtonSize.small:
        return 64;
      case UrutauButtonSize.medium:
        return 88;
      case UrutauButtonSize.large:
        return 104;
    }
  }

  EdgeInsetsGeometry _getPadding(UrutauButtonSize size) {
    switch (size) {
      case UrutauButtonSize.small:
        return const EdgeInsets.symmetric(horizontal: 12, vertical: 8);
      case UrutauButtonSize.medium:
        return const EdgeInsets.symmetric(horizontal: 20, vertical: 12);
      case UrutauButtonSize.large:
        return const EdgeInsets.symmetric(horizontal: 24, vertical: 16);
    }
  }

  TextStyle _getTextStyle(UrutauButtonSize size) {
    switch (size) {
      case UrutauButtonSize.small:
        return const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 0.5);
      case UrutauButtonSize.medium:
        return const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: 0.3);
      case UrutauButtonSize.large:
        return const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, letterSpacing: 0.2);
    }
  }

  double _getIconSize(UrutauButtonSize size) {
    switch (size) {
      case UrutauButtonSize.small:
        return 16;
      case UrutauButtonSize.medium:
        return 18;
      case UrutauButtonSize.large:
        return 20;
    }
  }

  double _getLoadingSize(UrutauButtonSize size) {
    switch (size) {
      case UrutauButtonSize.small:
        return 16;
      case UrutauButtonSize.medium:
        return 20;
      case UrutauButtonSize.large:
        return 24;
    }
  }

  double _getIconSpacing(UrutauButtonSize size) {
    switch (size) {
      case UrutauButtonSize.small:
        return 6;
      case UrutauButtonSize.medium:
        return 8;
      case UrutauButtonSize.large:
        return 10;
    }
  }
}

enum UrutauButtonVariant {
  primary,
  secondary,
  outline,
  text,
  destructive,
  success,
  warning,
  info,
}

enum UrutauButtonSize {
  small,
  medium,
  large,
}