# Data Model: Jarvis — Assistente Pessoal OpenClaw

> Define as entidades lógicas do sistema. Não são tabelas de banco — são conceitos que o agente manipula.

---

## 1. Entidades Principais

### 1.1 Card (Pendência)

Representa um assunto/pendência rastreada no sistema de controle (**Google Tasks**).

```
Card {
  id:              string          # ID interno (gerado pelo Google Tasks)
  title:           string          # Título resumido do assunto
  description:     string          # Contexto detalhado (campo "notes" do Tasks)
  category:        CategoryLabel   # Categorização (mapeada para task list)
  urgency:         UrgencyLevel    # INFORMATIVO | AÇÃO_NECESSÁRIA | URGENTE | CRÍTICO
  status:          CardStatus      # ABERTO | EM_PROGRESSO | AGUARDANDO | RESOLVIDO
  source_channel:  Channel         # WHATSAPP | GMAIL | TELEGRAM | MANUAL | AGENT
  source_contact:  string          # Nome/ID do contato de origem
  actions:         Action[]        # Lista de ações (sub-tasks no Google Tasks)
  history:         HistoryEntry[]  # Log de atualizações (armazenado nas notes)
  reminder_date:   datetime?       # Data de vencimento (due date do Tasks)
  deadline:        datetime?       # Data limite para ação
  created_at:      datetime
  updated_at:      datetime
  related_cards:   string[]        # IDs de cards relacionados
}
```

### 1.2 Action (Ação de um Card)

```
Action {
  description:  string      # "Responder email do João"
  completed:    boolean     # Checkbox status
  due_date:     datetime?   # Prazo específico da ação
  added_at:     datetime
  completed_at: datetime?
}
```

### 1.3 HistoryEntry (Histórico de Card)

```
HistoryEntry {
  timestamp:    datetime
  event_type:   EventType    # CREATED | UPDATED | MESSAGE_RECEIVED | RESPONSE_SENT | STATUS_CHANGED | REMINDER_SET
  summary:      string       # "Fulano respondeu com nova dúvida sobre orçamento"
  source:       Channel      # De onde veio a atualização
  raw_ref:      string?      # Referência à mensagem/email original
}
```

### 1.4 Enums

```
CategoryLabel:
  PESSOAL | PROFISSIONAL | FINANCEIRO | SAÚDE | CASA | VIAGEM | PROJETO_TI | OUTRO

UrgencyLevel:
  INFORMATIVO | AÇÃO_NECESSÁRIA | URGENTE | CRÍTICO

CardStatus:
  ABERTO | EM_PROGRESSO | AGUARDANDO | RESOLVIDO

Channel:
  WHATSAPP | GMAIL | TELEGRAM | GOOGLE_DRIVE | MANUAL | AGENT
  # WHATSAPP = leitura passiva (input-only)
  # TELEGRAM = interação bidirecional (canal principal)
  # GMAIL = leitura de emails

EventType:
  CREATED | UPDATED | MESSAGE_RECEIVED | RESPONSE_SENT | 
  STATUS_CHANGED | REMINDER_SET | DEADLINE_SET | RESOLVED
```

---

## 2. Entidades Financeiras

### 2.1 Transaction (Transação Financeira)

> Mapeada para entidades do Firefly III. O agente manipula via API/MCP.

```
Transaction {
  id:              string          # Firefly III ID
  date:            date
  amount:          decimal
  currency:        string          # BRL
  type:            TransactionType # EXPENSE | INCOME | TRANSFER
  category:        string          # Alimentação, Transporte, etc.
  description:     string          # Descrição original do extrato
  source_account:  string          # Conta corrente / cartão
  destination:     string?         # Destino (para transferências)
  owner:           FamilyMember    # Quem gerou a despesa
  owner_confidence: float          # 0.0-1.0 confiança na atribuição
  tags:            string[]        # Tags adicionais
  notes:           string?         # Observações do agente
  imported_from:   ImportSource    # CSV | PDF | MANUAL
  imported_at:     datetime
}
```

### 2.2 FamilyMember (Titular)

```
FamilyMember {
  id:              string       # victor | spouse | child1 | child2
  name:            string
  card_number_last4: string?    # Últimos 4 dígitos (para identificação)
  monthly_quota:   decimal?     # Cota mensal (se definida)
  email:           string?      # Para receber relatórios
}
```

### 2.3 ImportSession (Sessão de Importação)

