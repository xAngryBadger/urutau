# Analise do App Urutau — Caderno de Campo Offline

Data: 2026-06-09 (atualizado para alinhar com Plano Ultra)

---

## 1) Visao

O Urutau e um **caderno de campo digital** para inventario florestal.

- 100% offline, sem servidor, sem internet
- Abre -> registra -> salva. Simples como um bloco de notas.
- SQLite local como banco de dados (txt magnificado com estrutura)
- Zero login — nome opcional, abre e usa
- Dois modos: Campo (rapido) e Planejamento (batch/agenda)
- Compartilhamento via ZIP (WhatsApp/Drive)

**Nao e GIS. Nao e QGIS. Nao tem mapa. Nao tem servidor.**

---

## 2) Estado atual (pre-Plano Ultra)

O app atual esta com arquitetura **offline-first** em Flutter, com base local em Drift/SQLite e sincronizacao com PocketBase. Tem login, admin, sync, e multi-usuario — tudo que sera removido.

### Telas atuais que SERAO REMOVIDAS

| Tela | Motivo |
|---|---|
| LoginScreen | Sem autenticacao no Plano Ultra |
| AdminScreen | Sem admin no Plano Ultra |
| HomeScreen (legado sync) | Substituida por lista simples |
| ConflictResolutionDialog | Sem sync, sem conflito |
| AuditLogScreen | Simplificacao |
| SplashScreen (auth check) | Substituida por welcome simples |

### Telas atuais que SERAO ADAPTADAS

| Tela | Adaptacao |
|---|---|
| ExplorerScreen | Lista simples sem ownership, sem sync buttons |
| ParcelaFormScreen | Aceitar mode (campo/planejamento), sem sync |
| PlantaFormScreen | Manter (categorizacao altura/DAP, foto) |
| SettingsScreen | So opcoes offline (qualidade foto, storage, backup, tema) |

### Servicos atuais

| Servico | Acao |
|---|---|
| SyncService (~1800 lin) | DELETAR |
| ImageService | Manter (compressao + thumbnails) |
| SpeciesService | Manter (catalogo local XLSX + fallback) |
| ExportService | Adaptar para ZIP v2 |
| BackupService | Adaptar para ZIP import/merge |
| StorageService | Manter |
| PasswordService | DELETAR |
| PocketBase client | DELETAR |

---

## 3) Schema DB atual vs. Plano Ultra (v19)

### Tabelas que SERAO REMOVIDAS

- `usuarios` — sem auth
- `audit_log` — simplificacao

### Colunas que SERAO REMOVIDAS de `parcelas`

- `synced`, `prontaParaSync`, `parcialmenteSincronizada` — sem servidor
- `userId`, `createdBy`, `ownerName` — sem auth/ownership

### Colunas que SERAO REMOVIDAS de `plantas`

- `synced` — sem servidor

### Colunas que SERAO ADICIONADAS a `parcelas`

- `mode` TEXT ('campo' | 'planejamento')
- `status` TEXT ('rascunho' | 'concluida' | 'planejada')
- `planned` INTEGER (flag para parcelas pre-criadas)

### Nova tabela

- `device_info` — identidade do dispositivo (device_id UUID, user_name opcional)

---

## 4) Pontos fortes (o que esta bom e sera mantido)

- Modelo offline-first alinhado ao uso em campo (rede intermitente)
- Rascunho/conclusao explicitos reduzem perda de trabalho
- Explorer por hierarquia (Propriedade > Talhao > Parcela) e intuitivo
- Categorizacao automatica por altura/DAP funciona bem
- Regras de negocio em planta (categoria, DAP obrigatorio, NI com foto)
- Exportacao forte (XLSX, PDF, fotos)
- Backup/restore local implementado
- Compressao de fotos + thumbnails
- Monitoramento de espaco em disco
- Seed de catalogo de especies

---

## 5) Pontos a resolver (transicao para Plano Ultra)

### 5.1 Remocao de SyncService

- SyncService e o maior arquivo (~1800 linhas) e concentra: auth, pull/push, conflitos, fotos, usuarios, timers
- Toda referencia a sync nas telas precisa ser removida
- Queries que filtram por `synced = false` ou `prontaParaSync = true` precisam ser simplificadas
- `purgarDeletados()` e outros metodos que dependem de sync precisam ser adaptados

