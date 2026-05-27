# Urutau — Sistema de Inventário Florestal

**Urutau** é um sistema completo de inventário florestal para coleta de dados em campo. Permite que coletores registrem parcelas e plantas diretamente do celular (Android), mesmo sem internet, e sincronizem os dados com um servidor central quando conectados. Um painel web administrativo permite visualizar, filtrar, exportar e gerenciar todos os dados coletados.

> O nome vem do urutau, ave noturna brasileira da família dos nictibídeos.

---

## O que este projeto faz?

O Urutau resolve um problema real do trabalho florestal: **coletar dados no campo onde não há internet**. O coletor usa o app no celular para registrar propriedades, unidades de talhão (UTs), parcelas e plantas (com fotos). Quando o coletor volta a uma área com conexão, os dados são sincronizados com o servidor. De forma paralela, um administrador acompanha tudo pelo painel web — vendo estatísticas, fotos, exportando relatórios em Excel/PDF e gerenciando usuários.

---

## Funcionalidades

### App móvel (urutau-app)

- **Offline-first**: funciona sem internet; dados ficam no banco local (SQLite)
- **Registro de parcelas e plantas**: espécie, altura, DAP, categoria (1/2/3), fotos
- **Navegação em hierarquia**: Propriedade → UT/Talhão → Parcela → Plantas
- **Câmera integrada**: fotos de parcelas e plantas com compressão automática
- **GPS**: captura de coordenadas nas parcelas
- **Sincronização seletiva**: escolha quais parcelas enviar ao servidor
- **Detecção de conflitos**: parcelas duplicadas entre coletores são sinalizadas
- **Exportação local**: XLSX e PDF mesmo sem conexão
- **Backup/restauração**: exportar/importar banco SQLite completo
- **Login local e remoto**: autenticação no celular e no PocketBase
- **Tema claro/escuro** e modo de alto contraste
- **Modo admin**: gerenciamento de usuários e dados no app

### Painel web (urutau-admin)

- **Dashboard**: estatísticas gerais (propriedades, UTs, parcelas, plantas, usuários)
- **Parcelas**: listagem com filtros por propriedade, UT, usuário, status de sync, fotos
- **Galeria de fotos**: visualização e download das fotos enviadas
- **Relatórios**: exportação Excel e CSV com dados de parcelas e plantas
- **Usuários** (admin): gerenciar permissões, redefinir senhas, excluir contas
- **Autenticação**: login como usuário comum ou superusuário (admin PocketBase)

### Servidor (servidorbadger)

- **PocketBase** v0.36.4: banco de dados, API REST e autenticação
- **Túnel público**: Cloudflare Tunnel ou ngrok para acesso remoto
- **Landing page**: página inicial com links e URL do servidor para copiar
- **Hooks de validação**: previne duplicatas de parcelas e controla permissões de usuários
- **Seed via CSV**: popula o banco a partir de planilhas de mapeamento
- **Pacote Windows**: instalador automatizado com atalhos e inicialização junto ao Windows

---

## Tecnologias Utilizadas

| Componente | Tecnologia |
|---|---|
| App móvel | **Flutter** 3.x + **Dart** 3.x |
| Banco local (app) | **Drift** (SQLite) + `sqlite3_flutter_libs` |
| Banco/servidor | **PocketBase** v0.36.4 (Go, SQLite) |
| Painel web admin | **React** 19 + **Vite** 8 + **Tailwind CSS** 4 |
| Ícones (web) | **Lucide React** |
| Exportação (web) | **SheetJS (xlsx)** |
| Cliente PocketBase (Dart) | `pocketbase` v0.23.2 |
| Cliente PocketBase (JS) | `pocketbase` v0.27.0 |
| Túnel público | **Cloudflare Tunnel** (`cloudflared`) ou **ngrok** |
| Roteamento (web) | **React Router DOM** v7 |
| Sync em background | **workmanager** (Flutter) |
| Fotos | **image_picker** + **flutter_image_compress** |
| Exportação (app) | **excel**, **pdf** + **printing**, **share_plus** |
| Segurança | **flutter_secure_storage**, **crypto** (SHA-256 com salt) |
| Gráficos (app) | **fl_chart** |
| Animações (app) | **lottie** |
| Geolocalização | **geolocator** |
| Lint (Dart) | **flutter_lints** |
| Lint (JS) | **ESLint** 9 + plugins React |
| Licença | **MIT** |

