import 'dart:io' as io;
import 'package:flutter/foundation.dart';
import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../data/database.dart';
import 'download_helper.dart' as download;

class ExportService {
  final AppDatabase _db;

  ExportService(this._db);

  /// Exporta parcelas (e suas plantas) para XLSX.
  ///
  /// Se [userId] == null e [isAdmin] == true, exporta TUDO.
  /// Caso contrário, exporta apenas as parcelas do usuário.
  ///
  /// Retorna `true` se deu certo.
  Future<bool> exportarParcelasXlsx({
    String? userId,
    bool isAdmin = false,
    String? nomeUsuario,
    String? propriedade,
    String? propUt,
  }) async {
    try {
      List<Parcela> parcelas;
      if (propriedade != null || propUt != null) {
        parcelas = await _db.getParcelasByHierarchy(
          userId: isAdmin ? null : userId,
          isAdmin: isAdmin,
          propriedade: propriedade,
          propUt: propUt,
        );
      } else {
        parcelas = await _db.getAllParcelas(
          userId: userId,
          isAdmin: isAdmin,
        );
      }

      if (parcelas.isEmpty) return false;

      // 2. Criar workbook
      final excel = Excel.createExcel();

      // Carregar nomes de usuários (para admin)
      Map<String, String> nomesUsuarios = {};
      if (isAdmin) {
        final usuarios = await _db.getAllUsuarios();
        for (var u in usuarios) {
          nomesUsuarios[u.uuid] = u.nome;
        }
      }

      // ────── ABA PARCELAS (principal, limpa) ──────
      final sheetParcelas = excel['Parcelas'];
      final headerParcelas = [
        'Propriedade',
        'UT / Talhão',
        'Nº Parcela',
        'Área (ha)',
        'Anotações',
        'Qtd Plantas',
      ];
      if (isAdmin) headerParcelas.insert(0, 'Usuário');

      sheetParcelas.appendRow(
        headerParcelas.map((h) => TextCellValue(h)).toList(),
      );

      for (int i = 0; i < headerParcelas.length; i++) {
        final cell = sheetParcelas
            .cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
        cell.cellStyle = CellStyle(
          bold: true,
          backgroundColorHex: ExcelColor.fromHexString('#304d36'),
          fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
        );
      }

      // ────── ABA PLANTAS (dados essenciais) ──────
      final sheetPlantas = excel['Plantas'];
      final headerPlantas = [
        'Propriedade',
        'UT / Talhão',
        'Nº Parcela',
        'Espécie',
        'Altura (cm)',
        'DAP (cm)',
        'Categoria',
      ];
      if (isAdmin) headerPlantas.insert(0, 'Usuário');

      sheetPlantas.appendRow(
        headerPlantas.map((h) => TextCellValue(h)).toList(),
      );

      for (int i = 0; i < headerPlantas.length; i++) {
        final cell = sheetPlantas
            .cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
        cell.cellStyle = CellStyle(
          bold: true,
          backgroundColorHex: ExcelColor.fromHexString('#304d36'),
          fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
        );
      }

      // ────── ABA INFO TÉCNICA (metadados: fotos, sync, data) ──────
      final sheetInfo = excel['Info técnica'];
      final headerInfo = [
        'Propriedade',
        'UT / Talhão',
        'Nº Parcela',
        'Qtd Fotos',
        'Sincronizada',
        'Criada em',
      ];
      if (isAdmin) headerInfo.insert(0, 'Usuário');
      sheetInfo.appendRow(headerInfo.map((h) => TextCellValue(h)).toList());
      for (int i = 0; i < headerInfo.length; i++) {
        final cell = sheetInfo
            .cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
        cell.cellStyle = CellStyle(
          bold: true,
          backgroundColorHex: ExcelColor.fromHexString('#304d36'),
          fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
        );
      }

      // 3. Popular planilhas
      final dateFmt = DateFormat('dd/MM/yyyy HH:mm');

      for (final parcela in parcelas) {
        final plantas = await _db.getPlantasByParcela(parcela.uuid);
        final fotos = await _db.getFotosByParcela(parcela.uuid);

        final rowParcela = <CellValue>[
          if (isAdmin)
            TextCellValue(nomesUsuarios[parcela.userId] ?? parcela.userId),
          TextCellValue(parcela.propriedade),
          TextCellValue(parcela.propUt),
          IntCellValue(parcela.idParcela),
          parcela.areaHa != null
              ? DoubleCellValue(parcela.areaHa!)
              : TextCellValue(''),
          TextCellValue(parcela.observacoes ?? ''),
          IntCellValue(plantas.length),
        ];
        sheetParcelas.appendRow(rowParcela);

        final rowInfo = <CellValue>[
          if (isAdmin)
            TextCellValue(nomesUsuarios[parcela.userId] ?? parcela.userId),
          TextCellValue(parcela.propriedade),
          TextCellValue(parcela.propUt),
          IntCellValue(parcela.idParcela),
          IntCellValue(fotos.length),
          TextCellValue(parcela.synced ? 'Sim' : 'Não'),
          TextCellValue(dateFmt.format(parcela.createdAt)),
        ];
        sheetInfo.appendRow(rowInfo);

        for (final planta in plantas) {
          final rowPlanta = <CellValue>[
            if (isAdmin)
              TextCellValue(nomesUsuarios[parcela.userId] ?? parcela.userId),
            TextCellValue(parcela.propriedade),
            TextCellValue(parcela.propUt),
            IntCellValue(parcela.idParcela),
            TextCellValue(planta.especie),
            DoubleCellValue(planta.alturaCm),
            planta.dapCm != null
                ? DoubleCellValue(planta.dapCm!)
                : TextCellValue('—'),
            IntCellValue(planta.categoria),
          ];
          sheetPlantas.appendRow(rowPlanta);
        }
      }

      // Remover aba padrão "Sheet1" se existir
      if (excel.sheets.containsKey('Sheet1')) {
        excel.delete('Sheet1');
      }

      // Larguras das colunas
      for (int i = 0; i < headerParcelas.length; i++) {
        sheetParcelas.setColumnWidth(i, 18);
      }
      for (int i = 0; i < headerPlantas.length; i++) {
        sheetPlantas.setColumnWidth(i, 16);
      }
      for (int i = 0; i < headerInfo.length; i++) {
        sheetInfo.setColumnWidth(i, 16);
      }

      // 4. Gerar bytes (encode() para n\u00e3o auto-baixar no web)
      final bytes = excel.encode();
      if (bytes == null || bytes.isEmpty) return false;

      // 5. Nome do arquivo
      final now = DateFormat('yyyy-MM-dd_HHmm').format(DateTime.now());
      final prefix = nomeUsuario != null
? 'urutau_${_sanitize(nomeUsuario)}'
      : 'urutau_completo';
    final fileName = '${prefix}_$now.xlsx';

      // 6. Entregar ao usuário
      if (kIsWeb) {
        download.downloadFileBytes(bytes.toList(), fileName);
      } else {
        await _saveAndShareMobile(bytes.toList(), fileName);
      }

      return true;
    } catch (e) {
      debugPrint('Erro ao exportar XLSX: $e');
      return false;
    }
  }

