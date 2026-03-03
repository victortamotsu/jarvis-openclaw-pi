# Implementation Plan: Jarvis — Assistente Pessoal OpenClaw

**Branch**: `001-openclaw-personal-assistant` | **Date**: 2026-03-03 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/001-openclaw-personal-assistant/spec.md`

## Summary

Jarvis é um assistente pessoal de IA self-hosted rodando em um Raspberry Pi 4 (4GB RAM), usando **OpenClaw** como gateway de agente, **GitHub Copilot Pro** como único modelo de linguagem, e **Telegram** como canal principal de interação. O sistema é orquestrado via Docker Compose no Pi e cobre 4 domínios: gestão de pendências omnichannel, finanças pessoais, monitoramento de viagens e prototipagem de projetos de software.

A implementação segue arquitetura de **agente único com skills modulares** — um único agente OpenClaw que orquestra skills via ferramentas, compartilhando contexto e memória. Dados sensíveis são protegidos por anonimização antes de atingir o Copilot; credenciais são gerenciadas via `.env` criptografado com `git-crypt`.

---

## Technical Context

**Language/Version**: Node.js 22+ (runtime OpenClaw + skills MCP) · Python 3.11+ (pipeline CSV/PDF) · Bash (scripts cron)

**Primary Dependencies**:
- `openclaw` — AI agent gateway self-hosted (MIT)
- `@sylphx/pdf-reader-mcp` v2.3.0 — MCP server para parsing de PDF (ARM-compatível, PDF.js)
- `mcporter` — MCP server wrapper para Firefly III REST API
- `openclaw-whatsapp` (ClawHub) — skill nativa para leitura passiva de WhatsApp (Baileys)
- Skill Gmail nativa OpenClaw (ClawHub) — leitura de emails; fallback Gmail API REST (OAuth 2.0)
- `skills/google-tasks/` — MCP stdio custom para Google Tasks REST API
- `skills/telegram-bot/` — MCP stdio custom para Telegram Bot API
- `firefly-iii` — já em execução no Pi (Docker, SQLite)
- `git-crypt` — criptografia de `.env` em repouso
- `tavily-search` (ClawHub) — web search para skills de viagem e programador
- `flight-search` (ClawHub) — busca de passagens aéreas sem API key

**Storage**:
- Firefly III SQLite em `/mnt/external/firefly/` (disco externo)
- OpenClaw workspace files (SOUL.md, USER.md, AGENTS.md) em `/mnt/external/openclaw/`
- JSON persistente para memória estruturada: `owner-rules.json`, `travel-params.json`, `quota-rules.json`
- `.env` criptografado com `git-crypt` no repositório

**Testing**: Scenarios de validação manual E2E definidos em `quickstart.md`; sem testes automatizados na Fase 1-4

**Target Platform**: Raspberry Pi 4 (ARM64, 4GB RAM), Raspberry Pi OS Bookworm 64-bit, Docker Engine 24+

**Project Type**: Self-hosted AI agent / home automation (Docker Compose monorepo)

**Performance Goals**:
- Resposta para consultas simples: < 30 segundos
- Processamento PDF → Firefly: < 5 minutos
- Checagem periódica de canais: a cada 15 minutos
- RAM total de todos os containers: < 3GB

**Constraints**:
- Custo adicional = R$ 0/mês (Constituição Art. I)
- RAM máxima para containers: 3GB (Constituição Art. II)
- Todas as dependências ARM64-compatíveis (Constituição Art. II.2)
- SD card apenas para OS e imagens base; dados no disco externo 2TB (Constituição Art. II.3)
- Dados financeiros anonimizados antes de enviar ao Copilot (Constituição Art. III)
- Nenhuma porta exposta à internet pública (Constituição Art. III.5)

**Scale/Scope**: 1 usuário (Victor), < 200 mensagens/dia entre WhatsApp + Gmail, ~1.2M tokens/mês (subscription Copilot Pro, sem custo adicional)

---

## Constitution Check

*GATE: Verificado pré-Phase 0 e revalidado pós-Phase 1 design.*

| Artigo | Princípio | Status | Evidência |
|--------|-----------|--------|-----------|
| Art. I — Custo Zero | Nenhuma assinatura nova | ✅ PASS | Todos os componentes são open source ou gratuitos; apenas Copilot Pro já existente |
| Art. I §1.2 — Copilot exclusivo | GitHub Copilot é o único modelo | ✅ PASS | OpenClaw configurado com Copilot como único provider; sem Ollama |
| Art. II — RAM < 3GB | Budget de memória total validado | ✅ PASS | OS(500) + Firefly(256) + OpenClaw(900) + skills(300) + buffer(500) = ~2.5GB |
| Art. II.2 — Pi exclusivo | Todos os serviços no Pi | ✅ PASS | Docker Compose no Pi; Windows apenas último recurso documentado |
| Art. II.3 — Disco externo | Dados no HDD externo | ✅ PASS | Todos os volumes Docker apontam para `/mnt/external/` |
| Art. III — Segurança dados | `.env` criptografado, sem portas expostas | ✅ PASS | git-crypt + Tailscale/SSH apenas; dados financeiros anonimizados via `anonymizer.py` |
| Art. IV — Telegram principal | Toda saída via Telegram Bot | ✅ PASS | `/importar`, alertas, relatórios, diálogos — todos via Telegram |
| Art. IV.4 — Concisão | Digest diário para INFORMATIVO; URGENTE/CRÍTICO imediatos | ✅ PASS | Regras de agrupamento de notificações em `SOUL.md` (Art. IV.4 atualizado) |
| Art. V — Agente único | Uma instância OpenClaw | ✅ PASS | Um agente "jarvis" com múltiplas skills; sem overhead multi-agent |
| Art. VI — Semi-autônomo | Ações destrutivas requerem confirmação | ✅ PASS | `SendAlertRequest.action_required` + inline keyboard no Telegram |
| Art. VI.4 — Logs | Toda ação logada | ⚠️ PENDENTE | Implementar logging centralizado em Fase 0 (logging estruturado em `/mnt/external/logs/`) |

**Gates**: 0 violations bloqueantes. Logging (Art. VI.4) aceito como pendente — deve ser adicionado em Fase 0 antes de Fase 1.

---

## Project Structure

### Documentation (this feature)

```text
specs/001-openclaw-personal-assistant/
├── plan.md              ← este arquivo
├── research.md          ← decisões técnicas + updates pós-clarify
├── data-model.md        ← entidades lógicas do sistema
├── quickstart.md        ← cenários de validação E2E por fase
├── contracts/
│   └── interfaces.md    ← contratos entre skills e sistemas externos
└── tasks.md             ← a ser gerado por /speckit.tasks
```

### Source Code (repository root)

```text
jarvis-openclaw-pi/               # raiz do repositório (C:/Users/victo/Projetos/estudos)
│
├── docker-compose.yml             # orquestração: Firefly + OpenClaw + mcporter + scheduler
├── docker-compose.override.yml    # overrides locais (em .gitignore)
├── .env.example                   # template de variáveis (commitado)
├── .env                           # credenciais reais (git-crypt)
├── .gitattributes                 # configuração git-crypt (*.env filter=git-crypt)
│
├── config/
│   ├── openclaw/
│   │   ├── openclaw.json          # config do gateway (model: copilot, channels, skills)
│   │   └── agents/
│   │       └── jarvis/
│   │           ├── SOUL.md        # personalidade base, instruções persistentes
│   │           ├── USER.md        # perfil Victor + família
│   │           └── AGENTS.md     # context de skills disponíveis
│   └── crontabs/
│       └── jarvis                 # cron jobs: check-channels (15min), reports (mensal)
│
├── skills/
│   ├── telegram-bot/              # MCP stdio para Telegram Bot API
│   │   ├── package.json           # dependências Node.js
│   │   ├── index.js               # servidor MCP stdio
│   │   └── README.md
│   ├── google-tasks/              # MCP stdio para Google Tasks REST API
│   │   ├── package.json
│   │   ├── index.js
│   │   └── README.md
│   └── firefly-mcp/               # config do mcporter para Firefly III
│       ├── mcporter.json          # endpoint, auth, tools expostos
│       └── README.md
│
├── scripts/
│   ├── setup-pi.sh                # setup inicial: deps, Docker, volumes, git-crypt
│   ├── check-channels.sh          # chamado pelo cron a cada 15min
│   ├── monthly-report.sh          # chamado pelo cron no dia 5 de cada mês
│   └── import-statement.sh        # gatilho do pipeline de importação CSV+PDF
│
├── pipeline/
│   ├── pdf_parser.py              # extrai transações do PDF via pdf-reader-mcp
│   ├── csv_enricher.py            # merge CSV banco + dados PDF (adiciona coluna owner)
│   ├── anonymizer.py              # mascara nomes/valores antes de enviar ao Copilot
│   └── firefly_importer.py        # importa CSV enriquecido no Firefly via REST API
│
└── docs/
    └── runbook.md                 # operações: restart, backup, troubleshooting
