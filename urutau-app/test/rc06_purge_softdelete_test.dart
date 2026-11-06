// RC-06/RC-07 (MRV): purge destrutivo precisa de confirmacao explicita,
// tem piso de retencao de 10 anos e registra na trilha antes de apagar.
// "Limpar dados" da parcela vira soft-delete (linhas preservadas).
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:urutau/data/database.dart';

void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await db.customSelect('SELECT 1').get();
  });

  tearDown(() async => db.close());

  Future<void> _criarParcelaDeletada(String uuid, DateTime deletedAt) async {
    await db.insertParcela(ParcelasCompanion.insert(
      uuid: uuid,
      propriedade: drift.Value('Fazenda Teste'),
      propUt: 'UT-1',
      idParcela: 1,
      userId: 'user-1',
      deletedAt: drift.Value(deletedAt),
    ));
    await db.insertPlanta(PlantasCompanion.insert(
      uuid: 'planta-$uuid',
      parcelaUuid: uuid,
      especie: 'Ipê',
      alturaCm: 150,
      categoria: 1,
      deletedAt: drift.Value(deletedAt),
    ));
    await db.insertFotoParcela(FotosParcelaCompanion(
      uuid: drift.Value('foto-$uuid'),
      parcelaUuid: drift.Value(uuid),
      filePath: drift.Value('/tmp/nao_existe_$uuid.jpg'),
      deletedAt: drift.Value(deletedAt),
    ));
  }

  test('purge sem confirmacao nao apaga nada', () async {
    await _criarParcelaDeletada(
        'p1', DateTime.now().subtract(const Duration(days: 4000)));
    final apagadas = await db.purgarDeletados(diasRetencao: 30);
    expect(apagadas, 0);
    expect(await db.getParcelaByUuid('p1', includeDeleted: true), isNotNull);
  });

  test('purge com confirmacao respeita piso de 10 anos (30 dias vira 3650)', () async {
    // soft-deletada ha 40 dias: com piso de 3650 dias, NAO pode ser purgada
    await _criarParcelaDeletada(
        'p2', DateTime.now().subtract(const Duration(days: 40)));
    final apagadas =
        await db.purgarDeletados(diasRetencao: 30, confirmarDestruicao: true);
    expect(apagadas, 0);
    expect(await db.getParcelaByUuid('p2', includeDeleted: true), isNotNull);
  });

  test('purge com confirmacao apaga so apos 10 anos e registra na trilha', () async {
    await _criarParcelaDeletada(
        'p3', DateTime.now().subtract(const Duration(days: 4000)));
    final apagadas = await db.purgarDeletados(confirmarDestruicao: true);
    expect(apagadas, 1);
    expect(await db.getParcelaByUuid('p3', includeDeleted: true), isNull);

    // trilha registrou a destruicao e a cadeia continua integra
    final entradas = await (db.select(db.trilhaAuditoria)
          ..where((t) => t.acao.equals('purge_parcela')))
        .get();
    expect(entradas, hasLength(1));
    expect(entradas.first.entidadeUuid, 'p3');
    expect(await db.verificarCadeiaAuditoria(), isNull);
  });

  test('softDeleteDadosParcela marca deletedAt e preserva as linhas', () async {
    await db.insertParcela(ParcelasCompanion.insert(
      uuid: 'p4',
      propriedade: drift.Value('Fazenda Teste'),
      propUt: 'UT-1',
      idParcela: 2,
      userId: 'user-1',
    ));
    await db.insertPlanta(PlantasCompanion.insert(
      uuid: 'planta-p4',
      parcelaUuid: 'p4',
      especie: 'Ipê',
      alturaCm: 150,
      categoria: 1,
    ));
    await db.insertFotoParcela(FotosParcelaCompanion(
      uuid: drift.Value('foto-p4'),
      parcelaUuid: drift.Value('p4'),
      filePath: drift.Value('/tmp/nao_existe_p4.jpg'),
    ));

    await db.softDeleteDadosParcela('p4', by: 'user-1');

    // visiveis normalmente somem, mas as linhas continuam no banco
    expect(await db.getPlantasByParcela('p4'), isEmpty);
    expect(await db.getFotosByParcela('p4'), isEmpty);
    final plantasTodas = await (db.select(db.plantas)
          ..where((t) => t.parcelaUuid.equals('p4')))
        .get();
    expect(plantasTodas, hasLength(1));
    expect(plantasTodas.first.deletedAt, isNotNull);
    final fotosTodas = await (db.select(db.fotosParcela)
          ..where((t) => t.parcelaUuid.equals('p4')))
        .get();
    expect(fotosTodas, hasLength(1));
    expect(fotosTodas.first.deletedAt, isNotNull);

    // acao registrada na trilha e cadeia integra
    final trilha = await (db.select(db.trilhaAuditoria)
          ..where((t) => t.acao.equals('parcela_dados_limpos')))
        .get();
    expect(trilha, hasLength(1));
    expect(await db.verificarCadeiaAuditoria(), isNull);
  });
}
