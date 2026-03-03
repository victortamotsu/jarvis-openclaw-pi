# Tasks: Jarvis — Assistente Pessoal OpenClaw

**Input**: Design documents from `/specs/001-openclaw-personal-assistant/`
**Prerequisites**: plan.md ✅ · spec.md ✅ · research.md ✅ · data-model.md ✅ · contracts/interfaces.md ✅ · quickstart.md ✅

**Tests**: Não incluso (sem TDD explícito na spec). Critérios de validação E2E em quickstart.md por fase.

**Organization**: Tasks agrupadas por user story (US1→US4) para permitir implementação e teste independentes.

## Format: `[ID] [P?] [Story?] Description`

- `[P]` = paralelizável (arquivos diferentes, sem dependência de task incompleta)
- `[US1]...[US4]` = user story de origem
- Setup / Foundational = sem label de story

---

## Path Conventions

```text
/                             → raiz do repositório (C:/Users/victo/Projetos/estudos)
config/openclaw/              → configuração do OpenClaw Gateway
config/openclaw/agents/jarvis/ → workspace files do agente (SOUL.md, USER.md, AGENTS.md)
config/crontabs/              → definições de cron jobs
skills/google-tasks/          → MCP stdio custom para Google Tasks API
skills/telegram-bot/          → MCP stdio custom para Telegram Bot API (se necessário)
skills/firefly-mcp/           → config do mcporter para Firefly III
scripts/                      → scripts bash executados pelo cron e pelo agente
pipeline/                     → scripts Python para processamento CSV+PDF
docs/                         → documentação operacional
/mnt/external/openclaw/       → dados persistentes do OpenClaw no Pi (disco externo)
/mnt/external/openclaw/memory/ → JSON files de memória estruturada
```

---

## Phase 1: Setup (Infraestrutura Base)

**Purpose**: Estrutura do repositório, Docker Compose base, credenciais e workspace do agente.

- [ ] T001 Criar estrutura de diretórios do repositório conforme plan.md: `config/openclaw/agents/jarvis/`, `config/crontabs/`, `skills/google-tasks/`, `skills/firefly-mcp/`, `scripts/`, `pipeline/`, `docs/`
- [ ] T002 Criar `docker-compose.yml` com serviços base: `firefly-iii` (existente) + `openclaw` (mem_limit: 1g, volume /mnt/external/openclaw) + `scheduler` (Alpine cron, mem_limit: 64m)
- [ ] T003 [P] Criar `.env.example` com todas as variáveis necessárias: `GITHUB_TOKEN`, `TELEGRAM_BOT_TOKEN`, `TELEGRAM_CHAT_ID`, `GOOGLE_CLIENT_ID`, `GOOGLE_CLIENT_SECRET`, `GOOGLE_REFRESH_TOKEN`, `FIREFLY_TOKEN`, `FIREFLY_URL`
- [ ] T004 [P] Configurar `git-crypt`: adicionar `.gitattributes` com `*.env filter=git-crypt diff=git-crypt`, documentar setup em `docs/runbook.md` (seção "Setup inicial")
- [ ] T005 Criar `config/openclaw/agents/jarvis/SOUL.md` com personalidade do agente, instruções de comportamento (concisão, throttling, confirmação antes de ações destrutivas), e mapeamento de skills disponíveis
- [ ] T006 [P] Criar `config/openclaw/agents/jarvis/USER.md` com perfil de Victor (preferências, família: spouse, child1, child2) e `config/openclaw/agents/jarvis/AGENTS.md` com referência às skills disponíveis
- [ ] T007 [P] Criar `docs/runbook.md` com seções iniciais: Setup inicial, Restart de containers, Backup manual, Troubleshooting comum

---

## Phase 2: Foundational (Pré-requisitos Bloqueantes)

**Purpose**: Infraestrutura de runtime que DEVE estar completa antes de qualquer user story.

**⚠️ CRÍTICO**: Nenhuma skill pode ser implementada até esta fase estar completa e validada.

