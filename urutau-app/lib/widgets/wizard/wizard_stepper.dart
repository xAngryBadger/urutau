import 'package:flutter/material.dart';

import '../../theme/app_tokens.dart';

/// Stepper do wizard de parcela (UX-APP-CAMPO): mostra "Etapa N de 4", o nome
/// da etapa atual e os 4 passos. Ordem = protocolo de campo: primeiro a
/// PROPRIEDADE/UT (Local), depois as FOTOS DA PARCELA (visão geral), depois
/// as PLANTAS com suas fotos de espécie, e por fim Revisar.
/// Etapas já visitadas/anteriores podem ser tocadas para voltar; etapas
/// seguintes só avançam pelas travas de validação (quem decide é a tela).
class WizardStepper extends StatelessWidget {
  final int etapaAtual; // 0-based
  final void Function(int etapa) onEtapaTap;

  static const List<String> etapas = ['Local', 'Fotos', 'Plantas', 'Revisar'];

  const WizardStepper({
    super.key,
    required this.etapaAtual,
    required this.onEtapaTap,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Container(
      color: Theme.of(context).colorScheme.surface,
      padding: const EdgeInsets.fromLTRB(
          AppTokens.spaceL, AppTokens.spaceM, AppTokens.spaceL, AppTokens.spaceS),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Etapa ${etapaAtual + 1} de ${etapas.length}',
                style: TextStyle(
                  fontSize: AppTokens.fontCaption,
                  fontWeight: FontWeight.bold,
                  color: primary,
                  letterSpacing: 0.6,
                ),
              ),
              const Spacer(),
              Flexible(
                child: Text(
                  etapas[etapaAtual],
                  style: const TextStyle(
                    fontSize: AppTokens.fontTitle,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTokens.spaceM),
          Row(
            children: [
              for (var i = 0; i < etapas.length; i++) ...[
                if (i > 0)
                  Expanded(
                    child: Container(
                      height: 2,
                      margin: const EdgeInsets.only(bottom: 22),
                      color: i <= etapaAtual
                          ? primary
                          : Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                _StepDot(
                  indice: i,
                  nome: etapas[i],
                  concluida: i < etapaAtual,
                  atual: i == etapaAtual,
                  onTap: () => onEtapaTap(i),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _StepDot extends StatelessWidget {
  final int indice;
  final String nome;
  final bool concluida;
  final bool atual;
  final VoidCallback onTap;

  const _StepDot({
    required this.indice,
    required this.nome,
    required this.concluida,
    required this.atual,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final primary = cs.primary;
    // Concluída e atual usam a cor primária do tema; pendente, onSurfaceVariant.
    final cor = concluida || atual ? primary : cs.onSurfaceVariant;
    return Semantics(
      label: 'Etapa ${indice + 1}: $nome',
      button: true,
      selected: atual,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTokens.radiusS),
        child: SizedBox(
          width: 64,
          child: Column(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: concluida || atual ? primary : Colors.transparent,
                  border: Border.all(
                    color: cor,
                    width: atual || concluida ? 0 : 2,
                  ),
                ),
                alignment: Alignment.center,
                child: concluida
                    ? Icon(Icons.check, size: 16, color: cs.onPrimary)
                    : Text(
                        '${indice + 1}',
                        style: TextStyle(
                          fontSize: AppTokens.fontSmall,
                          fontWeight: FontWeight.bold,
                          color: atual ? cs.onPrimary : cor,
                        ),
                      ),
              ),
              const SizedBox(height: AppTokens.spaceXs),
              Text(
                nome,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: AppTokens.fontCaption,
                  fontWeight: atual ? FontWeight.bold : FontWeight.normal,
                  color: atual ? primary : cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
