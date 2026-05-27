/// Calcula a categoria da planta com base em altura e DAP.
///
/// Regras:
/// - Altura < 50cm → Categoria 1 (DAP ignorado)
/// - Altura >= 50cm e DAP < 5cm → Categoria 2
/// - Altura >= 50cm e DAP >= 5cm → Categoria 3
int calcularCategoria(double alturaCm, double? dapCm) {
  if (alturaCm < 50) {
    return 1;
  } else {
    if (dapCm == null || dapCm < 5) {
      return 2;
    } else {
      return 3;
    }
  }
}

/// Retorna se o campo DAP é obrigatório.
bool dapObrigatorio(double alturaCm) => alturaCm >= 50;

/// Retorna se a foto da espécie é obrigatória.
bool fotoEspecieObrigatoria(String especie) =>
    especie.trim().toUpperCase() == 'NI';

/// Descrição textual da categoria.
String descricaoCategoria(int categoria) {
  switch (categoria) {
    case 1:
      return 'Cat. 1 — Altura < 50cm';
    case 2:
      return 'Cat. 2 — Altura ≥ 50cm, DAP < 5cm';
    case 3:
      return 'Cat. 3 — Altura ≥ 50cm, DAP ≥ 5cm';
    default:
      return 'Categoria desconhecida';
  }
}

/// Lista de espécies comuns para autocomplete.
/// "NI" = Não Identificada.
const List<String> especiesComuns = [
  'NI',
  'Eucalyptus grandis',
  'Eucalyptus urophylla',
  'Eucalyptus saligna',
  'Pinus elliottii',
  'Pinus taeda',
  'Tectona grandis',
  'Acacia mangium',
  'Araucaria angustifolia',
  'Cedrela fissilis',
  'Handroanthus albus',
  'Dalbergia nigra',
  'Swietenia macrophylla',
  'Corymbia citriodora',
  'Schizolobium parahyba',
];
