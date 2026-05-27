import 'package:flutter/services.dart';
import 'package:excel/excel.dart' as excel;
import '../data/especie_item.dart';
import '../data/categoria_helper.dart';

/// Carrega lista de espécies (nome popular + científico) e filtra com normalização
/// (ignorar acentos, maiúsculas, hífens tratados como espaço para busca).
///
/// Para usar a planilha de espécies: copie o ficheiro XLSX para
/// `assets/dados_especies.xlsx` e adicione ao `pubspec.yaml` em flutter.assets:
///   - assets/dados_especies.xlsx
/// A planilha deve ter colunas "Nome popular" e "Nome científico" (ou similar).
/// Se o ficheiro não existir, é usada a lista estática de espécies comuns.
class SpeciesService {
  static const String _assetPath = 'assets/dados_especies.xlsx';
  static List<EspecieItem>? _cache;

  /// Normaliza para busca: minúsculas, sem acentos, hífen vira espaço.
  static String normalize(String s) {
    const accents = 'àáâãäåèéêëìíîïòóôõöùúûüçñÀÁÂÃÄÅÈÉÊËÌÍÎÏÒÓÔÕÖÙÚÛÜÇÑ';
    const plain = 'aaaaaaeeeeiiiiooooouuuucnAAAAAAEEEEIIIIOOOOOUUUUCN';
    String t = s.trim().toLowerCase();
    for (int i = 0; i < accents.length; i++) {
      t = t.replaceAll(accents[i], plain[i]);
    }
    t = t.replaceAll('-', ' ');
    return t.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// Converte valor de célula Excel para string.
  static String _cellToString(dynamic cell) {
    if (cell == null) return '';
    if (cell is excel.TextCellValue) {
      final v = cell.value;
      return v.text ?? '';
    }
    if (cell is excel.IntCellValue) return cell.value.toString();
    if (cell is excel.DoubleCellValue) return cell.value.toString();
    return cell.toString();
  }

  /// Carrega espécies: primeiro do Excel em assets; se falhar, lista estática.
  static Future<List<EspecieItem>> loadSpecies() async {
    if (_cache != null) return _cache!;
    try {
      final data = await rootBundle.load(_assetPath);
      final bytes = data.buffer.asUint8List();
      final workbook = excel.Excel.decodeBytes(bytes);
      final list = <EspecieItem>[];
      for (final name in workbook.tables.keys) {
        final sheet = workbook.tables[name]!;
        if (sheet.rows.isEmpty) continue;
        final header = sheet.rows.first.map(_cellToString).toList();
        int idxPopular = -1, idxCientifico = -1;
        for (int i = 0; i < header.length; i++) {
          final h = header[i].toLowerCase().trim();
          if (h.contains('popular') && !h.contains('cient')) idxPopular = i;
          if (h.contains('cient') || h.contains('cientifico') || h == 'espécie') idxCientifico = i;
        }
        if (idxPopular < 0) idxPopular = 0;
        if (idxCientifico < 0) idxCientifico = idxPopular == 0 ? 1 : 0;
        for (int r = 1; r < sheet.rows.length; r++) {
          final row = sheet.rows[r];
          final popular = idxPopular < row.length ? _cellToString(row[idxPopular]).trim() : '';
          final cientifico = idxCientifico < row.length ? _cellToString(row[idxCientifico]).trim() : '';
          if (popular.isEmpty && cientifico.isEmpty) continue;
          list.add(EspecieItem(
            nomePopular: popular.isEmpty ? cientifico : popular,
            nomeCientifico: cientifico.isEmpty ? popular : cientifico,
          ));
        }
        break;
      }
      if (list.isNotEmpty) {
        _cache = list;
        return list;
      }
    } catch (_) {}
    _cache = _buildFallbackList();
    return _cache!;
  }

  static List<EspecieItem> _buildFallbackList() {
    const ni = EspecieItem(nomePopular: 'NI', nomeCientifico: 'NI');
    final items = [ni];
    for (final s in especiesComuns) {
      if (s == 'NI') continue;
      items.add(EspecieItem(nomePopular: s, nomeCientifico: s));
    }
    return items;
  }

  /// Filtra espécies: [query] normalizado; [useNomePopular] escolhe o campo a exibir.
  /// Busca em AMBOS os campos (popular E científico) independente do modo de exibição.
  /// Retorna itens cujo nome popular OU científico corresponde à query.
  static List<EspecieItem> filter(List<EspecieItem> list, String query, bool useNomePopular) {
    final q = normalize(query);
    if (q.isEmpty) return list;
    return list.where((e) {
      // Buscar em ambos os nomes
      final popular = normalize(e.nomePopular);
      final cientifico = normalize(e.nomeCientifico);
      
      // Verificar se começa com a query em qualquer um dos nomes
      if (popular.startsWith(q) || cientifico.startsWith(q)) return true;
      
      // Verificar palavras individuais em ambos os nomes
      final palavrasPopular = popular.split(' ');
      final palavrasCientifico = cientifico.split(' ');
      
      for (final w in [...palavrasPopular, ...palavrasCientifico]) {
        if (w.startsWith(q)) return true;
      }
      
      return false;
    }).toList();
  }

  /// Limpa cache (para recarregar após trocar o asset).
  static void clearCache() {
    _cache = null;
  }
}
