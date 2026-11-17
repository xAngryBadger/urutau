import 'package:flutter/material.dart';

import '../../data/database.dart';
import '../../theme/app_tokens.dart';
import 'planta_card.dart';

/// Lista de plantas em CASCATA (UX-APP-CAMPO): grupos por espécie com
/// contagem, abre/fecha com 1 toque, e busca rápida pelas espécies JÁ
/// preenchidas naquela parcela (chips com contagem).
///
/// Feito pra parcela com muitas plantas: 50 plantas viram 3–5 grupos em
/// vez de 50 cards de scroll. A última adicionada/recém-editada fica com
/// destaque e o grupo dela abre sozinho.
///
/// Não altera dado nenhum — é pura visualização; adicionar/editar/remover
/// continua com os callbacks de sempre.
class PlantasAgrupadas extends StatefulWidget {
  const PlantasAgrupadas({
    super.key,
    required this.plantas,
    required this.nomesPopulares,
    required this.onEditar,
    required this.onRemover,
    this.ultimaUuid,
    this.scrollController,
  });

  final List<Planta> plantas;
  final Map<String, String> nomesPopulares;
  final void Function(Planta)? onEditar;
  final void Function(Planta)? onRemover;

  /// UUID da planta recém-adicionada/editada (destaque + grupo aberto).
  final String? ultimaUuid;

  /// Para rolar até a última adicionada quando pedido.
  final ScrollController? scrollController;

  @override
  State<PlantasAgrupadas> createState() => _PlantasAgrupadasState();
}

class _PlantasAgrupadasState extends State<PlantasAgrupadas> {
  final Set<String> _abertos = {};
  String? _filtro; // null = todas

  List<_Grupo> get _grupos {
    final mapa = <String, List<Planta>>{};
    for (final p in widget.plantas) {
      mapa.putIfAbsent(p.especie.trim(), () => []).add(p);
    }
    final lista = mapa.entries
        .map((e) => _Grupo(especie: e.key, plantas: e.value))
        .toList()
      ..sort((a, b) => b.plantas.length.compareTo(a.plantas.length));
    return lista;
  }

  List<_Grupo> get _visiveis {
    final todos = _grupos;
    if (_filtro == null) return todos;
    return todos.where((g) => g.especie == _filtro).toList();
  }

  @override
  Widget build(BuildContext context) {
    // estado vazio: quem renderiza é o _emptyPlantas() da tela (mensagem
    // rica + ação). Aqua fica só a cascata quando existe planta.
    if (widget.plantas.isEmpty) return const SizedBox.shrink();

    final grupos = _visiveis;
    final nEspecies = _grupos.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // resumo enxuto: total + quantas espécies diferentes
        Text(
          '${widget.plantas.length} plantas · $nEspecies espécies',
          style: TextStyle(
            fontSize: AppTokens.fontCaption,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        if (nEspecies > 1) ...[
          const SizedBox(height: AppTokens.spaceS),
          // busca rápida: chips das espécies JÁ digitadas nesta parcela
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              ChoiceChip(
                label: Text('Todas (${widget.plantas.length})'),
                selected: _filtro == null,
                onSelected: (_) => setState(() => _filtro = null),
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              for (final g in _grupos)
                ChoiceChip(
                  label: Text('${g.especie} (${g.plantas.length})'),
                  selected: _filtro == g.especie,
                  onSelected: (_) =>
                      setState(() => _filtro = _filtro == g.especie ? null : g.especie),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
            ],
          ),
        ],
        const SizedBox(height: AppTokens.spaceM),
        for (final g in grupos) _GrupoWidget(
          grupo: g,
          aberto: _filtro == g.especie || _abertos.contains(g.especie),
          nomesPopulares: widget.nomesPopulares,
          ultimaUuid: _filtro == null ? widget.ultimaUuid : null,
          // índice GLOBAL por uuid (em campo a planta é "planta 37").
          indiceGlobal: {for (var i = 0; i < widget.plantas.length; i++)
            widget.plantas[i].uuid: i},
          onEditar: widget.onEditar,
          onRemover: widget.onRemover,
          onToggle: () => setState(() {
            if (_abertos.contains(g.especie)) {
              _abertos.remove(g.especie);
            } else {
              _abertos.add(g.especie);
            }
          }),
        ),
      ],
    );
  }
}

class _Grupo {
  _Grupo({required this.especie, required this.plantas});
  final String especie;
  final List<Planta> plantas;
}

class _GrupoWidget extends StatelessWidget {
  const _GrupoWidget({
    required this.grupo,
    required this.aberto,
    required this.nomesPopulares,
    required this.onToggle,
    this.onEditar,
    this.onRemover,
    this.ultimaUuid,
    this.indiceGlobal = const {},
  });

  final _Grupo grupo;
  final bool aberto;
  final Map<String, String> nomesPopulares;
  final VoidCallback onToggle;
  final void Function(Planta)? onEditar;
  final void Function(Planta)? onRemover;
  final String? ultimaUuid;
  final Map<String, int> indiceGlobal;

  @override
  Widget build(BuildContext context) {
    final popular = nomesPopulares[grupo.especie.trim().toLowerCase()];

    return Container(
      margin: const EdgeInsets.only(bottom: AppTokens.spaceS),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppTokens.radiusM),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(AppTokens.radiusM),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppTokens.spaceM, AppTokens.spaceM, AppTokens.spaceS, AppTokens.spaceM),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          grupo.especie,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: AppTokens.fontBody,
                          ),
                        ),
                      if (popular != null)
                        Text(
                          popular,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: AppTokens.fontCaption,
                            // onSurfaceVariant: >=4.5:1 sobre o card nos 3 temas
                            // (grey[600] dava ~2.4:1 nos escuros).
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
                  Text(
                    '${grupo.plantas.length}',
                    style: TextStyle(
                      fontSize: AppTokens.fontSmall,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurfaceVariant,
                    ),
                  ),
                  Icon(
                    aberto ? Icons.expand_less : Icons.expand_more,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
          if (aberto)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppTokens.spaceS, 0, AppTokens.spaceS, AppTokens.spaceS),
              child: Column(
                children: [
                  for (var i = 0; i < grupo.plantas.length; i++)
                    Builder(builder: (context) {
                      final planta = grupo.plantas[i];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: PlantaCard(
                          planta: planta,
                          indice: indiceGlobal[planta.uuid] ?? i,
                          nomePopular:
                              nomesPopulares[planta.especie.trim().toLowerCase()],
                          destaque: planta.uuid == ultimaUuid,
                          onEditar: onEditar == null ? null : () => onEditar!(planta),
                          onRemover: onRemover == null ? null : () => onRemover!(planta),
                        ),
                      );
                    }),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
