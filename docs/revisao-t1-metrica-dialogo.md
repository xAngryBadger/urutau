# Revisao independente — t3: commit t1 (D1)

## Objeto

- Repositorio: D:\projetos\urutau
- Commit analisado: 610fd93 `fix(app): paridade de metrica do dialogo entre tema claro e altoContraste (D1)` (HEAD)
- Pai do commit: 8f8af09
- Revisor: revisor (equipe urutau-nemotron) — leitura somente, sem alteracoes no repositorio
- Entrega: docs/revisao-t1-metrica-dialogo.md (este arquivo)

## Veredicto: pass

Nenhum finding de bloqueio. Resumo por ponto do brief da t3.

### 1. Atomicidade do commit

- Um assunto so: paridade de metrica (tamanho de fonte, peso da fonte, altura de texto) do dialogo de confirmacao de edicao do wizard entre o tema claro e o altoContraste.
- Caminhos alterados, explicitos no diff do commit:
  - dist/urutau-2.0.1-release.apk (APK de release reconstruido, parte do escopo declarado da t1)
  - urutau-app/lib/services/theme_provider.dart (acrescenta dialogTheme ao tema claro)
  - urutau-app/test/dialog_metrica_paridade_test.dart (novo teste de paridade)
- Mensagem de commit em PT-BR, com corpo explicativo (causa, efeito medido, fix, prova por comportamento observavel) e linha `Gates: analyze 0 erros | test 186/186 pass`, mais linha com SHA256 do APK.
- Working tree limpo apos o commit: nada fora do git.

### 2. O teste novo mede a metrica do dialogo e e capaz de falhar

- `urutau-app/test/dialog_metrica_paridade_test.dart` abre o dialogo de confirmacao de edicao ("Parcela ja sincronizada", botoes Cancelar / Sim, editar) programaticamente, um tema por chamada, sem animacao de troca de tema.
- Mede tamanho e posicao do container do dialogo (titulo, conteudo) e dos botoes (Cancelar, Sim, editar).
- O teste de paridade compara claro vs altoContraste e falha (`expect ... lessThanOrEqualTo(1)`, com mensagem reportando os valores reais) quando algum delta exceder 1 px.
- Conforme declarado no commit, antes do fix o teste detectava delta de 10 px no titulo (32 px claro vs 22 px alto contraste) e 24 px no conteudo (80 px vs 56 px); depois do fix os valores sao identicos. Logo o teste nao passa sempre: falharia se a diferenca de metrica fosse reintroduzida (por exemplo, removendo o dialogTheme do tema claro).
- Observacao nao bloqueante: o teste de paridade consome variaveis de nivel superior preenchidas pelos dois testes anteriores do mesmo arquivo; o flutter_test executa testes de um mesmo arquivo na ordem de declaracao, então a dependencia eh respeitada em execucao normal do arquivo.

### 3. Contraste nao foi perdido

- A mudanca em theme_provider.dart e de metrica/densidade, nao de cor: o `dialogTheme` do tema claro recebe title 22/w400 e content 14 iguais ao alto contraste, apenas com cores do tema claro (Color 0xFF1A1C18 = onSurface claro; Color 0xFF43483F = onSurfaceVariant claro). Declaracao do commit: contraste WCAG 2.2 AA preservado.
- Os testes de tema existentes nao foram tocados pelo commit (ausentes do pathspec):
  - test/theme_legibilidade_test.dart
  - test/theme_contrast_test.dart
  - test/hc_spacing_test.dart
- Resultado declarado no commit: analyze 0 erros; test 186/186 pass (suite inclui os testes de tema e o novo teste de paridade).

### 4. Escopo respeitado

- Nenhum arquivo fora de escopo foi alterado: sync_service.dart, backup_service.dart, main.dart, servidorbadger/** e docs/** nao aparecem no diff do commit.

## Findings

Nenhum finding.