- [ ] T008 Criar `config/openclaw/openclaw.json` configurando: modelo exclusivo GitHub Copilot, Telegram como canal primário (long polling, sem webhook), e lista de skills a serem carregadas
- [ ] T009 Criar `scripts/setup-pi.sh` cobrindo: verificação de Docker, criação de `/mnt/external/{openclaw,openclaw/memory,logs,backups,firefly}`, permissões, montagem de disco externo
- [ ] T010 [P] Configurar logging centralizado: criar estrutura `/mnt/external/logs/{openclaw,firefly,scheduler}/` e arquivo `config/logrotate.conf` com rotação semanal e retenção de 90 dias (Art. VI.4)
- [ ] T011 Configurar Telegram Bot: registrar bot via BotFather, obter `TELEGRAM_BOT_TOKEN` e `TELEGRAM_CHAT_ID`, adicionar ao `.env`, validar com `curl https://api.telegram.org/bot$TOKEN/getMe`
- [ ] T012 Subir e validar OpenClaw Gateway: `docker compose up openclaw -d`, executar `openclaw agent --message "ping"` e confirmar resposta do Copilot (Quickstart 0.1, 0.2)
- [ ] T013 Validar Telegram Bot integrado ao OpenClaw: enviar mensagem de texto ao bot e confirmar que o agente responde via Telegram (Quickstart 0.3)
- [ ] T014 Configurar Google OAuth 2.0: criar credenciais OAuth no Google Cloud Console com scopes `gmail.readonly`, `tasks`, `drive.file`; executar fluxo de autorização; armazenar refresh token em `/mnt/external/openclaw/secrets/google-tokens.json`
- [ ] T015 [P] Validar acesso Firefly III API: `curl http://localhost:8080/api/v1/about -H "Authorization: Bearer $FIREFLY_TOKEN"` retorna versão (Quickstart 0.7)
- [ ] T016 [P] Validar disco externo montado e volumes Docker apontando corretamente: `df -h /mnt/external` + `docker compose config` para verificar bind mounts (Quickstart 0.8)

**Checkpoint**: Gateway respondendo via Telegram + OAuth Google ativo + Firefly acessível = fase 2 completa. User stories podem iniciar.

---

## Phase 3: User Story 1 — Gestor de Pendências MVP (Priority: P1) 🎯 MVP

**Story goal**: Agente detecta pendências em WhatsApp + Gmail → cria tasks no Google Tasks → envia alertas diferenciados via Telegram.

**Independent test criteria**: Enviar email ao Gmail → task criada no Google Tasks com título/urgência corretos → alerta Telegram recebido com criticidade correspondente (Quickstart Fase 1).

- [ ] T017 [P] [US1] Criar `skills/google-tasks/package.json` e `skills/google-tasks/index.js`: MCP stdio server Node.js que expõe tools: `create_task`, `update_task`, `list_tasks`, `create_subtask`, `complete_task`
- [ ] T018 [P] [US1] Implementar operações CRUD completas no `skills/google-tasks/index.js`: criação com título/notes/due_date/status, atualização de notes (append histórico), listagem por task list, via Google Tasks REST API (`https://tasks.googleapis.com/tasks/v1`)
- [ ] T019 [US1] Implementar lógica de sub-task no `skills/google-tasks/index.js`: criar sub-tasks com campo `parent`, seguindo estrutura de `Action` do data-model.md
- [ ] T020 [P] [US1] Configurar skill `openclaw-whatsapp` no `config/openclaw/openclaw.json`: habilitar skill via ClawHub, configurar para leitura passiva apenas (sem envio), documentar QR pairing em `docs/runbook.md`
- [ ] T021 [P] [US1] Configurar skill Gmail nativa no `config/openclaw/openclaw.json`: habilitar skill ClawHub com scopes de leitura; adicionar fallback comment para Gmail API REST em caso de indisponibilidade
- [ ] T022 [US1] Implementar prompt de classificação de urgência em `config/openclaw/agents/jarvis/SOUL.md`: instruções para classificar mensagens/emails em INFORMATIVO | AÇÃO_NECESSÁRIA | URGENTE | CRÍTICO com exemplos concretos (~200 tokens)
- [ ] T023 [US1] Implementar lógica de deduplicação em `config/openclaw/agents/jarvis/SOUL.md`: instruções para buscar task existente via `list_tasks` (match título + contato, janela 30 dias) antes de criar nova; se encontrar, fazer `update_task` com novo histórico
- [ ] T024 [US1] Criar `scripts/check-channels.sh`: script bash que dispara `openclaw agent --message "Verificar novos emails e mensagens WhatsApp. Processar pendências conforme instruções." --max-tokens 500`
- [ ] T025 [US1] Criar `config/crontabs/jarvis` com regras de cron: checagem a cada 15min (`*/15 * * * *`), resumo diário às 22h (`0 22 * * *`), relatório mensal dia 5 às 9h (`0 9 5 * *`)
- [ ] T026 [US1] Implementar throttling de alertas Telegram em `config/openclaw/agents/jarvis/SOUL.md`: regras INFORMATIVO (max 5/hora, agrupar em digest), AÇÃO_NECESSÁRIA (max 10/hora), URGENTE/CRÍTICO (sem limite; CRÍTICO repete a cada 15min até confirmação)
- [ ] T027 [US1] Validação E2E Skill 1: executar cenário completo do Quickstart Fase 1 (email real → task criada → alerta Telegram com urgência correta) e registrar resultado

