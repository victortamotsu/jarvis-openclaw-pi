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

### 2.4 SerpAPI Google Flights (Skill 3 → SerpAPI)

```bash
# Request
GET https://serpapi.com/search.json \
  ?engine=google_flights \
  &departure_id=GRU \
  &arrival_id=MCO \
  &outbound_date=2026-07-01 \
  &return_date=2026-07-15 \
  &adults=4 \
  &currency=BRL \
  &hl=pt \
  &type=1 \
  &api_key=$SERP_API_KEY

# type: 1 = ida e volta | 2 = somente ida
# departure_id / arrival_id: código IATA do aeroporto
```

**Response (campos relevantes)**:

```json
{
  "search_metadata": {
    "google_flights_url": "https://www.google.com/flights?...",
    "cached": false
  },
  "best_flights": [
    {
      "flights": [
        {
          "airline": "LATAM Airlines",
          "flight_number": "LA 8084",
          "departure_airport": { "id": "GRU", "time": "2026-07-01 22:30" },
          "arrival_airport":  { "id": "MIA", "time": "2026-07-02 04:15" },
          "duration": 345,
          "airplane": "Boeing 767"
        },
        {
          "airline": "American Airlines",
          "flight_number": "AA 1234",
          "departure_airport": { "id": "MIA", "time": "2026-07-02 09:00" },
          "arrival_airport":  { "id": "MCO", "time": "2026-07-02 09:55" },
          "duration": 55
        }
      ],
      "layovers": [
        { "id": "MIA", "name": "Miami International Airport", "duration": 285 }
      ],
      "total_duration": 685,
      "price": 2800,
      "type": "Round trip"
    }
  ]
}
```

**Mapeamento para formato obrigatório de saída** (AC Skill 3):

| Campo AC | Campo SerpAPI |
|----------|---------------|
| Airline + número do voo | `best_flights[0].flights[0].airline` + `.flight_number` |
| Horário partida com IATA | `departure_airport.id` + `departure_airport.time` |
| Horário chegada com IATA (+d) | `arrival_airport.id` + `arrival_airport.time` (calcular +d se datas diferem) |
| Duração total | `best_flights[0].total_duration` (minutos → "Xh Ym") |
| Número de escalas | `len(best_flights[0].layovers)` |
| Preço/pessoa em BRL | `best_flights[0].price` |
| Total para todos adultos em BRL | `best_flights[0].price * adults` |
| Link Google Flights | `search_metadata.google_flights_url` |

**Regras**:
- Antes de chamar: verificar `serp-usage.json` (`blocked == true` → retornar erro sem chamada HTTP)
- Se `search_metadata.cached == true`: não incrementar contador de cota
- Retornar sempre mínimo 1 opção (`best_flights[0]`); listar até 3 se houver

### 2.5 Airbnb MCP (Skill 3 → mcp-server-airbnb)

**Configuração no openclaw.json**:
```json
{
  "mcp_servers": [
    {
      "name": "airbnb",
      "command": "npx",
      "args": ["-y", "@openbnb/mcp-server-airbnb"]
    }
  ]
}
```

**Tool: `airbnb_search`**:
```json
{
  "location": "Orlando, Florida",
  "checkin": "2026-07-01",
  "checkout": "2026-07-15",
  "adults": 4,
  "children": 0,
  "minPrice": 100,
  "maxPrice": 300
}
```

**Tool: `airbnb_listing_details`**:
```json
{
  "id": "<listing-id>",
  "checkin": "2026-07-01",
  "checkout": "2026-07-15",
  "adults": 4
}
```

**Configuração docker-compose (container mcp-airbnb)**:
```yaml
mcp-airbnb:
  image: node:20-alpine
  command: npx -y @openbnb/mcp-server-airbnb
  restart: unless-stopped
  mem_limit: 200m
  # robots.txt: compliance ativada por padrão (sem --ignore-robots-txt)
  # Se smoke test falhar: adicionar arg --ignore-robots-txt e documentar decisão
```

**Regras**:
- robots.txt compliance ativada por padrão; ativar `--ignore-robots-txt` só após confirmação de falha no smoke test
- `airbnb_search` é o ponto de entrada; `airbnb_listing_details` apenas para detalhamento pedido pelo usuário

### 2.6 SerpAPI Quota Management (Skill 3 → serp-usage.json)

```
Antes de cada chamada SerpAPI:
  1. Ler /mnt/external/openclaw/memory/serp-usage.json
  2. Se month != currentMonth: reset (calls_used=0, alert_80_sent=false, blocked=false, month=currentMonth)
  3. Se blocked == true: RETORNAR ERRO sem chamada HTTP
     Mensagem: "Cota SerpAPI esgotada (250/250). Renova em 1º de [mes seguinte]."

Após chamada bem-sucedida (somente se cached == false):
  4. calls_used += 1; last_call = now()
  5. Se calls_used == 200: alert_80_sent = true; enviar Telegram AVISO
     Mensagem: "⚠️ SerpAPI: 200/250 chamadas usadas em [mês]. Monitoramentos automáticos podem ser suspensos."
  6. Se calls_used >= 250: blocked = true; enviar Telegram ALERTA
     Mensagem: "🛑 SerpAPI: cota esgotada (250/250). Buscas de voo desativadas até 1º de [mês seguinte]."
  7. Salvar serp-usage.json
```

**Health check semanal** (scheduler cron):
```bash
# Semanal (domingo 08:00)
0 8 * * 0 openclaw agent --message "Health check: executar 1 busca SerpAPI de teste (GRU-GIG proxima semana) + verificar mcp-airbnb acessível. Alertar Telegram APENAS se falhar."
# Consome ~4 chamadas SerpAPI/mês; silencioso em caso de sucesso
```

### 2.7 GitHub (Skill 4 → GitHub API/CLI)

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
| `importar` | 2 | Busca PDF+CSV mais recente em `Jarvis/imports/` no Drive → executa pipeline de enriquecimento → importa no Firefly III → confirma via Telegram |
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