```

**Structure Decision**: Monorepo Docker Compose. Separação clara entre `config/` (declarativo, versionado), `skills/` (Node.js MCPs custom), `scripts/` (bash/cron), `pipeline/` (Python para processamento de dados). Todos os volumes Docker montam de `/mnt/external/` no Pi (disco externo 2TB).

---

## Implementation Strategy

### Fase 0 — Infraestrutura (Semana 1)

**Objetivo**: Pi operacional com OpenClaw respondendo via Telegram.

| Componente | Decisão |
|-----------|---------|
| Docker Compose | `restart: unless-stopped` em todos os containers |
| OpenClaw model | GitHub Copilot Pro (único provider configurado) |
| Telegram | Long polling (sem webhook — sem porta exposta) |
| Credenciais | `git-crypt init` + `git-crypt add-gpg-user <key>` |
| Acesso remoto | Tailscale (sem portas públicas) |
| Logging | `/mnt/external/logs/` com logrotate (Art. VI.4) |

**Budget de RAM — Fase 0**:
```
OS + sistema:             ~500MB
Firefly III (SQLite):     ~256MB
OpenClaw Gateway:         ~800MB
Scheduler (Alpine cron):   ~64MB
─────────────────────────────────
Total:                  ~1.62GB  ✅ (de 3.8GB disponíveis)
```

**Artefatos**: `docker-compose.yml`, `.env.example`, `config/openclaw/openclaw.json`, `config/openclaw/agents/jarvis/SOUL.md`, `scripts/setup-pi.sh`

**Critério de validação**: mensagem `ping` via Telegram → agente responde `pong` em < 30s

---

### Fase 1 — Skill 1: Gestor de Pendências MVP (Semana 2-3)

**Objetivo**: WhatsApp + Gmail → Google Tasks → alertas Telegram com classificação de urgência.

| Integração | Decisão | Fallback |
|-----------|---------|---------|
| WhatsApp | Skill nativa `openclaw-whatsapp` (ClawHub, QR pairing) | Skip WA; restante continua funcional |
| Gmail | Skill Gmail nativa OpenClaw (ClawHub) | Gmail API REST (OAuth 2.0) |
| Google Tasks | MCP stdio custom (`skills/google-tasks/`) | — |
| Google OAuth | Refresh token em `/mnt/external/openclaw/secrets/` | — |
| Cron | `*/15 * * * * bash /app/scripts/check-channels.sh` | — |

**Budget RAM incremental** (adicional à Fase 0):
```
+ openclaw-whatsapp skill  ~100MB
+ google-tasks MCP          ~50MB
─────────────────────────────────
Total Fase 1:             ~1.77GB ✅
```

**Artefatos**: `skills/google-tasks/`, `scripts/check-channels.sh`, `config/crontabs/jarvis`

**Critério de validação**: email real enviado ao Gmail → task criada no Google Tasks → alerta Telegram com urgência correta

---

### Fase 2 — Skill 2: Gestor Financeiro MVP (Semana 4-5)

**Objetivo**: `/importar` via Telegram → pipeline CSV+PDF → Firefly III com titular identificado → consultas em linguagem natural.

| Componente | Decisão |
|-----------|---------|
| Firefly MCP | `mcporter` configurado via `skills/firefly-mcp/mcporter.json` |
| Firefly fallback | REST direto via `pipeline/firefly_importer.py` |
| PDF parsing | `@sylphx/pdf-reader-mcp` via `npx` no pipeline |
| Gatilho importação | Comando `/importar` via Telegram → busca arquivo em `Jarvis/imports/` no Drive |
| Regras de titular | JSON persistente em `/mnt/external/openclaw/memory/owner-rules.json` |
| Anonimização | `pipeline/anonymizer.py` antes de qualquer dado ao Copilot |

**Pipeline de importação**:
```
/importar (Telegram)
    → busca PDF+CSV mais recente em Google Drive (Jarvis/imports/)
    → pdf_parser.py     [pdf-reader-mcp]   → transações por titular
    → csv_enricher.py   [merge]             → CSV enriquecido com coluna 'owner'
    → anonymizer.py     [mascara]           → dados seguros para Copilot
    → categorização     [Copilot]           → categorias Firefly
    → firefly_importer.py [REST API]        → importado no Firefly III