---

## Pré-requisitos

### Para leigos (instalação do servidor no Windows)

- Notebook com **Windows 10+**
- Conexão com internet
- O pacote `servidorbadger-windows-package/` contém tudo necessário

### Para desenvolvedores

| Ferramenta | Versão | Uso |
|---|---|---|
| **Flutter** | >= 3.x | App móvel |
| **Dart** | >= 3.0.0 | App móvel + scripts de seed |
| **Node.js** | >= 18 | Painel web admin |
| **npm** | >= 9 | Gerenciamento de dependências (web) |
| **PocketBase** | v0.36.4 | Servidor (binário pronto, sem instalação) |
| **cloudflared** ou **ngrok** | qualquer | Túnel público para acesso remoto |

---

## Instalação

### 1. Servidor PocketBase (Linux)

```bash
cd servidorbadger/

# Dê permissão de execução
chmod +x pocketbase ngrok start.sh

# Inicie o servidor
./start.sh
```

O script `start.sh` inicia o PocketBase na porta 8090 e o ngrok, detectando a URL pública automaticamente.

### 2. Servidor PocketBase (Windows — pacote de instalação)

1. Copie a pasta `servidorbadger-windows-package/` para o notebook
2. Clique com **botão direito** em `INSTALAR.bat` → **Executar como Administrador**
3. O instalador copia arquivos para `C:\InventarioFlorestal\`, libera a porta 8090 no firewall e cria atalhos na Área de Trabalho
4. Após instalar, clique 2x no atalho **"Inventario Florestal - Iniciar Servidor"**

### 3. Painel Web Admin (urutau-admin)

```bash
cd urutau-admin/

# Instalar dependências
npm install

# Configurar variáveis de ambiente (ver seção Configuração)
cp .env .env.local  # edite conforme necessário

# Rodar em modo desenvolvimento
npm run dev

# Build para produção (arquivos em dist/)
npm run build
```

Após o build, copie o conteúdo de `dist/` para `servidorbadger/pb_public/urutau-admin/` para ser servido pelo PocketBase.

### 4. App Móvel (urutau-app)

```bash
cd urutau-app/

# Instalar dependências Flutter
flutter pub get

# Gerar código Drift (database.g.dart)
dart run build_runner build

# Rodar em emulador/dispositivo conectado
flutter run

# Gerar APK
flutter build apk --release
```

APKs prontos estão disponíveis em `releases/`.

### 5. Seed do banco a partir de CSV

```bash
# Pelo script Dart (dentro de urutau-app/)
dart run tool/seed_pocketbase_from_csv.dart \
  --pb-url=http://localhost:8090 \
  --admin-email=seu-email@exemplo.com \
  --admin-password=sua-senha \
  "caminho/para/Planilha_ISAAC.csv"

# Ou pelo PowerShell (Windows, dentro de servidorbadger/)
powershell -ExecutionPolicy Bypass -File seed_from_csv.ps1 -CsvPath "Planilha.csv"
```

O seed apaga todas as parcelas e plantas existentes e reinsere a partir do CSV.

---

## Uso

### Fluxo típico no campo

1. **Configurar a URL do servidor** no app: Configurações → URL do Servidor → colar a URL pública exibida ao iniciar o servidor
2. **Fazer login** com usuário e senha (criados pelo admin no PocketBase)
3. **Navegar pelo explorer**: Propriedade → UT → Parcelas
4. **Registrar parcela**: preencher dados, tirar fotos, marcar como "pronta para sync"
5. **Adicionar plantas** dentro de cada parcela (espécie, altura, DAP, categoria, foto)
6. **Sincronizar** quando tiver conexão: tela de sync → selecionar parcelas → enviar

### Fluxo típico no escritório (admin)

1. Acessar `http://<URL_DO_SERVIDOR>/urutau-admin/`
2. Fazer login com credenciais de admin
3. Acompanhar estatísticas no Dashboard
4. Visualizar parcelas e fotos, filtrar por propriedade/UT/usuário
5. Exportar relatórios em Excel ou CSV
6. Gerenciar usuários (permissões, senhas)

### URLs importantes

| Recurso | URL |
|---|---|
| Landing page | `http://<URL>/` |
| Painel admin web | `http://<URL>/urutau-admin/` |
| Admin PocketBase | `http://<URL>/_/` |
| API | `http://<URL>/api/` |
| Health check | `http://<URL>/api/health` |

