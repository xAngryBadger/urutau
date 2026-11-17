import 'package:flutter/material.dart';

/// Urutau design system filter chip with semantic variants.
class UrutauFilterChip extends StatelessWidget {
  const UrutauFilterChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onSelected,
    this.variant = UrutauFilterChipVariant.defaultChip,
    this.icon,
    this.semanticsLabel,
    this.tooltip,
    this.enabled = true,
  });

  /// Creates a default filter chip.
  const UrutauFilterChip.defaultChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onSelected,
    this.icon,
    this.semanticsLabel,
    this.tooltip,
    this.enabled = true,
  }) : variant = UrutauFilterChipVariant.defaultChip;

  /// Creates a primary filter chip.
  const UrutauFilterChip.primary({
    super.key,
    required this.label,
    required this.selected,
    required this.onSelected,
    this.icon,
    this.semanticsLabel,
    this.tooltip,
    this.enabled = true,
  }) : variant = UrutauFilterChipVariant.primary;

  /// Creates a success filter chip.
  const UrutauFilterChip.success({
    super.key,
    required this.label,
    required this.selected,
    required this.onSelected,
    this.icon,
    this.semanticsLabel,
    this.tooltip,
    this.enabled = true,
  }) : variant = UrutauFilterChipVariant.success;

  /// Creates a warning filter chip.
  const UrutauFilterChip.warning({
    super.key,
    required this.label,
    required this.selected,
    required this.onSelected,
    this.icon,
    this.semanticsLabel,
    this.tooltip,
    this.enabled = true,
  }) : variant = UrutauFilterChipVariant.warning;

  /// Creates a danger filter chip.
  const UrutauFilterChip.danger({
    super.key,
    required this.label,
    required this.selected,
    required this.onSelected,
    this.icon,
    this.semanticsLabel,
    this.tooltip,
    this.enabled = true,
  }) : variant = UrutauFilterChipVariant.danger;

  /// Creates an info filter chip.
  const UrutauFilterChip.info({
    super.key,
    required this.label,
    required this.selected,
    required this.onSelected,
    this.icon,
    this.semanticsLabel,
    this.tooltip,
    this.enabled = true,
  }) : variant = UrutauFilterChipVariant.info;

  /// Creates a neutral filter chip.
  const UrutauFilterChip.neutral({
    super.key,
    required this.label,
    required this.selected,
    required this.onSelected,
    this.icon,
    this.semanticsLabel,
    this.tooltip,
    this.enabled = true,
  }) : variant = UrutauFilterChipVariant.neutral;

  final String label;
  final bool selected;
  final ValueChanged<bool> onSelected;
  final UrutauFilterChipVariant variant;
  final Widget? icon;
  final String? semanticsLabel;
  final String? tooltip;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isEnabled = enabled && onSelected != null;

    final (bgColor, fgColor, borderColor) = _getColors(colorScheme, isEnabled);

    Widget chip = FilterChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            IconTheme(
              data: IconThemeData(
                color: selected ? fgColor : fgColor.withValues(alpha: 0.7),
                size: 16,
              ),
              child: icon!,
            ),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: TextStyle(
              color: selected ? fgColor : fgColor.withValues(alpha: 0.7),
              fontSize: 13,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ],
      ),
      selected: selected,
      onSelected: isEnabled ? onSelected : null,
      showCheckmark: false,
      backgroundColor: selected ? bgColor.withValues(alpha: 0.2) : colorScheme.surfaceContainerHighest,
      selectedColor: bgColor,
      side: BorderSide(
        color: selected ? borderColor : colorScheme.outline.withValues(alpha: 0.5),
        width: selected ? 1.5 : 1,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      labelPadding: EdgeInsets.zero,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
    );

    if (semanticsLabel != null) {
      chip = Semantics(
        label: semanticsLabel,
        button: true,
        selected: selected,
        enabled: isEnabled,
        child: chip,
      );
    }

    if (tooltip != null) {
      chip = Tooltip(message: tooltip!, child: chip);
    }

    return chip;
  }

  (Color, Color, Color) _getColors(ColorScheme colorScheme, bool isEnabled) {
    if (!isEnabled) {
      return (
        colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        colorScheme.onSurface.withValues(alpha: 0.38),
        colorScheme.outline.withValues(alpha: 0.38),
      );
    }

    switch (variant) {
      case UrutauFilterChipVariant.defaultChip:
        return (
          colorScheme.primaryContainer,
          colorScheme.onPrimaryContainer,
          colorScheme.primary,
        );
      case UrutauFilterChipVariant.primary:
        return (
          colorScheme.primaryContainer,
          colorScheme.onPrimaryContainer,
          colorScheme.primary,
        );
      case UrutauFilterChipVariant.success:
        return (
          colorScheme.tertiaryContainer,
          colorScheme.onTertiaryContainer,
          colorScheme.tertiary,
        );
      case UrutauFilterChipVariant.warning:
        return (
          colorScheme.secondaryContainer,
          colorScheme.onSecondaryContainer,
          colorScheme.secondary,
        );
      case UrutauFilterChipVariant.danger:
        return (
          colorScheme.errorContainer,
          colorScheme.onErrorContainer,
          colorScheme.error,
        );
      case UrutauFilterChipVariant.info:
        return (
          colorScheme.primaryContainer,
          colorScheme.onPrimaryContainer,
          colorScheme.primary,
        );
      case UrutauFilterChipVariant.neutral:
        return (
          colorScheme.surfaceContainerHighest,
          colorScheme.onSurfaceVariant,
          colorScheme.outline,
        );
    }
  }
}

