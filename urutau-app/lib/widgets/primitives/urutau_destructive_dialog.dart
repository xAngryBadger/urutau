import 'package:flutter/material.dart';

/// Type-safe confirmation dialog for destructive actions.
class UrutauDestructiveDialog extends StatelessWidget {
  const UrutauDestructiveDialog({
    super.key,
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.onConfirmed,
    this.cancelLabel = 'Cancelar',
    this.onCancelled,
    this.icon,
    this.semanticsLabel,
  });

  final String title;
  final String message;
  final String confirmLabel;
  final VoidCallback onConfirmed;
  final String cancelLabel;
  final VoidCallback? onCancelled;
  final Widget? icon;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AlertDialog(
      title: Row(
        children: [
          IconTheme(
            data: IconThemeData(color: colorScheme.error, size: 28),
            child: icon ?? const Icon(Icons.warning_amber_rounded),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: theme.textTheme.titleLarge?.copyWith(
                color: colorScheme.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      content: Text(
        message,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
            onCancelled?.call();
          },
          child: Text(cancelLabel),
        ),
        FilledButton(
          onPressed: () {
            Navigator.of(context).pop();
            onConfirmed();
          },
          style: FilledButton.styleFrom(
            backgroundColor: colorScheme.error,
            foregroundColor: colorScheme.onError,
          ),
          child: Text(confirmLabel),
        ),
      ],
    );
  }
}

/// Type-safe confirmation dialog with configurable type.
class UrutauConfirmationDialog extends StatelessWidget {
  const UrutauConfirmationDialog({
    super.key,
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.onConfirmed,
    this.type = UrutauDialogType.warning,
    this.cancelLabel = 'Cancelar',
    this.onCancelled,
    this.icon,
    this.semanticsLabel,
  });

  final String title;
  final String message;
  final String confirmLabel;
  final VoidCallback onConfirmed;
  final UrutauDialogType type;
  final String cancelLabel;
  final VoidCallback? onCancelled;
  final Widget? icon;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final (iconColor, defaultIcon, buttonStyle) = _getDialogStyle(colorScheme);

    return AlertDialog(
      title: Row(
        children: [
          IconTheme(
            data: IconThemeData(color: iconColor, size: 28),
            child: icon ?? defaultIcon,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: theme.textTheme.titleLarge?.copyWith(
                color: iconColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      content: Text(
        message,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
            onCancelled?.call();
          },
          child: Text(cancelLabel),
        ),
        FilledButton(
          onPressed: () {
            Navigator.of(context).pop();
            onConfirmed();
          },
          style: buttonStyle,
          child: Text(confirmLabel),
        ),
      ],
    );
  }

  (Color, Widget, ButtonStyle) _getDialogStyle(ColorScheme colorScheme) {
    switch (type) {
      case UrutauDialogType.primary:
        return (
          colorScheme.primary,
          const Icon(Icons.info_outline),
          FilledButton.styleFrom(
            backgroundColor: colorScheme.primary,
            foregroundColor: colorScheme.onPrimary,
          ),
        );
      case UrutauDialogType.warning:
        return (
          colorScheme.secondary,
          const Icon(Icons.warning_amber_rounded),
          FilledButton.styleFrom(
            backgroundColor: colorScheme.secondary,
            foregroundColor: colorScheme.onSecondary,
          ),
        );
      case UrutauDialogType.destructive:
        return (
          colorScheme.error,
          const Icon(Icons.delete_forever),
          FilledButton.styleFrom(
            backgroundColor: colorScheme.error,
            foregroundColor: colorScheme.onError,
          ),
        );
    }
  }
}

enum UrutauDialogType {
  primary,
  warning,
  destructive,
}