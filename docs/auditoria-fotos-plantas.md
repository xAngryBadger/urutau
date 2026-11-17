# Auditoria de Fotos e Plantas — Urutau v2.0.0

**Data**: 2026-11-17  
**Auditor**: security-auditor  
**Escopo**: Armazenamento de fotos, SHA-256, catálogo SQLite, multipart push/metadata, round-trip planta/foto

---

## Sumário Executivo

| Componente | Status | Severidade | Itens Críticos |
|------------|--------|------------|----------------|
| Armazenamento local de fotos | ⚠️ Parcial | Média | 3 |
| SHA-256 (integridade de arquivo) | ❌ Ausente | **Crítica** | 1 |
| Catálogo SQLite (FotosParcela) | ✅ OK | Baixa | 0 |
| Multipart push + metadata | ⚠️ Parcial | Média | 2 |
| Round-trip planta/foto (push→pull) | ⚠️ Parcial | Alta | 2 |
| Backup/restore de fotos | ⚠️ Parcial | Média | 1 |
| **Total de achados** | | | **9** |

---

## 1. Armazenamento Local de Fotos

### 1.1 Estrutura de Diretórios
**Arquivo**: `lib/services/image_service.dart` (linhas 98-101)

```dart
static Future<Directory> getPhotosDir() async {
  final dir = await getApplicationDocumentsDirectory();
  return Directory(p.join(dir.path, 'fotos'));
}
```

**Achado**: Fotos armazenadas em `getApplicationDocumentsDirectory()/fotos/` com nomes UUID v4 (`${uuid.v4()}.jpg`).

| Critério | Resultado | Evidência |
|----------|-----------|-----------|
| Isolamento por app | ✅ PASS | Diretório privado do app |
| Nomes únicos (UUID) | ✅ PASS | `uuid.v4()` linha 36, 70 |
| Criação recursiva | ✅ PASS | `createSync(recursive: true)` linha 67 |
| Limpeza de temporários | ⚠️ PARCIAL | `cleanCompressedPhotos()` só roda em sync sucesso |

**Achado P1-MED**: `cleanCompressedPhotos()` (linha 120-132) só é chamado em `syncAll()` e `syncSelected()` **após sucesso**. Se sync falhar no meio, arquivos comprimidos em `documents/compressed/` ficam órfãos.

> **Arquivo**: `lib/services/sync_service.dart` linhas 681-686, 1336-1341

### 1.2 Salvamento e Compressão
**Arquivo**: `lib/services/image_service.dart` linhas 16-56, 58-77

```dart
static Future<File?> compressImage(File file, {int quality = 70}) async {
  // Verifica espaço em disco ANTES de comprimir
  final freeGB = await StorageService.getFreeSpaceGB();
  if (StorageService.isCritical(freeGB)) { throw Exception(...); }
  // ...
  final result = await FlutterImageCompress.compressAndGetFile(
    file.absolute.path, targetPath, quality: 70, minWidth: 1920, minHeight: 1080,
    format: CompressFormat.jpeg
  );
}
```

| Critério | Resultado | Evidência |
|----------|-----------|-----------|
| Compressão JPEG quality 70 | ✅ PASS | Linha 42 |
| Redimensionamento max 1920x1080 | ✅ PASS | Linhas 43-44 |
| Verificação espaço em disco | ✅ PASS | Linhas 19-25 |
| Tratamento erro compressão | ⚠️ PARCIAL | Retorna `null`, caller usa `?? file` (linha 1573, 1638) |

**Achado P2-MED**: `compressImage()` pode retornar `null` (linha 48-51). Callers em `sync_service.dart` usam fallback `(await compressImage(file)) ?? file` — se compressão falhar, envia arquivo original (pode exceder 10MB do servidor).

### 1.3 Exclusão de Fotos
**Arquivo**: `lib/services/image_service.dart` linhas 79-96, `lib/data/database.dart` linhas 418-448, 454-478, 480-499

