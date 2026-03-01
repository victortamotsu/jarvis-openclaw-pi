# Contracts: Jarvis — Interfaces Entre Skills e Sistemas Externos

> Define como as skills se comunicam entre si e com sistemas externos.

---

## 1. Contratos Internos (Skill ↔ Skill)

### 1.1 Criar Pendência (qualquer Skill → Skill 1)

Qualquer skill pode solicitar criação de uma task no sistema de pendências (Google Tasks).

```
CreateCardRequest {
  title:           string          # Obrigatório
  description:     string          # Obrigatório (vai no campo "notes" da task)
  category:        CategoryLabel   # Obrigatório (determina task list)
  urgency:         UrgencyLevel    # Default: INFORMATIVO
  source_skill:    string          # "finance" | "travel" | "programmer"
  actions:         string[]        # Lista de ações (viram sub-tasks)
  reminder_date:   datetime?       # Se definido, seta due date
  deadline:        datetime?       # Data limite
  metadata:        json?           # Dados extras (deal_id, repo_url, etc.)
}

CreateCardResponse {
  card_id:         string
  status:          "CREATED" | "MERGED"  # MERGED se card existente foi atualizado
  merged_with:     string?               # ID do card existente (se MERGED)
}
```

**Regras**:
- Skill 1 busca duplicatas antes de criar (match por título + contato nos últimos 30 dias)
- Se encontrar task similar, faz MERGE (adiciona ao histórico/notes da existente)
- Retorna ID para que a skill chamadora possa referenciar

### 1.2 Atualizar Pendência (qualquer Skill → Skill 1)

```
UpdateCardRequest {
  card_id:         string          # Obrigatório
  add_history:     string?         # Nova entrada de histórico
  add_actions:     string[]?       # Ações adicionais
  set_urgency:     UrgencyLevel?   # Mudar urgência
  set_status:      CardStatus?     # Mudar status
  set_reminder:    datetime?       # Atualizar lembrete
}

UpdateCardResponse {
  success:         boolean
  card_id:         string
  alert_sent:      boolean         # Se urgência gerou alerta via Telegram
}
```

### 1.3 Enviar Alerta ao Usuário (qualquer Skill → Telegram Bot)

```
SendAlertRequest {
  message:         string          # Texto da mensagem (< 500 chars para alerta)
  urgency:         UrgencyLevel   
  skill:           string          # Skill de origem
  action_required: boolean         # Se precisa de resposta do usuário
  options:         string[]?       # Opções de resposta rápida (inline keyboard buttons)
}
```

**Canal de envio**: Telegram Bot (API oficial)

**Regras de throttling** (Constituição Art. IV):
- INFORMATIVO: max 5/hora, agrupados em digest
- AÇÃO_NECESSÁRIA: max 10/hora
- URGENTE: sem limite
- CRÍTICO: sem limite + repeat a cada 15 min até confirmação

### 1.4 Salvar no Google Drive (qualquer Skill → gog)

```
SaveToDriveRequest {
  content:         string          # Conteúdo (markdown ou texto)
  filename:        string          # Nome do arquivo
  folder:          string          # Pasta no Drive ("Jarvis/reports", "Jarvis/imports")
  mime_type:       string          # "text/markdown" | "text/csv" | "application/pdf"
}

SaveToDriveResponse {
  file_id:         string
  share_link:      string          # Link para compartilhar via Telegram
}
```

---

## 2. Contratos Externos (Skill → Sistema)

### 2.1 Firefly III API (Skill 2 → Firefly)

**Base URL**: `http://firefly-iii:8080/api/v1`
**Auth**: `Authorization: Bearer <FIREFLY_TOKEN>`

Operações principais usadas:

```
# Importar transação
POST /transactions
{
  "transactions": [{
    "type": "withdrawal",
    "date": "2026-02-15",
    "amount": "150.00",
    "description": "Supermercado Extra",
    "category_name": "Alimentação",
    "source_name": "Conta Corrente",
    "tags": ["spouse"],
    "notes": "Identificado como cônjuge (regra: Extra Morumbi)"
  }]
}

# Consultar transações com filtro
GET /transactions?start=2026-02-01&end=2026-02-28&type=withdrawal

# Listar categorias
GET /categories

# Relatório por categoria
GET /insight/expense/category?start=2026-02-01&end=2026-02-28

# Relatório por tag (usado para filtrar por membro da família)
GET /insight/expense/tag?start=2026-02-01&end=2026-02-28&tags=child1
```

### 2.2 Google Tasks API (Skill 1 → Google Tasks)

