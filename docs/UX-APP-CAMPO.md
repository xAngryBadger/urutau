# UX-APP-CAMPO — redesenho do formulário de parcela (wizard com swipe)

**Data:** 2026-11-06 · **Status:** aprovado pelo usuário (direção A + flag nas Configurações)
**Escopo:** `urutau-app/lib/screens/parcela_form_screen.dart`, `planta_form_screen.dart`, novos widgets em `lib/widgets/`, flag em Configurações. **Fora de escopo:** servidor, sync, regras MRV, painel admin.

## Problemas (evidência em `docs/evidencias-emulador/`)
- Form único com ~12 seções empilhadas = scroll longo, informação enterrada (`43`–`46`)
- Card da planta trunca o nome: "1. Eucal…" + "Alt: 1250.0cm | DAP: 32.5cm" quebrado (`46`)
- Nome científico/popular empilhados em celular pequeno fica feio (2 campos na mesma linha)
- Chip "C1" de categoria: ninguém sabe que é categoria; mal posicionado, grande (`46`)
- Estimativa de carbono (MRV) aparece no meio do formulário, antes de concluir — confunde
- Bug: salvar sem espécie → ao digitar no campo, as sugestões não aparecem (só no 2º clique)
- "Adicionar foto" não sugere que aceita várias fotos (`44`)
- Aviso "não será sincronizada até concluir" no meio do form (`45`)
- Suspeita de performance: ListView sem itemExtent, rebuild do form inteiro a cada tecla (a medir em device real — emulador aqui é GPU de software)

## Decisão de design
**Wizard de 4 etapas com swipe** (`PageView`), ativado por flag **"modo wizard"** (default LIGADO) em Configurações; form clássico preservado como fallback. Uma etapa por tela, dedo/uma mão, luva.

### Etapas
1. **Local** — GPS (obrigatório ao concluir, manter RC-10) · Propriedade · UT/Talhão · Número · Unidade amostral (forma + área) · Projeto/Período · RS-06 (substituída por sensoriamento + fonte)
2. **Plantas** — lista + adicionar/editar (loop). Card: nome científico (1 linha, negrito) / popular (abaixo, cinza, 1 linha) sem truncar o científico; DAP e Altura como chips compactos; categoria como chip pequeno COM rótulo; editar/excluir por ícones menores
3. **Fotos** - grid N fotos ("Adicionar foto" → plural, contador), cada foto com miniatura + estado (hash verificado/pendente)
4. **Revisar** — Anotações · Verificação (só admin) · resumo da parcela · **Estimativa de carbono SOMENTE aqui** (card recolhido, com rastro do cálculo) · botão Concluir verde + Guardar rascunho

### Navegação
- `PageView` com swipe; header com stepper "1/4 … 4/4" e nome da etapa
- Botões Voltar/Continuar; ** Continuar bloqueia se a etapa atual é inválida** (mostra o motivo — mantém as mensagens atuais); swipe para trás sempre permitido; swipe para frente em etapa inválida → volta sozinho + snackbar
- Concluir só na etapa 4 com as MESMAS validações de hoje

## INVARIANTS — não podem quebrar (rigor/auditoria)
- Todo campo escrito no `concluir` continua igual: `projetoUuid`, `periodoUuid`, `protocoloVersao='SOP-MRV-V1'`, `statusParcela`, `substitutaDe`, `geoJson` (com `n_satelites_fonte`), `createdBy`
- GPS obrigatório, área > 0, plantas ≥ 1 (mensagens atuais)
- Cálculo MRV (`MrvCalcService.persistirCalculo` + `calcularParcela` com `densidadesPorEspecie`) **somente no concluir** (`prontaParaSync: true`) — nunca no rascunho
- `logAudit`/trilha em create/update inalterados; `marcarFotosEnviadasVerificadas`/`marcarAtivosVerificadosDaParcela` intactos
- Insert de foto com GPS próprio/autor/hash no catálogo (`ativos_brutos`) intacto
- Dossiê (folder_zip), exportar ZIP, delete/soft-delete, "Próxima parcela" continuam funcionando
- `_popAposSalvar`/PopScope (fix de `6728a6d`) mantido
- Foto/listas: `itemExtent`/`cacheExtent` onde der; nada de rebuild do form inteiro por tecla (isolar estado da lista de plantas)

## Aceitação
1. 4 etapas, swipe + botões, stepper visível; Continuar bloqueia com mensagem clara
2. Card da planta sem truncar científico; categoria com rótulo; DAP/Alt em chips
3. Sugestões de espécie aparecem no 1º clique/digitação (bug corrigido)
4. Estimativa MRV só na etapa Revisar
5. Flag "modo wizard" em Configurações; desligada = comportamento de hoje idêntico
6. Gates: `flutter analyze` 0 erros · `flutter test` 115+/115 · print no emulador de cada etapa