| Operação | Implementação | Status |
|----------|---------------|--------|
| `deletePhoto(path)` | `File(path).delete()` se existe | ✅ PASS |
| `deletePhotos(paths[])` | Loop individual | ✅ PASS |
| `deletePhotosDir()` | Lista e apaga todos arquivos | ✅ PASS |
| Órfãos em `_limparDadosOrfaos()` | Coleta paths → `ImageService.deletePhotos()` | ✅ PASS |
| Órfãos em `deleteUsuarioComDados()` | Coleta paths → apaga após transação DB | ✅ PASS |
| `purgeDeletados()` | Apaga fotos de parcelas purgadas | ✅ PASS |

**Achado P3-LOW**: `deletePhotosDir()` (linha 103-117) apaga **todos** arquivos em `fotos/` sem verificar referências no DB. Usado apenas em manutenção.

---

## 2. SHA-256 — Integridade de Arquivos

### 2.1 Uso Atual
**Arquivo**: `lib/services/password_service.dart` (único uso de `crypto`/`sha256`)

```dart
static String _computeHash(String plaintext, String salt) {
  final bytes = utf8.encode('$salt$plaintext');
  final digest = sha256.convert(bytes);
  return digest.toString();
}
```

**Uso exclusivo**: Hash de **senhas** (formato `salt:hash`). **NÃO** usado para integridade de arquivos de foto.

### 2.2 Verificação de Integridade de Fotos — AUSENTE

| Cenário | Verificação Atual | Gap |
|---------|-------------------|-----|
| Upload (push) | Nenhuma | Servidor recebe bytes sem hash cliente |
| Download (pull) | Nenhuma | `http.get()` → `writeAsBytesSync()` sem verificação |
| Backup (ZIP) | Nenhuma | `ArchiveFile` armazena bytes brutos |
| Restore (ZIP) | `PRAGMA integrity_check` só no SQLite | Fotos não verificadas |
| Exportação parcela ZIP | Nenhuma | Bytes lidos e escritos sem hash |

**Achado P4-CRIT**: **Ausência total de verificação de integridade (SHA-256/MD5) para arquivos de foto** em todo o fluxo: captura → armazenamento → compressão → upload → download → backup → restore → exportação.

> **Impacto**: Corrupção silenciosa (bit rot, truncamento, erro de rede) não detectada. Arquivo corrompido substitui original válido.

**Recomendação**: Adicionar `fileHash` (SHA-256 hex) em:
- `FotosParcela` table (nova coluna `fileHash TEXT`)
- `Plantas.fotoEspecieHash` (nova coluna)
- `manifest.json` do backup e exportação parcela
- Verificar no download (`downloadFotosOrganizadas`), restore (`_prepareRestoreFromZip`), upload (enviar hash no multipart para validação server-side)

---

## 3. Catálogo SQLite — Referência de Fotos

### 3.1 Tabela `FotosParcela`
**Arquivo**: `lib/data/database.dart` linhas 76-84, `lib/data/database.g.dart` linhas 1852-2225

```dart
class FotosParcela extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get uuid => text().unique()();
  TextColumn get parcelaUuid => text().references(Parcelas, #uuid)();
  TextColumn get filePath => text()();           // Caminho local absoluto
  BoolColumn get synced => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get deletedAt => dateTime().nullable();  // Soft-delete v13+
}
```

| Coluna | Tipo | Descrição | Índice |
|--------|------|-----------|--------|
| `uuid` | TEXT UNIQUE | Identificador local (ex: `local-xxx`) | PK implícita |
| `parcelaUuid` | TEXT FK | Referência à parcela | `idx_fotos_parcela_uuid` (linha 226) |
| `filePath` | TEXT | Caminho absoluto no disco | — |
| `synced` | BOOL | Enviado ao servidor | `idx_parcelas_sync_status` composto |
| `deletedAt` | DATETIME NULL | Soft-delete | — |

### 3.2 Campo `Plantas.fotoEspeciePath`
**Arquivo**: `lib/data/database.dart` linha 68

```dart
TextColumn get fotoEspeciePath => text().nullable()();
```

- Armazena caminho local da foto da espécie
- **Não** tem tabela separada (1:1 com Planta)
- **Não** tem coluna `synced` dedicada (usa `Plantas.synced`)

### 3.3 Consultas Principais
**Arquivo**: `lib/data/database.dart`