---

## Phase 4: User Story 2 — Gestor Financeiro MVP (Priority: P2)

**Story goal**: `/importar` via Telegram aciona pipeline CSV+PDF → Firefly III com titular identificado → consultas em linguagem natural funcionam.

**Independent test criteria**: Enviar `/importar` via Telegram com CSV+PDF reais no Drive → Firefly III atualizado com dados e titular → consulta "quanto gastei em fevereiro?" retorna resposta correta (Quickstart Fase 2).

- [ ] T028 [P] [US2] Criar `skills/firefly-mcp/mcporter.json`: configurar mcporter apontando para `http://firefly-iii:8080/api/v1`, auth Bearer `$FIREFLY_TOKEN`, expondo tools: `get_transactions`, `create_transaction`, `get_categories`, `get_expense_report`
- [ ] T029 [P] [US2] Criar `pipeline/pdf_parser.py`: script Python que chama `@sylphx/pdf-reader-mcp` via subprocess/npx, extrai texto e tabelas do PDF de fatura, retorna lista de transações com campos: data, estabelecimento, valor, titular (quando identificado)
- [ ] T030 [P] [US2] Criar `pipeline/csv_enricher.py`: lê CSV do banco (colunas: data, estabelecimento, valor), lê saída do `pdf_parser.py`, faz merge por (data ≈ ±1 dia, valor exato, estabelecimento similar), adiciona coluna `owner` ao CSV enriquecido; consulta `/mnt/external/openclaw/memory/owner-rules.json` para matches automáticos
- [ ] T031 [P] [US2] Criar `pipeline/anonymizer.py`: substitui nomes de titulares por IDs (`victor`→`MEMBER_A`), mascara valores exatos por faixas (R$0-100→`LOW`, R$100-500→`MED`, >500→`HIGH`) para envio seguro ao Copilot (Art. III)
- [ ] T032 [US2] Criar `pipeline/firefly_importer.py`: lê CSV enriquecido, chama `POST /transactions` na Firefly REST API para cada linha, marca titular como tag, registra resumo de importação (total, duplicatas, erros)
- [ ] T033 [US2] Criar `scripts/import-statement.sh`: orquestra o pipeline completo: download do arquivo do Drive → `pdf_parser.py` → `csv_enricher.py` → `anonymizer.py` → categorização via Copilot → `firefly_importer.py` → confirma resultado via Telegram
- [ ] T034 [US2] Implementar handler do comando `/importar` no agente: instrução em `SOUL.md` para, ao receber `/importar`, buscar arquivo mais recente em `Jarvis/imports/` no Google Drive e disparar `scripts/import-statement.sh`
- [ ] T035 [US2] Implementar persistência e aprendizado de regras de titular: `pipeline/csv_enricher.py` deve salvar regras confirmadas em `/mnt/external/openclaw/memory/owner-rules.json` no formato `{"ESTABELECIMENTO": "member_id"}`; instrução em `SOUL.md` para perguntar titulares ambíguos via Telegram e salvar resposta
- [ ] T036 [US2] Criar `scripts/monthly-report.sh`: gera relatório de gastos por categoria e por titular do mês anterior via Firefly REST API, formata em Markdown, envia link do Google Drive via Telegram para Victor e email para cônjuge
- [ ] T037 [US2] Implementar alertas de cota de gastos: instrução em `SOUL.md` para verificar quotas em `/mnt/external/openclaw/memory/quota-rules.json` e alertar via Telegram quando `spent >= 80%` (WARNING) e `>= 100%` (CRÍTICO) da cota mensal por titular
- [ ] T038 [US2] Validação E2E Skill 2: executar cenário completo do Quickstart Fase 2 (CSV real + PDF real → `/importar` → Firefly atualizado → consulta NL respondida) e registrar resultado

