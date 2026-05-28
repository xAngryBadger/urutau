/// Um item da lista de espécies (nome popular e científico).
class EspecieItem {
  final String nomePopular;
  final String nomeCientifico;

  const EspecieItem({
    required this.nomePopular,
    required this.nomeCientifico,
  });

  /// Texto para exibir conforme o modo (popular vs científico).
  String display(bool useNomePopular) =>
      useNomePopular ? nomePopular : nomeCientifico;

  @override
  String toString() => nomePopular;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EspecieItem &&
          nomePopular == other.nomePopular &&
          nomeCientifico == other.nomeCientifico;

  @override
  int get hashCode => Object.hash(nomePopular, nomeCientifico);
}
