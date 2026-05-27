# Análise detalhada do app Inventário Florestal

Data: 2026-04-07

## 1) Visão geral atual

O app está com arquitetura **offline-first** em Flutter, com base local em Drift/SQLite e sincronização com PocketBase.  
No estado atual, o fluxo principal está centrado em:

- login local/servidor;
- navegação por hierarquia **Propriedade > UT/Talhão > Parcela**;
- preenchimento de parcela (rascunho/concluída);
- inclusão de plantas e fotos;
- envio posterior via sincronização.

Também existem capacidades maduras de exportação (XLSX/PDF/fotos), backup/restore local, e tela administrativa.

---

## 2) Mapa de telas e como funcionam

## 2.1 Splash

- Exibe animação Lottie por ~3s.
- Se há usuário salvo em sessão, vai para `/explorer`; caso contrário, `/login`.
- Comportamento simples e estável, com fallback se animação falhar.

## 2.2 Login / Cadastro / Recuperação

- Login tenta autenticação local primeiro.
- Se não encontrar local e houver internet, tenta autenticar no servidor e sincroniza usuário para local.
- Primeiro acesso exige seed de catálogo (`ensureCatalogSeeded`), com diálogo de retry.
- Cadastro é online-first (cria no servidor e depois salva local).
- Recuperação de senha no app é apenas informativa (sem envio de email funcional no fluxo comum).

## 2.3 Explorer (fluxo principal de campo)

- Tela principal no modo usuário.
- Navegação em níveis: Propriedades -> UTs -> Parcelas.
- Mostra ownership de parcelas:
  - minhas;
  - livres (claimable);
  - de outros (bloqueadas).
- Permite:
  - assumir parcela livre;
  - abrir/editar parcela própria;
  - criar nova parcela no contexto da hierarquia;
  - operações de sync/pull/export no menu de sincronização.
- É hoje o coração operacional do app.

## 2.4 Formulário de Parcela

- Suporta novo e edição.
- Pré-preenchimento vindo do Explorer (propriedade/UT e, quando aplicável, próximo número).
- Mantém dados de plantas e fotos vinculados.
- Trabalha com conceito de rascunho x pronta para sync.
- Ao editar parcela já sincronizada, mostra aviso explícito.
- Tem ação de ir para próxima parcela da UT, com regra para pular parcelas de outros usuários.

## 2.5 Formulário de Planta

- Entrada de espécie, altura, DAP, categoria e foto.
- Regras importantes:
  - categoria automática por altura/DAP;
  - modo manual de categoria (altura 0 e categoria 1/2/3);
  - foto obrigatória para espécie `NI`.
- Campo de espécie usa serviço com:
  - carga por planilha em asset (`assets/dados_especies.xlsx`) se existir;
  - fallback para lista estática de espécies comuns se não existir.

## 2.6 Settings

- Configuração e teste da URL do PocketBase.
- Status de sincronização e botão de sync manual.
- Backup/restore local.
- Acessibilidade (tema alto contraste).

## 2.7 Admin

- Gestão de usuários e operações administrativas.
- Exportações e downloads ampliados.
- Funções de manutenção e sincronização mais abrangentes.
- É uma tela grande e com muita responsabilidade (complexidade elevada).

## 2.8 Home (legado/paralelo)

- Ainda existe com lógica de listagem, filtros e sync.
- Porém o fluxo atual de usuário comum foi desviado para Explorer.
- Indício de coexistência de fluxo antigo e novo (potencial dívida de UX e manutenção).

---

## 3) Fluxos naturais do app (como o usuário percorre hoje)

## 3.1 Fluxo ideal de campo

1. Usuário faz login.
2. App garante catálogo inicial (primeiro acesso).
3. Usuário entra no Explorer.
4. Escolhe Propriedade/UT e abre uma parcela livre ou sua.
5. Preenche dados da parcela e plantas (podendo salvar rascunho).
6. Marca concluída e depois sincroniza.
7. Opcionalmente exporta XLSX/PDF/fotos.

## 3.2 Fluxo de sincronização

1. App conta pendências locais (`pendingCount`).
2. Usuário abre painel/ação de sync.
3. App valida conexão/autenticação quando necessário.
4. Envia parcelas prontas e seus filhos (plantas/fotos), com tratamento de conflitos e bloqueios.
5. Atualiza flags locais de sincronização conforme sucesso/falha.

## 3.3 Fluxo de recuperação operacional

1. Usuário exporta backup local (share de arquivo sqlite).
2. Em novo aparelho/instalação, escolhe restaurar backup.
3. App marca restauração pendente e aplica no próximo start.

---

## 4) Pontos fortes (o que está bom)

## 4.1 Produto e fluxo de campo

- Modelo offline-first bem alinhado ao uso em campo (rede intermitente).
- Rascunho/conclusão explícitos reduzem perda de trabalho.
- Explorer por hierarquia é intuitivo para operação florestal.
- Ownership de parcela evita edição concorrente acidental.

## 4.2 Robustez funcional

- Sincronização com retries, progress e contagem de pendências.
- Modo de exportação forte (XLSX com abas, PDF, fotos organizadas).
- Backup/restore local implementado (importante para operação real).
- Tratamento de regras de negócio em planta (categoria, DAP obrigatório, NI com foto).

## 4.3 Evolução e maturidade

- Há documentação técnica útil (`ROADMAP`, schema PocketBase, seed e validações).
- Existe preocupação com conflitos e auditoria (`AuditLog`).
- Fluxo de login/cross-device já cobre parte dos casos reais.

---

## 5) Pontos ruins / riscos / dívida técnica

## 5.1 Espécies (problema que você citou)