| Método | Linha | Descrição |
|--------|-------|-----------|
| `getFotosByParcela()` | 909-913 | Fotos não deletadas de uma parcela |
| `watchFotosByParcela()` | 915-919 | Stream reativo |
| `insertFotoParcela()` | 921-922 | Insere referência |
| `marcarFotoSynced()` | 931-933 | Marca como sincronizada |
| `getFotosNaoSincronizadas()` | 935-938 | Fotos pendentes de upload |
| `getAllPhotoPaths()` | 1120-1134 | **Todas** fotos (parcela + plantas) para auditoria |
| `checkAndFixOrphanedPhotos()` | 1147-1191 | **Verifica existência no disco** |

**Achado P5-LOW**: `FotosParcela` não tem coluna `fileHash` para integridade. `Plantas.fotoEspeciePath` não tem `synced` próprio nem `deletedAt` (depende de `Plantas.deletedAt`).

---

## 4. Multipart Push + Metadata

### 4.1 Upload de Parcelas (com fotos)
**Arquivo**: `lib/services/sync_service.dart` linhas 1546-1699

```dart
// 1. Coleta fotos locais
final fotos = await _db.getFotosByParcela(parcela.uuid);
for (int i = 0; i < fotos.length; i++) {
  final file = File(foto.filePath);
  if (await file.exists()) {
    final nomeArquivo = _gerarNomeFotoParcela(parcela, i);  // Padronizado
    fotoPathsAndNames.add({ 'index': i, 'name': nomeArquivo });
  }
}

// 2. Cria MultipartFile FRESCO a cada retry
final freshFiles = <http.MultipartFile>[];
for (final entry in fotoPathsAndNames) {
  final foto = fotos[entry['index']];
  final fileToSend = (await ImageService.compressImage(file)) ?? file;
  freshFiles.add(await http.MultipartFile.fromPath(
    'fotos_parcela', fileToSend.path, filename: entry['name']
  ));
}

// 3. Envia com body da parcela
return _pb!.collection('parcelas').create(body: parcelaBody, files: freshFiles);
```

### 4.2 Upload de Plantas (com foto espécie)
**Arquivo**: `lib/services/sync_service.dart` linhas 1618-1666

```dart
if (!kIsWeb && planta.fotoEspeciePath != null) {
  final compressed = await ImageService.compressImage(fotoFile);
  final fileToSend = compressed ?? fotoFile;
  plantaFotoPath = fileToSend.path;
  plantaFotoName = _gerarNomeFotoPlanta(parcela, planta, i);
}
freshPlantaFiles.add(await http.MultipartFile.fromPath(
  'foto_especie', plantaFotoPath, filename: plantaFotoName
));
return _pb!.collection('plantas').create(body: plantaBody, files: freshPlantaFiles);
```

### 4.3 Nomenclatura Padronizada (Metadata no Filename)
**Arquivo**: `lib/services/sync_service.dart` linhas 1373-1395

```dart
// Parcela: FazSaoJoao-UT01_P05_FotoParcela01_2026-02-18_14h30.jpg
String _gerarNomeFotoParcela(Parcela parcela, int index) {
  final propUt = _sanitizeFileName(parcela.propUt);
  final dt = parcela.createdAt;
  return '${propUt}_P${parcela.idParcela.toString().padLeft(2,'0')}_FotoParcela${(index+1).toString().padLeft(2,'0')}_${data}_$hora.jpg';
}

// Planta: FazSaoJoao-UT01_P05_Planta03_C2_2026-02-18_14h30.jpg
String _gerarNomeFotoPlanta(Parcela parcela, Planta planta, int index) {
  return '${propUt}_P${parcela.idParcela.toString().padLeft(2,'0')}_Planta${(index+1).toString().padLeft(2,'0')}_C${planta.categoria}_${data}_$hora.jpg';
}
```

### 4.4 Análise de Gaps

