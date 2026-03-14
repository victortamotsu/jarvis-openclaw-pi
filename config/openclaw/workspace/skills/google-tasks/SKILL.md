---
name: google-tasks
description: Gerencie as tarefas pessoais e pendências do Victor no Google Tasks — criar, atualizar, listar, completar tasks e sub-tasks com datas de vencimento.
metadata:
  openclaw:
    requires:
      bins:
        - node
      env:
        - GOOGLE_REFRESH_TOKEN
        - GOOGLE_CLIENT_ID
        - GOOGLE_CLIENT_SECRET
---

# google-tasks Skill

Use esta skill para gerenciar a lista de tarefas pessoais do Victor no Google Tasks.

## Quando Usar

- Usuário pede para criar uma tarefa, lembrete ou pendência
- Usuário pede para listar suas tarefas ou pendências em aberto
- Usuário pede para marcar uma tarefa como concluída
- Pipeline de triagem de emails/whatsapp cria uma task nova

## Tools Disponíveis

### `create_task`
Cria uma nova task na lista padrão do Google Tasks.
- `title` (obrigatório): Título curto da tarefa
- `notes` (opcional): Descrição / contexto adicional
- `due` (opcional): Data de vencimento em formato ISO 8601 (ex: `2026-03-15T23:59:59Z`)

### `create_subtask`
Cria uma sub-task vinculada a uma task pai.
- `parent_id` (obrigatório): ID da task pai
- `title` (obrigatório): Título da sub-task

### `list_tasks`
Lista tasks em aberto da lista padrão.
- `max_results` (opcional): Máximo de resultados (padrão: 20)
- `due_min` (opcional): Filtro de data mínima (ISO 8601)

### `update_task`
Atualiza campos de uma task existente.
- `task_id` (obrigatório): ID da task
- `title` (opcional): Novo título
- `notes` (opcional): Novas notas
- `due` (opcional): Nova data de vencimento
- `status` (opcional): `needsAction` ou `completed`

### `complete_task`
Marca uma task como concluída.
- `task_id` (obrigatório): ID da task a ser completada

## Servidor MCP

Este skill usa um servidor MCP stdio localizado em:
```
/home/node/.openclaw/workspace/../../../skills/google-tasks/index.js
```

## Regras de Uso

1. Sempre confirme com o Victor antes de deletar tasks (use `update_task` com `status: completed` em vez de deletar)
2. Para tarefas CRÍTICAS, adicione `🚨` no título
3. Ao listar tasks, agrupe por urgência usando as notas da task

---

## Triagem de Mensagens (Skill 1 — Gestor de Pendências)

Para cada email/mensagem recebido, determinar se precisa de ação:

**Ignorar** (sem ação): "ok", "pdc", "chego em 5 min", "obrigado", acks curtos

**Processar** (criar/atualizar task):
- Perguntas directas ("quando você...?")
- Confirmações de compromisso ("confirma para segunda?")
- Problemas/dúvidas ("não entendi", "deu erro")
- Links/referências para análise

### Algoritmo de Deduplicação (janela 30 dias)

1. Extrair palavras-chave do assunto (remover "Re:", "Fwd:")
2. `list_tasks(show_completed=false, max_results=50, due_min=<30 dias atrás>)`
3. Buscar match: ≥2 palavras-chave no título **E** remetente nas notas
4. **Match encontrado** → `update_task`: notas append `"[HH:MM] @remetente: resumo"` — sem alerta novo
5. **Sem match** → `create_task`: `title="Assunto | @contato"`, notas com timestamp → alerta com urgência

**Exemplo**:
```
Email 1: "Maria: Remarcar reunião para sexta?"
→ create_task "Remarcar reunião sexta | @Maria" → alerta ACAO_NECESSARIA

Email 2 (2h depois): "Maria: Esqueci, pode ser segunda?"
→ MATCH: mesmo assunto + contato
→ update_task: notas append "[14:30] @Maria: alterou para segunda"
→ atualizar alerta (não novo)
```

---

## Encerramento Automático

Ao detectar confirmação em mensagem: "feito", "ok feito", "resolvido", "confirmado", "tá certo":
1. `list_tasks` para encontrar task aberta por assunto+contato
2. `complete_task(task_id)` para marcar concluída
3. Confirmar via Telegram: "✅ Task encerrada: [título]"

---

## Comando `/responder <task_id>`

1. `list_tasks` para buscar task pelo ID
2. Se necessário, `tavily-search` para pesquisar contexto adicional
3. Gerar 2–3 opções de resposta formatadas
4. Enviar ao Victor via Telegram para revisão antes de responder
