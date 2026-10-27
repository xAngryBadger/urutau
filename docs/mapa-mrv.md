# Mapa de Obrigações Técnicas MRV/SBCE → Requisitos de Produto

**Projeto:** Urutau / Flora Sensus (app Flutter + painel React + PocketBase)
**Data:** 2026-10-22
**Autor:** especialista-mrv (team urutau-update, task t4)
**Público:** Badger (dev), time de auditoria (t1/t2/t3), consolidação t5
**Status:** entregável de trabalho. Itens marcados **[A CONFIRMAR]** exigem leitura do texto primário antes de virarem compromisso com cliente.

---

## 0. Como ler este documento

Este documento faz três coisas, nesta ordem:

1. **Corrige o estado regulatório real** (o que a sessão de 15/10 afirmou sobre SBCE, o que continua válido e o que mudou).
2. **Separa três naturezas de exigência** — regulatória, de metodologia de crédito e boa prática de engenharia — porque confundir as três é o que produz promessa comercial furada.
3. **Converte cada obrigação em requisito de produto**, com evidência do estado atual do código do Urutau e severidade do gap.

Regra de ouro deste time (registrada na sessão de 15/10): **toda afirmação técnica carrega evidência**. Onde não há fonte primário lido, o item está marcado. Nada aqui foi inventado para "fechar" o documento.

### Resumo executivo (5 linhas)

- O Urutau hoje **não tem MRV**: captura parcela/planta/DAP/altura/categoria/foto, mas **não registra geo da parcela (GPS desativado no formulário), não tem hash de arquivo, não tem versão de pipeline de processamento, não quantifica carbono e não produz dossiê de verificação**.
- O achado mais grave para auditoria **não é a ausência de cálculo de carbono** — é a **custódia do dado bruto**: hoje só a foto *comprimida* sobe ao servidor; o original full-res fica só no celular, sem hash, sem retenção definida e **ninguém sabe onde os arquivos estão**.
- A regulamentação MRV do **SBCE ainda está em consulta pública/consolidação em 2026** (ciclo fechado em 28/08/2026). Portanto: **não se deve vender "conformidade SBCE"**; vende-se "audit-ready para padrão voluntário + prontidão para o SBCE".
- O SBCE regulado cobre, na minuta consultada, **fontes de emissão industrial** — restauração florestal entra pela via do **mercado voluntário** (Verra/Gold Standard), que é *mais exigente em evidência*. É lá que o produto precisa mirar.
- 90% dos requisitos MRV do Urutau são **metadados e governança**, não algoritmo. Ou seja: são baratos. O caro (drone, alometria, ML) é o de menos.

---

## 1. Estado regulatório — o que foi verificado

### 1.1 Linha do tempo confirmada (com fonte)