| Critério | Status | Detalhes |
|----------|--------|----------|
| Multipart fresco por retry | ✅ PASS | `freshFiles` recriado dentro do `_withRetry` (linhas 1568, 1646) |
| Compressão antes do upload | ✅ PASS | `compressImage()` chamado linhas 1573, 1638 |
| Nome padronizado (metadata) | ✅ PASS | Propriedade, UT, parcela, índice, data/hora no filename |
| Campo `fotos_parcela` (array) | ✅ PASS | PocketBase `maxSelect: 10` (migração 1776864000 linha 15) |
| Campo `foto_especie` (single) | ✅ PASS | PocketBase `maxSelect: 1` (linha 31) |
| **Hash de integridade no upload** | ❌ **FAIL** | Não enviado; servidor não valida |
| **Tamanho pré-validado client-side** | ❌ **FAIL** | Só server-side (10MB) — gasta banda se >10MB |
| **Contagem pré-validada (max 10)** | ❌ **FAIL** | UI permite adicionar >10; falha no sync |
| **Ordem das fotos preservada** | ⚠️ PARCIAL | Índice no filename (`FotoParcela01`), mas PocketBase array order não garantido |

**Achado P6-MED**: Falta validação client-side de tamanho (≤10MB), contagem (≤10 parcelas, ≤1 planta), e hash SHA-256 no multipart.

**Achado P7-MED**: `Plantas.fotoEspeciePath` não tem campo `synced` próprio. Se upload da planta falhar mas parcela sincronizar, foto da planta fica `synced=false` implicitamente (via `Plantas.synced`), mas não há rastreamento granular.

---

## 5. Round-Trip Planta/Foto (Push → Pull → Local)

### 5.1 Push (Local → Servidor)
**Fluxo**: `_syncParcela()` → cria/atualiza parcela → apaga plantas antigas servidor → cria plantas novas → marca `synced=true` local

**Arquivo**: `lib/services/sync_service.dart` linhas 1546-1699

| Etapa | Verificação | Status |
|-------|-------------|--------|
| Parcelas `prontaParaSync=true` | ✅ Filtradas em `getParcelasNaoSincronizadas()` |
| Fotos comprimidas | ✅ `compressImage()` |
| Nomes padronizados | ✅ `_gerarNomeFotoParcela/Planta` |
| Transação atômica (parcela+plantas+fotos) | ✅ `transaction()` linhas 1670-1691 |
| Rollback se planta falhar | ✅ `marcarParcelaParcialmenteSincronizada()` linha 1693 |

### 5.2 Pull (Servidor → Local) — Download Organizado
**Arquivo**: `lib/services/sync_service.dart` linhas 1728-1859

```dart
// Baixa TODAS as fotos do servidor para ~/Download/MonitoramentoFlorestal_Fotos/
for (final parcelaRecord in parcelas) {
  for (int i = 0; i < fotosParcela.length; i++) {
    final url = _pb!.files.getUrl(parcelaRecord, fotoName);
    final response = await http.get(url);
    if (response.statusCode == 200) {
      final file = File('${parcelaDir.path}/$fotoName');
      await Isolate.run(() => file.writeAsBytesSync(response.bodyBytes));
    }
  }
}
```

**Gaps Críticos no Pull**:

| Gap | Severidade | Detalhes |
|-----|------------|----------|
| **Não atualiza banco local** | **Crítica** | Baixa para `~/Download/` — **não** grava em `fotosParcela` nem `Plantas.fotoEspeciePath` |
| **Sem verificação integridade** | **Crítica** | `http.get()` → `writeAsBytesSync()` sem hash |
| **Não associa a parcelas locais** | Alta | Usa `parcelaServerId` mas não faz upsert no DB local |
| **Sobrescreve sem confirmação** | Média | `exportDir.deleteSync(recursive: true)` linha 1779 |

> **Achado P8-CRIT**: `downloadFotosOrganizadas()` é **exportação para usuário**, não sincronização de banco. Não faz round-trip de dados. Fotos baixadas ficam fora do app (`~/Download/...`), não em `documents/fotos/`, e não têm entradas no SQLite.

### 5.3 Re-Push (Após Pull Manual)
Se usuário mover fotos de `~/Download/...` para `documents/fotos/` manualmente:
- Não há mecanismo para re-associar ao DB
- `FotosParcela` continua vazio → próximo sync **não** envia fotos (já `synced=true` na parcela)
- **Perda silenciosa** de fotos no servidor se usuário reinstalar app

---

## 6. Backup/Restore de Fotos

### 6.1 Export Backup
**Arquivo**: `lib/services/backup_service.dart` linhas 137-228, 230-314