---

## Comandos Disponíveis

### urutau-app (Flutter)

| Comando | Descrição |
|---|---|
| `flutter pub get` | Instalar dependências |
| `dart run build_runner build` | Gerar código Drift (database.g.dart) |
| `flutter run` | Rodar app em modo debug |
| `flutter build apk --release` | Gerar APK de release |
| `flutter analyze` | Analisar código com linter |
| `flutter test` | Rodar testes |

### urutau-admin (React + Vite)

| Comando | Descrição |
|---|---|
| `npm install` | Instalar dependências |
| `npm run dev` | Servidor de desenvolvimento (Vite) |
| `npm run build` | Build de produção |
| `npm run preview` | Visualizar build de produção |
| `npm run lint` | Verificar código com ESLint |
| `npm run deploy` | Deploy para GitHub Pages |

### servidorbadger (Linux)

| Comando | Descrição |
|---|---|
| `./start.sh` | Iniciar PocketBase + ngrok |
| `./pocketbase serve --http=0.0.0.0:8090` | Iniciar só o PocketBase |

### servidorbadger (Windows)

| Script | Descrição |
|---|---|
| `INSTALAR.bat` | Instalar servidor (executar como admin) |
| `iniciar_servidor.bat` | Iniciar PocketBase + Cloudflare Tunnel |
| `parar_servidor.bat` | Parar todos os processos |
| `backup_dados.bat` | Fazer backup dos dados |
| `atualizar_dados.bat` | Atualizar dados a partir de HDD externo |

---

## Estrutura do Projeto

```
urutau/
├── servidorbadger/                  # Servidor PocketBase (Linux)
│   ├── pocketbase                   # Binário PocketBase (Linux amd64)
│   ├── pb_data/                     # Banco de dados SQLite
│   ├── pb_hooks/                    # Hooks de validação
│   │   ├── parcelas_validation.js
│   │   └── users_validation.js
│   ├── pb_migrations/               # Migrações do banco
│   ├── pb_public/                   # Arquivos estáticos servidos pelo PocketBase
│   │   ├── index.html               # Landing page
│   │   └── urutau-admin/            # Painel web admin (build de produção)
│   ├── start.sh                     # Script de inicialização (Linux)
│   ├── seed_from_csv.ps1            # Script de seed via CSV
│   ├── .env.seed.example            # Exemplo de configuração de seed
│   ├── LICENSE.md                   # Licença MIT
│   └── CHANGELOG.md                 # Changelog do PocketBase
│
├── servidorbadger-windows-package/  # Pacote de instalação Windows
│   ├── pocketbase.exe
│   ├── cloudflared.exe
│   ├── INSTALAR.bat                 # Instalador automatizado
│   ├── iniciar_servidor.bat/.ps1
│   ├── parar_servidor.bat
│   ├── backup_dados.bat
│   ├── atualizar_dados.bat
│   ├── find_tunnel_url.ps1
│   ├── pb_data/
│   ├── pb_migrations/
│   └── LEIA-ME.txt
│
├── urutau-app/                      # App móvel Flutter
│   ├── lib/
│   │   ├── main.dart                # Ponto de entrada
│   │   ├── data/
│   │   │   ├── database.dart        # Schema Drift (tabelas locais)
│   │   │   ├── database.g.dart      # Código gerado pelo Drift
│   │   │   ├── categoria_helper.dart
│   │   │   └── especie_item.dart
│   │   ├── screens/
│   │   │   ├── splash_screen.dart
│   │   │   ├── login_screen.dart
│   │   │   ├── home_screen.dart
│   │   │   ├── explorer_screen.dart
│   │   │   ├── parcela_form_screen.dart
│   │   │   ├── planta_form_screen.dart
│   │   │   ├── sync_screen_pro.dart
│   │   │   ├── settings_screen.dart
│   │   │   └── admin_screen.dart
│   │   └── services/
│   │       ├── sync_service.dart    # Sincronização com PocketBase
│   │       ├── backup_service.dart  # Backup/restauração SQLite
│   │       ├── export_service.dart  # Exportação XLSX/PDF
│   │       ├── image_service.dart   # Compressão de imagens
│   │       ├── secure_storage_service.dart
│   │       ├── password_service.dart
│   │       ├── species_service.dart
│   │       └── theme_provider.dart
│   ├── tool/                        # Scripts de seed
│   │   ├── seed_pocketbase_from_csv.dart
│   │   └── README_SEED.md
│   ├── docs/                        # Documentação interna
│   ├── android/                     # Projeto Android
│   ├── windows/                     # Suporte desktop Windows
│   ├── web/                         # Suporte web
│   ├── assets/                      # Imagens e animações
│   ├── test/
│   ├── pubspec.yaml
│   └── analysis_options.yaml
│
├── urutau-admin/                    # Painel web admin (React + Vite)
│   ├── src/
│   │   ├── App.jsx                  # Rotas e layout principal
│   │   ├── main.jsx
│   │   ├── pages/
│   │   │   ├── Dashboard.jsx        # Estatísticas gerais
│   │   │   ├── Parcels.jsx          # Listagem de parcelas
│   │   │   ├── Photos.jsx           # Galeria de fotos
│   │   │   ├── Reports.jsx          # Exportação de relatórios
│   │   │   ├── Users.jsx            # Gerenciamento de usuários
│   │   │   └── Login.jsx
│   │   ├── components/
│   │   │   ├── Layout.jsx
│   │   │   └── ErrorBoundary.jsx
│   │   ├── context/
│   │   │   └── AuthContext.jsx       # Autenticação
│   │   └── services/
│   │       ├── pocketbase.js         # Cliente PocketBase + funções de dados
│   │       └── logger.js
│   ├── public/
│   ├── package.json
│   ├── vite.config.js
│   ├── eslint.config.js
│   └── postcss.config.js
│
├── MMVCServerSIO/                   # Servidor de voz (MMVC, uso experimental)
│   ├── MMVCServerSIO                # Binário
│   ├── model_dir/
│   ├── models/
│   └── pretrain/
│
├── releases/                        # APKs prontos para instalação
│   ├── inventario_florestal_v1.apk
│   ├── inventario_florestal_v2.apk
│   └── urutau_v1.apk
│
└── RENAME_WARNING.txt               # Nota sobre renomeação do projeto
```

