# Schema PocketBase — Gestor de Campo

Hierarquia **fixa**: **Propriedade > UT/Talhão > Parcela**. O servidor impõe isso por relações; não há como gravar UT no lugar de Propriedade.

---

## 1. Coleções (schema normalizado)

### 1.1 `propriedades`
| Campo   | Tipo | Obrigatório | Descrição |
|--------|------|-------------|-----------|
| name   | Text | Sim         | Nome único da propriedade (ex: "São João"). |

- **Regra**: não usar códigos de UT aqui (ex: "UT11"). Só nomes de propriedade.

### 1.2 `uts`
| Campo        | Tipo     | Obrigatório | Descrição |
|-------------|----------|-------------|-----------|
| propriedade | Relation | Sim (single, → propriedades) | Propriedade a que o UT pertence. |
| name        | Text     | Sim         | Nome do UT/Talhão (ex: "UT1", "UTE2"). |

- **Unicidade**: (propriedade, name) deve ser único (um UT por nome dentro da mesma propriedade).
- Criação: sempre com `propriedade` apontando para um registro de `propriedades`.

### 1.3 `parcelas`
| Campo      | Tipo     | Obrigatório | Descrição |
|-----------|----------|-------------|-----------|
| ut        | Relation | Sim (single, → uts) | UT/Talhão a que a parcela pertence. |
| id_parcela| Number   | Sim         | Número da parcela dentro do UT. |
| user      | Text     | Não (pode "") | ID do utilizador (owner); vazio = livre. |
| area_ha   | Number   | Não         | Área em hectares. |
| observacoes | Text   | Não         | Observações. |

- **Sem** campos `propriedade` nem `prop_ut`. Propriedade e UT vêm só pela relação `ut` (e `ut.propriedade`).
- Plantas e fotos continuam a referenciar parcela (collection `plantas` com relação `parcela`).

### 1.4 `users`
- Mantida como já existe (email, password, name, etc.).

### 1.5 `plantas`
| Campo   | Tipo     | Obrigatório | Descrição |
|--------|----------|-------------|-----------|
| parcela | Relation | Sim (single, → parcelas) | Parcela a que a planta pertence. |
| especie | Text     | Sim         | |
| altura_cm | Number | Sim        | |
| dap_cm | Number   | Não         | |
| categoria | Number  | Sim         | 1, 2 ou 3. |

---

## 2. Reset completo do PocketBase

Para evitar erros operacionais (ex: UT gravado como propriedade), o recomendado é **resetar** e usar só este schema.

### 2.1 Passos de reset (manual no Admin)

1. Abrir o PocketBase Admin (ex: `http://localhost:8090/_/`).
2. **Apagar dados** (sempre nesta ordem, por causa das relações):
   - Apagar todos os registos de **plantas**.
   - Apagar todos os registos de **parcelas**.
   - Apagar todos os registos de **uts** (se a coleção existir).
   - Apagar todos os registos de **propriedades** (se a coleção existir).
3. **Remover coleções antigas** (recomendado para evitar confusão):
   - Remover a coleção **parcelas** antiga que tinha campos texto `propriedade` e `prop_ut`.
   - Opcional: remover **uts** e **propriedades** se forem recriar de raiz.
4. **Criar o schema novo** (se ainda não existir):
   - **propriedades**: criar coleção com um único campo `name` (Text, obrigatório).
   - **uts**: criar coleção com `propriedade` (Relation, single, apontando para **propriedades**) e `name` (Text, obrigatório).
   - **parcelas**: criar coleção com `ut` (Relation, single, apontando para **uts**), `id_parcela` (Number), `user` (Text), `area_ha` (Number), `observacoes` (Text). **Não** criar campos `propriedade` nem `prop_ut`.
   - **plantas**: garantir que o campo de relação para parcela aponta para a coleção **parcelas** (e não para uma coleção antiga).
5. **Executar o seed** (na raiz do projeto):  
   `dart run tool/seed_pocketbase_from_csv.dart [caminho/para/planilha.csv]`  
   O seed popula propriedades → uts → parcelas e não grava nunca UT no lugar de Propriedade.

### 2.2 Ordem de criação no seed

1. **propriedades** — um registro por nome único de propriedade (ex: a partir da coluna do CSV que é Propriedade).
2. **uts** — um registro por (propriedade, nome UT), com relação para a propriedade correta.
3. **parcelas** — um registro por parcela, com relação para o UT correto; `user` vazio para parcelas “livres”.

Assim, **nunca** se grava UT no lugar de Propriedade: a propriedade existe só em `propriedades`, e cada parcela chega à propriedade através de `parcela.ut.propriedade`.

---

## 3. Compatibilidade com schema antigo (flat)

O app pode suportar durante a transição:

- **Schema novo**: parcelas com relação `ut` (e expand `ut`, `ut.propriedade`). Pull/Push usam propriedade e UT derivados das relações.
- **Schema antigo**: parcelas com campos texto `propriedade` e `prop_ut`. Pull aplica correção para não tratar UT como propriedade; push grava nos campos texto.

Recomendação: **migrar para o schema normalizado e deixar de usar o schema flat**, para evitar erros operacionais.

---

## 4. Execução do seed após reset

Do projeto (raiz do inventario_florestal):

```bash
dart run tool/seed_pocketbase_from_csv.dart [caminho/para/planilha.csv]
```

O seed:

- Assume que as coleções **propriedades**, **uts** e **parcelas** já existem com a estrutura acima.
- Lê o CSV (col0 = Propriedade, col1 = UT; ou `--swap-columns` se o CSV tiver UT na 1ª coluna).
- Cria primeiro propriedades, depois uts (com relação à propriedade), depois parcelas (com relação ao UT).
- Não grava nunca um valor que pareça UT no lugar de propriedade.

Depois do seed, no app: **Atualizar catálogo do servidor** (ou abrir o explorer com rede) para carregar os dados no dispositivo.