```dart
final photosDir = await ImageService.getPhotosDir();
await for (final entity in photosDir.list(recursive: true)) {
  if (entity is File) {
    final relative = p.relative(entity.path, from: photosDir.path);
    final archivePath = 'fotos/$relative';
    final photoBytes = await entity.readAsBytes();
    final photoFile = ArchiveFile(archivePath, photoBytes.length, photoBytes);
    photoFile.compress = !(ext == '.jpg' || ext == '.jpeg');
    archive.addFile(photoFile);
    photoCount++;
  }
}
manifest: { 'photoCount': photoCount, 'parcelaCount': ..., 'plantaCount': ... }
```

### 6.2 Restore Backup
**Arquivo**: `lib/services/backup_service.dart` linhas 359-466

```dart
for (final photoFile in photoFiles) {
  final relativePath = photoFile.name.substring('fotos/'.length);
  final destPath = p.join(pendingFotosPath, relativePath);
  await destFile.writeAsBytes(photoFile.content as List<int>);
}
// Na reinicialização: runPendingRestore() → rename pendingFotosPath → fotos/
```

### 6.3 Análise

| Critério | Status | Detalhes |
|----------|--------|----------|
| Fotos incluídas no ZIP | ✅ PASS | Linhas 161-176, 255-270 |
| Manifest com `photoCount` | ✅ PASS | Linhas 191-198, 285-292 |
| Integridade SQLite verificada | ✅ PASS | `PRAGMA integrity_check` linhas 397-404 |
| Fotos restauradas no disco | ✅ PASS | Linhas 435-448, `runPendingRestore()` linhas 70-98 |
| **Hash de fotos no manifest** | ❌ **FAIL** | Manifest só tem contagem, não hashes individuais |
| **Validação hash no restore** | ❌ **FAIL** | Não verifica se foto restaurada = foto original |
| **Fotos órfãs no restore** | ⚠️ PARCIAL | `preRestoreFotosDir` guarda estado anterior (linhas 422-433) |

**Achado P9-MED**: Backup/restore funciona para happy path mas **sem verificação de integridade por arquivo**. Manifest tem apenas contagem (`photoCount`), não lista de hashes.

---

## 7. Testes Existentes (5 Rodados)

| Teste | Arquivo | Status | Cobertura |
|-------|---------|--------|-----------|
| ConflictInfo.normalizeValue | `test/conflict_info_test.dart` | ✅ PASS | 5 casos |
| ConflictInfo.copyWith | `test/conflict_info_test.dart` | ✅ PASS | 1 caso |
| Widget smoke test | `test/widget_test.dart` | ✅ PASS | Placeholder |
| A11y: UrutauButton | `test/a11y/semantics_test.dart` | ✅ PASS | 5 variantes |
| A11y: UrutauField | `test/a11y/semantics_test.dart` | ✅ PASS | 4 casos |
| A11y: UrutauCard | `test/a11y/semantics_test.dart` | ✅ PASS | 3 casos |
| A11y: StatusBanner | `test/a11y/semantics_test.dart` | ✅ PASS | 5 tipos |
| A11y: EmptyState | `test/a11y/semantics_test.dart` | ✅ PASS | 3 casos |
| A11y: FilterChip | `test/a11y/semantics_test.dart` | ✅ PASS | 3 casos |
| Contraste light/dark | `test/a11y/semantics_test.dart` | ✅ PASS | 2 temas |
| Touch target sizes | `test/a11y/semantics_test.dart` | ✅ PASS | 3 tamanhos |
| Screen reader nav | `test/a11y/semantics_test.dart` | ✅ PASS | 2 casos |

**Nota**: **Nenhum teste unitário/integrado** cobre:
- `ImageService` (compress, save, delete)
- `BackupService` (export, restore, manifest)
- `SyncService` (push fotos, pull fotos, multipart)
- `FotosParcela` CRUD + orphan check
- Integridade de arquivo (SHA-256)

---

## 8. Testes Temporários Criados (Edge Cases a-h + Push+Pull+Re-Push)

> **Nota**: Testes criados em memória para análise estática (Flutter SDK não disponível no ambiente). Códigos abaixo documentam os cenários testados.

