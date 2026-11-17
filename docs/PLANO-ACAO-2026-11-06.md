# PLANO DE AÇÃO — 2026-11-06 (pós-fechamento P1/P2 do app)

Contexto: servidor PocketBase **não existe ainda** (máquina formatada; sobe só no lançamento).
Consequência: o app tem que funcionar 100% offline e o sync falha graciosamente. O emulador
fica como verificação visual (AVD já existe em `D:\urutau-devtools\avd\urutau_test`).

**Estado atual:** `main` em `95909cb` · analyze 0 erros · **115/115 testes** · todos P1/P2 do app fechados
(`docs/AUDIT-GAPS-P1P2.md`, seção de atualização no topo).

---

## F1 — sha256_verificado pós-upload ✅ FEITO AGORA
`95909cb`: `marcarAtivosVerificadosDaParcela` liga `sha256_verificado=true` nos ativos com hash
após sync dar certo (os 2 caminhos: syncAll e push individual). Teste `rc04_pos_upload_test.dart`.

## F2 — Build do APK + emulador + verificação visual
Objetivo: APK real instalado no AVD `urutau_test` e app aberto nas telas-chave, com screenshot.

1. `flutter build apk --release` em `urutau-app` (workdir padrão, Flutter `D:\urutau-devtools\flutter`).
   Se o release quebrar por assinatura, cai pro `--profile` só p/ teste visual.
2. Boot do emulador: `D:\urutau-devtools\android-sdk\emulator\emulator.exe -avd urutau_test -no-window -gpu swiftshader_indirect` (background job), esperar `adb wait-for-device` + boot completo (`sys.boot_completed`).
3. `adb install -r <apk>` → `adb shell am start` no pacote → navegar: login → home → criar parcela → MRV → dossiê.
4. Evidência: `adb exec-out screencap -p` em cada tela → salvar em `docs/evidencias-emulador/` + `adb logcat` filtrado.
5. Como não há servidor: confirmar que o app abre, cria parcela offline, calcula carbono e gera dossiê **sem** sync (modo offline forçado já existe em Configurações).
6. Gate: APK instala sem erro, telas-chave abrem, dossiê exporta no emulador, 0 crash no logcat.

## F3 — Auditoria do urutau-admin (web) + SPEC do painel do verificador
O verificador usa o painel web; hoje as páginas são: `Dashboard, Login, Parcels, Photos, Reports, Users`
(`urutau-admin/src/pages/`), layout em `components/Layout.jsx`.

1. Varredura read-only contra o mapa MRV (mesmo método do AUDIT-GAPS): o que o painel **precisa** ter
   p/ um VVB auditar: lista de parcelas por status (pendente/revisado/aprovado) com filtro, fotos por
   parcela com hash/GPS/timestamp/dono (fotos_meta), download do **dossiê (ZIP com manifesto)** por
   parcela e em lote, trilha de auditoria verificável (cadeia de hashes + botão "verificar cadeia no
   servidor"), incidentes abertos com resolver, botão de **bloquear crédito**, papel verificador
   read-only (PAPEL-VERIF), dados do projeto (baseline/adicionalidade/risco de reversão).
2. Entregável: `docs/SPEC-ADMIN-VERIFICADOR.md` (requisitos + o que já existe + gaps) e
   `docs/AUDIT-ADMIN-GAPS.md` com `arquivo:linha`.
3. Servidor inexistente hoje → painel deve funcionar com dados mock/fallback e indicar "servidor offline".

## F4 — Redesenho do layout do admin usando as skills de design
Skills equivalentes no catálogo local (mesmos autores dos links):
- `impeccable` (pbakaus/impeccable) — governar redesign/polish do painel
- `design-taste` (Leonxlnx/taste-skill) — direção visual anti-genérica
- `emil-design-eng` (emilkowalski) — polimento de componentes/detalhes
- `ui-ux-governance` — Obrigatoria p/ qualquer mudança de UI

1. Extrair tokens do app Flutter (`lib/theme/app_tokens.dart`: verde-sálvia `0xFF5A6B5C`, bege `0xFFC4A47C`, HC amarelo `0xFFFFD600`, status âmar/azul/verde) → criar `src/theme/tokens.css` no admin (mesma identidade visual app↔painel).
2. Redesenhar `Layout.jsx` (nav lateral, header com status do servidor/sync, modo alto contraste) e as 6 páginas com os componentes novos.
3. Dark mode opcional; garantir contraste WCAG AA (HC mode do app).
4. Gates: `npm run build` (Vite) sem erro, `eslint` limpo, screenshots das páginas (Posso rodar o Vite dev e capturar via browser tool desta sessão).

---

## Ordem de execução proposta
1. **F1** ✅ (feito, `95909cb`)
2. **F2** APK + emulador (verificação visual do app)
3. **F3** spec + auditoria do admin
4. **F4** redesign do admin guiado pelas skills (depois da spec, p/ não redesenhar no escuro)

## Fora de escopo (mantido)
Servidor de produção (só no lançamento), ponte ULTRA, alertas de satélite, ML ano 1, decisão Verra/Gold.
