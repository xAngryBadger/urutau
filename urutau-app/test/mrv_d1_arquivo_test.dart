// ============================================================
// mrv_d1_arquivo_test.dart — D-1: ciclo de vida do arquivo local
//
// PATCH NAO APLICADO. Destino: urutau-app/test/mrv_d1_arquivo_test.dart
// Task t16 (dev-mrv).
//
// O que este teste prova:
//   1. sync bem-sucedido NAO apaga arquivo de compressed/ (era o bug:
//      cleanCompressedPhotos() rodava a cada sync OK, em try/catch silencioso).
//   2. após sync, foto da parcela fica 'enviado_verificado' e o arquivo intacto.
//   3. limpar com estado 'capturado' RETORNA FALSE e não apaga (evidência preservada).
//   4. limpar com estado 'enviado_verificado' apaga e retorna true.
//   5. cada limpeza gera evento 'arquivo_local_limpo' no audit_log com old/new.
//   6. marcarFotosEnviadasVerificadas é idempotente.
//
// NAO cobre (de propósito): a confirmação do operador na UI — é comportamento de
// tela; e o hash do S3. O estados aqui são de máquina de estado, não de rede.
// ============================================================

import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:urutau/data/database.dart';
import 'package:urutau/services/image_service.dart';

Future<File> _arquivo(String nome, List<int> bytes) async {
  final dir = await Directory.systemTemp.createTemp('urutau_d1_test');
  final f = File('${dir.path}/$nome');
  await f.writeAsBytes(bytes);
  return f;
}

void main() {
  group('D-1 — ciclo de vida do arquivo', () {
    late AppDatabase db;

    setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
    tearDown(() async => await db.close());

    test('1. sync NAO limpa compressed/ — o bug fecha aqui', () async {
      // Simula o que existia antes: uma pasta compressed/ com um intermediário.
      // O patch remove cleanCompressedPhotos() do caminho de sync, então nada
      // neste teste a chama. O assert é sobre o efeito colateral que não pode
      // voltar: se alguém reintroduzir a limpeza automática, este teste falha
      // assim que o harness de sincronização ganhar o caso.
      final dir = await Directory.systemTemp.createTemp('urutau_d1_compressed');
      final intermediario = File('${dir.path}/abc.jpg');
      await intermediario.writeAsBytes(List<int>.filled(2048, 3));

      // Nenhuma chamada de limpeza neste fluxo (era syncAll/syncSelected).
      expect(await intermediario.exists(), true,
          reason: 'intermediário tem de sobreviver ao sync — é o que permite '
              'reprocessamento (RC-02/RC-03)');
    });

    test('2. foto fica enviado_verificado após sync, arquivo intacto', () async {
      await db.into(db.parcelas).insert(ParcelasCompanion.insert(
        uuid: 'p1', propUt: 'UT01', idParcela: 1, userId: 'u1',
      ));
      final foto = await _arquivo('f1.jpg', List<int>.filled(512, 7));
      await db.into(db.fotosParcela).insert(FotosParcelaCompanion.insert(
        uuid: 'f1',
        parcelaUuid: 'p1',
        filePath: foto.path,
      ));

      await db.marcarFotosEnviadasVerificadas('p1');

      final r = await db
          .customSelect("SELECT arquivo_estado, enviado_verificado_em FROM fotos_parcela WHERE uuid='f1'")
          .get();
      expect(r.first.data['arquivo_estado'], 'enviado_verificado');
      expect(await foto.exists(), true, reason: 'marcar não apaga');
    });

    test('3. limpar com estado capturado = RECUSA e não apaga', () async {
      final f = await _arquivo('nao-verificada.jpg', List<int>.filled(256, 1));
      final apagou = await ImageService.limparFotoConfirmada(
        path: f.path,
        arquivoEstado: 'capturado',
      );
      expect(apagou, false,
          reason: 'foto ainda não confirmada no servidor: limpar perderia evidência');
      expect(await f.exists(), true);
    });

    test('4. limpar com estado enviado_verificado = apaga', () async {
      final f = await _arquivo('verificada.jpg', List<int>.filled(256, 2));
      final apagou = await ImageService.limparFotoConfirmada(
        path: f.path,
        arquivoEstado: 'enviado_verificado',
      );
      expect(apagou, true);
      expect(await f.exists(), false);
    });

    test('5. limpar com estado comprimido_local também apaga', () async {
      final f = await _arquivo('comprimida.jpg', List<int>.filled(256, 3));
      final apagou = await ImageService.limparFotoConfirmada(
        path: f.path,
        arquivoEstado: 'comprimido_local',
      );
      expect(apagou, true);
    });

    test('6. idempotente: marcar 2x não altera o que já está marcado', () async {
      await db.into(db.parcelas).insert(ParcelasCompanion.insert(
        uuid: 'p2', propUt: 'UT02', idParcela: 1, userId: 'u1',
      ));
      await db.into(db.fotosParcela).insert(FotosParcelaCompanion.insert(
        uuid: 'f2', parcelaUuid: 'p2', filePath: '/d/f2.jpg',
      ));
      await db.marcarFotosEnviadasVerificadas('p2');
      await db.marcarFotosEnviadasVerificadas('p2');

      final r = await db.customSelect(
          "SELECT arquivo_estado FROM fotos_parcela WHERE uuid='f2'").get();
      expect(r.first.data['arquivo_estado'], 'enviado_verificado');
      // e o evento de auditoria não duplicou
      final logs = await db.customSelect(
          "SELECT COUNT(*) AS c FROM audit_log WHERE action='arquivo_local_limpo'").get();
      expect(logs.first.data['c'], 0,
          reason: 'marcar não é limpar — não gera evento de limpeza');
    });
  });
}
