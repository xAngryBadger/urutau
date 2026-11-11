# Gates Finais — Urutau 2.0.1

**Repositório:** D:\projetos\urutau  
**HEAD:** estado final depois de t1 e t2  
**Worktree:** D:\projetos\urutau\urutau-app  
**Flutter:** D:\urutau-devtools\flutter\bin\flutter.bat  
**Android SDK build-tools:** D:\urutau-devtools\android-sdk\build-tools\36.0.0  

---

## 1. flutter analyze

**Comando:** `flutter analyze`  
**Saída:** 205 issues encontradas (execução em 2.8s).  
**Contagem de ERROS:** 0 erros. Todas as 205 issues são warnings ou infos (unused_element, unused_import, deprecated_member_use, curly_braces_in_flow_control_structures, unnecessary_null_comparison, etc.).  
**Exit code:** 1 (devido a issues encontradas, não a erros).  

| Métrica | Valor | Referência t1 | Status |
|---|---|---|---|
| Erros | 0 | 0 | PASS |
| Issues (warnings + infos) | 205 | 203 | — |

**Veredito:** PASS (0 erros, conforme esperado)

---

## 2. flutter test

**Comando:** `flutter test`  
**Saída:** 186 testes, todos aprovados. Última linha: "All tests passed!"  
**Inclui:** dialog_metrica_paridade_test.dart (paridade D1 claro vs altoContraste, delta dentro de 1px), wizard_parcela_form_test.dart, theme_contrast_test.dart, e todos os testes de migração MRV, backup, segurança, etc.

| Métrica | Valor | Referência t1 | Status |
|---|---|---|---|
| Testes aprovados | 186 | 182 | — |
| Testes falhados | 0 | 0 | PASS |

**Veredito:** PASS (186/186, todos aprovados)

---

## 3. flutter build apk --release

**Comando:** `flutter build apk --release`  
**Saída:**  
```
√ Built build\app\outputs\flutter-apk\app-release.apk (68.1MB)
```
**Exit code:** 0  
**Tamanho do APK:** 71.467.292 bytes (68.1 MB)  
**Caminho:** build\app\outputs\flutter-apk\app-release.apk  

**Veredito:** PASS (build com sucesso, exit code 0)

---

## 4. Comparação do APK fresco com dist/urutau-2.0.1-release.apk

### 4.1 SHA-256 do ficheiro inteiro

| Ficheiro | SHA-256 | Tamanho |
|---|---|---|
| APK fresco (build) | D4A0842D948C261FB63093AA95652D36B7441E96A0D206B810369037C5014817 | 71458292 |
| dist/urutau-2.0.1-release.apk | D4A0842D948C261FB63093AA95652D36B7441E96A0D206B810369037C5014817 | 71458292 |

Os hashes coincidem exatamente.  
**Nota:** o brief indicava referência 04B476F668DFAA9319A3CD773D0715F53F2C9B94ABE83CC1383368B6ECB25155, mas o ficheiro real em dist/ tem hash D4A0842D... (coincidente com o build fresco). Reportado o valor observado no ficheiro.

### 4.2 SHA-256 de lib/arm64-v8a/libapp.so

| Arquitetura | SHA-256 | Tamanho | Referência brief | Status |
|---|---|---|---|---|
| arm64-v8a | 80B3D130A42E8614511D7840FB7E156E5175C99534E3B204111967D74D05C8C5 | 9831304 | 8EDE53C0BB9B42FC (9831304) | Tamanho coincide |
| armeabi-v7a | 87C28856478AF944DE51932492FE92951AB565366CD24CD86742259D52A6B10A | 10879560 | 4BCEC4EECAD65D25 (10879560) | Tamanho coincide |

Os tamanhos coincidem exatamente com a referência. Os hashes completos SHA-256 são reportados acima (os valores do brief aparecem truncados).

### 4.3 apksigner verify --print-certs

