import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

/// Título de seção padronizado (ícone + título em negrito) — substitui
/// o `_sectionTitle` local de cada tela.
class SectionTitle extends StatelessWidget {
  final String title;
  final IconData icon;

  const SectionTitle({super.key, required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.primary, size: 22),
        const SizedBox(width: AppTokens.spaceS),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
                fontSize: 18, fontWeight: FontWeight.bold),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

/// Card de seção: cabeçalho com chip de ícone colorido + título em negrito
/// + ações à direita, e corpo livre. Um padrão só para GPS, área, carbono,
/// verificação, fotos etc. — nada de Card solto com padding inventado.
class UrutauSectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget child;
  final Color? accent;
  final Color? background;
  final List<Widget>? headerTrailing;

  const UrutauSectionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.child,
    this.accent,
    this.background,
    this.headerTrailing,
  });

  @override
  Widget build(BuildContext context) {
    final cor = accent ?? Theme.of(context).colorScheme.primary;
    return Card(
      color: background,
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: cor.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(AppTokens.radiusS),
                  ),
                  child: Icon(icon, color: cor, size: 20),
                ),
                const SizedBox(width: AppTokens.spaceS),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                        fontSize: AppTokens.fontBody,
                        fontWeight: FontWeight.bold),
                  ),
                ),
                if (headerTrailing != null) ...headerTrailing!,
              ],
            ),
            const SizedBox(height: AppTokens.spaceS),
            child,
          ],
        ),
      ),
    );
  }
}