### 5.2 Remocao de Auth

- LoginScreen, PasswordService, SecureStorage: deletar
- SplashScreen: substituir verificacao de sessao por welcome simples
- Referencias a `userId`, `createdBy` nas queries: remover
- Usuarios tabela: deletar inteira

### 5.3 Simplificacao do Explorer

- Remover ownership (minhas/livres/de outros)
- Remover botoes de sync
- Remover status de sync (synced/parcialmente sincronizada)
- Lista simples: todas as parcelas, sem filtro de usuario
- Adicionar status visual (rascunho/concluida/planejada)

### 5.4 Especies (problema existente)

- O app NAO esta usando planilha de especies em runtime atualmente
- `pubspec.yaml` nao lista `assets/dados_especies.xlsx`
- UI cai no fallback estatico (`especiesComuns`), que mistura nomes genericos
- **Acao no Plano Ultra:** Incluir XLSX no bundle e usar como catalogo oficial
- No modo Planejamento: pre-cadastrar especies novas antes do campo

---

## 6) Novas funcionalidades (Plano Ultra)

### 6.1 Zero-auth entry

Primeira execucao:
1. App gera device_id (UUID)
2. Pede nome opcional
3. Salva em `device_info`
4. Direto para lista de parcelas

Execucoes subsequentes:
1. Abre direto na lista
2. Sem verificacao de sessao, sem login

### 6.2 Modo Campo (Escrever)

- Lista de parcelas
- Criar parcela rapidamente
- Adicionar plantas com foto
- Categoria automatica
- Salvar rascunho ou concluir

### 6.3 Modo Planejamento (Agenda)

- Pre-cadastrar especies
- Criar propriedades e talhoes
- Criar parcelas em lote (1-50)
- Editar dados existentes em batch
- Parcelas ficam com status 'planejada'

### 6.4 ZIP Export/Import

- Export: manifest.json + dados.json + fotos/ + thumbnails/
- Import: upsert por UUID, updated_at mais recente ganha
- Compartilhavel via WhatsApp/Drive/WeTransfer

---

## 7) Prioridades (Plano Ultra)

## Fase 1 — Fundacao (1 sem)

1. Migration v19 (schema sem auth/sync)
2. DeviceInfo table + UUID
3. Remover tabelas e colunas legado

## Fase 2 — Zero-auth (3-4d)

1. Nova SplashScreen sem auth
2. WelcomeScreen (nome opcional)
3. Deletar LoginScreen, Auth, Password, SecureStorage

## Fase 3 — Limpeza de legado (1 sem)

1. Deletar SyncService, AdminScreen, ConflictResolution, HomeScreen
2. Limpar Settings, Explorer
3. Remover PocketBase client

## Fase 4 — Mode Selector + Campo (1 sem)

1. Mode switch (Campo/Planejamento)
2. Explorer adaptada: lista simples
3. Status visual (rascunho/concluida/planejada)

## Fase 5 — Planejamento (1-2 sem)

1. Batch create de parcelas
2. Pre-cadastro de especies
3. Editar dados em batch

## Fase 6 — ZIP Export/Import (1 sem)

1. Export ZIP v2
2. Import + merge
3. UI de export/import

## Fase 7 — Polimento (3-5d)

1. Testes de campo
2. Build APK
3. Limpeza final

---

## 8) Testes de aceitação

### Campo

- Abre app sem login -> direto na lista
- Cria parcela -> adiciona planta -> salva
- Foto para especie NI e obrigatoria
- DAP obrigatorio
- Categoria calculada automaticamente

### Planejamento

- Cria 50 parcelas em lote
- Pre-cadastra especies novas
- Muda para modo Campo -> parcelas planejadas aparecem

### ZIP

- Exporta ZIP com dados + fotos
- Importa ZIP em outro dispositivo -> mescla corretamente
- Nao perde dados existentes ao importar

### Offline

- Funciona 100% sem internet
- Nao tenta conectar a servidor
- Backup local funciona

---

## 9) Conclusao

O Urutau atual tem uma base solida (Drift DB, hierarquia Prop>Talhao>Parcela, categorizacao, fotos, exportacao). O Plano Ultra remove o que nao serve (auth, sync, admin, GIS) e foca no que importa: **caderno de campo simples, 100% offline, com dois modos de uso e compartilhamento via ZIP**.