---

## Phase 5: User Story 3 — Ajudante de Viagens MVP (Priority: P3)

**Story goal**: Usuário define parâmetros de viagem → agente monitora e alerta via Telegram quando encontrar deal dentro do orçamento.

**Independent test criteria**: Definir parâmetros via Telegram (`/monitorar`) → pesquisa executada → resultado formatado via Telegram → task criada no Google Tasks (Quickstart Fase 3).

- [ ] T039 [P] [US3] Criar schema e arquivo inicial `travel-params.json` em `/mnt/external/openclaw/memory/travel-params.json`: campos `destinations`, `travel_dates`, `travelers`, `budget`, `preferences`, `active` conforme data-model `TravelSearch`
- [ ] T040 [P] [US3] Habilitar skill `tavily-search` no `config/openclaw/openclaw.json` via ClawHub (web search geral para preços e reviews)
- [ ] T041 [P] [US3] Habilitar skill `flight-search` no `config/openclaw/openclaw.json` via ClawHub (busca estruturada de passagens, sem API key)
- [ ] T042 [US3] Implementar handler do comando `/monitorar` em `SOUL.md`: parsear destino + datas + orçamento do texto Telegram, salvar em `travel-params.json` com `active: true`, confirmar via Telegram
- [ ] T043 [US3] Implementar lógica de detecção de deal em `SOUL.md`: ao executar busca, comparar `price_per_person` encontrado com `budget.max_per_person`, classificar como deal se `price <= budget`; formatar alerta com: airline, preço total, preço/pessoa, paradas, link
- [ ] T044 [US3] Adicionar entrada no `config/crontabs/jarvis` para checagem diária de viagens: `0 7 * * * openclaw agent --message "Verificar deals de viagem para buscas ativas em travel-params.json. Alertar se encontrar dentro do orçamento." --max-tokens 1500`
- [ ] T045 [US3] Implementar notificação de deal: alerta via Telegram (formato definido em `contracts/interfaces.md`) + CreateCardRequest para Skill 1 com deadline de 48h para análise
- [ ] T046 [US3] Validação E2E Skill 3: executar cenário completo do Quickstart Fase 3 (parâmetros → busca → alerta Telegram → task criada) e registrar resultado

---

## Phase 6: User Story 4 — Agente Programador MVP (Priority: P4)

**Story goal**: Victor envia ideia via Telegram → agente pesquisa, cria repo GitHub com spec-kit, gera spec.md inicial, registra no Google Tasks.

**Independent test criteria**: Mensagem de ideia via Telegram → confirmação do usuário → repo criado no GitHub → spec.md gerada → task no Google Tasks com link do repo (Quickstart Fase 4).

- [ ] T047 [P] [US4] Instalar e autenticar GitHub CLI (`gh`) no Pi: `apt install gh`, `gh auth login --web` com `GITHUB_TOKEN`, validar com `gh repo list`
- [ ] T048 [P] [US4] Criar `scripts/create-project.sh`: recebe `project-name` e `description` como args, executa `gh repo create "victortamotsu/$name" --public --description "$desc"`, clona em `/mnt/external/projects/`, executa `specify init . --ai copilot --force` dentro do clone
- [ ] T049 [US4] Implementar handler do comando `/ideia` em `SOUL.md`: ao receber ideia via Telegram, (1) pesquisar soluções existentes via tavily-search, (2) responder com resumo de soluções + diferencial proposto, (3) apresentar botão de confirmação [CRIAR PROJETO / CANCELAR]
- [ ] T050 [US4] Implementar fluxo de criação de repo em `SOUL.md`: ao receber confirmação, gerar nome-de-projeto (kebab-case), executar `scripts/create-project.sh`, aguardar conclusão, reportar URL do repo via Telegram
- [ ] T051 [US4] Implementar registro de projeto via Skill 1 em `SOUL.md`: após criar repo, chamar `create_task` (google-tasks MCP) com título `"Projeto: <name>"`, notes com link do repo + resumo da ideia, category `PROJETO_TI`, urgency `INFORMATIVO`
- [ ] T052 [US4] Validação E2E Skill 4: executar cenário completo do Quickstart Fase 4 (ideia via Telegram → pesquisa → confirmação → repo criado → spec.md → task Google Tasks) e registrar resultado

