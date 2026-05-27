# Planilha de espécies (dropdown + preditor)

O formulário de planta passou a ter um campo de espécie com:

- **Switch:** "Nome popular" ou "Nome científico" — o utilizador escolhe qual tipo de nome quer ver e filtrar.
- **Dropdown + preditor:** pode digitar (ex.: "fedego") e a lista filtra em tempo real (ex.: fedegoso-amarela, fedegoso branca). A busca ignora acentos, maiúsculas/minúsculas e trata hífens como espaço.
- **Seleção:** ao tocar num item da lista, o campo é preenchido com esse valor.

## Usar a vossa planilha XLSX

1. Copie o ficheiro (ex.: `Dados espécies arbóreas (3).xlsx`) para a pasta do projeto:
   - `inventario_florestal/assets/dados_especies.xlsx`
2. No `pubspec.yaml`, em `flutter.assets`, adicione:

   ```yaml
   assets:
     - assets/images/
     - assets/animations/
     - assets/dados_especies.xlsx
   ```

3. Faça um rebuild do app.

A planilha deve ter na primeira linha (cabeçalho) colunas que contenham "Nome popular" e "Nome científico" (ou "espécie", "cientifico", etc.). A primeira folha é lida; a primeira linha é o cabeçalho e as seguintes são as espécies.

Se o ficheiro não existir ou não estiver em assets, o app usa uma lista estática de espécies comuns (NI, Eucalyptus grandis, etc.).
