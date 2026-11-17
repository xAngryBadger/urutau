import 'package:flutter/material.dart';

/// Urutau design system form field with semantic colors and validation.
class UrutauField extends StatefulWidget {
  const UrutauField({
    super.key,
    this.controller,
    this.initialValue,
    this.label,
    this.hint,
    this.helperText,
    this.errorText,
    this.prefixIcon,
    this.suffixIcon,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.validator,
    this.onChanged,
    this.onSubmitted,
    this.enabled = true,
    this.readOnly = false,
    this.maxLines = 1,
    this.minLines,
    this.maxLength,
    this.autofillHints,
    this.semanticsLabel,
  });

  final TextEditingController? controller;
  final String? initialValue;
  final String? label;
  final String? hint;
  final String? helperText;
  final String? errorText;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool enabled;
  final bool readOnly;
  final int maxLines;
  final int? minLines;
  final int? maxLength;
  final Iterable<String>? autofillHints;
  final String? semanticsLabel;

  @override
  State<UrutauField> createState() => _UrutauFieldState();
}

class _UrutauFieldState extends State<UrutauField> {
  late TextEditingController _controller;
  final FocusNode _focusNode = FocusNode();
  bool _obscureText = false;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? TextEditingController(text: widget.initialValue);
    _obscureText = widget.obscureText;
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    if (widget.controller == null) {
      _controller.dispose();
    }
    super.dispose();
  }

  void _onFocusChange() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final hasError = widget.errorText != null;
    final isFocused = _focusNode.hasFocus;
    final isDisabled = !widget.enabled;

    final effectiveErrorText = hasError ? widget.errorText : null;
    final effectiveHelperText = widget.helperText;

    final fillColor = _getFillColor(colorScheme, isFocused, isDisabled, hasError);
    final borderColor = _getBorderColor(colorScheme, isFocused, isDisabled, hasError);

    return Semantics(
      label: widget.semanticsLabel ?? widget.label,
      textField: true,
      readOnly: widget.readOnly,
      enabled: widget.enabled,
      child: TextFormField(
        controller: _controller,
        focusNode: _focusNode,
        obscureText: _obscureText,
        keyboardType: widget.keyboardType,
        textInputAction: widget.textInputAction,
        validator: widget.validator,
        onChanged: widget.onChanged,
        onFieldSubmitted: widget.onSubmitted,
        enabled: widget.enabled,
        readOnly: widget.readOnly,
        maxLines: widget.maxLines,
        minLines: widget.minLines,
        maxLength: widget.maxLength,
        autofillHints: widget.autofillHints,
        decoration: InputDecoration(
          labelText: widget.label,
          hintText: widget.hint,
          helperText: effectiveHelperText,
          errorText: effectiveErrorText,
          prefixIcon: widget.prefixIcon != null
              ? IconTheme(
                  data: IconThemeData(
                    color: isDisabled
                        ? colorScheme.onSurface.withValues(alpha: 0.38)
                        : colorScheme.onSurfaceVariant,
                  ),
                  child: widget.prefixIcon!,
                )
              : null,
          suffixIcon: _buildSuffixIcon(colorScheme, isDisabled),
          filled: true,
          fillColor: fillColor,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: borderColor, width: 1.5),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: borderColor, width: 1.5),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: hasError ? colorScheme.error : colorScheme.primary,
              width: 2,
            ),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: colorScheme.error, width: 1.5),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: colorScheme.error, width: 2),
          ),
          disabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: colorScheme.outline.withValues(alpha: 0.38),
              width: 1.5,
            ),
          ),
          labelStyle: TextStyle(
            color: isFocused
                ? (hasError ? colorScheme.error : colorScheme.primary)
                : colorScheme.onSurfaceVariant,
            fontSize: 15,
          ),
          hintStyle: TextStyle(
            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
            fontSize: 15,
          ),
          helperStyle: TextStyle(
            color: colorScheme.onSurfaceVariant,
            fontSize: 12,
          ),
          errorStyle: TextStyle(
            color: colorScheme.error,
            fontSize: 12,
          ),
          counterStyle: TextStyle(
            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
            fontSize: 11,
          ),
        ),
      ),
    );
  }

  Widget? _buildSuffixIcon(ColorScheme colorScheme, bool isDisabled) {
    if (widget.obscureText) {
      return IconButton(
        icon: Icon(_obscureText ? Icons.visibility_off : Icons.visibility),
        color: isDisabled
            ? colorScheme.onSurface.withValues(alpha: 0.38)
            : colorScheme.onSurfaceVariant,
        onPressed: isDisabled ? null : () => setState(() => _obscureText = !_obscureText),
        tooltip: _obscureText ? 'Mostrar' : 'Ocultar',
      );
    }
    return widget.suffixIcon != null
        ? IconTheme(
            data: IconThemeData(
              color: isDisabled
                  ? colorScheme.onSurface.withValues(alpha: 0.38)
                  : colorScheme.onSurfaceVariant,
            ),
            child: widget.suffixIcon!,
          )
        : null;
  }

  Color _getFillColor(ColorScheme colorScheme, bool isFocused, bool isDisabled, bool hasError) {
    if (isDisabled) {
      return colorScheme.surfaceContainerHighest.withValues(alpha: 0.5);
    }
    return colorScheme.surfaceContainerHighest;
  }

  Color _getBorderColor(ColorScheme colorScheme, bool isFocused, bool isDisabled, bool hasError) {
    if (isDisabled) {
      return colorScheme.outline.withValues(alpha: 0.38);
    }
    if (hasError) {
      return colorScheme.error;
    }
    if (isFocused) {
      return colorScheme.primary;
    }
    return colorScheme.outline;
  }
}