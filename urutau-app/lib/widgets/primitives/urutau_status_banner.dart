import 'package:flutter/material.dart';

/// Urutau design system status banner with semantic types.
class UrutauStatusBanner extends StatelessWidget {
  const UrutauStatusBanner({
    super.key,
    required this.message,
    required this.type,
    this.title,
    this.actionLabel,
    this.onActionPressed,
    this.dismissible = false,
    this.onDismissed,
    this.compact = false,
    this.icon,
    this.semanticsLabel,
    this.syncState = SyncState.idle,
  });

  /// Creates a success status banner.
  const UrutauStatusBanner.success({
    super.key,
    required this.message,
    this.title,
    this.actionLabel,
    this.onActionPressed,
    this.dismissible = false,
    this.onDismissed,
    this.compact = false,
    this.semanticsLabel,
  }) : type = UrutauStatusType.success,
       icon = null,
       syncState = SyncState.idle;

  /// Creates a warning status banner.
  const UrutauStatusBanner.warning({
    super.key,
    required this.message,
    this.title,
    this.actionLabel,
    this.onActionPressed,
    this.dismissible = false,
    this.onDismissed,
    this.compact = false,
    this.semanticsLabel,
  }) : type = UrutauStatusType.warning,
       icon = null,
       syncState = SyncState.idle;

  /// Creates a danger/error status banner.
  const UrutauStatusBanner.danger({
    super.key,
    required this.message,
    this.title,
    this.actionLabel,
    this.onActionPressed,
    this.dismissible = false,
    this.onDismissed,
    this.compact = false,
    this.semanticsLabel,
  }) : type = UrutauStatusType.danger,
       icon = null,
       syncState = SyncState.idle;

  /// Creates an info status banner.
  const UrutauStatusBanner.info({
    super.key,
    required this.message,
    this.title,
    this.actionLabel,
    this.onActionPressed,
    this.dismissible = false,
    this.onDismissed,
    this.compact = false,
    this.semanticsLabel,
  }) : type = UrutauStatusType.info,
       icon = null,
       syncState = SyncState.idle;

  /// Creates a neutral status banner.
  const UrutauStatusBanner.neutral({
    super.key,
    required this.message,
    this.title,
    this.actionLabel,
    this.onActionPressed,
    this.dismissible = false,
    this.onDismissed,
    this.compact = false,
    this.semanticsLabel,
  }) : type = UrutauStatusType.neutral,
       icon = null,
       syncState = SyncState.idle;

  /// Creates a sync status banner.
  const UrutauStatusBanner.sync({
    super.key,
    required this.message,
    this.title,
    this.actionLabel,
    this.onActionPressed,
    this.dismissible = false,
    this.onDismissed,
    this.compact = false,
    this.semanticsLabel,
    this.syncState = SyncState.idle,
  }) : type = UrutauStatusType.sync,
       icon = null;

  final String message;
  final UrutauStatusType type;
  final String? title;
  final String? actionLabel;
  final VoidCallback? onActionPressed;
  final bool dismissible;
  final VoidCallback? onDismissed;
  final bool compact;
  final Widget? icon;
  final String? semanticsLabel;
  final SyncState syncState;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final (bgColor, fgColor, defaultIcon) = _getColorsAndIcon(colorScheme);
    final effectiveIcon = icon ?? defaultIcon;

    Widget banner = Container(
      padding: compact
          ? const EdgeInsets.symmetric(horizontal: 12, vertical: 8)
          : const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: fgColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!compact) ...[
            IconTheme(
              data: IconThemeData(color: fgColor, size: 20),
              child: effectiveIcon,
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (title != null) ...[
                  Text(
                    title!,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: fgColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                ],
                Text(
                  message,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: fgColor.withValues(alpha: 0.9),
                  ),
                ),
                if (actionLabel != null && onActionPressed != null) ...[
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: onActionPressed,
                    style: TextButton.styleFrom(
                      foregroundColor: fgColor,
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 32),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      actionLabel!,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: compact ? 12 : 14,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (dismissible)
            IconButton(
              icon: Icon(Icons.close, color: fgColor, size: 20),
              onPressed: onDismissed,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              tooltip: 'Dispensar',
            ),
        ],
      ),
    );

    if (type == UrutauStatusType.sync) {
      banner = _buildSyncBanner(context, banner, colorScheme);
    }

    if (semanticsLabel != null) {
      banner = Semantics(
        label: semanticsLabel,
        liveRegion: true,
        child: banner,
      );
    }

    return banner;
  }

  Widget _buildSyncBanner(
    BuildContext context,
    Widget child,
    ColorScheme colorScheme,
  ) {
    final isSyncing = syncState == SyncState.syncing;
    final hasError = syncState == SyncState.error;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        child,
        if (isSyncing || hasError) ...[
          const SizedBox(height: 8),
          LinearProgressIndicator(
            color: hasError ? colorScheme.error : colorScheme.primary,
            backgroundColor: colorScheme.surfaceContainerHighest,
            minHeight: 4,
          ),
        ],
      ],
    );
  }

  (Color, Color, Widget) _getColorsAndIcon(ColorScheme colorScheme) {
    switch (type) {
      case UrutauStatusType.success:
        return (
          colorScheme.tertiaryContainer,
          colorScheme.onTertiaryContainer,
          const Icon(Icons.check_circle, size: 24),
        );
      case UrutauStatusType.warning:
        return (
          colorScheme.secondaryContainer,
          colorScheme.onSecondaryContainer,
          const Icon(Icons.warning_amber_rounded, size: 24),
        );
      case UrutauStatusType.danger:
        return (
          colorScheme.errorContainer,
          colorScheme.onErrorContainer,
          const Icon(Icons.error_outline, size: 24),
        );
      case UrutauStatusType.info:
        return (
          colorScheme.primaryContainer,
          colorScheme.onPrimaryContainer,
          const Icon(Icons.info_outline, size: 24),
        );
      case UrutauStatusType.neutral:
        return (
          colorScheme.surfaceContainerHighest,
          colorScheme.onSurfaceVariant,
          const Icon(Icons.remove_circle_outline, size: 24),
        );
      case UrutauStatusType.sync:
        return (
          colorScheme.primaryContainer,
          colorScheme.onPrimaryContainer,
          const Icon(Icons.sync, size: 24),
        );
    }
  }
}

enum UrutauStatusType {
  success,
  warning,
  danger,
  info,
  neutral,
  sync,
}

enum SyncState {
  idle,
  syncing,
  success,
  error,
}