  /// Salva arquivo em temp e abre compartilhamento no mobile.
  Future<void> _saveAndShareMobile(List<int> bytes, String fileName) async {
    final dir = await getTemporaryDirectory();
    final filePath = p.join(dir.path, fileName);
    final file = io.File(filePath);
    await file.writeAsBytes(bytes);

    await Share.shareXFiles(
      [XFile(filePath)],
      subject: 'Monitoramento Florestal — Exportação',
    );
  }

  /// Remove caracteres especiais para nome de arquivo.
  String _sanitize(String name) {
    return name
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]'), '_')
        .replaceAll(RegExp(r'_+'), '_');
  }

  // ─────────────────────────────────────────
  //  Exportar fotos (parcela/UT do usuário)
  // ─────────────────────────────────────────

  /// Exporta fotos locais das parcelas para uma pasta e abre compartilhamento.
  /// Mesmos filtros que XLSX: [userId], [isAdmin], [propriedade], [propUt].
  /// Retorna (sucesso, mensagem).
  Future<(bool, String)> exportarFotosLocais({
    String? userId,
    bool isAdmin = false,
    String? propriedade,
    String? propUt,
  }) async {
    if (kIsWeb) {
      return (false, 'Exportar fotos não disponível na versão web.');
    }
    try {
      List<Parcela> parcelas;
      if (propriedade != null || propUt != null) {
        parcelas = await _db.getParcelasByHierarchy(
          userId: isAdmin ? null : userId,
          isAdmin: isAdmin,
          propriedade: propriedade,
          propUt: propUt,
        );
      } else {
        parcelas = await _db.getAllParcelas(
          userId: userId,
          isAdmin: isAdmin,
        );
      }
      if (parcelas.isEmpty) return (false, 'Nenhuma parcela com fotos para exportar.');

      final dir = await getTemporaryDirectory();
      final exportDir = io.Directory(
        p.join(dir.path, 'MonitoramentoFlorestal_Fotos_${DateTime.now().millisecondsSinceEpoch}'),
      );
      exportDir.createSync(recursive: true);

      final xFiles = <XFile>[];
      for (final parcela in parcelas) {
        final pastaName = _sanitize('${parcela.propUt}_P${parcela.idParcela.toString().padLeft(2, '0')}');
        final parcelaDir = io.Directory(p.join(exportDir.path, pastaName));
        parcelaDir.createSync(recursive: true);

        final fotos = await _db.getFotosByParcela(parcela.uuid);
        for (var i = 0; i < fotos.length; i++) {
          final path = fotos[i].compressedPath ?? fotos[i].filePath;
          final f = io.File(path);
          if (await f.exists()) {
            final ext = p.extension(path);
            final dest = io.File(p.join(parcelaDir.path, 'parcela_${i + 1}$ext'));
            await f.copy(dest.path);
            xFiles.add(XFile(dest.path));
          }
        }

        final plantas = await _db.getPlantasByParcela(parcela.uuid);
        for (var i = 0; i < plantas.length; i++) {
          final path = plantas[i].fotoEspeciePath;
          if (path != null) {
            final f = io.File(path);
            if (await f.exists()) {
              final ext = p.extension(path);
              final nomeEsp = _sanitize(plantas[i].especie);
              final short = nomeEsp.isEmpty ? 'especie' : (nomeEsp.length > 12 ? nomeEsp.substring(0, 12) : nomeEsp);
              final dest = io.File(p.join(parcelaDir.path, 'planta_${i + 1}_$short$ext'));
              await f.copy(dest.path);
              xFiles.add(XFile(dest.path));
            }
          }
        }
      }

      if (xFiles.isEmpty) {
        try { exportDir.deleteSync(recursive: true); } catch (_) {}
        return (false, 'Nenhuma foto encontrada nas parcelas selecionadas.');
      }

      await Share.shareXFiles(
        xFiles,
        subject: 'Fotos — Monitoramento Florestal',
        text: '${xFiles.length} foto(s) de ${parcelas.length} parcela(s).',
      );
      try { exportDir.deleteSync(recursive: true); } catch (_) {}
      return (true, '${xFiles.length} foto(s) partilhadas.');
    } catch (e) {
      debugPrint('Erro ao exportar fotos: $e');
      return (false, 'Erro ao exportar: $e');
    }
  }

  // ─────────────────────────────────────────
  //  PDF Export
  // ─────────────────────────────────────────

  /// Exporta parcelas (e suas plantas) para PDF e abre compartilhamento.
  /// Deprecado: preferir XLSX. Mantido para uso futuro se necessário.
  ///
  /// Se [userId] == null e [isAdmin] == true, exporta TUDO.
  Future<bool> exportarParcelasPdf({
    String? userId,
    bool isAdmin = false,
    String? nomeUsuario,
  }) async {
    try {
      final parcelas = await _db.getAllParcelas(
        userId: userId,
        isAdmin: isAdmin,
      );
      if (parcelas.isEmpty) return false;

      Map<String, String> nomesUsuarios = {};
      if (isAdmin) {
        final usuarios = await _db.getAllUsuarios();
        for (var u in usuarios) {
          nomesUsuarios[u.uuid] = u.nome;
        }
      }

      final dateFmt = DateFormat('dd/MM/yyyy HH:mm');
      final now = DateTime.now();
      final nowStr = DateFormat('dd/MM/yyyy HH:mm').format(now);

      // ── PDF theme colours ──
      const headerBg = PdfColor.fromInt(0xFF304d36);
      const headerFg = PdfColors.white;
      const rowAlternate = PdfColor.fromInt(0xFFe8f5e9);
      const text = PdfColors.black;

      final pdf = pw.Document();

      // ─── COVER PAGE ───
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (ctx) => pw.Center(
            child: pw.Column(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                pw.Container(
                  width: 80,
                  height: 80,
                  decoration: const pw.BoxDecoration(
                    color: headerBg,
                    shape: pw.BoxShape.circle,
                  ),
                  child: pw.Center(
                    child: pw.Text(
                      'IF',
                      style: pw.TextStyle(
                        fontSize: 32,
                        fontWeight: pw.FontWeight.bold,
                        color: headerFg,
                      ),
                    ),
                  ),
                ),
                pw.SizedBox(height: 24),
                pw.Text(
                  'Urutau',
                  style: pw.TextStyle(
                    fontSize: 28,
                    fontWeight: pw.FontWeight.bold,
                    color: headerBg,
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Text(
                  isAdmin
                      ? 'Relatório Completo — Todas as Parcelas'
                      : 'Relatório — ${nomeUsuario ?? 'Usuário'}',
                  style: const pw.TextStyle(
                    fontSize: 14,
                    color: PdfColors.grey700,
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Text(
                  'Gerado em $nowStr',
                  style: const pw.TextStyle(
                    fontSize: 11,
                    color: PdfColors.grey600,
                  ),
                ),
                pw.SizedBox(height: 32),
                pw.Container(
                  padding: const pw.EdgeInsets.all(16),
                  decoration: pw.BoxDecoration(
                    color: rowAlternate,
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Column(
                    children: [
                      _pdfStat(
                        'Total de Parcelas',
                        parcelas.length.toString(),
                        headerBg,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      // ─── PARCELAS SUMMARY PAGE(S) ───
      final parcelasColLabels = isAdmin
          ? ['Usuário', 'Prop/UT', 'Parcela', 'Plantas', 'Fotos', 'Sync', 'Criada em']
          : ['Prop/UT', 'Parcela', 'Plantas', 'Fotos', 'Sync', 'Criada em'];

      // Build rows
      final parcelasRows = <List<String>>[];
      final allPlantas = <Map<String, dynamic>>[];

      for (final parcela in parcelas) {
        final plantas = await _db.getPlantasByParcela(parcela.uuid);
        final fotos = await _db.getFotosByParcela(parcela.uuid);
        final nomeUser = nomesUsuarios[parcela.userId] ?? parcela.userId;

        final row = isAdmin
            ? [
                nomeUser,
                parcela.propUt.isEmpty ? '—' : parcela.propUt,
                parcela.idParcela.toString(),
                plantas.length.toString(),
                fotos.length.toString(),
                parcela.synced ? 'Sim' : 'Não',
                dateFmt.format(parcela.createdAt),
              ]
            : [
                parcela.propUt.isEmpty ? '—' : parcela.propUt,
                parcela.idParcela.toString(),
                plantas.length.toString(),
                fotos.length.toString(),
                parcela.synced ? 'Sim' : 'Não',
                dateFmt.format(parcela.createdAt),
              ];
        parcelasRows.add(row);

        for (final pl in plantas) {
          allPlantas.add({
            'user': nomeUser,
            'propUt': parcela.propUt.isEmpty ? '—' : parcela.propUt,
            'idParcela': parcela.idParcela.toString(),
            'especie': pl.especie,
            'altura': pl.alturaCm.toStringAsFixed(1),
            'dap': pl.dapCm != null ? pl.dapCm!.toStringAsFixed(1) : '—',
            'categoria': pl.categoria.toString(),
            'synced': pl.synced ? 'Sim' : 'Não',
          });
        }
      }

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          header: (_) => _pdfTableHeader('Parcelas', nowStr),
          footer: (ctx) => _pdfFooter(ctx),
          build: (ctx) => [
            _buildPdfTable(parcelasColLabels, parcelasRows,
                headerBg: headerBg,
                headerFg: headerFg,
                rowAlternate: rowAlternate,
                text: text),
          ],
        ),
      );

      // ─── PLANTAS DETAIL PAGE(S) ───
      final plantasColLabels = isAdmin
          ? ['Usuário', 'Prop/UT', 'Parcela', 'Espécie', 'Alt (cm)', 'DAP (cm)', 'Cat.', 'Sync']
          : ['Prop/UT', 'Parcela', 'Espécie', 'Alt (cm)', 'DAP (cm)', 'Cat.', 'Sync'];

      final plantasRows = allPlantas
          .map((p) => isAdmin
              ? [
                  p['user'] as String,
                  p['propUt'] as String,
                  p['idParcela'] as String,
                  p['especie'] as String,
                  p['altura'] as String,
                  p['dap'] as String,
                  p['categoria'] as String,
                  p['synced'] as String,
                ]
              : [
                  p['propUt'] as String,
                  p['idParcela'] as String,
                  p['especie'] as String,
                  p['altura'] as String,
                  p['dap'] as String,
                  p['categoria'] as String,
                  p['synced'] as String,
                ])
          .toList();

      if (plantasRows.isNotEmpty) {
        pdf.addPage(
          pw.MultiPage(
            pageFormat: PdfPageFormat.a4,
            header: (_) => _pdfTableHeader('Plantas', nowStr),
            footer: (ctx) => _pdfFooter(ctx),
            build: (ctx) => [
              _buildPdfTable(plantasColLabels, plantasRows,
                  headerBg: headerBg,
                  headerFg: headerFg,
                  rowAlternate: rowAlternate,
                  text: text),
            ],
          ),
        );
      }

      final pdfBytes = await pdf.save();
      final fileNameTs = DateFormat('yyyy-MM-dd_HHmm').format(now);
      final prefix = nomeUsuario != null
? 'urutau_${_sanitize(nomeUsuario)}'
      : 'urutau_completo';
    final fileName = '${prefix}_$fileNameTs.pdf';

      if (kIsWeb) {
        download.downloadFileBytes(pdfBytes.toList(), fileName);
      } else {
        final dir = await getTemporaryDirectory();
        final filePath = p.join(dir.path, fileName);
        final file = io.File(filePath);
        await file.writeAsBytes(pdfBytes);
        await Printing.sharePdf(bytes: pdfBytes, filename: fileName);
      }

      return true;
    } catch (e) {
      debugPrint('Erro ao exportar PDF: $e');
      return false;
    }
  }

  // ─── PDF helpers ───

  pw.Widget _pdfTableHeader(String section, String dateStr) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 8),
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: PdfColor.fromInt(0xFF304d36), width: 1.5)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'Urutau — $section',
            style: pw.TextStyle(
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
              color: const PdfColor.fromInt(0xFF304d36),
            ),
          ),
          pw.Text(
            dateStr,
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
          ),
        ],
      ),
    );
  }

  pw.Widget _pdfFooter(pw.Context ctx) {
    return pw.Container(
      alignment: pw.Alignment.centerRight,
      margin: const pw.EdgeInsets.only(top: 4),
      child: pw.Text(
        'Página ${ctx.pageNumber} de ${ctx.pagesCount}',
        style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
      ),
    );
  }

  pw.Widget _pdfStat(String label, String value, PdfColor color) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(label,
            style: pw.TextStyle(
                fontWeight: pw.FontWeight.bold, color: PdfColors.grey800)),
        pw.Text(value,
            style: pw.TextStyle(
                fontWeight: pw.FontWeight.bold, color: color, fontSize: 14)),
      ],
    );
  }

  pw.Widget _buildPdfTable(
    List<String> headers,
    List<List<String>> rows, {
    required PdfColor headerBg,
    required PdfColor headerFg,
    required PdfColor rowAlternate,
    required PdfColor text,
  }) {
    return pw.TableHelper.fromTextArray(
      headers: headers,
      data: rows,
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      headerStyle: pw.TextStyle(
        fontWeight: pw.FontWeight.bold,
        color: headerFg,
        fontSize: 9,
      ),
      headerDecoration: pw.BoxDecoration(color: headerBg),
      cellStyle: const pw.TextStyle(fontSize: 8),
      cellAlignments: {
        for (int i = 0; i < headers.length; i++) i: pw.Alignment.centerLeft,
      },
      rowDecoration: pw.BoxDecoration(color: PdfColors.white),
      oddRowDecoration: pw.BoxDecoration(color: rowAlternate),
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
    );
  }
}
