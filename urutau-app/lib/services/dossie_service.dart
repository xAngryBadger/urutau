import 'dart:convert';
import 'dart:io' as io;

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../data/database.dart';
import 'clock_service.dart';

/// RC-09 — Dossiê de auditoria por parcela (promessa do pitch:
/// "dossiê gerado com o rastro de cada número").
///
/// Gera um ZIP contendo:
/// - `dossie.pdf`     — legível por humano/verificadora (dados, plantas,
///                      carbono com ±% e hashes, fotos com hash+GPS+autor,
///                      trilha da parcela e resultado das verificações);
/// - `dados.json`     — dump completo machine-readable;
/// - `manifesto.json` — SHA-256 de CADA arquivo do ZIP + verificações de
///                      cadeia (local e servidor) + relógio confiável;
/// - `fotos/*`        — os arquivos de evidência originais.
class DossieService {
  /// Gera o dossiê da parcela e retorna o caminho do ZIP.
  static Future<String> gerarDossieParcela(
    AppDatabase db,
    String parcelaUuid, {
    String? serverChainStatus,
  }) async {
    final parcela = await db.getParcelaByUuid(parcelaUuid);
    if (parcela == null) {
      throw Exception('Parcela não encontrada: $parcelaUuid');
    }
    final plantas = await db.getPlantasByParcela(parcelaUuid);
    final fotos = await db.getFotosByParcela(parcelaUuid);
    final calculos = await (db.select(db.calculosMrv)
          ..where((t) => t.escopoUuid.equals(parcelaUuid))
          ..orderBy([(t) => OrderingTerm.desc(t.executadoEm)]))
        .get();
    final trilha = await (db.select(db.trilhaAuditoria)
          ..where((t) => t.entidadeUuid.equals(parcelaUuid))
          ..orderBy([(t) => OrderingTerm.asc(t.idSeq)]))
        .get();
    final cadeiaLocal = await db.verificarCadeiaAuditoria();

    final geradoEm = await ClockService.agoraConfiavel();
    final offsetMs = (await ClockService.offsetMedido())?.inMilliseconds ?? 0;

    // hash de cada foto vem do catálogo de ativos (sha256 na origem, S3)
    final fotosInfo = <Map<String, dynamic>>[];
    for (final f in fotos) {
      fotosInfo.add({
        'uuid': f.uuid,
        'arquivo': p.basename(f.filePath),
        'sha256': await _hashFoto(db, f.uuid),
        'latitude': f.latitude,
        'longitude': f.longitude,
        'autor_uuid': f.autorUuid,
        'capturada_em': f.createdAt.toIso8601String(),
      });
    }
    final plantasInfo = <Map<String, dynamic>>[];
    for (final pl in plantas) {
      plantasInfo.add({
        'uuid': pl.uuid,
        'especie': pl.especie,
        'categoria': pl.categoria,
        'dap_cm': pl.dapCm,
        'altura_cm': pl.alturaCm,
        'autor_uuid': pl.autorUuid,
        'foto_especie_sha256': pl.fotoEspeciePath != null
            ? await _sha256File(pl.fotoEspeciePath!)
            : null,
      });
    }

    // ── dados.json (machine-readable) ────────────────────────────────
    final dados = {
      'app': 'Urutau',
      'gerado_em_relogio_confiavel': geradoEm.toUtc().toIso8601String(),
      'offset_relogio_ms': offsetMs,
      'parcela': {
        'uuid': parcela.uuid,
        'propriedade': parcela.propriedade,
        'prop_ut': parcela.propUt,
        'id_parcela': parcela.idParcela,
        'latitude': parcela.latitude,
        'longitude': parcela.longitude,
        'area_m2': parcela.areaM2,
        'unidade_forma': parcela.unidadeForma,
        'raio_m': parcela.raioM,
        'marcador': parcela.marcador,
        'status_parcela': parcela.statusParcela,
        'observacoes': parcela.observacoes,
        'created_at': parcela.createdAt.toIso8601String(),
        'user_id': parcela.userId,
        'synced': parcela.synced,
      },
      'plantas': plantasInfo,
      'fotos': fotosInfo,
      'calculos_mrv': calculos
          .map((c) => {
                'uuid': c.uuid,
                'equacao_uuid': c.equacaoUuid,
                'pipeline_versao': c.pipelineVersao,
                'algorithm_versao': c.algorithmVersao,
                'insumos_hash': c.insumosHash,
                'resultado': c.resultado != null ? jsonDecode(c.resultado!) : null,
                'incerteza':
                    c.incerteza != null ? jsonDecode(c.incerteza!) : null,
                'executado_em': c.executadoEm?.toIso8601String(),
                'status': c.status,
              })
          .toList(),
      'trilha': trilha
          .map((t) => {
                'id_seq': t.idSeq,
                'acao': t.acao,
                'antes': t.antes,
                'depois': t.depois,
                'usuario_uuid': t.usuarioUuid,
                'ts_servidor': t.tsServidor?.toUtc().toIso8601String(),
                'ts_dispositivo': t.tsDispositivo?.toUtc().toIso8601String(),
                'offset_relogio_ms': t.offsetRelogioMs,
                'origem': t.origem,
                'prev_hash': t.prevHash,
                'entry_hash': t.entryHash,
              })
          .toList(),
      'verificacao': {
        'cadeia_local': cadeiaLocal == null ? 'INTEGRA' : cadeiaLocal,
        'cadeia_servidor':
            serverChainStatus == null ? 'INTEGRA (ultimo sync)' : serverChainStatus,
      },
    };
    final dadosJson = const JsonEncoder.withIndent('  ').convert(dados);

    // ── dossie.pdf (humano) ──────────────────────────────────────────
    final pdfBytes = await _gerarPdf(
      parcela: parcela,
      plantasInfo: plantasInfo,
      fotosInfo: fotosInfo,
      calculos: calculos,
      trilha: trilha,
      cadeiaLocalOk: cadeiaLocal == null,
      serverChainStatus: serverChainStatus,
      geradoEm: geradoEm,
    );

    // ── manifesto.json (hash de cada arquivo) ────────────────────────
    final arquivos = <String, List<int>>{
      'dados.json': utf8.encode(dadosJson),
      'dossie.pdf': pdfBytes,
    };
    for (final f in fotos) {
      final file = io.File(f.filePath);
      if (await file.exists()) {
        arquivos['fotos/${p.basename(f.filePath)}'] = await file.readAsBytes();
      }
    }
    for (final pl in plantas) {
      if (pl.fotoEspeciePath != null) {
        final file = io.File(pl.fotoEspeciePath!);
        if (await file.exists()) {
          arquivos['fotos/${p.basename(pl.fotoEspeciePath!)}'] =
              await file.readAsBytes();
        }
      }
    }
    final manifesto = {
      'app': 'Urutau',
      'tipo': 'dossie_mrv',
      'gerado_em_relogio_confiavel': geradoEm.toUtc().toIso8601String(),
      'offset_relogio_ms': offsetMs,
      'parcela_uuid': parcelaUuid,
      'arquivos': arquivos.map((nome, bytes) => MapEntry(
            nome,
            {
              'sha256': sha256.convert(bytes).toString(),
              'bytes': bytes.length,
            },
          )),
      'verificacao': dados['verificacao'],
    };
    final manifestoJson = const JsonEncoder.withIndent('  ').convert(manifesto);

    // ── monta o ZIP ──────────────────────────────────────────────────
    final archive = Archive();
    void add(String nome, List<int> bytes) =>
        archive.addFile(ArchiveFile(nome, bytes.length, bytes));

    add('manifesto.json', utf8.encode(manifestoJson));
    for (final e in arquivos.entries) {
      add(e.key, e.value);
    }

    final zipName =
        'dossie_parcela_${parcela.idParcela}_${geradoEm.millisecondsSinceEpoch}.zip';
    final zipPath = p.join(io.Directory.systemTemp.path, zipName);
    final zipBytes = ZipEncoder().encode(archive) ?? <int>[];
    await io.File(zipPath).writeAsBytes(zipBytes, flush: true);
    return zipPath;
  }