| Marco | O que é | Fonte |
|---|---|---|
| **Lei 14.299/2022** | Política Nacional sobre Mudança do Clima; base legal original do SBCE | planalto.gov.br — *caminho não acessado nesta sessão (fetch falhou); marco conhecido, **confirmar texto*** |
| **Decreto 11.155/2022** | Primeira regulamentação do SBCE e do registro público de emissões | planalto.gov.br — *idem, **A CONFIRMAR** o texto e o limite de 25.000 tCO₂e/ano* |
| **Lei 15.042/2024** (11/12/2024) | **Institui o SBCE** e o mercado regulado de carbono no Brasil (*cap-and-trade*); altera Leis 12.187/2009, 12.651/2012 (Código Florestal), 6.385/1976 (CVM) e 6.015/1973 (Registros Públicos) | [planalto.gov.br/ccivil_03/_ato2023-2026/2024/lei/l15042.htm](https://www.planalto.gov.br/ccivil_03/_ato2023-2026/2024/lei/l15042.htm) · [legislacao.presidencia.gov.br](https://legislacao.presidencia.gov.br/atos/?tipo=LEI&numero=15042&ano=2024&data=11/12/2024) |
| **28/07/2026 — consulta pública** | Minuta de Portaria da Secretaria Extraordinária do Mercado de Carbono (SEMC/MF) definindo as **etapas das obrigações de MRV** no SBCE | [Trench Rossi Watanabe, 31/07/2026](https://www.trenchrossi.com/alertas-legais/sbce-consulta-publica-plano-de-monitoramento-e-de-efetivo-monitoramento-relato-e-verificacao-mrv/) · [gov.br/fazenda](https://www.gov.br/fazenda/pt-br/assuntos/noticias/2026/julho/aberta-consulta-publica-sobre-proposta-de-cronograma-para-monitoramento-relato-e-verificacao-mrv)-no-mercado-regulado-de-carbono) |
| **28/08/2026 — fim da consulta** | Encerra o **primeiro ciclo de regulamentação** do mercado de carbono brasileiro | [Brasil Participativo — Obrigações de MRV no âmbito do SBCE](https://brasilparticipativo.presidencia.gov.br/processes/obrigacoesmrvsbce) · [Conecta Info, 02/09/2026](https://conectainfo.net/2026/09/02/323969-consulta-publica-fecha-primeiro-ciclo-do-sbce/) |

**Texto confirmado da base governamental (Brasil Participativo, lido em 22/10/2026):**

> "As obrigações de MRV constituem a base para a implementação do SBCE. É essencial que as informações sobre as emissões sejam produzidas de forma consistente, transparente e submetidas à verificação independente."

### 1.2 O que a nota técnica anterior (MRV-Digital-Viabilidade-Tecnica) acertou e errou

| Afirmação da sessão de 15/10 | Veredito |
|---|---|
| "Lei 15.042/24 criou o SBCE" | **Ajustar.** A Lei 15.042/2024 *institui* o SBCE e o mercado regulado cap-and-trade; a criação original remonta à Lei 14.299/2022. Na comunicação comercial, usar "SBCE (Lei 15.042/2024)". |
| "Registro central em jan/2026; regras completas até dez/2026" | **Parcialmente certo e já defasado.** Em 22/10/2026 o ciclo de regulação do **MRV** fechou em 28/08/2026; as Portarias finais e seu escopo setorial ainda estavam em consolidação. Data exata de vigência: **[A CONFIRMAR]** no DOU. |
| "Quem emite >25 mil tCO₂e/ano precisa de MRV auditável" | **Plausível, não verificado aqui.** Limite usualmente citado do Decreto 11.155/2022 para o registro público de emissões. **Confirmar texto** antes de usar em proposta. |
| "Restauração tem credibilidade reforçada para gerar CRVEs" | **Não verificado.** O termo/conceito não pôde ser confirmado em fonte oficial nesta sessão. **Não usar em material comercial** até confirmar no texto da Lei 15.042/2024 e na Portaria final. |
| "MRV auditável é o diferencial vs. o app atual" | **Correto e permanece a tese central.** |
| Stack "Next.js + Supabase free tier" | **Obsoleto** (ver §5.0). |

### 1.3 A distinção que decide o escopo do produto

Isto é o achado estratégico mais importante do mapa:

```
┌─────────────────────────────────────────────────────────────┐
│  SBCE (mercado REGULADO)                                    │
│  Minuta de Portaria MRV em consulta (2026)                  │
│  Escopo = FONTES DE EMISSÃO industrial:                     │
│    Etapa 1 (A1 a partir de 2027): alumínio primário/alumina,│
│      ferro-aço integrado, cimento, E&P de petróleo e gás,   │
│      refino, papel e celulose, transporte aéreo             │
│    Etapa 2 (A1 até 2029): alumínio secundário, aço semi-    │
│      integrado, química, mineração, alimentos e bebidas,    │
│      resíduos, esgoto, cerâmica, vidro, setor elétrico      │
│    Etapa 3 (A1 até 2031): aquaviário, ferroviário, rodoviário│
│  → Restauração florestal / remoções NÃO está nesse escopo.  │
├─────────────────────────────────────────────────────────────┤
│  MERCADO VOLUNTÁRIO (Verra VCS, Gold Standard, CCB, ART)    │
│  É aqui que crédito de restauração florestal é gerado hoje. │
│  Exige: PD + Relatório de Monitoramento + verificação       │
│  independente por VVB acreditada.                           │
│  → É AQUI que o Urutau precisa ser audit-ready.             │
└─────────────────────────────────────────────────────────────┘
```

**Consequência de produto:** o Urutau deve ser construído para o **padrão voluntário (mais rigoroso em evidência)** e manter **prontidão de plug-in** para o registro público federal quando remoções entrarem no escopo. Isso é bom negócio: atende hoje, não fica obsoleto amanhã.

---

## 2. As três naturezas de exigência (e por que separar)

| Natureza | Quem impõe | Consequência de descumprir | Como tratamos no produto |
|---|---|---|---|
| **Regulatória** | Lei/Decreto/Portaria (SBCE, Código Florestal, CAR, LGPD) | Sanção administrativa, crédito inválido, exposição legal | Requisitos não negociáveis (R-xx marcados `REG`) |
| **Metodologia de crédito** | Verra VCS, Gold Standard, CCB, ART/TREES, metodologia escolhida | Emissão de crédito negada na verificação | Requisitos de aderência (`MET`) |
| **Boa prática de engenharia** | Ninguém "exige" — mas é o que sustenta as duas acima | Evidência não reproduzível, laudo do VVB inconclusivo | Requisitos de qualidade (`BP`) |

> **Aviso de método.** Os padrões de crédito publicam seus requisitos em **PDF**. Nesta sessão `web_search` estava indisponível (sem chave de API) e `web_fetch` **não processa PDF**. Portanto: as exigências abaixo vêm de páginas HTML oficiais que **foi possível ler**, e os PDFs estão citados como fonte a consultar. Onde um número de prazo de retenção não pôde ser lido, ele está marcado **[A CONFIRMAR]** — não inventamos "7 anos" porque soa razoável.

---

## 3. Obrigações decompostas → requisitos

### 3.1 CUSTÓDIA E LINHAGEM DO DADO BRUTO (achado central do capitão)

**Contexto do capitão (incorporado ao mapa):** o Urutau ficou abandonado; a hospedagem planejada (Supabase) não existe mais; a stack real é PocketBase local + arquivos em disco; **hoje ninguém sabe como acessar as imagens que a equipe sobe** — a equipe só sabe exportar.

**O que o código confirma** (`image_service.dart`, `sync_service.dart`):

| # | Evidência no código | Consequência MRV |
|---|---|---|
| 1 | `ImageService.compressImage` gera JPEG *quality 70, máx 1920×1080*; `sync_service.dart:1386-1393` envia `foto.compressedPath ?? foto.filePath` — **só o comprimido sobe** | O **arquivo bruto (raw) nunca sai do celular**. Se o aparelho for trocado/perdido, a evidência primária desaparece. |
| 2 | `ImageService.savePhotoLocally` copia para `<appDocuments>/fotos/<uuid>.jpg` — caminho absoluto do aparelho, sem vínculo externo | Sem catálogo de onde o bruto está; "ninguém sabe acessar". |
| 3 | `cleanCompressedPhotos()` **apaga a pasta `compressed/` inteira** após sync OK | Destruição do intermediário; sem capacidade de reprocessamento. |
| 4 | `deletePhoto()` chamado em edição/remoção de foto (`parcela_form_screen.dart:962,1031,1038,1190,1194`; `explorer_screen.dart:1863,1867,1941,1945`) | Exclusão destrutiva sem rastro de lixeira para arquivos. |
| 5 | Nome do arquivo gerado em `_gerarNomeFotoParcela`/`_gerarNomeFotoPlanta` (UT_P05_FotoParcela01_2026-02-18_14h30.jpg) — **minuto, não segundos**; nome original perdido | Precisão temporal insuficiente; impossível auditar ordem de eventos. |
| 6 | `planta.createdAt`/`parcela.createdAt` vêm do **relógio do dispositivo**, sem selo de tempo confiável | Relógio do celular é ajustável — não serve como evidência de tempo sem atestado. |
| 7 | Push de plantas **deleta e recria** todas as plantas no servidor (`sync_service.dart:1415-1486`) | Histórico de alteração destruído; verificação de "o que mudou" impossível. |
| 8 | **Nenhum hash** em nenhum ponto do fluxo (`crypto` já está no pubspec!) | Impossível provar que o arquivo auditado é o mesmo coletado. |

#### Requisitos de custódia (R-CUSTODIA)

| ID | Requisito | Natureza | Critério de aceite | Prio |
|---|---|---|---|---|
| `RC-01` | **Catálogo de ativos brutos**: toda imagem/dado bruto tem registro com caminho lógico estável, hash SHA-256, tipo MIME, bytes, dispositivo, operador e data/hora da captura | BP (sustenta MET) | Para 100% dos arquivos ingeridos existe linha de catálogo consultável | **P0** |
| `RC-02` | **Upload do bruto + preservação do derivado**: o pipeline arquiva o arquivo original (ou um "near-raw" explicitamente rotulado) e o derivado comprimido, com hash dos dois | BP | Raw recuperável por hash em qualquer ponto do pipeline | **P0** |
| `RC-03` | **Nada de exclusão destrutiva**: soft-delete em todas as entidades; arquivo só removido após política de retenção explícita | BP/MET | Nenhum `File.delete()` em fluxo de usuário; lixeira + `deletedAt` | **P0** |
| `RC-04` | **Hash na origem**: SHA-256 calculado no aparelho **antes** do upload e verificado no servidor após ingestão | BP | Falha de hash ⇒ upload rejeitado e sinalizado | **P0** |
| `RC-05` | **Tempo confiável**: capturar hora do dispositivo + hora do servidor no ingresso; armazenar delta de relógio; rejeitar/alertar Δ > limiar | BP | Todo registro tem `deviceClockOffsetMs` | **P1** |
| `RC-06` | **Imutabilidade do ingerido**: modo append-only/WORM ou log encadeado por hash para dados já sincronizados | BP | Alteração em dado sincronizado gera nova versão + registro de auditoria, nunca overwrite silencioso | **P1** |
| `RC-07` | **Retenção definida e aplicada**: política escrita (anos), tiering (quente → frio → HD externo), verificação periódica de legibilidade | **[A CONFIRMAR]** prazo por metodologia; ver §3.2 | Política versionada + relatório mensal de integridade dos arquivos | **P1** |
| `RC-08` | **Rastreabilidade de pipeline**: cada campo derivado carrega `pipelineVersion`, `algorithmVersion`, `inputs` (hashes) e `executedAt` | BP | Dado derivado sem linhagem é rejeitado na exportação de dossiê | **P1** |
| `RC-09` | **Acesso verificador**: papel read-only para VVB, com consulta por parcela/UTC e download em lote com manifesto de hashes | MET | Verificador externo baixa pacote auto-verificável sem falar com dev | **P1** |

#### Onde esses requisitos quebram no Urutau hoje

- **App (`urutau-app`)**: viola RC-01..RC-05, RC-08. É a origem da evidência — a correção é aqui ou não é correção.
- **Servidor (`servidorbadger`)**: hoje o PocketBase guarda arquivos em `pb_data/storage/` com nome interno próprio, sem catálogo_hash. Viola RC-01, RC-06.
- **Painel (`urutau-admin`)**: não expõe catálogo de arquivos, hash nem linhagem — é onde a "equipe não sabe acessar" se manifesta. Viola RC-09.
- **Pipeline de derivação**: hoje **não existe** (não há CHM/NDVI/alometria ligados). RC-08 nasce junto com o pipeline — mais barato agora do que retrofit depois.

### 3.2 Retenção e rastreabilidade: o que se exige, com fonte

Tabela exigida pelo capitão. Separando **regulatório** de **boa prática**, com URL.

| # | Exigência | Fonte / quem exige | Natureza | Status da verificação |
|---|---|---|---|---|
| E-01 | Registrar **todos os dados e parâmetros monitorados** no Relatório de Monitoramento, e submetê-los a verificação por VVB aprovada | [Verra — Project Description and Monitoring Report](https://verra.org/programs/verified-carbon-standard/project-description-and-monitoring-report/) | Metodologia | ✅ **Lido** (HTML) em 22/10/2026 |
| E-02 | Verificação independente por VVB acreditada; VVB confirma que os resultados "foram alcançados e quantificados conforme os requisitos do padrão"; sanções a VVB por não-conformidade | [Verra — Validation and Verification](https://verra.org/validation-verification/) | Metodologia | ✅ **Lido** (HTML) |
| E-03 | Documento normativo mãe do VCS (regras de monitoramento, parâmetros, fórmulas) | [VCS Standard v4.7 (PDF)](https://verra.org/documents/vcs-standard-v4-7/) · [Monitoring Report Template v4.4 (DOC)](https://verra.org/documents/vcs-monitoring-report-template-v4-4/) | Metodologia | ⚠️ **PDF/DOC não lido** — `web_fetch` não processa. Ler antes de citar número de prazo. |
| E-04 | Requisitos centrais do padrão (monitoramento, evidência, papéis) | [Gold Standard for the Global Goals — Principles & Requirements v2.0, release 31.01.2025](https://globalgoals.goldstandard.org/101-par-principles-requirements/) · [PDF](https://globalgoals.goldstandard.org/standards/101_V2.0_PAR_Principles-Requirements.pdf) | Metodologia | ⚠️ Página ✅ lida; **PDF não lido** |
| E-05 | Padrão de aplicação dos requisitos GS4GG a **soluções dMRV digitais** (é o nosso caso!) | [Gold Standard — DMRV Pilot Programme: "Application of GS4GG Requirements with dMRV Solution"](https://globalgoals.goldstandard.org/standards/DMRV-Programme-DMRV-Requirements-pilot-v0.1.pdf) · [página do programa](https://globalgoals.goldstandard.org/digital-measurement-reporting-verification-pilot-programme/) | Metodologia | ⚠️ Programa ✅ lido (piloto ativo até **30/10/2026**); **PDF de requisitos não lido** |
| E-06 | MRV "consistente, transparente e submetida a verificação independente" como base do SBCE | [Brasil Participativo — Obrigações de MRV no SBCE](https://brasilparticipativo.presidencia.gov.br/processes/obrigacoesmrvsbce) | **Regulatório** | ✅ **Lido** |
| E-07 | Plano de Monitoramento aprovado pelo órgão gestor (A1) → monitoramento efetivo (A2) → Relatório de Emissões e Remoções **verificado** (A3+) | [Trench Rossi, 31/07/2026](https://www.trenchrossi.com/alertas-legais/sbce-consulta-publica-plano-de-monitoramento-e-de-efetivo-monitoramento-relato-e-verificacao-mrv/) | **Regulatório** | ✅ **Lido** |
| E-08 | Prazo numérico de retenção de evidências/dados brutos (anos) e regra de guarda | VCS Standard / GS4GG / Portaria SBCE — **textos não lidos** | Metodologia + Regulatório | ❌ **[A CONFIRMAR]** — **não inventar número**. Ação: baixar os 3 PDFs e extrair a cláusula. |
| E-09 | Hash SHA-256, log encadeado, WORM, catálogo com dispositivo/operador | Nenhuma norma exige por nome. É o **meio técnico** de satisfazer E-01..E-04 de forma demonstrável | **Boa prática de engenharia** | ✅ justificativa técnica própria (ver §3.1 RC-xx) |

**Leitura honesta de E-08.** O mercado de carbono em geral e as normas ISO/GHG Protocol tratam retenção de registros, mas os prazos variam por padrão e por jurisdição. Como os PDFs primários não foram legíveis nesta sessão, o entregável **assume a política mais conservadora como padrão de projeto** e **não a divulga como obrigação**:

> **Política de retenção interna adotada (decisão de projeto, não citação de norma):** manter **todo bruto + metadados + linhagem por toda a vigência do projeto de crédito + 7 anos**, com verificação anual de legibilidade. Se a metodologia escolhida exigir mais, o limite sobe; se exigir menos, mantemos o nosso — retenção longa não cria passivo, retenção curta cria laudo negativo.

O que **pode** ser dito ao cliente hoje, sem risco: *"o sistema preserva o arquivo bruto com hash e linhagem completa, e o verificador externo consegue reproduzir o caminho do dado até a medição de campo"*. O que **não** pode: *"atende a exigência de retenção de X anos da norma Y"* — antes de ler a norma Y.

### 3.3 Qualidade e rastreabilidade da medição de campo

Ações: medição auditável (R-CAMPO)

| ID | Requisito | Estado atual (evidência) | Gap | Prio |
|---|---|---|---|---|
| `RC-10` | **Geo obrigatória por parcela** com lat/long, acurácia em metros, nº de satélites/fix, datum/CRS declarado, timestamp do fix | `parcela_form_screen.dart:5-6,124-125,1202-1203`: geolocator **comentado/removido** ("[GPS DESATIVADO - MANUTENÇÃO]") e grava `latitude: null, longitude: null`. `geolocator` **não está mais no pubspec**. | **BLOQUEADOR MRV.** Sem geo não há parcela auditável; amostragem vira afirmação sem lastro. | **P0** |
| `RC-11` | **Protocolo de medição versionado** (SOP): regra de DAP, altura, categoria, inclusão/exclusão, unidade | Regras espalhadas na UI (`categoria_helper.dart`, `parcela_form_screen.dart`, `planta_form_screen.dart`); sem identificador de versão de protocolo no registro | Requisitos de metodologia: parâmetros monitorados precisam ser rastreáveis ao método. | **P1** |
| `RC-12` | **Catálogo de espécies oficial e fechado**, com densidade básica de madeira por espécie | Já diagnosticado em `ANALISE_DETALHADA_APP.md` §5.1/§6: asset `dados_especies.xlsx` ausente, campo aceita texto livre, fallback mistura nomes | Espécie define ρ → biomassa. Espécie errada = carbono errado, na fonte. | **P0** |
| `RC-13` | **Metadados de instrumento**: dispositivo, modelo, versão do app, operador, treinamento | Só `userId`/`createdBy` em texto livre | Reprodução de medição exige saber com o que e por quem. | **P1** |
| `RC-14` | **Foto atrelada à medição com hash e geo** (foto da parcela e da espécie NI) | Foto existe; sem hash, sem EXIF preservado, sem geo por foto | Evidência visual sem lastro técnico. | **P1** |

Nota de correção importante: a nota técnica anterior dizia "GPS na parcela" como capacidade do app. **Hoje não é verdade** — está desativado. Qualquer material que prometa geo deve ser revisado.

### 3.4 Projeto de amostragem e incerteza

| ID | Requisito | Estado atual | Prio |
|---|---|---|---|
| `RS-01` | Desenho de amostragem explícito: área da parcela (m²), formato/raio, densidade (1 parcela / X ha), % da área amostrada, critério de posicionamento | `areaHa` é **campo manual, opcional, nullable** (`database.dart:35`); não dimensão de parcela em m² nem forma geométrica | **P0** |
| `RS-02` | **Identidade permanente da parcela**: marcador/estaca + ID estável entre campanhas | `uuid` local remapeado após push (`remapParcelaUuid`); id seria fragilizado por re-seed e reimportação | **P0** |
| `RS-03` | **Incerteza quantificada**: erro amostral (±%), intervalo de confiança, n, propagação para tCO₂e | Inexistente | **P0** |
| `RS-04` | Metas de erro declaradas. Sessão de 15/10 fixou: altura de parcela 8–15 cm RMSE; biomassa por parcela 6–12% RMSE (Verra/VCS e Gold Standard tolerariam 15–20%) | Inexistente — só serve como **meta de projeto**, confirmar contra metodologia escolhida | P1 |
| `RS-05` | Estratificação documentada (UT, idade, material genético, manejo) | Hierarquia existe (`propriedade→UT→parcela`) mas sem semântica de estrato | P1 |
| `RS-06` | Amostragem híbrida campo+drone: 1 parcela/10–20 ha, 0,1–0,5% da área | Inexistente | P2 |

### 3.5 Quantificação: alometria e carbono

| ID | Requisito | Estado atual | Prio |
|---|---|---|---|
| `RQ-01` | Equação alométrica identificada e versionada (bioma/IPCC), com fonte bibliográfica | **Inexistente** — nenhuma linha de carbono no Urutau (confirmado na sessão de 15/10 por grep: 17 matches, todos acidentais) | **P0** |
| `RQ-02` | Fração de carbono aplicada (0,47) e fator de conversão (44/12) explícitos no registro do cálculo | Inexistente | P0 |
| `RQ-03` | Densidade básica por espécie vinculada ao catálogo oficial | Inexistente | P0 |
| `RQ-04` | Cálculo reproduzível: mesma entrada ⇒ mesmo tCO₂e, com hash do resultado | Inexistente | P1 |
| `RQ-05` | Separação de pools (árvore, sub-bosque, serapilheira, solo) declarada — inclusive o que **não** foi medido | Inexistente | P1 |
| `RQ-06` | Ponto de vista de "zero ML no ano 1": alometria publicada; ML só com ciclo pareado campo+drone | Alinhado à decisão da sessão; manter | — |

### 3.6 Governança, papéis e QA/QC

| ID | Requisito | Estado atual | Prio |
|---|---|---|---|
| `RG-01` | **Separação de funções**: quem mede ≠ quem aprova ≠ quem reporta | App tem `isAdmin` único; sem papel de revisor/verificador interno | P0 |
| `RG-02` | **Fluxo de aprovação** com trilha (pendente → revisado → aprovado → rejeitado + justificativa) | `ROADMAP` propôs `parcelas_pendentes`/`parcelas_aprovadas` — **não implementado** | P0 |
| `RG-03` | **Re-amostragem/verificação interna**: % de parcelas re-medidas por supervisor, com resultado | Inexistente | P1 |
| `RG-04` | **Auditoria completa e encadeada**, sincronizada ao servidor, à prova de edição retroativa | `AuditLog` existe **só no banco local** (`database.dart:75-83, 870-893`), não sobe no sync, sem encadeamento por hash | P0 |
| `RG-05` | Registro de treinamento/competência do operador | Inexistente | P2 |
| `RG-06` | Gestão de incidentes (dado suspeito, relógio adulterado, foto faltante) com bloqueio de uso para crédito | Inexistente | P1 |

### 3.7 Temporalidade: permanência e monitoramento

| ID | Requisito | Estado atual | Prio |
|---|---|---|---|
| `RT-01` | Identificação do **período de monitoramento** e vínculo da parcela a ele | `createdAt`/`updatedAt` soltos, sem entidade "campanha/período" | P0 |
| `RT-02` | Revisita da mesma parcela em intervalos definidos | Inexistente | P1 |
| `RT-03` | Evidência de permanência/anti-reversão (fogo, desmatamento, corte) por sensoriamento | Inexistente | P2 |
| `RT-04` | Baseline e adicionalidade documentados | Inexistente (é anterior ao app; entra no PD) | P1 |

---

## 4. Mapa de gaps por subsistema (evidência → requisito)

| Subsistema | Achado | Fonte | Requisitos feridos | Severidade |
|---|---|---|---|---|
| **urutau-app** | GPS desativado no formulário; import removido do pubspec | `parcela_form_screen.dart:5,124-125,1202-1203`; `pubspec.yaml` | RC-10, RS-01 | **Bloqueador** |
| **urutau-app** | Só foto comprimida sobe; bruto fica no celular | `sync_service.dart:1386-1393`; `image_service.dart:14-45` | RC-01, RC-02 | **Alto** |
| **urutau-app** | `cleanCompressedPhotos()` apaga intermediário pós-sync | `image_service.dart:82-94` | RC-02, RC-03 | Alto |
| **urutau-app** | `deletePhoto()` destrutivo em edição/remoção | `parcela_form_screen.dart:962,1031,1038,1190,1194`; `explorer_screen.dart:1863,1867,1941,1945` | RC-03 | Médio |
| **urutau-app** | Nome de arquivo com minuto (não segundos); nome original perdido | `sync_service.dart:1204-1224` | RC-05, RC-01 | Médio |
| **urutau-app** | Relógio do dispositivo como única fonte de tempo | `database.dart:39-40` | RC-05 | Médio |
| **urutau-app** | Plantas deletadas e recriadas a cada push | `sync_service.dart:1415-1486` | RG-04, RC-06 | Alto |
| **urutau-app** | AuditLog local, não sincronizado, sem hash | `database.dart:75-83,870-893` | RG-04 | **Bloqueador** |
| **urutau-app** | Espécie em texto livre; asset oficial ausente | `ANALISE_DETALHADA_APP.md` §5.1 | RC-12, RQ-03 | **Bloqueador** |
| **urutau-app** | Sem equação alométrica, sem ρ, sem tCO₂e | grep (`mrv|carbono|biomassa|allometr|tCO2|sbce`) em `lib/` = **0 ocorrências** — verificado em 22/10/2026 | RQ-01..RQ-03 | Alto |
| **urutau-app** | `crypto` já disponível no pubspec | `pubspec.yaml:46` | (facilitador) RC-04 | — |
| **urutau-admin** | Sem visão de catálogo/hash/linhagem; equipe "só sabe exportar" | README + contexto do capitão | RC-01, RC-09 | Alto |
| **urutau-admin** | Sem painel de aprovação/pendências | `ROADMAP_E_PROXIMOS_PATCHES.md` (proposta, não implementada) | RG-02, RG-01 | Alto |
| **servidorbadger** | PocketBase + arquivos em disco, sem catálogo_hash, sem WORM, sem retenção | `pb_data/storage`; pacote Windows | RC-01, RC-06, RC-07 | **Bloqueador** |
| **servidorbadger** | Supabase/Next.js do plano antigo não existem | nota técnica 15/10 vs. realidade | — | Médio (replanejar) |
| **pipeline** | Não existe ponte parcela↔raster (zonal stats) nem etapa de derivação | sessão 15/10, gap map | RC-08, RQ | Médio |

---

## 5. Requisitos priorizados para o MVP

### P0 — sem isso não existe MRV (bloqueadores)

| # | Requisito | Dono |
|---|---|---|
| 1 | **RC-04 + RC-01**: hash SHA-256 da foto na origem, verificado no ingresso, com catálogo de ativos (caminho, bytes, tipo, dispositivo, operador, timestamp) | app + servidor |
| 2 | **RC-02**: upload do bruto (ou near-raw rotulado) + preservação do derivado, ambos com hash | app + servidor |
| 3 | **RC-10**: reativar GPS com acurácia/fix/datum; tornar geo obrigatória por parcela | app |
| 4 | **RG-04**: auditoria encadeada por hash, sincronizada ao servidor, imutável | app + servidor |
| 5 | **RC-12**: catálogo oficial de espécies no bundle + entrada fechada/híbrida com marcação de origem | app |
| 6 | **RS-01/RS-02**: área de parcela em m² + forma/raio + ID de parcela estável | app |
| 7 | **RQ-01..RQ-03**: equação alométrica versionada, ρ por espécie, cálculo tCO₂e reproduzível | pipeline + app/servidor |
| 8 | **RG-01/RG-02**: papéis + fluxo pendente→revisado→aprovado com trilha | servidor + painel |

### P1 — custódia madura e verificador (30–60 dias)

| # | Requisito | Dono |
|---|---|---|
| 9 | **RC-03/RC-06**: soft-delete de arquivos, append-only/WORM, versionamento em vez de overwrite | servidor |
| 10 | **RC-05**: tempo confiável (offset de relógio, alerta de deriva) | app + servidor |
| 11 | **RC-07**: política de retenção aplicada + tiering quente/frio + relatório de integridade | servidor/infra |
| 12 | **RC-08**: linhagem de pipeline (`pipelineVersion`, `algorithmVersion`, inputs com hash) | pipeline |
| 13 | **RC-09**: papel de verificador read-only + pacote de exportação auto-verificável com manifesto de hashes | painel |
| 14 | **RS-03**: incerteza amostral propagada a tCO₂e (±%, IC, n) | pipeline |
| 15 | **RT-01**: entidade período/campana de monitoramento | app + servidor |

### P2 — robustez de programa (pós-piloto)

| # | Requisito |
|---|---|
| 16 | RG-03 re-amostragem interna com resultado |
| 17 | RG-05 competência/treinamento do operador |
| 18 | RT-02/RT-03 revisita, permanência e alertas de reversão (fogo/corte) |
| 19 | RS-05/RS-06 estratificação e amostragem híbrida campo+drone |

---

## 6. Recomendações de arquitetura (não prescritivas, custo zero)

Alinhado à restrição de custo da sessão (R$ 0 de infra; HD externo 2–4 TB para arquivo de auditoria):

1. **Catálogo de ativos como cidadão de primeira classe.** Uma coleção/tabela `ativos_brutos` com `hash_sha256`, `path_lógico`, `bytes`, `mime`, `device_id`, `operador_id`, `capturado_em`, `ingerido_em`, `pipeline_version`. Sem isso, "acessar as imagens" continua sendo adivinhação.
2. **Diretório de arquivos versionado por hash**: `<raiz>/<yyyy>/<mm>/<hash[0:2]>/<hash>.<ext>` + manifest JSONL. Torna o arquivo endereçável pelo hash, imune a renomeação e trivial de auditar.
3. **Primeira ingestão = boundary de confiança.** Tudo que entra é hasheado e selado no catálogo; o que sai (dossiê) referencia o hash. Dentro desse limite, mudanças são versões novas.
4. **Manter o PocketBase, mas separar "banco" de "acervo".** PocketBase continua como API/auth/consultas; o acervo bruto vai para árvore de arquivos + catálogo. O `pb_data/storage` não é sistema de arquivos de auditoria.
5. **Um único Pipeline Manifest por execução** (versão, inputs, parâmetros, outputs, hashes) — é o que o verificador lê para reproduzir o número.
6. **Dossiê de verificação como produto**, não como trabalho manual: exportação por projeto contendo PD-equivalente, plano de amostragem, dados crus, linhagem, cálculo, incerteza e log de auditoria.
7. **Não construir ML no ano 1.** Alometria publicada + campo. ML quando houver ciclo pareado campo+drone (decisão já tomada; registrar como restrição de roadmap).

---

## 7. Riscos e o que não prometer

| Risco | Ação |
|---|---|
| Vender "conformidade SBCE" | **Proibido.** A Portaria MRV do SBCE fechou consulta em 28/08/2026 e seu texto final/escopo ainda precisa ser lido. Vender "audit-ready padrão voluntário + prontidão SBCE". |
| Citar "restauração gera CRVE com credibilidade reforçada" | **Não verificado em fonte oficial.** Remover de material comercial até leitura da Lei 15.042/2024/Portaria. |
| Citar prazo de retenção ("7 anos") como exigência | **[A CONFIRMAR]** nos PDFs do VCS/GS4GG/Portaria. Usar como política interna, não como citação. |
| Geo fora do ar desde a desativação | Toda afirmação de "rastreabilidade geo" do app está hoje **falsa**. Corrigir antes de qualquer demo. |
| Exclusão de `compressed/` pós-sync | Pode já ter destruído evidência histórica. Auditar antes de qualquer uso retroativo dos dados. |
| Push delete+recreate de plantas | Perda de histórico já ocorrida em dados sincronizados. Tratar dados antigos como não auditáveis até reprocessamento. |
| Plantação vs. restauração (categoria 1/2/3, DAP, UT) | O modelo de dados atual é de **plantio florestal/inventário de produção**. Restauração (mistura de espécies, DIN, sobrevivência) tem requisitos diferentes. **Alinhar antes de posicionar como MRV de restauração.** |

---

## 8. Ações imediatas (para t5 e para o Badger)

1. Baixar e ler os 3 PDFs pendentes (VCS Standard v4.7; GS4GG Principles & Requirements v2.0; "Application of GS4GG Requirements with dMRV Solution") e **extrair as cláusulas de retenção, evidência e parâmetros**. Fechar E-08.
2. Ler a Lei 15.042/2024 (planalto/in.gov.br) e a Portaria/SBCE final do DOU e **fechar 1.2 e 1.3**: escopo de remoções, prazos, papéis.
3. Levantar o **estado real do acervo**: onde estão hoje as imagens que a equipe subiu, em que formato, se ainda existem. (Contexto do capitão: ninguém sabe.)
4. Decidir o **padrão de crédito alvo** (Verra vs. Gold Standard vs. outro) — o mapa de requisitos muda pouco, mas o dossiê muda muito.
5. Definir a **política de retenção** e o tamanho real do acervo (drone gera GBs por voo) → dimensionar HD externo/NAS com o arquiteto-infra (t3).

---

## 9. Fontes

**Regulatórias / governo**
- Lei nº 15.042/2024 (SBCE) — [planalto.gov.br](https://www.planalto.gov.br/ccivil_03/_ato2023-2026/2024/lei/l15042.htm) · [legislacao.presidencia.gov.br](https://legislacao.presidencia.gov.br/atos/?tipo=LEI&numero=15042&ano=2024&data=11/12/2024)
- Ministério da Fazenda — página do SBCE (mercado regulado, cap-and-trade): [gov.br/fazenda](https://www.gov.br/fazenda/pt-br/composicao/orgaos/mercado-de-carbono/sobre/sistema-brasileiro-de-comercio-de-emissoes)
- Consulta pública minuta de Portaria MRV (jul/2026): [gov.br/fazenda — notícia](https://www.gov.br/fazenda/pt-br/assuntos/noticias/2026/julho/aberta-consulta-publica-sobre-proposta-de-cronograma-para-monitoramento-relato-e-verificacao-mrv)-no-mercado-regulado-de-carbono) · [Aviso de Consulta Pública nº 1/2026 (DOU)](https://www.in.gov.br/web/dou/-/aviso-de-consulta-publica-n-1/2026-721959702)
- Brasil Participativo — Obrigações de MRV no âmbito do SBCE: [link](https://brasilparticipativo.presidencia.gov.br/processes/obrigacoesmrvsbce)
- Análise jurídica das etapas A1/A2/A3 e fases setoriais: [Trench Rossi Watanabe, 31/07/2026](https://www.trenchrossi.com/alertas-legais/sbce-consulta-publica-plano-de-monitoramento-e-de-efetivo-monitoramento-relato-e-verificacao-mrv/)

**Metodologias de crédito**
- Verra — Project Description & Monitoring Report: [link](https://verra.org/programs/verified-carbon-standard/project-description-and-monitoring-report/)
- Verra — Validation and Verification (VVBs, sanções): [link](https://verra.org/validation-verification/)
- Verra — VCS Standard v4.7 (PDF, **não lido**): [link](https://verra.org/documents/vcs-standard-v4-7/)
- Verra — Monitoring Report Template v4.4 (DOC, **não lido**): [link](https://verra.org/documents/vcs-monitoring-report-template-v4-4/)
- Gold Standard GS4GG — Principles & Requirements v2.0 (página lida; [PDF](https://globalgoals.goldstandard.org/standards/101_V2.0_PAR_Principles-Requirements.pdf) **não lido**): [link](https://globalgoals.goldstandard.org/101-par-principles-requirements/)
- Gold Standard — DMRV Pilot Programme: [página](https://globalgoals.goldstandard.org/digital-measurement-reporting-verification-pilot-programme/) · ["Application of GS4GG Requirements with dMRV Solution" (PDF, **não lido**)](https://globalgoals.goldstandard.org/standards/DMRV-Programme-DMRV-Requirements-pilot-v0.1.pdf)
- Gold Standard — acervo completo de documentos: [link](https://globalgoals.goldstandard.org/all-documents/)

**Evidência de código (Urutau)**
- [urutau-app/lib/data/database.dart](../urutau-app/lib/data/database.dart) — schema local (parcelas, plantas, fotos, auditlog)
- [urutau-app/lib/services/image_service.dart](../urutau-app/lib/services/image_service.dart) — compressão, salvamento, limpeza
- [urutau-app/lib/services/sync_service.dart](../urutau-app/lib/services/sync_service.dart) — push/pull, upload de comprimido, delete+recreate
- [urutau-app/lib/screens/parcela_form_screen.dart](../urutau-app/lib/screens/parcela_form_screen.dart) — GPS desativado
- [urutau-app/docs/ANALISE_DETALHADA_APP.md](../urutau-app/docs/ANALISE_DETALHADA_APP.md) — diagnóstico de espécies
- [urutau-app/docs/ROADMAP_E_PROXIMOS_PATCHES.md](../urutau-app/docs/ROADMAP_E_PROXIMOS_PATCHES.md) — proposta parcelas_pendentes/aprovadas
- [urutau/README.md](../README.md) — stack e arquitetura

**Contexto de negócio**
- [Síntese da sessão 95586fe8 (MRV/Inovesa)](C:/Users/Badger/urutau-dsh/SINTESE-95586fe8.md)

---

## 10. Limitações deste entregável

- `web_search` indisponível nesta sessão (sem chave de API) → a pesquisa regulatória foi feita por fetch direto de fontes oficiais.
- `web_fetch` **não processa PDF/DOC** → os textos primários de Verra e Gold Standard foram citados mas **não lidos**. Nenhum número de prazo de retenção foi afirmado a partir deles.
- O escopo do task (in scope / out of scope) veio vazio no contrato; o escopo foi inferido do subject + contexto do time e das instruções do capitão.
- Não foi lido código do painel (`urutau-admin`) nem dos hooks do servidor — as afirmações sobre eles vêm do README/documentação e do contexto do capitão.