---

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose**: Logging (Art. VI.4), backup, otimização de tokens, documentação operacional, validação de recovery.

- [ ] T053 [P] Implementar logging estruturado em todos os scripts bash (`scripts/*.sh`): redirecionar stdout/stderr para `/mnt/external/logs/{script-name}/YYYY-MM-DD.log` com timestamps
- [ ] T054 [P] Criar `config/logrotate.conf` e registrar no `docker-compose.yml` scheduler: rotação semanal, compressão gzip, retenção 90 dias (Art. VI.4 — fecha gap do Constitution Check)
- [ ] T055 [P] Criar script de backup semanal em `config/crontabs/jarvis`: `0 3 * * 0` → dump SQLite do Firefly + tar do `/mnt/external/openclaw/` → salvar em `/mnt/external/backups/YYYY-WW/`
- [ ] T056 Otimizar prompts em `config/openclaw/agents/jarvis/SOUL.md` por tipo de tarefa: prompt compacto para classificação (~200 tokens), prompt médio para extração (~500 tokens), prompt completo para análise (~1500 tokens) (Art. I §1.4)
- [ ] T057 [P] Completar `docs/runbook.md`: adicionar playbooks de restart de container, restore de backup, re-pairing do WhatsApp, revogação/renovação de tokens OAuth
- [ ] T058 Executar teste de recovery: parar container `openclaw` manualmente → verificar restart automático via `restart: unless-stopped` → confirmar uptime via `docker ps`
- [ ] T059 Commit e push de todos os artefatos de implementação para o repositório GitHub `victortamotsu/jarvis-openclaw-pi`

---

## Dependencies & Execution Order

```
Phase 1 (Setup)
    ↓
Phase 2 (Foundational) ← BLOQUEANTE: todas as fases dependem desta
    ↓
Phase 3 (US1 — Pendências) ← MVP — deve ser validada antes de Phase 4
    ↓
Phase 4 (US2 — Finanças) ←── independente de Phase 5 e 6
Phase 5 (US3 — Viagens)  ←── independente de Phase 4 e 6 (requer Phase 3 para CreateCardRequest)
Phase 6 (US4 — Programador) ← independente de Phase 4 e 5 (requer Phase 3 para CreateCardRequest)
    ↓
Phase 7 (Polish)
```

**Paralelização possível**:
- Phase 4, 5 e 6 podem ser executadas em paralelo após Phase 3 estar validada
- Dentro de cada Phase, tasks marcadas `[P]` podem ser executadas simultaneamente

---

## Parallel Example: User Story 1 (Phase 3)

Tasks que podem rodar em paralelo após Phase 2 completa:

```
Grupo A (sem dependências mútuas):
  T017 — skills/google-tasks/ package.json + index.js (estrutura)
  T020 — configurar openclaw-whatsapp no openclaw.json
  T021 — configurar Gmail skill no openclaw.json
  T018 — implementar CRUD no google-tasks MCP (depende T017)

Grupo B (sem dependências mútuas):
  T022 — prompt de classificação de urgência em SOUL.md
  T023 — lógica de deduplicação em SOUL.md
  T026 — regras de throttling em SOUL.md

Sequencial (depende de A e B):
  T019 → T024 → T025 → T027
```

---

## Implementation Strategy Summary

| Scope | Tasks | Stories | Parallelizable |
|-------|-------|---------|----------------|
| MVP sugerido | T001–T027 | US1 completa | T003, T004, T006, T010, T015, T016, T017, T018, T020, T021 |
| Fases 1–2 | T028–T038 | US2 completa | T028, T029, T030, T031 |
| Fases 3–4 | T039–T052 | US3 + US4 | T039, T040, T041, T047, T048 |
| Polish | T053–T059 | — | T053, T054, T055, T057 |
| **Total** | **59 tasks** | **4 user stories** | **~22 paralelizáveis** |

**MVP recomendado**: Phases 1+2+3 (T001–T027) = infraestrutura + Skill 1 completa.
Permite validar o loop completo WhatsApp/Gmail → Google Tasks → Telegram antes de avançar para skills mais complexas.