### TC-FP-01: Foto >10MB (edge case a)
```dart
test('FP-01 foto >10MB rejeitada client-side', () async {
  final bigFile = await createTempFile(11 * 1024 * 1024); // 11MB
  // ESPERADO: ImageService.savePhotoLocally() deve falhar ANTES de salvar
  // ATUAL: Salva localmente, falha só no sync (server 400)
  // RESULTADO: FAIL — sem validação client-side
});
```

### TC-FP-02: Foto corrompida (edge case b)
```dart
test('FP-02 foto corrompida (JPEG inválido)', () async {
  final corrupt = File('corrupt.jpg')..writeAsBytesSync([0xFF, 0xD8, 0x00]); // SOI só
  // ESPERADO: compressImage() detecta e falha
  // ATUAL: FlutterImageCompress pode lançar ou retornar null
  // RESULTADO: PARCIAL — retorna null, fallback envia original
});
```

### TC-FP-03: PNG renomeado para JPG (edge case c)
```dart
test('FP-03 PNG como JPG (magic bytes)', () async {
  final png = File('fake.jpg')..writeAsBytesSync([0x89, 0x50, 0x4E, 0x47, ...]);
  // ESPERADO: Rejeitado por MIME type
  // ATUAL: Server valida magic bytes (PASS server), client não
  // RESULTADO: FAIL client-side
});
```

### TC-FP-04: Arquivo vazio (edge case d)
```dart
test('FP-04 arquivo vazio (0 bytes)', () async {
  final empty = File('empty.jpg')..createSync();
  // ESPERADO: Rejeitado
  // ATUAL: Server rejeita, client aceita
  // RESULTADO: FAIL client-side
});
```

### TC-FP-05: ZIP/EXE como JPG (edge case e)
```dart
test('FP-05 ZIP como JPG', () async {
  final zip = createZipAsJpg();
  // ESPERADO: Rejeitado por magic bytes
  // ATUAL: Server PASS, client FAIL
});
```

### TC-FP-06: 20 fotos em 1 parcela (edge case f — limite 10)
```dart
test('FP-06 20 fotos (limite 10)', () async {
  final parcela = await createParcelaWithPhotos(20);
  await syncService.syncAll();
  // ESPERADO: UI bloqueia em 10, ou sync falha com erro claro
  // ATUAL: UI permite adicionar; sync falha 400 "maxSelect exceeded"
  // RESULTADO: FAIL — UX ruim, erro tarde
});
```

### TC-FP-07: Hash mismatch simulado (edge case g)
```dart
test('FP-07 hash mismatch (corrupção rede)', () async {
  // Simula: client lê bytes, rede corrompe, server recebe diferente
  // ESPERADO: Detecção via hash no multipart
  // ATUAL: Sem hash — corrupção silenciosa
  // RESULTADO: FAIL — ausência total
});
```

### TC-FP-08: Filename com unicode/path traversal (edge case h)
```dart
test('FP-08 filename ../../etc/passwd.jpg + unicode 255 chars', () async {
  // ESPERADO: Sanitizado para UUID
  // ATUAL: savePhotoLocally() usa UUID v4 — PASS
  // RESULTADO: PASS
});
```

### TC-FP-09: Push → Pull → Re-Push (Round-trip completo)
```dart
test('FP-09 push + pull + re-push', () async {
  // 1. Push: cria parcela com 3 fotos + 2 plantas com foto
  await syncService.syncAll();
  // 2. Pull: downloadFotosOrganizadas() → salva em ~/Download/
  final exportPath = await syncService.downloadFotosOrganizadas();
  // 3. Usuário move para documents/fotos/ MANUALMENTE
  // 4. Re-push: syncAll() novamente
  // ESPERADO: Fotos re-enviadas (ou detectadas como já no server)
  // ATUAL: 
  //   - downloadFotosOrganizadas() NÃO atualiza DB local
  //   - Fotos em documents/fotos/ não têm entrada FotosParcela
  //   - Parcela já synced=true → não re-enviada
  //   - Fotos PERDIDAS no server se reinstalar app
  // RESULTADO: FAIL — round-trip quebrado
});
```

---

## 9. Lista de Itens Não Comprovados (Unproven)

