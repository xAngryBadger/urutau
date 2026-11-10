# Bateria adversarial — ficheiros hostis no upload de fotos (t17)

- **Data:** 2026-11-10
- **Executor:** verificador (team urutau-liso), attempt `6b3bbe82-3ee6-4cd7-bff2-af8358f906c4`
- **Alvo:** app Urutau release (dist) no emulator-5554, sync real contra PocketBase de prova em `127.0.0.1:8094` (dir `D:\urutau-devtools\pb-hostil`, binário renomeado `pb-verif.exe` para não ser abatido pela limpeza do capitão em 8090 — combinado no grupo).
- **App user:** `admin@urutau.local` / `teste123` (coleção `users`, id `fdw8ib4v9xcltnk`). Coleção `parcelas` id `pbc_3294281715`.
- **Método:** para cada caso, SQL insere uma parcela pendente `hostil01` (id_parcela=99) + foto(s) em `/data/data/com.urutau.app/app_flutter/fotos/` (+ linha de catálogo em `ativos_brutos` quando aplicável); app é religado, sync disparado pela UI (tap 240,52 → "Enviar agora" 179,505); depois conferem-se UI (snackbar), logcat, base local (`sqlite3 .read`), servidor (API superuser) e storage em disco.
- **Evidências:** `docs/evidencias-t17/ui_<caso>.{xml,png}` + logcat.
- **Nota de harness:** o emulador está com SELinux Enforcing e o app corre com MCS `s0:c199,c256,c512,c768`; ficheiros criados via `adb root` precisam de `chown u0_a199 + chcon u:object_r:app_data_file:s0:c199,c256,c512,c768`, senão o app recebe EACCES no SHA-256/upload (artefato de teste, não bug do app).

## Resumo

