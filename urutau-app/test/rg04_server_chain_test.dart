// RG-04 fase 4: o payload remontado pro servidor tem de bater com o entryHash
// gravado localmente — prova de que a verificação server-side usa o mesmo hash.
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:urutau/data/database.dart';

void main() {
  test('payload do servidor (remontado) == entryHash local', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    await db.customSelect('SELECT 1').get();
    addTearDown(db.close);

    await db.logTrilha(
      acao: 'create',
      entidadeTipo: 'parcela',
      entidadeUuid: 'p1',
      antes: 'nulo',
      depois: 'rascunho',
      origem: 'app',
    );
    final e = await (db.select(db.trilhaAuditoria)).getSingle();

    // remonta o payload como o verificarCadeiaServidor faz a partir do JSON
    // que o servidor devolveria (ts em ISO UTC, offset como número)
    final tsDispIso = DateTime.fromMillisecondsSinceEpoch(
            e.tsDispositivo!.millisecondsSinceEpoch,
            isUtc: true)
        .toIso8601String();
    final payload = jsonEncode({
      'prev': e.prevHash,
      'acao': e.acao,
      'entidade_tipo': e.entidadeTipo,
      'entidade_uuid': e.entidadeUuid,
      'usuario_uuid': e.usuarioUuid,
      'antes': e.antes,
      'depois': e.depois,
      'ts_dispositivo': tsDispIso,
      if (e.offsetRelogioMs != null) 'offset_relogio_ms': e.offsetRelogioMs,
      'origem': e.origem,
    });
    final esperado = sha256.convert(utf8.encode(payload)).toString();
    expect(esperado, e.entryHash);
    expect(await db.verificarCadeiaAuditoria(), isNull);
  });
}
