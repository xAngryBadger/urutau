import 'package:flutter/material.dart';

import '../../theme/app_tokens.dart';

/// Página de uma etapa do wizard (UX-APP-CAMPO): container rolável com o
/// padding padrão do app. Um passo por tela — dedo/uma mão, luva.
class WizardStepPage extends StatelessWidget {
  final List<Widget> children;

  const WizardStepPage({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(AppTokens.spaceL, AppTokens.spaceM,
          AppTokens.spaceL, AppTokens.spaceXl),
      children: children,
    );
  }
}