| Caso | Entrada hostil | Resultado | Veredicto |
|---|---|---|---|
| 1 | JPEG 11 MB (> maxSize 10 MB) | HTTP 400 `validation_file_size_limit`; sem registo; app vivo | PASS |
| 1b | JPEG 500 MB no caminho real do app | servidor fecha a ligação (broken pipe no cliente); 3 retries; sem registo; sem lixo em disco; app vivo | PASS |
| 2 | .jpg com bytes aleatórios (hash do catálogo correto) | HTTP 400 `validation_invalid_mime_type` (sniff de conteúdo); sem registo | PASS |
| 3 | PNG renomeado .jpg | HTTP 201; ficheiro gravado com nome gerado; sha256 no servidor == catálogo | PASS |
| 4 | ficheiro 0 bytes | HTTP 400 `validation_invalid_mime_type`; sem registo | PASS |
| 4b | colisão de hash vazio (e3b0c442…) no catálogo local | 2.º INSERT falha `UNIQUE constraint failed: ativos_brutos.sha256` | PASS |
| 5 | ZIP e EXE renomeados .jpg | HTTP 400 `validation_invalid_mime_type`; sem registo | PASS |
| 6 | prop_ut / nomes hostis (`../`, unicode, newline, `<>`, `\`, 255 chars, vazio; file_path com newline+unicode) | nome enviado ao servidor é sempre o gerado por `_gerarNomeFotoParcela` (sanitizado); sem traversal/injeção; prop_ut vai como texto (dado, não nome de ficheiro) | PASS |
| 7 | 20 fotos numa parcela (maxSelect=10) | HTTP 400 `validation_too_many_files`; rejeição atómica (0 registos); local fica pendente intacto | PASS |
| 8 | hash do ficheiro diverge do catálogo (RC-04) | bloqueado no cliente antes de enviar; `hash_divergente_upload` na trilha local; HTTP nem chega; sem registo | PASS |

**Nenhum caso crashou o app** (`ps` com 1 processo após cada caso, sem FATAL no logcat) e **nenhum deixou estado inconsistente no servidor** (estado final: 6 registos = 2 seed + 4 casos de nome hostil com ficheiro válido; storage com 8 ficheiros / 1750 bytes no total — o 500 MB não deixou rasto).

## Caso 1 — JPEG de 11 MB vs maxSize 10 MB

- Comando: `run_case.ps1 -Label c1 -SqlFile case_c1.sql` (foto `big11.jpg` 11.534.356 B, hash no catálogo).
- Logcat: `statusCode: 400, code: validation_file_size_limit, message: "Failed to upload Hostil-UT-99_P99_FotoParcela01_...jpg - the maximum allowed file size is 10485760 bytes."`
- UI: snackbar `Falha ao enviar parcela 99. Verifique a conexão e tente novamente.` (evidência `ui_c1.png`)
- Servidor: `observacoes ~ 't17-c1'` → totalItems 0 (rejeição atómica, sem registo parcial).
- **PASS**

## Caso 1b — JPEG de 500 MB no caminho real do app (o caso pedido pelo capitão)

- Comando: `run_case.ps1 -Label c1b -SqlFile case_c1b.sql` (foto `big500.jpg` 524.288.020 B, hash no catálogo → RC-04 calculou SHA-256 dos 500 MB sem erro).
- Logcat: `statusCode: 0, originalError: SocketException: Broken pipe (errno 32)` — o servidor pára de ler e fecha a ligação a meio do stream; o app apanha, faz 3 retries com backoff e mostra erro limpo.
- UI: `Falha ao enviar parcela 99...` (`ui_c1b.png`). Processo vivo (`ps` = 1). `/data` com 4,4 GB livres depois — o ficheiro não é copiado para lado nenhum.
- Servidor: `observacoes ~ 't17-c1b'` → totalItems 0; nenhum ficheiro em storage.
- **PASS** (rejeição limpa; o limite de tamanho protege o servidor antes de gravar; o cliente não estoura memória nem disco)

## Caso 2 — .jpg corrompido (bytes aleatórios)

- Comando: `run_case.ps1 -Label c2 -SqlFile case_c2.sql` (`corrupt.jpg` 2048 B aleatórios, hash do catálogo = hash real → RC-04 passa e o envio é tentado).
- Logcat: `statusCode: 400, code: validation_invalid_mime_type, "mime type must be one of: image/jpeg, image/png, image/webp"` — o servidor faz sniff do CONTEÚDO, não confia na extensão.
- Servidor: totalItems 0. UI: snackbar de falha (`ui_c2.png`). App vivo.
- **PASS**

## Caso 3 — PNG renomeado .jpg

- Comando: `run_case.ps1 -Label c3 -SqlFile case_c3.sql` (`png_renamed.jpg`, 70 B PNG, hash catálogo `c414cd0e…`).
- Servidor: registo criado `67duhttv3patu66`, ficheiro gravado como `hostil_ut_99_p99_foto_parcela01_2025_11_10_18h40_f6uhkx2nfo.jpg`; download via `/api/files/...` → sha256 `c414cd0e204de974…` == hash do ficheiro local == catálogo. Integridade preservada.
- Aceite porque a lista de mimeTypes inclui `image/png` e a validação é por conteúdo. **PASS**

## Caso 4 — ficheiro de 0 bytes (+ 4b colisão de hash vazio)

- Comando: `run_case.ps1 -Label c4 -SqlFile case_c4.sql` (`empty.jpg`, 0 B, hash catálogo = hash vazio `e3b0c442…` → RC-04 passa).
- Logcat: `statusCode: 400, code: validation_invalid_mime_type` (0 bytes não dá para sniffar). Servidor: totalItems 0. UI: falha limpa (`ui_c4.png`).
- 4b (local): `INSERT` de duas linhas em `ativos_brutos` com o mesmo sha256 vazio → 2.º falha `UNIQUE constraint failed: ativos_brutos.sha256 (uq_ativos_brutos_sha256)`; count=1. A tabela local impede colisão de hash vazio.
- **PASS**

## Caso 5 — ZIP / EXE renomeados .jpg

- Comando: `run_case.ps1 -Label c5 -SqlFile case_c5.sql` (`zip_real.jpg` = PK zip real; `exe.jpg` = MZ; hashes de catálogo corretos).
- Logcat: `statusCode: 400, code: validation_invalid_mime_type`. Servidor: totalItems 0. App vivo. Sem registo.
- **PASS** (não há check de conteúdo além do sniff de imagem — mas o sniff bloqueia tudo o que não é imagem)

## Caso 6 — nomes hostis

O nome original do ficheiro NUNCA é enviado: `_syncParcela` gera `_gerarNomeFotoParcela` = `<sanitize(prop_ut)>_P<id>_FotoParcela<nn>_<data>_<hora>.jpg`, e `_sanitizeFileName` remove tudo menos `[\w\s-]` (ASCII), colapsa espaços/hífens.

- 6a `prop_ut='../../etc/passwd'` → registo `ipnwprhxr55qe4n`, ficheiro no servidor `etcpasswd_p99_foto_parcela01_..._rrrp8xwo4k.jpg` — sem `/`, sem `..`, sem traversal. prop_ut vai como texto no campo (dado, não caminho). **PASS**
- 6b `prop_ut` com `植物<script>alert(1)</script>` + newline + `C:\temp\..\evil` + 255×A → ficheiro no servidor `ript_ctempevil_aaaa…aaa_sygdlicpjz.jpg` (115 chars, unicode/`<>`/`\`/`.` removidos, newlines colapsados). Sem injeção no nome. **PASS**
- 6c `prop_ut=''` + file_path `/…/fotos/evil\n名.jpg` (newline + unicode no nome do ficheiro, conteúdo PNG válido) → prop_ut enviado como `Sem_Identificacao` (fallback), ficheiro no servidor `p99_foto_parcela01_..._k1iongrfgn.jpg` — o nome hostil do ficheiro não chega ao servidor. **PASS**
  - Observação (low, cosmética): com prop_ut vazio o nome gerado sai sem o prefixo (`p99_…` em vez de `Sem_Identificacao_P99_…`) porque `_gerarNomeFotoParcela` sanitiza o `propUt` cru, não o fallback. Não é buraco de segurança.

## Caso 7 — 20 fotos numa parcela vs maxSelect=10

- Comando: `run_case.ps1 -Label c7 -SqlFile case_c7.sql` (20 fotos `u1..u20.jpg` com hashes de catálogo válidos e paths absolutos).
- Logcat: `statusCode: 400, code: validation_too_many_files, message: "The maximum allowed files is 10."`
- A parcela INTEIRA falha (rejeição atómica): servidor sem registo (`totalItems=0` para `t17-c7`), local fica pendente com as 20 fotos intactas, UI mostra `Falha ao enviar parcela 99` (`ui_c7.png`), app vivo. Não envia "só as 10 primeiras".
- **PASS**

## Caso 8 — hash divergente do catálogo (RC-04)

- Comando: `run_case.ps1 -Label c8 -SqlFile case_c8.sql` (ficheiro `u20.jpg` real, hash real `89c94189…`, catálogo com `deadbeef…`).
- Bloqueado NO CLIENTE antes de enviar: logcat `Exception: Hash divergente no upload (RC-04): catalogo=deadbeef… arquivo=89c94189…`; trilha local `trilha_auditoria` tem 4 registos `hash_divergente_upload` (antes=deadbeef…, depois=89c94189…); servidor `totalItems=0`; UI `Falha ao enviar parcela 99` (`ui_c8.png`); app vivo; local permanece pendente.
- **PASS**

## Conclusão

A upload de fotos resiste à bateria hostil: limites de tamanho (400 atómico até 500 MB), sniff de conteúdo (lixo/0 bytes/ZIP/EXE → 400), maxSelect (20 → 400 atómico), nomes sempre regenerados/sanitizados (sem traversal nem injeção), hash RC-04 bloqueia divergência com auditoria local, e o índice UNIQUE local impede colisão de hash vazio. Nenhum caso crashou o app nem deixou lixo no servidor. Achado cosmético (low): prefixo do nome gerado fica vazio quando prop_ut é vazio.

Gates: não se aplicam a este documento (sem mudança de código) — flutter analyze/test/build corridos na t14 (0 erros, 151/151, APK release OK).