---

## Arquitetura

```
┌─────────────────┐          ┌──────────────────────────────────┐
│   urutau-app    │          │        servidorbadger             │
│   (Flutter)     │◄────────►│   (PocketBase v0.36.4)           │
│                 │   API    │                                   │
│  SQLite local   │   REST   │  SQLite (pb_data/)               │
│  (Drift)        │          │  Hooks: validação de parcelas    │
│  Sync offline   │          │  e permissões de usuário         │
│  → online       │          │  Migrações (pb_migrations/)      │
└─────────────────┘          │  Arquivos estáticos (pb_public/) │
                             │  ├── Landing page                │
┌─────────────────┐          │  └── urutau-admin/ (React)       │
│  urutau-admin   │◄────────►│                                   │
│  (React + Vite) │   API    │  Túnel: Cloudflare / ngrok       │
│                 │   REST   │  → URL pública para campo        │
│  Navegador web  │          └──────────────────────────────────┘
└─────────────────┘
```

**Fluxo de dados:**

1. O **app móvel** grava localmente no SQLite (Drift). Quando o coletor marca uma parcela como "pronta para sync" e inicia a sincronização, o app faz **push** (envia dados e fotos) e **pull** (baixa dados do servidor) via API REST do PocketBase.
2. O **servidor PocketBase** armazena tudo em SQLite, aplica validações via hooks (prevenção de duplicatas, controle de permissões) e serve o painel admin como arquivos estáticos.
3. O **painel web** (`urutau-admin`) consome a mesma API REST do PocketBase para visualizar, filtrar e exportar dados.
4. O **túnel** (Cloudflare Tunnel ou ngrok) expõe o servidor localmente na internet, gerando uma URL pública que os coletores usam no campo.

**Hierarquia de dados:**

```
Propriedade → UT/Talhão → Parcela → Plantas
                                   └── Foto da espécie
                         └── Fotos da parcela
```

No PocketBase, as relações são: `plantas.parcela → parcelas`, `parcelas.ut → uts`, `uts.propriedade → propriedades`.

---

## Configuração

### Variáveis de ambiente — servidorbadger