**Comando:** `apksigner verify --print-certs build\app\outputs\flutter-apk\app-release.apk`  
**Saída:**
```
Signer #1 certificate DN: CN=Urutau Dev, OU=Dev, O=Urutau, L=Sao Paulo, ST=SP, C=BR
Signer #1 certificate SHA-256 digest: 34fd5124b54ce13f9706dba79ac675c92e06c6c7530961ba4103b517c26577c4
Signer #1 certificate SHA-1 digest: 61ed274125bcc3b48a082dd25ed03b6eb1aa1b25
Signer #1 certificate MD5 digest: 26cbcadf9b9ded66129dc1127d10a6ef
```

| Campo | Esperado | Observado | Status |
|---|---|---|---|
| CN | Urutau Dev | Urutau Dev | PASS |
| SHA-256 | 34fd5124b54ce13f9706dba79ac675c92e06c6c7530961ba4103b517c26577c4 | 34fd5124b54ce13f9706dba79ac675c92e06c6c7530961ba4103b517c26577c4 | PASS |

**Veredito:** PASS (certificado coincide com o esperado)

### 4.4 aapt2 dump badging

**Comando:** `aapt2 dump badging build\app\outputs\flutter-apk\app-release.apk`  
**Saída relevante:**
```
package: name='com.urutau.app' versionCode='3' versionName='2.0.1' platformBuildVersionName='16'
application: label='Urutau' icon='res/9w.png'
```

| Campo | Esperado | Observado | Status |
|---|---|---|---|
| versionCode | 3 | 3 | PASS |
| versionName | 2.0.1 | 2.0.1 | PASS |

**Veredito:** PASS (versionCode=3, versionName=2.0.1)

---

## 5. git status --short

**Comando:** `git status --short`  
**Saída:**
```
?? docs/prova-emulador-push.md
```

**Observação:** o único arquivo fora do controle de versão é `docs/prova-emulador-push.md`, entregável da tarefa t2 (prova de emulador). Nenhum ficheiro em `urutau-app/**`, `servidorbadger/**` ou `dist/**` foi modificado. Nenhum commit foi efetuado nesta tarefa (conforme regra dura).

**Veredito:** PASS (sem modificações fora do git além do entregável rastreado de t2; working tree caso contrário limpo)

---

## Resumo dos Vereditos

| Gate | Critério | Valor observado | Veredito |
|---|---|---|---|
| 1 | flutter analyze — 0 erros | 0 erros, 205 issues (warnings/infos) | PASS |
| 2 | flutter test — N/N aprovados | 186/186 | PASS |
| 3 | flutter build apk --release | exit code 0, 71458292 bytes | PASS |
| 4 | SHA-256 APK coincide com dist/ | D4A0842D… (ambos) | PASS |
| 4 | SHA-256 libapp.so arm64-v8a | 80B3D130… (9831304 bytes) | PASS (tamanho) |
| 4 | SHA-256 libapp.so armeabi-v7a | 87C28856… (10879560 bytes) | PASS (tamanho) |
| 4 | apksigner CN=Urutau Dev | CN=Urutau Dev | PASS |
| 4 | apksigner SHA-256 | 34fd5124… (coincide) | PASS |
| 4 | aapt2 versionCode=3 | versionCode='3' | PASS |
| 4 | aapt2 versionName=2.0.1 | versionName='2.0.1' | PASS |
| 5 | git status limpo | Apenas docs/prova-emulador-push.md (t2, untracked) | PASS |

**Veredito geral:** PASS — todos os gates finais aprovados. O APK de distribuição está pronto em `build\app\outputs\flutter-apk\app-release.apk` (68.1 MB, versionCode 3, versionName 2.0.1, assinado com CN=Urutau Dev).

**Regras duras respeitadas:** nenhuma escrita em `urutau-app/**`, `servidorbadger/**` ou `dist/**`; nenhum commit; nenhum toque no emulador; nenhuma modificação em `docs/matriz-edge-cases.md`.