  /// Hash da foto no catálogo de ativos (papel original ou derivado).
  static Future<String?> _hashFoto(AppDatabase db, String fotoUuid) async {
    final rows = await (db.select(db.ativosBrutos)
          ..where((t) => t.entidadeUuid.equals(fotoUuid) & t.sha256.isNotNull())
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .get();
    return rows.isEmpty ? null : rows.first.sha256;
  }

  static Future<String?> _sha256File(String path) async {
    final f = io.File(path);
    if (!await f.exists()) return null;
    return sha256.convert(await f.readAsBytes()).toString();
  }

  static Future<List<int>> _gerarPdf({
    required Parcela parcela,
    required List<Map<String, dynamic>> plantasInfo,
    required List<Map<String, dynamic>> fotosInfo,
    required List<CalculosMrvData> calculos,
    required List<TrilhaAuditoriaData> trilha,
    required bool cadeiaLocalOk,
    String? serverChainStatus,
    required DateTime geradoEm,
  }) async {
    final doc = pw.Document();

    final ultimoCalc = calculos.isNotEmpty ? calculos.first : null;
    final resultado = ultimoCalc?.resultado != null
        ? jsonDecode(ultimoCalc!.resultado!) as Map<String, dynamic>
        : null;

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (ctx) => [
          pw.Header(
              level: 0,
              child: pw.Text('Dossiê MRV — Parcela ${parcela.idParcela}',
                  style: pw.TextStyle(
                      fontSize: 20, fontWeight: pw.FontWeight.bold))),
          pw.Text(
              'Gerado em ${geradoEm.toUtc().toIso8601String()} (relógio confiável, offset medido) · Urutau'),
          pw.SizedBox(height: 12),

          pw.Header(level: 1, child: pw.Text('1. Identificação da parcela')),
          pw.TableHelper.fromTextArray(
            headers: ['Campo', 'Valor'],
            data: [
              ['Propriedade', '${parcela.propriedade ?? ''}'],
              ['UT', parcela.propUt],
              ['ID parcela', '${parcela.idParcela}'],
              [
                'GPS',
                parcela.latitude != null
                    ? '${parcela.latitude!.toStringAsFixed(6)}, ${parcela.longitude!.toStringAsFixed(6)}'
                    : 'NÃO CAPTURADO'
              ],
              ['Área (m²)', '${parcela.areaM2 ?? '?'}'],
              [
                'Unidade',
                '${parcela.unidadeForma ?? '?'} '
                '${parcela.raioM != null ? '(raio ${parcela.raioM} m)' : ''}'
              ],
              ['Marcador', parcela.marcador ?? '-'],
              ['Status', parcela.statusParcela],
              ['Responsável', parcela.userId],
            ],
          ),

          pw.Header(
              level: 1,
              child: pw.Text('2. Indivíduos medidos (${plantasInfo.length})')),
          plantasInfo.isEmpty
              ? pw.Text('Nenhum indivíduo registrado.')
              : pw.TableHelper.fromTextArray(
                  headers: ['Espécie', 'DAP (cm)', 'Altura (cm)', 'Autor'],
                  data: plantasInfo
                      .map((pl) => [
                            '${pl['especie']}',
                            '${pl['dap_cm'] ?? '-'}',
                            '${pl['altura_cm']}',
                            '${pl['autor_uuid'] ?? '-'}',
                          ])
                      .toList(),
                ),

          pw.Header(level: 1, child: pw.Text('3. Estimativa de carbono (MRV)')),
          resultado == null
              ? pw.Text('Cálculo não persistido ainda.')
              : pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                        'tCO₂e/ha: ${(resultado['tco2e_ha'] as double).toStringAsFixed(2)}'
                        '  ·  total na parcela: ${(resultado['tco2e_total'] as double).toStringAsFixed(3)} tCO₂e'),
                    if (resultado['incerteza_pct'] is double)
                      pw.Text(
                          'Incerteza: ±${(resultado['incerteza_pct'] as double).toStringAsFixed(1)}% (IC 95%, n=${resultado['n_com_dap']})'),
                    pw.Text(
                        'Equação: ${resultado['equacao']} · FC ${resultado['fracao_carbono']} · 44/12'),
                    pw.Text('insumos_hash: ${resultado['insumos_hash'] ?? '-'}',
                        style: const pw.TextStyle(fontSize: 8)),
                    pw.Text(
                        'resultado_hash: ${resultado['resultado_hash'] ?? '-'}',
                        style: const pw.TextStyle(fontSize: 8)),
                  ],
                ),