```

**Artefatos**: `pipeline/`, `skills/firefly-mcp/`, `scripts/import-statement.sh`, `scripts/monthly-report.sh`

**Critério de validação**: `/importar` via Telegram → CSV enriquecido com titular → importado Firefly → consulta "quanto gastei em fevereiro?" retornada via Telegram

---

### Fase 3 — Skill 3: Ajudante de Viagens MVP (Semana 6-7)

**Objetivo**: Monitoramento de emails de promoções + pesquisa de voos sob demanda via Telegram.

| Componente | Decisão |
|-----------|---------|
| Parâmetros viagem | JSON em `/mnt/external/openclaw/memory/travel-params.json` |
| Web search | `tavily-search` (ClawHub) |
| Busca de voos | `flight-search` (ClawHub) |
| Booking/Airbnb | Tavily scraping (sem API dedicada) |
| Cron | Diário nos 3 meses antes das datas-alvo |
| Deal report | Telegram + CreateCardRequest (Skill 1) |

**Artefatos**: atualização `config/openclaw/agents/jarvis/SOUL.md` com parâmetros, cron entry para checagem diária

**Critério de validação**: parâmetros definidos → busca executada → resultado formatado via Telegram → task criada

---

### Fase 4 — Skill 4: Agente Programador MVP (Semana 8)

**Objetivo**: Ideia via Telegram → repo GitHub com template spec-kit → spec.md inicial → task Google Tasks.

| Componente | Decisão |
|-----------|---------|
| GitHub CLI | `gh` instalado no Pi host, auth via `GITHUB_TOKEN` |
| Criação de repo | Script bash: `gh repo create + gh repo clone` |
| Spec-kit | `specify init <project> --ai copilot` via shell no Pi |
| Spec inicial | Gerada pelo Copilot via diálogo Telegram |
| Rastreio | CreateCardRequest (Skill 1) com link do repo |

**Artefatos**: `scripts/create-project.sh`

**Critério de validação**: ideia via Telegram → repo criado no GitHub → spec.md gerada → task Google Tasks com link

---

### Fase 5 — Integração e Polimento (Semana 9-10)

- Logging centralizado em `/mnt/external/logs/` com `logrotate` (fecha gap Art. VI.4)
- Otimização de prompts por tipo de tarefa (token efficiency — Art. I §1.4)
- Backup automático semanal: SQLite dump + `openclaw/` config para `/mnt/external/backups/`
- Teste de recovery: simular falha de container + `restart: unless-stopped`
- `docs/runbook.md` com playbooks de operação e troubleshooting

---

## Complexity Tracking

| Decisão | Justificativa | Alternativa mais simples rejeitada |
|---------|--------------|-----------------------------------|
| MCP (mcporter) + REST fallback (Firefly) | Infraestrutura MCP reusável para outros MCPs futuros | Apenas REST: suficiente para Fase 2, mas não prepararia ambiente MCP |
| Pipeline Python isolado (pdf+csv+anonymizer) | PDF parsing robusto em ARM; anonimização obrigatória antes do Copilot (Art. III) | Enviar PDF ao Copilot diretamente: violaria Art. III |
| `git-crypt` para `.env` | Tokens no repositório criptografados em repouso | `.env` em `.gitignore`: mais simples mas sem proteção se backup vazar |
| MCP stdio custom para Google Tasks | Expõe Google Tasks como "tool" nativa do agente OpenClaw | REST direto via script: funciona mas não integra nativamente como tool do agente |

---

## Dependency Graph

```
Fase 0 (infra base: Docker, OpenClaw, Telegram, git-crypt, logging)
    ↓
Fase 1 (Skill 1 — pendências: WA, Gmail, Tasks, alertas)
    ↓                     ↓
Fase 2                  Fase 3        ← Fase 3 e 4 independentes entre si
(Skill 2 — finanças)   (Skill 3 — viagens)
    ↓                     ↓
                        Fase 4
                       (Skill 4 — programador)
                            ↓
                        Fase 5 (polimento + integração cross-skill)
```

**Nota**: Fases 3 e 4 podem ser paralelizadas após Fase 1 estar completa.

