import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

/// Lint rule that prohibits raw token usage outside of tokens/primitives directories.
///
/// This rule flags:
/// - `Colors.*` usage (e.g., Colors.red, Colors.blue)
/// - `Color(0x...)` constructor calls
/// - Direct `fontSize:` usage in TextStyle (should use typography tokens)
/// - Direct `BorderRadius.*` usage (should use radius tokens)
/// - Direct `EdgeInsets.*` usage (should use spacing tokens)
///
/// Allowed locations:
/// - Files under `lib/theme/` (tokens definitions)
/// - Files under `lib/widgets/primitives/` (primitives implementations)
/// - Test files
/// - Generated files (*.g.dart, *.freezed.dart)
class NoRawTokens extends LintRule {
  NoRawTokens()
      : super(
          code: const LintCode(
            name: 'no_raw_tokens',
            problemMessage:
                'Raw token usage detected. Use UrutauTokens/UrutauPrimitives instead of raw Colors/Color/fontSize/BorderRadius/EdgeInsets.',
            correctionMessage:
                'Replace with semantic tokens from UrutauTokens or UrutauPrimitives.',
            errorSeverity: ErrorSeverity.ERROR,
          ),
        );

  @override
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    // Skip generated files and test files
    final path = context.file.libraryElement?.source.uri.toString() ?? '';
    if (_isExcluded(path)) return;

    // Visit all nodes in the file
    final visitor = _NoRawTokensVisitor(reporter, context);
    context.file.unit.visitChildren(visitor);
  }

  bool _isExcluded(String path) {
    // Skip generated files
    if (path.contains('.g.dart') || path.contains('.freezed.dart')) return true;
    // Skip test files
    if (path.contains('/test/') || path.contains('_test.dart')) return true;
    // Skip build files
    if (path.contains('/build/')) return true;
    // Allow tokens and primitives directories
    if (path.contains('/lib/theme/') || path.contains('/lib/widgets/primitives/')) {
      return true;
    }
    return false;
  }
}

class _NoRawTokensVisitor extends SimpleAstVisitor<void> {
  final ErrorReporter _reporter;
  final CustomLintContext _context;

  _NoRawTokensVisitor(this._reporter, this._context);

  @override
  void visitPrefixedIdentifier(PrefixedIdentifier node) {
    // Check for Colors.* usage
    if (node.prefix.name == 'Colors') {
      _reportViolation(
        node,
        'Avoid using Colors.${node.identifier.name} directly. '
            'Use UrutauTokens.colors.semanticColorName instead.',
      );
    }
    super.visitPrefixedIdentifier(node);
  }

  @override
  void visitConstructorName(ConstructorName node) {
    // Check for Color(0x...) constructor calls
    if (node.type != null) {
      final typeName = node.type!.getDisplayString();
      if (typeName == 'Color') {
        // Check if it's a const Color(0x...) call
        final parent = node.parent;
        if (parent is InstanceCreationExpression) {
          _checkColorConstructor(parent);
        }
      }
    }
    super.visitConstructorName(node);
  }

  void _checkColorConstructor(InstanceCreationExpression node) {
    // Check if this is a const Color(0x...) call
    if (node.constructorName?.type?.getDisplayString() == 'Color') {
      final arguments = node.argumentList?.arguments;
      if (arguments != null && arguments.isNotEmpty) {
        final firstArg = arguments.first;
        // Check if it's a hex literal (0x...)
        if (firstArg is IntegerLiteral && _isHexColor(firstArg)) {
          _reportViolation(
            node,
            'Avoid using raw Color(0x...) values. '
                'Use UrutauTokens.colors.semanticColorName or UrutauColorTokens.light/dark/highContrast instead.',
          );
        }
      }
    }
  }

  bool _isHexColor(IntegerLiteral literal) {
    final text = literal.lexeme;
    // Check if it looks like a hex color (0xFF..., 0x..., etc.)
    return text.startsWith('0x') && text.length >= 6;
  }

