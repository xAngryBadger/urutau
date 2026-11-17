import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

/// Badge padronizado do status de verificação (RG-02).
/// Cor + ícone + rótulo vêm dos tokens — não repetir em cada tela.
class StatusBadge extends StatelessWidget {
  final String status; // pendente | revisado | aprovado
  final bool compact;

  const StatusBadge({super.key, required this.status, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final cor = AppTokens.statusColor(status);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: cor, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(AppTokens.statusIcon(status), size: compact ? 13 : 15, color: cor),
          const SizedBox(width: 4),
          Text(
            AppTokens.statusLabel(status),
            style: TextStyle(
              color: cor,
              fontSize: compact ? 11 : 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