/// Group of filter chips with single or multi-selection.
class UrutauFilterChipGroup extends StatefulWidget {
  const UrutauFilterChipGroup({
    super.key,
    required this.chips,
    this.selectionMode = UrutauFilterChipSelectionMode.single,
    this.initialSelection,
    this.onSelectionChanged,
    this.spacing = 8,
    this.runSpacing = 8,
    this.semanticsLabel,
  });

  final List<UrutauFilterChipData> chips;
  final UrutauFilterChipSelectionMode selectionMode;
  final Set<String>? initialSelection;
  final ValueChanged<Set<String>>? onSelectionChanged;
  final double spacing;
  final double runSpacing;
  final String? semanticsLabel;

  @override
  State<UrutauFilterChipGroup> createState() => _UrutauFilterChipGroupState();
}

class _UrutauFilterChipGroupState extends State<UrutauFilterChipGroup> {
  late Set<String> _selectedValues;

  @override
  void initState() {
    super.initState();
    _selectedValues = widget.initialSelection ?? <String>{};
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (widget.semanticsLabel != null) {
      return Semantics(
        label: widget.semanticsLabel,
        child: _buildChips(theme),
      );
    }

    return _buildChips(theme);
  }

  Widget _buildChips(ThemeData theme) {
    return Wrap(
      spacing: widget.spacing,
      runSpacing: widget.runSpacing,
      children: widget.chips.map((chipData) {
        final isSelected = _selectedValues.contains(chipData.value);
        return UrutauFilterChip(
          label: chipData.label,
          selected: isSelected,
          onSelected: (selected) {
            setState(() {
              if (widget.selectionMode == UrutauFilterChipSelectionMode.single) {
                _selectedValues.clear();
                if (selected) {
                  _selectedValues.add(chipData.value);
                }
              } else {
                if (selected) {
                  _selectedValues.add(chipData.value);
                } else {
                  _selectedValues.remove(chipData.value);
                }
              }
            });
            widget.onSelectionChanged?.call(_selectedValues);
          },
          variant: chipData.variant,
          icon: chipData.icon,
          semanticsLabel: chipData.semanticsLabel,
          tooltip: chipData.tooltip,
          enabled: chipData.enabled,
        );
      }).toList(),
    );
  }
}

class UrutauFilterChipData {
  const UrutauFilterChipData({
    required this.value,
    required this.label,
    this.variant = UrutauFilterChipVariant.defaultChip,
    this.icon,
    this.semanticsLabel,
    this.tooltip,
    this.enabled = true,
  });

  final String value;
  final String label;
  final UrutauFilterChipVariant variant;
  final Widget? icon;
  final String? semanticsLabel;
  final String? tooltip;
  final bool enabled;
}

enum UrutauFilterChipVariant {
  defaultChip,
  primary,
  success,
  warning,
  danger,
  info,
  neutral,
}

enum UrutauFilterChipSelectionMode {
  single,
  multiple,
}