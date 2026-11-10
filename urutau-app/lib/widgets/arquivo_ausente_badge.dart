import 'package:flutter/material.dart';

/// Badge que torna visível a marcação do Q2 (commit 43a165e).
/// Aparece SOBRE a foto quando o arquivo não está mais no disco — a linha e o
/// path continuam no banco como evidência; antes deste badge a marcação era
/// invisível para o usuário (S1, catálogo de evidência RC-01).
/// Requer que o pai da imagem seja um Stack.
class ArquivoAusenteBadge extends StatelessWidget {
  const ArquivoAusenteBadge({super.key});

  @override
  Widget build(BuildContext context) {
    // Cores do tema (antes laranja fixo + branco: vazava nos temas escuros).
    final cs = Theme.of(context).colorScheme;
    return Positioned(
      left: 4,
      top: 4,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: cs.tertiary,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.warning_amber_rounded, size: 12, color: cs.onTertiary),
            const SizedBox(width: 4),
            Text('arquivo ausente',
                style: TextStyle(color: cs.onTertiary, fontSize: 10)),
          ],
        ),
      ),
    );
  }
}