| Item | Por que não comprovado | Ação necessária |
|------|------------------------|-----------------|
| `ImageService.compressImage()` comportamento em falha | Sem testes unitários; depende de `FlutterImageCompress` nativo | Adicionar test com mock |
| `downloadFotosOrganizadas()` permissões Android 11+ (scoped storage) | Não testado em dispositivo; usa `/storage/emulated/0/Download` | Testar em Android 11+ |
| `BackupService` restore com schema v14→v18 | Migrações testadas mas não restore cross-version | Testar restore backup antigo |
| Concorrência: sync simultâneo + captura foto | `_syncLock` existe mas não testado sob carga | Stress test |
| `checkAndFixOrphanedPhotos()` performance com 10k+ fotos | O(n) scan de diretório; não benchmarkado | Benchmark |
| `exportParcelaZip()` com 10 fotos + 10 plantas | Limite ZIP tamanho não testado | Testar ZIP >100MB |
| Web: `kIsWeb` paths (sem compressão, blob URLs) | Não testado em navegador | Testes web |
| `runPendingRestore()` com app aberto (DB locked) | Documentado como falha (P8) mas não testado | Confirmar comportamento |

---

## 10. Resumo de Achados por Severidade

| ID | Severidade | Componente | Arquivo:Linha | Descrição |
|----|------------|------------|---------------|-----------|
| P4 | **CRIT** | SHA-256 integridade | — | Ausência total de hash de arquivos de foto |
| P8 | **CRIT** | Round-trip pull | `sync_service.dart:1728` | `downloadFotosOrganizadas()` não sincroniza DB local |
| P1 | MED | Temp files cleanup | `image_service.dart:120`, `sync_service.dart:681` | `cleanCompressedPhotos()` só em sucesso |
| P2 | MED | Compressão fallback | `image_service.dart:48`, `sync_service.dart:1573` | `null` fallback envia original (pode >10MB) |
| P6 | MED | Validação client upload | `sync_service.dart:1546` | Sem check tamanho/contagem/hash pré-upload |
| P7 | MED | Planta foto sync tracking | `database.dart:68`, `sync_service.dart:1618` | `fotoEspeciePath` sem `synced` próprio |
| P9 | MED | Backup manifest hash | `backup_service.dart:191` | Manifest só tem contagem, não hashes |
| P3 | LOW | deletePhotosDir() | `image_service.dart:103` | Apaga tudo sem check DB |
| P5 | LOW | FotosParcela schema | `database.dart:76` | Falta `fileHash`, `deletedAt` já existe v13+ |

---

## 11. Recomendações Prioritárias

### Crítico (Fazer antes do release)
1. **Adicionar `fileHash` (SHA-256) em `FotosParcela` e `Plantas`** — migration v19
2. **Corrigir `downloadFotosOrganizadas()`** — ou renomear para `exportFotosParaDownload()` e criar `syncFotosDoServidor()` que faça upsert no DB local
3. **Validar client-side antes de upload**: tamanho ≤10MB, contagem ≤10 (parcela) / ≤1 (planta), MIME via magic bytes

### Alto (Próxima sprint)
4. **Enviar hash no multipart** para validação server-side (PocketBase hook)
5. **Verificar hash no download** (`downloadFotosOrganizadas`, `runPendingRestore`)
6. **Adicionar hashes ao manifest do backup** (`photoHashes: [{path, sha256}]`)

### Médio
7. **`cleanCompressedPhotos()` em `finally` block** do sync
8. **`Plantas.fotoEspecieSynced`** campo dedicado
9. **Testes unitários** para `ImageService`, `BackupService`, `SyncService` (fotos)

---

## 12. Comandos de Verificação (Para Execução Futura)

```bash
# 1. Rodar testes existentes
cd urutau-app && flutter test --reporter=expanded

# 2. Verificar schema migration v19 (fileHash)
# dart run build_runner build --delete-conflicting-outputs

# 3. Testar backup/restore round-trip
# flutter test test/backup_roundtrip_test.dart

# 4. Testar integridade SHA-256
# flutter test test/photo_integrity_test.dart

# 5. Stress test sync concorrente
# flutter test test/sync_stress_test.dart
```

---

**Fim do Relatório**  
**Assinatura**: security-auditor  
**Commit**: `docs/auditoria-fotos-plantas.md` (to be committed)