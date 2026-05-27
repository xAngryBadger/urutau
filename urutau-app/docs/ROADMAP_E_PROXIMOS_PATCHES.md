# Roadmap e Próximos Patches — Inventário Florestal

**Versão base (backup):** `backup_v1.0/inventario_florestal_v1.0.apk`  
**Versão actual:** 2.0.0 (v2)

---

## Versão 2.0 — Resumo

- **Tudo é rascunho até guardar.** Fluxo simplificado: entrar, registar parcelas, sincronizar quando quiser.
- **Gestão de conflitos removida.** Interface comum reduzida ao essencial.
- **Botão Sincronizar** abre uma lista onde:
  1. O app **puxa o estado do servidor primeiro** (para saber conflitos).
  2. Lista de parcelas concluídas a enviar com **checkbox** (marcar as que quer enviar), **lápis** (editar) e botão **Confirmar envio**.
  3. Parcelas **em conflito** (mesma prop/UT/parcela já registada por outro no servidor) aparecem com **aviso** e **não podem ser seleccionadas** para envio.
  4. Após envio, mensagem indica quantas foram enviadas e quantas ficaram em conflito (não enviadas).
- Opções **Puxar do servidor** e **Limpar cache** continuam disponíveis no rodapé da mesma sheet.

---

## Subcamada para aprovação (opções robustas)

Em vez de apenas uma flag `aprovado`, usar subcamada no servidor:

1. **Coleções separadas**
   - `parcelas_pendentes`: dados enviados pelos usuários, em espera de aprovação
   - `parcelas_aprovadas`: após admin aprovar, o registro é movido para aqui
   - Relatórios oficiais consultam só `parcelas_aprovadas`

2. **Fluxo**
   - Push do app → sempre grava em `parcelas_pendentes`
   - Admin, no painel web, vê `parcelas_pendentes`
   - Aprovar → move para `parcelas_aprovadas` (ou duplica e marca original como processado)
   - Rejeitar → marca como rejeitado ou remove (definir política)

3. **Conflitos**
   - Mesmo (propriedade, UT, parcela) por usuários diferentes → indicar conflito no painel
   - Admin escolhe qual versão aprovar ou solicita correção

4. **PocketBase**
   - Duas coleções com schema igual
   - Regras de acesso: usuários só criam em `parcelas_pendentes`; admin lê e escreve em ambas

---

## ✅ Já aplicado (patches atuais)

1. **Descartar limpa dados** — Ao escolher "Descartar" no diálogo de sair, os dados da parcela são limpos (mesmo fluxo de "Limpar dados").
2. **Duplicação ao limpar** — Ao criar nova parcela após limpar, o app reutiliza a parcela disponível em vez de criar outra, evitando duplicatas (ex.: duas "Parcela 1" em faula UT0).
3. **Backup v1.0** — APK funcional salvo em `backup_v1.0/inventario_florestal_v1.0.apk`.

---

## Pendências e dúvidas

### 5. Encaminhar link de UT/propriedade/parcela

**Ideia:** Compartilhar referência (ex.: “faula / UT0 / Parcela 1”) com outro usuário do app, que pode abrir no próprio celular.

**Complexidade:** Precisa de deep links ou um formato reconhecido pelo app (ex.: `inventario://parcela/faula/UT0/1`). Dá para implementar sem mudar o servidor.

### 6. Painel admin em tempo real

**Ideia:** Admin vê quem criou/apagou e resolve pendências antes de subir para o banco principal.

**Opções:**

- **A) Painel web** — App web (Flutter ou outro) conectado ao PocketBase mostrando dados pendentes.
- **B) Subcamada no servidor** — Coleção “parcelas_pendentes” e “parcelas_aprovadas”; admin aprova antes de mover para “parcelas”.
- **C) Flag “aprovado”** — Coluna nas parcelas; admin marca como aprovada antes de liberar para relatórios finais.

**Pergunta:** O PocketBase atual já está em produção? Existe ambiente de homologação para testar isso?

---

## Decisões aplicadas (respostas do utilizador)

- **1. Parcela após limpar:** Permanece no catálogo; ao limpar volta a Disponível. OK.
- **2. Limpar vs apagar slot:** Menu (⋮) em cada parcela no Explorer: "Limpar dados" (parcela fica disponível) ou "Apagar parcela" (remove slot local e servidor). Só criador (`createdBy`) ou admin. `SyncService.deleteParcelaNoServidor` implementado.
- **3. Gestão de conflitos:** Tela `/gestao-conflitos` (ícone no AppBar do Explorer), carregada só ao abrir. Ao sair (voltar ao Explorer), `dispose()` limpa listas e mapas para evitar OOM/ memory leaks. Alternativa leve: botão "Ver parcelas já feitas" — quando está dentro de uma UT, filtra **só parcelas dessa UT** no servidor ("parcelas desta UT já feitas").
- **4. Export:** Dois botões no fluxo XLSX: "Exportar do APP" e "Exportar do Servidor" (pull antes de mostrar opções).
- **5 e 6:** Encaminhar link e painel admin ficam para depois.

**Melhorias feitas:** (a) Gestão de conflitos: `dispose()` libera dados ao sair. (b) "Ver parcelas já feitas": se estiver numa UT, mostra só essa UT. Possível evolução: exibir conflitos no botão de sincronização ao verificar servidor; manter uma única aba/ecrã leve para "parcelas desta UT feitas" em vez de ecrã completo pesado.

---

## Resumo de decisões (actual)

| Item | Decisão |
|------|---------|
| Parcela após limpar | Permanece no catálogo; volta a Disponível. OK. |
| Limpar vs apagar slot | Duas opções: limpar dados (parcela fica disponível) ou apagar slot (local + servidor). Só criador ou admin. |
| Gestão de conflitos | Removida em v2. Conflitos tratados na própria sheet de sync (aviso + bloqueio de envio). |
| Export | "Exportar do APP" e "Exportar do Servidor" (pull antes de escolher). |
| Encaminhar link / Painel admin | Para depois. |

---

## Implementado / Referência

- **Renomear parcela:** no formulário (edição) pode alterar prop/UT/número; validação evita duplicado; push envia UPDATE. **Diminuir parcelas:** menu ⋮ → "Apagar parcela". **Conflitos no sync:** painel de sync exibe conflitos (mesma prop/UT/parcela com outro utilizador no servidor). **Gestão de conflitos:** botão só para admin.
- **Uma aba só para “parcelas desta UT feitas”:** já coberto pelo botão "Ver parcelas já feitas" quando está dentro de uma UT (filtra por essa UT). A tela "Gestão de conflitos" continua como visão global; ao sair, os dados são libertados em `dispose()`.

---

*Documento actualizado em 2026-02-20.*