| Variável | Onde | Descrição | Exemplo |
|---|---|---|---|
| `PB_URL` | `.env.seed` | URL do PocketBase | `http://localhost:8090` |
| `PB_ADMIN_EMAIL` | `.env.seed` | Email do admin do PocketBase (dashboard) | `admin@exemplo.com` |
| `PB_ADMIN_PASSWORD` | `.env.seed` | Senha do admin do PocketBase | `sua-senha` |

> **Atenção**: o arquivo `.env.seed` contém credenciais e **nunca** deve ser commitado. Use `.env.seed.example` como modelo.

### Variáveis de ambiente — urutau-admin

| Variável | Onde | Descrição | Exemplo |
|---|---|---|---|
| `VITE_POCKETBASE_URL` | `.env` | URL do PocketBase (vazio = auto-detectar) | `https://tunnel.trycloudflare.com` |
| `VITE_BASE_PATH` | `.env` | Caminho base para deploy | `/urutau-admin/` |

Se `VITE_POCKETBASE_URL` estiver vazio, o app detecta automaticamente a partir de `window.location.origin` (funciona quando servido pelo PocketBase via túnel).

### Configuração no app móvel

A URL do servidor é configurada dentro do app em **Configurações → URL do Servidor**. É salva de forma segura no dispositivo via `flutter_secure_storage`.

---

## Testes

### App móvel

```bash
cd urutau-app/
flutter test
```

O diretório `test/` contém testes de widget (`widget_test.dart`).

### Painel web

O projeto `urutau-admin` não possui testes automatizados configurados atualmente. Para verificar a qualidade do código:

```bash
cd urutau-admin/
npm run lint
```

---

## Solução de Problemas

| Problema | Solução |
|---|---|
| **URL pública não aparece** (Windows) | Aguarde até 60 segundos. Verifique se `cloudflared.exe` está rodando no Gerenciador de Tarefas. Consulte `C:\InventarioFlorestal\cloudflared_output.log`. |
| **URL pública muda a cada reinício** | Isso é normal com túneis gratuitos. Compartilhe a nova URL com os coletores a cada reinício. |
| **App não conecta ao servidor** | Verifique se a URL está correta em Configurações. Teste a conexão pelo botão "Testar". Certifique-se de que o servidor está rodando e o túnel está ativo. |
| **Sincronização falha** | Verifique a conexão com internet. Tente novamente — o app usa retry exponencial (3 tentativas). Verifique se a URL do servidor não mudou. |
| **"Conflito: parcela já existe"** | Outro coletor já registrou essa parcela (mesma propriedade + UT + número). Edite os dados ou escolha outra parcela. |
| **Fotos não aparecem no painel web** | As fotos são sincronizadas junto com as parcelas. Certifique-se de que a parcela foi marcada como "pronta para sync" e enviada. |
| **Erro de autenticação no painel** | Verifique email e senha. Tente login como superusuário (conta do PocketBase Admin) se for admin. |
| **PocketBase não inicia** | Verifique se a porta 8090 não está em uso. No Linux: `lsof -i :8090`. No Windows: `netstat -ano \| findstr :8090`. |
| **Backup necessário antes de atualizar** | No Windows: execute `backup_dados.bat`. No Linux: copie a pasta `pb_data/` manualmente. |
| **Build do Flutter falha** | Execute `dart run build_runner build` para gerar `database.g.dart` antes de compilar. |
| **Deploy do painel web** | `npm run build` gera `dist/`. Copie para `servidorbadger/pb_public/urutau-admin/`. Se usar GitHub Pages: `npm run deploy`. |

---

## Contribuindo

1. Faça um fork do repositório
2. Crie uma branch para sua feature: `git checkout -b feature/nova-funcionalidade`
3. Commit suas mudanças: `git commit -m "Adiciona nova funcionalidade"`
4. Push para a branch: `git push origin feature/nova-funcionalidade`
5. Abra um Pull Request

**Regras importantes:**

- **Nunca** commite arquivos `.env`, `.env.seed`, credenciais, tokens ou chaves
- Execute `flutter analyze` (app) e `npm run lint` (painel web) antes de commitar
- Gere o código Drift com `dart run build_runner build` ao alterar `database.dart`
- Não commite `pb_data/`, `node_modules/`, `build/`, nem binários

---

## Licença

Este projeto está licenciado sob a **Licença MIT**. Veja o arquivo [servidorbadger/LICENSE.md](servidorbadger/LICENSE.md).

Copyright (c) 2022 - present, Gani Georgiev (PocketBase) / Badger (Urutau)