```
# Google Tasks API (oficial)
# Base URL: https://tasks.googleapis.com/tasks/v1
# Auth: OAuth2 (mesmo token Google que Gmail/Drive)

# Listar task lists (uma por categoria)
GET /users/@me/lists

# Criar task
POST /lists/<listId>/tasks
{
  "title": "Responder orçamento caixa d'água",
  "notes": "Pendente desde 28/02. Orçamento de R$350.\n\n[HISTÓRICO]\n2026-02-28 - Recebido via WhatsApp de João",
  "due": "2026-03-02T11:00:00.000Z",
  "status": "needsAction"
}

# Criar sub-task (via parent parameter)
POST /lists/<listId>/tasks
{
  "title": "Ligar para encanador",
  "parent": "<parent-task-id>"
}

# Atualizar task
PATCH /lists/<listId>/tasks/<taskId>
{
  "notes": "<updated notes with history>",
  "status": "completed"
}

# Listar tasks não concluídas  
GET /lists/<listId>/tasks?showCompleted=false
```

**Mapeamento CategoryLabel → Task List**:
- Cada CategoryLabel (PESSOAL, PROFISSIONAL, FINANCEIRO, etc.) é uma task list separada
- Urgência e metadata ficam no campo `notes` (JSON ou texto estruturado)

### 2.3 Gmail (Skills 1,2,3 → gog)

```
# Leitura de emails (Skill 1 - triagem)
gog gmail list --unread --after "2026-03-01" --format json

# Envio de email (Skill 2 - relatório para cônjuge)
gog gmail send --to "<spouse-email>" --subject "Relatório Mensal Fev/2026" --body "<content>"

# Busca específica (Skill 3 - promoções de viagem)  
gog gmail search "subject:(promoção OR deal OR oferta) AND (voo OR hotel OR passagem)"
```

### 2.4 Flight Search (Skill 3 → skill)

```
# Via Flight Search skill
search_flights {
  origin: "GRU",           # Guarulhos
  destination: "MCO",      # Orlando
  departure_date: "2026-07-01",
  return_date: "2026-07-15",
  passengers: 4,
  cabin_class: "economy",
  max_stops: 1
}

# Response
{
  flights: [
    {
      airline: "LATAM",
      price_total: 12400.00,
      price_per_person: 3100.00,
      departure: "2026-07-01T22:30",
      arrival: "2026-07-02T06:15",
      stops: 0,
      duration: "9h45m",
      booking_url: "https://..."
    }
  ]
}
```

### 2.5 GitHub (Skill 4 → GitHub API/CLI)

```
# Criar repositório
gh repo create "victor/<project-name>" --public --description "<desc>"

# Inicializar com spec-kit
cd <project-name>
uvx --from git+https://github.com/github/spec-kit.git specify init . --ai copilot

# Push inicial
git add . && git commit -m "feat: scaffold spec-driven project" && git push
```

---

## 3. Contrato de Scheduling (Cron → OpenClaw)

```bash
# /mnt/external/openclaw-workspace/crontabs/jarvis

# Checagem de canais (WhatsApp leitura + Gmail) - a cada 15 minutos
*/15 * * * * openclaw agent --message "Verificar novos emails e mensagens do WhatsApp. Processar pendências." --max-tokens 500

# Relatório diário via Telegram (22:00)
0 22 * * * openclaw agent --message "Gerar resumo diário de pendências e alertas pendentes. Enviar via Telegram." --max-tokens 1000

# Relatório financeiro mensal (dia 5, 09:00)
0 9 5 * * openclaw agent --message "Gerar relatório financeiro do mês anterior. Enviar para Victor via Telegram e cônjuge via email." --max-tokens 3000

# Checagem de viagens (diária, 07:00 - apenas se há busca ativa)
0 7 * * * openclaw agent --message "Verificar deals de viagem para buscas ativas. Alertar via Telegram se encontrar." --max-tokens 1500

# Health check (a cada 5 minutos)
*/5 * * * * /mnt/external/openclaw-workspace/scripts/healthcheck.sh
```

---

## 4. Fluxo de Interação via Telegram (Canal Principal)

### Comandos do Usuário (Telegram → Agente)

| Comando | Skill | Ação |
|---------|-------|------|
| (mensagem livre) | 1 | Agente interpreta contexto e roteia para skill apropriada |
| `pendencias` | 1 | Lista tasks abertas por urgência |
| `gastos` | 2 | Resumo de gastos do mês atual |
| `gastos <pessoa>` | 2 | Gastos filtrados por membro da família |
| `importar` | 2 | Inicia fluxo de importação (aguarda CSV/PDF no Drive) |
| `viagem <destino>` | 3 | Busca instantânea de passagens |
| `monitorar <destino> <datas>` | 3 | Ativa monitoramento contínuo |
| `ideia <descrição>` | 4 | Registra nova ideia de projeto |
| `status` | - | Status geral do sistema (containers, memória, última execução) |

> **Nota**: Telegram suporta inline keyboards — o agente pode enviar botões de confirmação/opções ao invés de exigir texto livre.

### Formato de Resposta Padrão

```
📋 *PENDÊNCIAS*
━━━━━━━━━━━━━━━
🔴 URGENTE (2)
• Orçamento caixa d'água - vence amanhã
• Responder RH sobre férias

🟡 AÇÃO NECESSÁRIA (3)  
• Agendar pediatra - semana que vem
• Renovar seguro carro - até 15/03
• Review PR #234 - time aguardando

Total: 5 pendências abertas
```
