import 'package:flutter/material.dart';

import '../../data/categoria_helper.dart';
import '../../data/database.dart';
import '../../theme/app_tokens.dart';

/// Card de planta do wizard (UX-APP-CAMPO): nome científico em 1 linha sem
/// truncar (ellipsis só se muito longo — o nome completo fica no tooltip e no
/// Semantics), nome popular em cinza abaixo quando o catálogo o conhece,
/// DAP e Altura em chips compactos e categoria como chip pequeno COM rótulo.
/// Altura fixa para permitir itemExtent na lista (performance).
class PlantaCard extends StatelessWidget {
  final Planta planta;
  final int indice;
  final String? nomePopular;
  final VoidCallback? onEditar;
  final VoidCallback? onRemover;

  /// Destaque verde para a planta recém-adicionada/editada (cascata).
  final bool destaque;

  /// Altura fixa do card (usada como itemExtent na lista de plantas).
  static const double alturaCard = 112;

  const PlantaCard({
    super.key,
    required this.planta,
    required this.indice,
    this.nomePopular,
    this.onEditar,
    this.onRemover,
    this.destaque = false,
  });

  @override
  Widget build(BuildContext context) {
    final popular = nomePopular;

    return Semantics(
      label: 'Planta ${indice + 1}: ${planta.especie}${destaque ? ' (nova)' : ''}',
      child: Container(
        decoration: destaque
            ? BoxDecoration(
                borderRadius: BorderRadius.circular(AppTokens.radiusM),
                border: Border.all(color: AppTokens.mrvGreen, width: 1.5),
              )
            : null,
        child: Card(
          margin: EdgeInsets.zero,
          color: destaque ? AppTokens.mrvGreenBg : null,
        child: SizedBox(
          height: alturaCard,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(AppTokens.spaceM,
                AppTokens.spaceS, AppTokens.spaceXs, AppTokens.spaceS),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Nome científico: 1 linha, negrito; nome completo no
                      // tooltip (long press) e no Semantics.
                      Tooltip(
                        message: planta.especie,
                        child: Text(
                          '${indice + 1}. ${planta.especie}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: AppTokens.fontBody,
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      SizedBox(
                        height: 16,
                        child: popular != null
                            ? Text(
                                popular,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: AppTokens.fontSmall,
                                  color: Colors.grey[600],
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 6,
                        runSpacing: 2,
                        children: [
                          _MiniChip(
                            rotulo:
                                'Alt ${planta.alturaCm.toStringAsFixed(0)} cm',
                            cor: Colors.grey[700]!,
                          ),
                          if (planta.dapCm != null)
                            _MiniChip(
                              rotulo:
                                  'DAP ${planta.dapCm!.toStringAsFixed(1)} cm',
                              cor: Colors.grey[700]!,
                            ),
                          if (planta.fotoEspeciePath != null)
                            const _MiniChip(
                              rotulo: 'Foto',
                              cor: AppTokens.mrvGreen,
                              icone: Icons.photo_camera,
                            ),
                        ],
                      ),
                      // Categoria: informação de protocolo, não ação. Fica
                      // DISCRETA no rodapé do card (letra pequena, cinza,
                      // sem fundo) — a regra completa no tooltip/Semantics.
                      Tooltip(
                        message: descricaoCategoria(planta.categoria),
                        child: Text(
                          rotuloChipCategoria(planta.categoria),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: AppTokens.fontCaption,
                            color: Colors.grey[500],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (onEditar != null)
                      Semantics(
                        label: 'Editar planta',
                        button: true,
                        child: IconButton(
                          icon: const Icon(Icons.edit, size: 18),
                          onPressed: onEditar,
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    if (onRemover != null)
                      Semantics(
                        label: 'Remover planta',
                        button: true,
                        child: IconButton(
                          icon: Icon(Icons.delete,
                              size: 18, color: Colors.red[300]),
                          onPressed: onRemover,
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      ),
    );
  }
}

class _MiniChip extends StatelessWidget {
  final String rotulo;
  final Color cor;
  final String? tooltip;
  final IconData? icone;

  const _MiniChip({
    required this.rotulo,
    required this.cor,
    this.tooltip,
    this.icone,
  });

  @override
  Widget build(BuildContext context) {
    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: cor.withAlpha(28),
        border: Border.all(color: cor.withAlpha(90)),
        borderRadius: BorderRadius.circular(AppTokens.radiusS),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icone != null) ...[
            Icon(icone, size: 11, color: cor),
            const SizedBox(width: 3),
          ],
          Text(
            rotulo,
            style: TextStyle(
              fontSize: AppTokens.fontCaption,
              fontWeight: FontWeight.w600,
              color: cor,
            ),
          ),
        ],
      ),
    );
    if (tooltip == null) return chip;
    return Tooltip(message: tooltip, child: chip);
  }
}
