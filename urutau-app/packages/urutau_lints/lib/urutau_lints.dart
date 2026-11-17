library urutau_lints;

import 'package:custom_lint_builder/custom_lint_builder.dart';
import 'src/no_raw_tokens.dart';

PluginBase createPlugin() => _UrutauLints();

class _UrutauLints extends PluginBase {
  @override
  List<LintRule> getLintRules(CustomLintConfigs configs) => [
        NoRawTokens(),
      ];
}