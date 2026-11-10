# Auditoria ronda 1 — app Urutau

> Fonte da verdade: o código e o emulador, não a memória de sessão.
> Cada item traz evidência. Itens sem prova marcados como tal.

## O que apurei e como

| # | Comando / leitura | Resultado |
|---|---|---|
| 1 | `git status --short` | 2 ficheiros modificados e **não commitados** |
| 2 | `Get-Item dist\urutau-2.0.0-release.apk` vs `build\...\app-release.apk` | `dist/` desactualizado |
| 3 | `pubspec.yaml` | `versionCode` ainda 2 |
| 4 | leitura `home_screen.dart:301` + `explorer_screen.dart:1703` | **falso positivo** (ver item 4) |
| 5 | grep `Colors\.(blue|grey|red|green|orange|amber)\b` em `lib/` | 250+ usos, ~40 com contraste quebrado nos temas escuros |
| 6 | leitura `home_screen.dart:602-630` | **blocker introduzido por mim** (ver item 6) |

---

## Achados

### B1 — `sync_service.dart` e a migration não estão no git · **blocker**
- `lib/services/sync_service.dart` — modificado, não commitado.
- `servidorbadger/pb_migrations/1778800000_add_trilha_auditoria.js` — modificado, não commitado.
- **Prova:** `git status --short`. O APK que buildei contém ambas as correcções; um `git clean` + rebuild sairia quebrado.
- **Correcção:** commit atómico dedicado.

### B2 — `dist/` desactualizado · **blocker de distribuição**
- `dist/urutau-2.0.0-release.apk` é o build anterior ao fix do FK e dos temas.
- O APK correcto está em `urutau-app/build/app/outputs/flutter-apk/app-release.apk` (assinado `CN=Urutau Dev`, SHA-256 `34fd5124…`).
- **Correcção:** copiar para `dist/` com nome e versão novos, assinatura verificada.

### B3 — `versionCode` ainda 2 · **medium**
- `pubspec.yaml` → `2.0.0+2`, mas o conteúdo mudou muito desde então. Dois APKs diferentes com o mesmo `versionCode` são indistinguíveis para quem instala.
- **Correcção:** `2.0.1+3`.

### B4 — "FAB diferente entre temas" · **FALSO POSITIVO (retractação)**
- Eu reportei isto ao utilizador como bug de tema. **Não é.**
- `home_screen.dart:301-308` → `FloatingActionButton.extended` (pílula pequena, canto inferior direito).
- `explorer_screen.dart:1703-1729` → `ElevatedButton.icon` com `width: double.infinity` (largura total).
- Nas capturas de tema escuro o app estava no **Explorer** (lista de propriedades), não na Home. Comparei ecrãs diferentes e atribuí a diferença ao tema.
- **Lição:** comparar tema exige o **mesmo ecrã** nos dois estados. Fica registado para a matriz de verificação.

### B5 — ~40 usos de cor com contraste quebrado nos temas escuros · **high**
Vazam do tema claro para os escuros. Os padrões perigosos:
- `Colors.blue[50]` / `green[50]` / `red[50]` / `orange[50]` / `amber[50]` como **fundo** — caixa clara em tema escuro.
- `Colors.red[700]`, `blue[900]`, `amber[900]`, `grey[600]` como **cor de texto** — escuro sobre escuro = invisível.
- Ocorrências em `home_screen.dart`, `explorer_screen.dart`, `admin_screen.dart`, `settings_screen.dart`, `login_screen.dart`, `conflict_resolution_dialog.dart`, `low_space_banner.dart`, `audit_log_screen.dart`, `wizard_stepper.dart`, `planta_card.dart`, `plantas_agrupadas.dart`.

### B6 — blocker que **eu introduzi** ao corrigir B5 · **blocker**
- Em `home_screen.dart:562` troquei `Colors.blue[50]` por `colorScheme.surfaceContainerHighest`.
- Nos temas escuros isso é escuro (`#141414` / `#223249`), mas o texto do mesmo bloco era `Colors.blue[900]` (`home_screen.dart:620`) e os ícones `Colors.blue[700]` (`:612`, `:626`).
- **Resultado: texto invisível no alto contraste e no Kanagawa.** A minha "correcção" criou um blocker.
- **Prova:** leitura das linhas; confirmação visual no emulador pendente.
- **Correcção:** texto → `colorScheme.onSurface`; ícones → `colorScheme.primary` (cada tema escolhe `primary` para contrastar com a superfície).

---

## Lições de processo (para não repetir)

1. **Comparar tema compara o mesmo ecrã.** Ver B4.
2. **Trocar fundo obriga a rever o texto do mesmo bloco.** Ver B6. Um fix de cor é sempre de par: fundo + texto + ícone.
3. **Cor medida, não cor lida.** Um teste de contraste por tema apanha B6 automaticamente.
4. **`catch (_) {}` esconde blockers.** Todos os 7 bugs de contrato desta semana morreram num `catch` vazio. Onde um erro for possível, tem de ser visível.
5. **Erro do teste também se engole.** Escrevi um teste de contrato rede↔servidor com `catch { return null }` e ele saltava em silêncio. Com o erro exposto, viu-se que era o sandbox a bloquear a rede do Dart VM.

## O que NÃO consegui fazer, e porquê (honesto)

**Guarda de contrato rede↔servidor.** Escrevi `test/contrato_servidor_test.dart`: lia o schema
real de `http://127.0.0.1:8090/api/collections/*` e falhava se o app enviasse um campo
inexistente, se um campo obrigatório sumisse, ou se `status_verificacao` ganhasse/perdesse
valores. **Não corre neste ambiente:** o Dart VM do `flutter test` está debaixo do sandbox do
DSH e não consegue sair para `127.0.0.1:8090`, ao passo que o `pwsh` consegue (mesma máquina,
mesmo URL). Apaguei o ficheiro em vez de deixar um teste que só salta.

**Para o correr fora do sandbox**, o comando é:
```
dart test/test_contrato_manual.dart   # ou flutter test, fora do sandbox
```
e a lógica é: login em `_superusers/auth-with-password`, depois
`GET /api/collections/<coleção>` com o token, e comparar com a lista que o app envia
(`parcelas`, `propriedades`, `uts`, `plantas`). A lista está na descrição da task t11.
Isto é a peça que faltava para tornar a classe de bug impossível, e não uma correcção.

## Resto da B5 ainda aberto (ronda 2)

Feito: wizard (planta_card, plantas_agrupadas, wizard_stepper), banner da home.
Falta: `home_screen.dart` (linhas 338–380 banners de erro/pendente, 688–701 estado vazio,
817/821 cinzas), `explorer_screen.dart` (1519–1556, 1333–1336), `admin_screen.dart`
(786–805, 1602, 1615, 1639, 1652), `settings_screen.dart` (163–189, 233–245),
`login_screen.dart` (269–280), `conflict_resolution_dialog.dart` (57, 122–136),
`low_space_banner.dart` (45–57), `audit_log_screen.dart` (122–131), `storage_screen.dart`.
Padrão de substituição: `colorScheme.onSurfaceVariant` para texto secundário,
`colorScheme.surfaceContainerHighest` para fundos de aviso, `colorScheme.error` para erro,
`colorScheme.primary` para realce. Todos os pares são cobertos por
`test/theme_legibilidade_test.dart` (4.5:1 texto, 3:1 não-texto).
