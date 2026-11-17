import 'package:flutter/material.dart';
import 'urutau_button.dart';

/// Urutau design system empty state with semantic variants.
class UrutauEmptyState extends StatelessWidget {
  const UrutauEmptyState({
    super.key,
    required this.variant,
    this.title,
    this.message,
    this.actionLabel,
    this.onActionPressed,
    this.icon,
    this.semanticsLabel,
  });

  /// Empty state for search results.
  const UrutauEmptyState.search({
    super.key,
    this.title,
    this.message,
    this.actionLabel,
    this.onActionPressed,
    this.semanticsLabel,
  }) : variant = UrutauEmptyStateVariant.search,
       icon = null;

  /// Empty state for no data.
  const UrutauEmptyState.noData({
    super.key,
    this.title,
    this.message,
    this.actionLabel,
    this.onActionPressed,
    this.semanticsLabel,
  }) : variant = UrutauEmptyStateVariant.noData,
       icon = null;

  /// Empty state for offline mode.
  const UrutauEmptyState.offline({
    super.key,
    this.title,
    this.message,
    this.actionLabel,
    this.onActionPressed,
    this.semanticsLabel,
  }) : variant = UrutauEmptyStateVariant.offline,
       icon = null;

  /// Empty state for errors.
  const UrutauEmptyState.error({
    super.key,
    this.title,
    this.message,
    this.actionLabel,
    this.onActionPressed,
    this.semanticsLabel,
  }) : variant = UrutauEmptyStateVariant.error,
       icon = null;

  /// Empty state for no permission.
  const UrutauEmptyState.noPermission({
    super.key,
    this.title,
    this.message,
    this.actionLabel,
    this.onActionPressed,
    this.semanticsLabel,
  }) : variant = UrutauEmptyStateVariant.noPermission,
       icon = null;

  /// Empty state for loading.
  const UrutauEmptyState.loading({
    super.key,
    this.title,
    this.message,
    this.semanticsLabel,
  }) : variant = UrutauEmptyStateVariant.loading,
       icon = null,
       actionLabel = null,
       onActionPressed = null;

  final UrutauEmptyStateVariant variant;
  final String? title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onActionPressed;
  final Widget? icon;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final (defaultTitle, defaultMessage, defaultIcon) = _getDefaults(colorScheme);
    final effectiveTitle = title ?? defaultTitle;
    final effectiveMessage = message ?? defaultMessage;
    final effectiveIcon = icon ?? defaultIcon;

    Widget content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconTheme(
          data: IconThemeData(
            color: colorScheme.onSurfaceVariant,
            size: 64,
          ),
          child: effectiveIcon,
        ),
        const SizedBox(height: 16),
        if (effectiveTitle != null) ...[
          Text(
            effectiveTitle,
            style: theme.textTheme.titleLarge?.copyWith(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
        ],
        if (effectiveMessage != null) ...[
          Text(
            effectiveMessage,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
        ],
        if (actionLabel != null && onActionPressed != null) ...[
          UrutauButton.primary(
            onPressed: onActionPressed,
            label: actionLabel!,
            size: UrutauButtonSize.medium,
          ),
        ],
      ],
    );

    if (semanticsLabel != null) {
      content = Semantics(
        label: semanticsLabel,
        child: content,
      );
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: content,
      ),
    );
  }

  (String?, String?, Widget) _getDefaults(ColorScheme colorScheme) {
    switch (variant) {
      case UrutauEmptyStateVariant.search:
        return (
          'Nenhum resultado',
          'Tente alterar os termos da busca.',
          const Icon(Icons.search_off, size: 64),
        );
      case UrutauEmptyStateVariant.noData:
        return (
          'Nenhum dado disponível',
          'Ainda não há informações para exibir.',
          const Icon(Icons.inbox_outlined, size: 64),
        );
      case UrutauEmptyStateVariant.offline:
        return (
          'Você está offline',
          'Verifique sua conexão e tente novamente.',
          const Icon(Icons.wifi_off, size: 64),
        );
      case UrutauEmptyStateVariant.error:
        return (
          'Ocorreu um erro',
          'Não foi possível carregar os dados.',
          const Icon(Icons.error_outline, size: 64),
        );
      case UrutauEmptyStateVariant.noPermission:
        return (
          'Acesso restrito',
          'Você não tem permissão para ver este conteúdo.',
          const Icon(Icons.lock_outline, size: 64),
        );
      case UrutauEmptyStateVariant.loading:
        return (
          'Carregando...',
          'Por favor, aguarde.',
          const CircularProgressIndicator(),
        );
    }
  }
}

/// Sliver version of UrutauEmptyState for use in CustomScrollView.
class UrutauSliverEmptyState extends StatelessWidget {
  const UrutauSliverEmptyState({
    super.key,
    required this.variant,
    this.title,
    this.message,
    this.actionLabel,
    this.onActionPressed,
    this.icon,
    this.semanticsLabel,
  });

  /// Empty state for search results.
  const UrutauSliverEmptyState.search({
    super.key,
    this.title,
    this.message,
    this.actionLabel,
    this.onActionPressed,
    this.semanticsLabel,
  }) : variant = UrutauEmptyStateVariant.search,
       icon = null;

  final UrutauEmptyStateVariant variant;
  final String? title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onActionPressed;
  final Widget? icon;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    return SliverFillRemaining(
      hasScrollBody: false,
      child: UrutauEmptyState(
        variant: variant,
        title: title,
        message: message,
        actionLabel: actionLabel,
        onActionPressed: onActionPressed,
        icon: icon,
        semanticsLabel: semanticsLabel,
      ),
    );
  }
}

enum UrutauEmptyStateVariant {
  search,
  noData,
  offline,
  error,
  noPermission,
  loading,
}