```
ImportSession {
  id:              string
  date:            date
  source_file:     string       # Nome do arquivo CSV/PDF
  source_type:     ImportSource # CSV | PDF
  account:         string       # Conta/cartão de origem
  total_records:   int
  imported:        int
  duplicates:      int
  needs_review:    int          # Transações com owner_confidence < 0.8
  status:          ImportStatus # PENDING | PROCESSING | REVIEW | COMPLETED
  created_at:      datetime
}
```

### 2.4 SpendingAlert (Alerta de Gasto)

```
SpendingAlert {
  member:          FamilyMember
  period:          string       # "2026-03"
  quota:           decimal      # Cota definida
  spent:           decimal      # Gasto acumulado
  percentage:      float        # % da cota usado
  triggered_at:    datetime?    # Quando alertou (80% ou 100%)
  alert_level:     string       # WARNING_80 | EXCEEDED_100
}
```

---

## 3. Entidades de Viagem

### 3.1 TravelSearch (Busca de Viagem)

```
TravelSearch {
  id:              string
  destinations:    Destination[]   # Destinos monitorados
  travel_dates:    DateRange[]     # Períodos de interesse
  travelers:       int             # Número de passageiros (4)
  budget:          Budget
  preferences:     TravelPrefs
  active:          boolean         # Monitoramento ativo?
  created_at:      datetime
  last_checked:    datetime
}
```

### 3.2 Destination

```
Destination {
  city:            string       # "Orlando"
  country:         string       # "EUA"
  airports:        string[]     # ["MCO", "SFB"]
  priority:        int          # 1 = mais desejado
}
```

### 3.3 TravelDeal (Oferta Encontrada)

```
TravelDeal {
  id:              string
  type:            DealType      # FLIGHT | HOTEL | PACKAGE
  search_id:       string        # Referência ao TravelSearch
  destination:     string
  price_total:     decimal       # Preço total para todos os viajantes
  price_per_person: decimal
  source:          string        # "Google Flights", "Booking.com"
  url:             string        # Link direto
  details:         string        # Detalhes formatados
  valid_until:     datetime?     # Validade da oferta
  found_at:        datetime
  card_id:         string?       # Task criada no Google Tasks (via Skill 1)
  status:          DealStatus    # FOUND | NOTIFIED | ANALYZING | BOOKED | EXPIRED
}
```

---

## 4. Entidades de Projeto (Skill 4)

### 4.1 ProjectIdea (Ideia de Projeto)

```
ProjectIdea {
  id:              string
  title:           string
  description:     string        # Descrição original recebida via Telegram
  status:          IdeaStatus    # IDEATION | RESEARCHING | SPECIFYING | ACTIVE | ARCHIVED
  github_repo:     string?       # URL do repo criado
  spec_path:       string?       # Path da spec no repo
  research_notes:  string?       # Resultado da pesquisa do agente
  card_id:         string?       # Task no Google Tasks (via Skill 1)
  created_at:      datetime
  updated_at:      datetime
}
```

---

## 5. Entidades de Memória do Agente

### 5.1 AgentMemory (Memória Persistente)

```
AgentMemory {
  key:             string        # Namespace.chave (ex: "travel.preferences")
  value:           any           # JSON value
  skill:           string        # Skill que criou ("travel", "finance", etc.)
  created_at:      datetime
  updated_at:      datetime
  expires_at:      datetime?     # TTL para dados temporários
}
```

Exemplos de memória:
```json
{ "key": "travel.destinations", "value": ["Orlando", "NYC", "London", "Paris", "Rome"] }
{ "key": "finance.quotas.child1", "value": { "monthly": 500, "currency": "BRL" } }
{ "key": "finance.owner_rules", "value": { "LOJA_GAMES": "child1", "SALON_BEAUTY": "spouse" } }
{ "key": "pending.classification_rules", "value": { "keywords_urgent": ["urgente", "prazo", "vence hoje"] } }
```

---

## 6. Relacionamentos

```
Card ──────── 1:N ── Action
Card ──────── 1:N ── HistoryEntry
Card ──────── N:N ── Card (related_cards)

TravelSearch ─ 1:N ── Destination
TravelSearch ─ 1:N ── TravelDeal
TravelDeal ─── 1:1 ── Card (referência cruzada)

ImportSession ─ 1:N ── Transaction
Transaction ─── N:1 ── FamilyMember
FamilyMember ── 1:N ── SpendingAlert

ProjectIdea ─── 1:1 ── Card (referência cruzada)

AgentMemory ─── standalone (key-value store)
```