  @override
  void visitNamedExpression(NamedExpression node) {
    // Check for fontSize: in TextStyle
    if (node.name.label.name == 'fontSize') {
      final parent = node.parent;
      // Check if we're inside a TextStyle constructor
      if (_isInsideTextStyle(parent)) {
        _reportViolation(
          node,
          'Avoid using raw fontSize values. '
              'Use UrutauTokens.typography.textStyleName or UrutauTypographyTokens instead.',
        );
      }
    }
    // Check for BorderRadius usage
    else if (node.name.label.name == 'borderRadius') {
      if (!_isAllowedBorderRadiusContext(node)) {
        _reportViolation(
          node,
          'Avoid using raw BorderRadius values. '
              'Use UrutauTokens.radius.radiusName or UrutauRadiusTokens instead.',
        );
      }
    }
    // Check for EdgeInsets usage
    else if (node.name.label.name == 'padding' ||
        node.name.label.name == 'margin' ||
        node.name.label.name == 'contentPadding') {
      if (!_isAllowedEdgeInsetsContext(node)) {
        _reportViolation(
          node,
          'Avoid using raw EdgeInsets values. '
              'Use UrutauTokens.spacing.spacingName or UrutauSpacingTokens instead.',
        );
      }
    }
    super.visitNamedExpression(node);
  }

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    // Check for BorderRadius.* constructor calls
    final constructorName = node.constructorName?.type?.getDisplayString();
    if (constructorName == 'BorderRadius' ||
        constructorName == 'BorderRadius.circular' ||
        constructorName == 'BorderRadius.only' ||
        constructorName == 'BorderRadius.horizontal' ||
        constructorName == 'BorderRadius.vertical' ||
        constructorName == 'BorderRadiusDirectional' ||
        constructorName == 'BorderRadiusDirectional.circular' ||
        constructorName == 'BorderRadiusDirectional.only') {
      if (!_isAllowedBorderRadiusContext(node)) {
        _reportViolation(
          node,
          'Avoid using raw BorderRadius constructors. '
              'Use UrutauTokens.radius.radiusName or UrutauRadiusTokens instead.',
        );
      }
    }
    // Check for EdgeInsets.* constructor calls
    else if (constructorName == 'EdgeInsets' ||
        constructorName == 'EdgeInsets.all' ||
        constructorName == 'EdgeInsets.symmetric' ||
        constructorName == 'EdgeInsets.only' ||
        constructorName == 'EdgeInsets.fromLTRB' ||
        constructorName == 'EdgeInsetsDirectional' ||
        constructorName == 'EdgeInsetsDirectional.all' ||
        constructorName == 'EdgeInsetsDirectional.symmetric' ||
        constructorName == 'EdgeInsetsDirectional.only' ||
        constructorName == 'EdgeInsetsDirectional.fromSTEB') {
      if (!_isAllowedEdgeInsetsContext(node)) {
        _reportViolation(
          node,
          'Avoid using raw EdgeInsets constructors. '
              'Use UrutauTokens.spacing.spacingName or UrutauSpacingTokens instead.',
        );
      }
    }
    // Check for TextStyle with fontSize
    else if (constructorName == 'TextStyle') {
      _checkTextStyle(node);
    }
    super.visitInstanceCreationExpression(node);
  }

  void _checkTextStyle(InstanceCreationExpression node) {
    final arguments = node.argumentList?.arguments ?? [];
    for (final arg in arguments) {
      if (arg is NamedExpression && arg.name.label.name == 'fontSize') {
        _reportViolation(
          arg,
          'Avoid using raw fontSize values in TextStyle. '
              'Use UrutauTokens.typography.textStyleName or UrutauTypographyTokens instead.',
        );
      }
    }
  }

  bool _isInsideTextStyle(AstNode? node) {
    var current = node;
    while (current != null) {
      if (current is InstanceCreationExpression) {
        final typeName = current.constructorName?.type?.getDisplayString();
        if (typeName == 'TextStyle') return true;
      }
      current = current.parent;
    }
    return false;
  }

  bool _isAllowedBorderRadiusContext(AstNode node) {
    // Allow in tokens and primitives - already handled by _isExcluded in the main rule
    // But also allow in specific widget build methods that are part of primitives
    return false;
  }

  bool _isAllowedEdgeInsetsContext(AstNode node) {
    // Allow in tokens and primitives - already handled by _isExcluded in the main rule
    return false;
  }

  void _reportViolation(AstNode node, String message) {
    _reporter.reportErrorForNode(
      LintCode(
        name: 'no_raw_tokens',
        problemMessage: message,
        correctionMessage:
            'Replace with semantic tokens from UrutauTokens or UrutauPrimitives.',
        errorSeverity: ErrorSeverity.ERROR,
      ),
      node,
    );
  }
}