# Plano: Limpar servidor e seed a partir da Planilha ISAAC (mapeamento_area_pt)

## O que foi entendido

1. **Fonte de verdade:** O ficheiro `Planilha_ISAAC 1(mapeamento_area_pt).csv` define:
   - **Propriedades** (coluna `ID_PROP`, ex: GHGH0206, VGVG0069)
   - **UT/Talhões** (coluna `ID_UT`, ex: UT03, UT01)
   - **Área em hectares** (coluna `Área`; separador decimal é vírgula, ex: 0,0076)
   - **Quantidade de parcelas** (coluna `Qtd Parcelas`: 1, 5, 6, 7, 8, 12 ou 19)

2. **Estrutura dos dados:**
   - Cada linha pode representar **uma parcela** (Qtd = 1) ou **várias parcelas no mesmo UT** (Qtd = 5, 6, 7, 8, 12, 19).
   - Para a mesma Propriedade + UT, as parcelas são numeradas em sequência (1, 2, 3, …). Quando Qtd > 1, criamos N parcelas com o mesmo valor de Área (Ha).
   - **Hectares (Ha)** é importante para o mesmo (propriedade, UT): serve de “no-draw” para o utilizador saber qual parcela está a editar quando há várias no mesmo talhão.

3. **Servidor (PocketBase):**
   - **Limpar:** Remover todos os dados **adicionados por utilizadores** (parcelas, plantas, fotos), **sem alterar** as coleções/campos que a app usa (users, parcelas, plantas, etc.).
   - **Seed:** Inserir as parcelas derivadas do CSV. Ficam **sem dono** (user vazio) para aparecerem como “disponíveis” para os coletores assumirem no app.
   - Manter usuários e estrutura das coleções; apenas esvaziar e repopular **parcelas** (e, se desejado, plantas associadas a essas parcelas).

4. **Resumo da lógica de seed:**
   - Agrupar mentalmente por `(ID_PROP, ID_UT)` e atribuir `id_parcela` 1, 2, 3, … por ordem das linhas no CSV.
   - Por cada linha: criar `Qtd Parcelas` registos de parcela com:
     - `propriedade` = ID_PROP  
     - `prop_ut` = ID_UT  
     - `area_ha` = Área (convertida: vírgula → ponto)  
     - `id_parcela` = próximo número na sequência daquele (prop, UT)  
     - `user` = "" (parcela livre)
   - Não criar plantas nem fotos no seed; a app e os utilizadores preenchem depois.

---

## Passos técnicos

1. **Limpar servidor (apenas dados de parcelas/plantas):**
   - Autenticar como admin no PocketBase.
   - Listar todos os registos em `parcelas` (paginação).
   - Apagar cada parcela (e, opcionalmente, plantas cuja `parcela` aponta para ela).
   - Ou: apagar todos os registos de `plantas` e depois todos os de `parcelas`.

2. **Seed a partir do CSV:**
   - Ler o CSV (separador `;`, encoding UTF-8).
   - Parse: `ID_PROP`;`ID_UT`;`Área`;`Qtd Parcelas` (Área com vírgula → double).
   - Por cada `(ID_PROP, ID_UT)` manter um contador para `id_parcela`.
   - Por cada linha, criar `Qtd Parcelas` parcelas com a mesma `Área`, `id_parcela` sequencial, `user` vazio.
   - Inserir via API PocketBase (POST `/api/collections/parcelas/records` com auth admin, ou regras que permitam criar com `user` vazio).

3. **App:**
   - Já usa `areaHa` e lista por Propriedade → UT → Parcela; mostrar Ha na lista/editor ajuda o utilizador a identificar “qual parcela estou a editar” no mesmo UT (no-draw).

---

## Ficheiros

- **Script de seed:** `tool/seed_pocketbase_from_csv.dart` (Dart; usa `dart run`).
- **Uso:**  
  - Colocar o CSV no project root ou passar o caminho como argumento.  
  - Definir variáveis de ambiente: `PB_URL`, `PB_ADMIN_EMAIL`, `PB_ADMIN_PASSWORD`.  
  - Executar (a partir da raiz do projeto):  
    `dart run tool/seed_pocketbase_from_csv.dart "caminho/para/Planilha_ISAAC 1(mapeamento_area_pt).csv"`  
  - Se o PocketBase exiger que `user` seja um ID válido, criar um utilizador "seed" na UI, obter o ID e usar opcionalmente `PB_SEED_USER_ID` no script (ou alterar o script para enviar esse ID em vez de string vazia).

- **Este plano:** `docs/SEED_SERVER_PLAN.md`.
