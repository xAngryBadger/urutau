# EVIDÊNCIAS — APK no emulador (2026-11-06)

**Ambiente:** AVD `urutau_test` (android-34, google_apis x86_64) em `D:\urutau-devtools\avd`,
boot headless (`-no-window -gpu swiftshader_indirect`), `adb` em `D:\urutau-devtools\android-sdk`.
**APK:** `--profile` (instalável + asserts desligadas; o `--release` fica como artefato para o celular).
**Screenshot:** 320x640, em `docs/evidencias-emulador/`.

## Fluxo verificado

| Passo | Evidência | Resultado |
|---|---|---|
| Cold start + login por sessão local | 06 | Home como **Admin Emulador** (sem servidor — login local) |
| Lista de parcelas | 06 | Parcela seed **3 plantas / 0 fotos**, estado pendente |
| Form da parcela | 07, 08 | GPS -23.5505/-46.6333 (WGS84, "GPS do aparelho"), área 400 m², checkbox RS-06, dropdowns **Projeto/Período (P0)**, card Verificação |
| **Card MRV** | 10 | **59.9 tCO₂e/ha · 2.40 tCO₂e na parcela · 3/3 com DAP · ±60.2% (IC 95%, n=3) · IC 59.9 ± 36.1 tCO₂e/ha** · Equação Chave et al. 2014 (pantropical) · FC 0,47 · 44/12 · AGB aérea apenas · **Rastro do cálculo `#5a1355083b49…`** |
| Exportar dossiê (RC-09) | 15 | Share sheet do Android com `dossie_parcela_1_*.zip` (Drive/Gmail/Bluetooth/Nearby) |
| **Dossiê verificado** | — | ZIP com `manifesto.json` + `dados.json` + `dossie.pdf`. SHA-256 recalculado **bate 100%** com o manifesto: `dados.json=195c0301891e…`, `dossie.pdf=4e5adb800b35…`. `cadeia_local: INTEGRA`, `creditação: liberada`, `gerado_em_relogio_confiavel` com `offset_relogio_ms` |
| Concluir parcela (pronta) | 27–31 | "UT-77 — Parcela 7" (TESTE-VISUAL-UNICO), 3 plantas, GPS, área 400 → **Concluir alterações** |
| Pós-concluir no banco | — | `parcelas.pronta_para_sync=1`, `status='pendente'`; trilha `id_seq=1 acao=update entidade=emu-unica-0001`; **`calculos_mrv` persistido**: `insumos_hash=6b41ee497d67…`, `fracao_carbono=0.47`, `pools=["agb_aerea"]`, `status=valido` |
| Números auditáveis | — | `resultado`: n=3, n_com_dap=3, altura_media 12,43 m, dap_medio 31,57 cm, **agb 34,76 t/ha**, **tCO₂e_total 2,396**, **tCO₂e/ha 59,895**; `incerteza`: n=3, dp 14,52, EP 8,38, **IC95 36,07 (±60,21%)** — idênticos ao card da tela (59,9 tCO₂e/ha · ±60,2%) |
| Home pós-concluir | 35 | "1 parcela(s) pendente(s) Sincronizar" (badge 1) — parcela pronta, aguardando rede |

## Bugs encontrados e corrigidos nesta rodada

1. **`GlobalKey` duplicada no `_ErrorBoundary`** (`main.dart`): assert
   `_children.contains(child) is not true` + tela vermelha em **debug**. Trocado por
   `ValueNotifier<String?> appErrorNotifier` + `ValueListenableBuilder` (sem GlobalKey).
2. **`PopScope` sequestrava a saída após salvar** (`parcela_form_screen.dart:498`): com
   `canPop: false`, o `Navigator.pop(true)` do "Concluir alterações" era interceptado e
   aparecia **"Sair sem salvar?" mesmo tendo acabado de salvar** — e tocar em
   "Guardar rascunho" ali **revertia a parcela para rascunho** (`pronta_para_sync=0`,
   sobrescrevendo o concluir). Corrigido com `_canPop`/`_popAposSalvar()`: pop liberado
   só depois do save completar.
3. **Observação de harness (não é bug do app):** `adb shell input text` engole `@`
   (`%s` = espaço) — usei sessão injetada em prefs para testar; logs e fingerprints do
   app ficaram norminais.

## O que NÃO foi testado aqui (depende de servidor/ultra)
- Sync push/pull real (PocketBase não existe ainda — máquina formatada).
- Câmera/GPS reais do aparelho (emulador usou coordenadas semeadas).
- Alertas de satélite / CHM / NDVI (workstation ULTRA).

## Como reproduduzir
```
D:\urutau-devtools\android-sdk\emulator\emulator.exe -avd urutau_test -no-window -gpu swiftshader_indirect
flutter build apk --profile
adb install -r build\app\outputs\flutter-apk\app-profile.apk
```
Seed: usuário `admin@urutau.local` / `teste123` (hash `salt:sha256`), parcela com 3 plantas
— ver `C:\Users\Badger\AppData\Local\Temp\seed2.sql` no log da sessão.