Este é hoje um ponto crítico de qualidade de dado:

- o app **não está usando planilha de espécies em runtime** atualmente;
- `pubspec.yaml` não lista `assets/dados_especies.xlsx`;
- o arquivo `assets/dados_especies.xlsx` não foi encontrado no projeto;
- então a UI cai no fallback estático (`especiesComuns`), que mistura nomes genéricos e pode divergir da sua planilha oficial.

Resultado prático: surgem espécies "inventadas" ou fora do catálogo oficial porque:

- a lista fallback não representa seu domínio completo;
- o campo ainda aceita digitação livre (não só seleção fechada), permitindo entradas fora do padrão.

## 5.2 Acoplamento e complexidade

- `SyncService` é muito grande e concentra várias responsabilidades (auth, pull/push, conflitos, fotos, usuários, timers).
- Telas grandes (`Explorer`, `Admin`, `ParcelaForm`) têm muita regra de negócio acoplada na UI.
- Isso aumenta custo de manutenção e risco de regressão.

## 5.3 Configuração sensível hardcoded

- URL default do ngrok está hardcoded em serviço de sync.
- Esse ponto é frágil para produção (troca de túnel, ambiente, segurança e suporte).

## 5.4 Fluxos paralelos / legado

- Coexistência de `HomeScreen` e `ExplorerScreen` pode confundir evolução do produto.
- Comentários indicam "admin fora do app", mas existe tela admin no app; isso sugere decisão de produto ainda ambígua.

## 5.5 Qualidade de erro e observabilidade

- Há vários `catch (_) {}` silenciosos.
- Em falhas de parsing/requisições, parte do erro pode ficar invisível para operação.
- Debug prints extensivos ajudam desenvolvimento, mas faltam métricas/telemetria operacional consistente.

## 5.6 Higiene de assets

- Pasta `assets` contém arquivos não relacionados ao app (executáveis/imagens diversas), o que pode:
  - poluir repositório;
  - aumentar chance de confusão em build;
  - dificultar governança de conteúdo oficial.

---

## 6) Diagnóstico específico: dropdown de espécies vs planilha Excel

## 6.1 O que a implementação faz hoje

1. Tenta carregar `assets/dados_especies.xlsx`.
2. Se falhar, usa lista fallback em código (`categoria_helper.dart`).
3. Campo permite texto digitado pelo usuário.

## 6.2 Evidências do estado atual

- Existe documentação de uso da planilha (`docs/PLANILHA_ESPECIES.md`), mas não está efetivada no bundle atual.
- `pubspec.yaml` não inclui o asset da planilha.
- Não há `assets/dados_especies.xlsx` presente.

## 6.3 Consequência no dado coletado

- Catálogo fica inconsistente entre dispositivos/versões.
- Termos fora da taxonomia oficial entram na base.
- Qualidade de relatório e comparabilidade histórica pioram.

## 6.4 Melhor direção funcional (recomendação)

- Definir um **catálogo oficial único** de espécies (planilha validada).
- Bundle obrigatório no app (asset) + validação de integridade de colunas.
- Decidir regra de entrada:
  - **modo estrito**: só espécies do catálogo (recomendado para qualidade);
  - **modo híbrido**: permite "Outro" com justificativa e marcação explícita.
- Registrar origem da espécie (catálogo/oficial vs manual) para rastreabilidade.

---

## 7) Prioridades recomendadas (curto prazo)

## P0 — qualidade de dados (imediato)

1. Integrar de fato `assets/dados_especies.xlsx` no bundle.
2. Remover dependência prática do fallback para produção.
3. Definir política de entrada da espécie (estrito/híbrido).
4. Criar rotina de saneamento para espécies já coletadas fora do padrão.

## P1 — estabilidade operacional

1. Externalizar URL base por ambiente (dev/homolog/prod).
2. Melhorar mensagens de erro para sync/login com códigos mais claros.
3. Reduzir `catch` silenciosos e padronizar logs de falha.

## P2 — manutenção e escalabilidade

1. Fatiar `SyncService` em camadas (auth, catálogo, push/pull, mídia, conflitos).
2. Extrair regras de domínio das telas para serviços/use-cases.
3. Consolidar o fluxo oficial (Explorer vs Home) para reduzir duplicidade.

---

## 8) Testes de aceitação recomendados (foco em risco real)

## 8.1 Espécies

- Com planilha válida: dropdown e preditor exibem catálogo oficial.
- Sem planilha: comportamento explícito (erro guiado ou fallback controlado, conforme política).
- Inserção de espécie fora catálogo: bloqueada ou marcada como "manual" (conforme decisão).

## 8.2 Fluxo de campo

- Criar parcela -> adicionar plantas -> concluir -> sync -> pull em outro aparelho.
- Abrir parcela livre e assumir ownership.
- Editar parcela sincronizada com aviso e reenvio.

## 8.3 Resiliência

- Login sem internet (com usuário local) vs com internet (cross-device).
- Queda de rede durante sync.
- Backup + restauração completa e validação de integridade.

---

## 9) Conclusão executiva

O app está funcional e relativamente maduro para uso de campo, com boa base de offline/sync/export e fluxo operacional coerente no Explorer.  
O principal problema de valor imediato está na **governança das espécies**: hoje o comportamento tende ao fallback + entrada livre, o que explica a mistura de espécies oficiais e inventadas.  

Se corrigirmos o pipeline de espécies (asset oficial + regra de validação), já elevamos fortemente a qualidade dos dados. Em paralelo, a próxima frente é reduzir acoplamento (especialmente `SyncService`) para manter velocidade de evolução sem aumentar risco.