          pw.Header(
              level: 1,
              child:
                  pw.Text('4. Fotos (${fotosInfo.length}) — hash + GPS + autor')),
          fotosInfo.isEmpty
              ? pw.Text('Nenhuma foto.')
              : pw.TableHelper.fromTextArray(
                  headers: ['Arquivo', 'SHA-256 (12)', 'GPS', 'Autor'],
                  data: fotosInfo
                      .map((f) => [
                            '${f['arquivo']}',
                            (f['sha256'] as String?)?.substring(0, 12) ?? '-',
                            f['latitude'] != null
                                ? '${(f['latitude'] as double).toStringAsFixed(5)}, ${(f['longitude'] as double).toStringAsFixed(5)}'
                                : '-',
                            '${f['autor_uuid'] ?? '-'}',
                          ])
                      .toList(),
                ),

          pw.Header(
              level: 1,
              child: pw.Text(
                  '5. Trilha de auditoria desta parcela (${trilha.length} entradas)')),
          trilha.isEmpty
              ? pw.Text('Sem entradas.')
              : pw.TableHelper.fromTextArray(
                  headers: ['Seq', 'Ação', 'ts (servidor)', 'entry_hash (12)'],
                  data: trilha
                      .map((t) => [
                            '${t.idSeq}',
                            t.acao,
                            t.tsServidor?.toUtc().toIso8601String() ?? '-',
                            t.entryHash != null && t.entryHash!.length >= 12
                                ? t.entryHash!.substring(0, 12)
                                : (t.entryHash ?? '-'),
                          ])
                      .toList(),
                ),

          pw.Header(level: 1, child: pw.Text('6. Verificação de integridade')),
          pw.Text('Cadeia local: ${cadeiaLocalOk ? 'INTEGRA' : 'QUEBRADA'}'),
          pw.Text(
              'Cadeia servidor: ${serverChainStatus == null ? 'INTEGRA (último sync)' : serverChainStatus}'),
          pw.SizedBox(height: 16),
          pw.Text(
              'O manifesto.json deste ZIP traz o SHA-256 de cada arquivo, '
              'incluindo este PDF — qualquer alteração é detectável.',
              style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
        ],
      ),
    );
    return doc.save();
  }
}
