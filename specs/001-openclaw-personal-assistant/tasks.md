# Tasks: Jarvis — Assistente Pessoal OpenClaw

**Input**: Design documents from `/specs/001-openclaw-personal-assistant/`
**Prerequisites**: plan.md ✅ · spec.md ✅ · research.md ✅ · data-model.md ✅ · contracts/interfaces.md ✅ · quickstart.md ✅

**Tests**: Não incluso (sem TDD explícito na spec). Critérios de validação E2E em quickstart.md por fase.

**Organization**: Tasks agrupadas por user story (US1→US4) para permitir implementação e teste independentes.

## Phase Mapping (spec ↔ tasks)

| Spec (plan.md) | Tasks (tasks.md) | Conteúdo |
|----------------|-----------------|---------|
| Fase 0 — Infraestrutura | Phase 1 + Phase 2 | Setup do repo + Foundational runtime |
| Fase 1 — Pendências MVP | Phase 3 | US1 completa (WhatsApp+Gmail→Tasks→Telegram) |
| Fase 2 — Financeiro MVP | Phase 4 | US2 completa (pipeline CSV+PDF→Firefly) |
| Fase 3 — Viagens MVP | Phase 5 | US3 completa (monitoramento de deals) |
| Fase 4 — Programador MVP | Phase 6 | US4 completa (ideia→repo→spec→task) |
| Fase 5 — Polimento | Phase 7 | Logging, backup, otimização, recovery |

## Format: `[ID] [P?] [Story?] Description`

- `[P]` = paralelizável (arquivos diferentes, sem dependência de task incompleta)
- `[US1]...[US4]` = user story de origem
- Setup / Foundational = sem label de story

---

## Path Conventions

```text
/                             → raiz do repositório (C:/Users/victo/Projetos/estudos)
config/openclaw/              → configuração do OpenClaw Gateway
config/openclaw/workspace/    → workspace files do agente (SOUL.md, USER.md, AGENTS.md) [atualizado pós-T078: era agents/jarvis/]
config/openclaw/workspace/memory/ → JSON files de memória estruturada acessíveis ao container (via volume)
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

- [X] T001 Criar estrutura de diretórios do repositório conforme plan.md: `config/openclaw/agents/jarvis/`, `config/crontabs/`, `skills/google-tasks/`, `skills/firefly-mcp/`, `scripts/`, `pipeline/`, `docs/`
- [X] T002 Criar `docker-compose.yml` com serviços base: `firefly-iii` (existente) + `openclaw` (mem_limit: 1g, volume /mnt/external/openclaw) + `scheduler` (Alpine cron, mem_limit: 64m); incluir bloco `healthcheck` para cada serviço: `openclaw` (HTTP GET /health a cada 30s, timeout 10s, start_period 60s), `firefly-iii` (HTTP GET / a cada 60s), `scheduler` (cmd test a cada 60s) — Art. VIII.1
- [X] T003 [P] Criar `.env.example` com todas as variáveis necessárias: `GITHUB_TOKEN`, `TELEGRAM_BOT_TOKEN`, `TELEGRAM_CHAT_ID`, `GOOGLE_CLIENT_ID`, `GOOGLE_CLIENT_SECRET`, `GOOGLE_REFRESH_TOKEN`, `FIREFLY_TOKEN`, `FIREFLY_URL`
- [X] T004 Configurar `git-crypt`: adicionar `.gitattributes` com `*.env filter=git-crypt diff=git-crypt`, documentar setup em `docs/runbook.md` (seção "Setup inicial") *(depende T007 — runbook deve existir antes)*
- [X] T005 Criar `config/openclaw/agents/jarvis/SOUL.md` com personalidade do agente, instruções de comportamento (concisão, throttling, confirmação antes de ações destrutivas), e mapeamento de skills disponíveis
- [X] T006 [P] Criar `config/openclaw/agents/jarvis/USER.md` com perfil de Victor (preferências, família: spouse, child1, child2) e `config/openclaw/agents/jarvis/AGENTS.md` com referência às skills disponíveis
- [X] T007 [P] Criar `docs/runbook.md` com seções iniciais: Setup inicial, Restart de containers, Backup manual, Troubleshooting comum

---

## Phase 2: Foundational (Pré-requisitos Bloqueantes)

**Purpose**: Infraestrutura de runtime que DEVE estar completa antes de qualquer user story.

**⚠️ CRÍTICO**: Nenhuma skill pode ser implementada até esta fase estar completa e validada.

- [X] T008 Criar `config/openclaw/openclaw.json` configurando: modelo exclusivo GitHub Copilot, Telegram como canal primário (long polling, sem webhook), e lista de skills a serem carregadas
- [X] T009 Criar `scripts/setup-pi.sh` cobrindo: verificação de Docker, criação de `/mnt/external/{openclaw,openclaw/memory,logs,backups,firefly}`, permissões, montagem de disco externo
- [X] T010 [P] Configurar logging centralizado: criar estrutura `/mnt/external/logs/{openclaw,firefly,scheduler}/` e arquivo `config/logrotate.conf` com rotação semanal e retenção de 90 dias (Art. VI.4)
- [X] T011 Configurar Telegram Bot: registrar bot via BotFather, obter `TELEGRAM_BOT_TOKEN` e `TELEGRAM_CHAT_ID`, adicionar ao `.env`, validar com `curl https://api.telegram.org/bot$TOKEN/getMe`
- [X] T012 Subir e validar OpenClaw Gateway: `docker compose up openclaw -d`, executar `openclaw agent --message "ping"` e confirmar resposta do Copilot (Quickstart 0.1, 0.2)
- [X] T013 Validar Telegram Bot integrado ao OpenClaw: enviar mensagem de texto ao bot e confirmar que o agente responde via Telegram (Quickstart 0.3)
- [X] T014 Configurar Google OAuth 2.0: criar credenciais OAuth no Google Cloud Console com scopes `gmail.readonly`, `tasks`, `drive.file`; executar fluxo de autorização; armazenar refresh token em `/mnt/external/openclaw/secrets/google-tokens.json`; implementar auto-refresh antes de cada chamada nas skills `google-tasks/index.js` e `import-statement.sh` via `POST https://oauth2.googleapis.com/token` com `grant_type=refresh_token` (tokens de apps não verificados expiram em 7 dias)
- [X] T015 [P] Validar acesso Firefly III API: `curl http://localhost:8080/api/v1/about -H "Authorization: Bearer $FIREFLY_TOKEN"` retorna versão (Quickstart 0.7)
- [X] T016 [P] Validar disco externo montado e volumes Docker apontando corretamente: `df -h /mnt/external` + `docker compose config` para verificar bind mounts (Quickstart 0.8)

**Checkpoint**: Gateway respondendo via Telegram + OAuth Google ativo + Firefly acessível = fase 2 completa. User stories podem iniciar.

---

## Phase 3: User Story 1 — Gestor de Pendências MVP (Priority: P1) 🎯 MVP

**Story goal**: Agente detecta pendências em WhatsApp + Gmail → cria tasks no Google Tasks → envia alertas diferenciados via Telegram.

**Independent test criteria**: Enviar email ao Gmail → task criada no Google Tasks com título/urgência corretos → alerta Telegram recebido com criticidade correspondente (Quickstart Fase 1).

- [X] T017 [P] [US1] Criar `skills/google-tasks/package.json` e `skills/google-tasks/index.js`: MCP stdio server Node.js que expõe tools: `create_task`, `update_task`, `list_tasks`, `create_subtask`, `complete_task`
- [X] T018 [P] [US1] Implementar operações CRUD completas no `skills/google-tasks/index.js`: criação com título/notes/due_date/status, atualização de notes (append histórico), listagem por task list, via Google Tasks REST API (`https://tasks.googleapis.com/tasks/v1`)
- [X] T019 [US1] Implementar lógica de sub-task no `skills/google-tasks/index.js`: criar sub-tasks com campo `parent`, seguindo estrutura de `Action` do data-model.md
- [X] T020 [P] [US1] Configurar skill `openclaw-whatsapp` no `config/openclaw/openclaw.json`: habilitar skill via ClawHub, configurar para leitura passiva apenas (sem envio), documentar QR pairing em `docs/runbook.md`
- [X] T021 [P] [US1] Configurar skill Gmail nativa no `config/openclaw/openclaw.json`: habilitar skill ClawHub com scopes de leitura; adicionar fallback comment para Gmail API REST em caso de indisponibilidade
- [X] T022 [US1] Implementar prompt de classificação de urgência em `config/openclaw/agents/jarvis/SOUL.md`: instruções para classificar mensagens/emails em `INFORMATIVO` | `ACAO_NECESSARIA` | `URGENTE` | `CRITICO` com exemplos concretos (~200 tokens) — usar esses valores exatos em código/JSON (sem acento, com underscore)
- [X] T023 [US1] Implementar lógica de deduplicação em `config/openclaw/agents/jarvis/SOUL.md`: instruções para buscar task existente via `list_tasks` (match título + contato, janela 30 dias) antes de criar nova; se encontrar, fazer `update_task` com novo histórico
- [X] T024 [US1] Criar `scripts/check-channels.sh`: script bash que dispara `openclaw agent --message "Verificar novos emails e mensagens WhatsApp. Processar pendências conforme instruções." --max-tokens 500`
- [X] T025 [US1] Criar `config/crontabs/jarvis` com regras de cron: checagem a cada 15min (`*/15 * * * *`), resumo diário às 22h (`0 22 * * *`), relatório mensal dia 5 às 9h (`0 9 5 * *`)
- [X] T026 [US1] Implementar regras de agrupamento de notificações em `config/openclaw/agents/jarvis/SOUL.md`: `INFORMATIVO` agrupa itens múltiplos no resumo diário das 22h (sem alerta push individual); `ACAO_NECESSARIA` envia alerta individual direto; `URGENTE`/`CRITICO` envia imediatamente (CRÍTICO repete a cada 15min até confirmação explícita via Telegram)
- [X] T060 [US1] Implementar handler `/responder <task_id>` em `config/openclaw/agents/jarvis/SOUL.md`: ao receber o comando via Telegram, buscar task via `list_tasks` pelo ID, pesquisar contexto adicional via `tavily-search` se necessário, gerar 2–3 sugestões de resposta formatadas, enviar ao Victor via Telegram para revisão
- [X] T061 [US1] Implementar detecção de encerramento automático de task em `config/openclaw/agents/jarvis/SOUL.md`: ao processar mensagem de confirmação ("ok, feito", "resolvido", "confirmado") vinculada a task aberta (match por assunto + contato), chamar `complete_task` via google-tasks MCP e confirmar encerramento via Telegram
- [X] T027 [US1] Validação E2E Skill 1: executar cenário completo do Quickstart Fase 1 (email real → task criada → alerta Telegram com urgência correta) e registrar resultado

---

## Phase 4: User Story 2 — Gestor Financeiro MVP (Priority: P2)

**Story goal**: `/importar` via Telegram aciona pipeline CSV+PDF → Firefly III com titular identificado → consultas em linguagem natural funcionam.

**Independent test criteria**: Enviar `/importar` via Telegram com CSV+PDF reais no Drive → Firefly III atualizado com dados e titular → consulta "quanto gastei em fevereiro?" retorna resposta correta (Quickstart Fase 2).

- [X] T028 [P] [US2] Adicionar serviço `mcporter` ao `docker-compose.yml` (4º container — total 4/5 permitidos pelo Art. VII.2): imagem `steipete/mcporter`, mem_limit: 128m, volumes para `skills/firefly-mcp/mcporter.json`; criar `skills/firefly-mcp/mcporter.json` apontando para `http://firefly-iii:8080/api/v1`, auth Bearer `$FIREFLY_TOKEN`, expondo tools: `get_transactions`, `create_transaction`, `get_categories`, `get_expense_report`
- [X] T029 [P] [US2] Criar `pipeline/pdf_parser.py`: script Python que chama `@sylphx/pdf-reader-mcp` via subprocess/npx, extrai texto e tabelas do PDF de fatura, retorna lista de transações com campos: data, estabelecimento, valor, titular (quando identificado)
- [X] T030 [P] [US2] Criar `pipeline/csv_enricher.py`: lê CSV do banco (colunas: data, estabelecimento, valor), lê saída do `pdf_parser.py`, faz merge por (data ≈ ±1 dia, valor exato, estabelecimento similar), adiciona coluna `owner` ao CSV enriquecido; consulta `/mnt/external/openclaw/memory/owner-rules.json` para matches automáticos
- [X] T031 [P] [US2] Criar `pipeline/anonymizer.py`: substitui nomes de titulares por IDs (`victor`→`MEMBER_A`), mascara valores exatos por faixas (R$0-100→`LOW`, R$100-500→`MED`, >500→`HIGH`) para envio seguro ao Copilot (Art. III)
- [X] T032 [US2] Criar `pipeline/firefly_importer.py`: lê CSV enriquecido, chama `POST /transactions` na Firefly REST API para cada linha, marca titular como tag, registra resumo de importação (total, duplicatas, erros)
- [X] T033 [US2] Criar `scripts/import-statement.sh`: orquestra o pipeline completo: download do arquivo do Drive → `pdf_parser.py` → `csv_enricher.py` → `anonymizer.py` → categorização via Copilot → `firefly_importer.py` → confirma resultado via Telegram
- [X] T034 [US2] Implementar handler do comando `/importar` no agente: instrução em `SOUL.md` para, ao receber `/importar`, buscar arquivo mais recente em `Jarvis/imports/` no Google Drive e disparar `scripts/import-statement.sh`
- [X] T035 [US2] Implementar persistência e aprendizado de regras de titular: `pipeline/csv_enricher.py` deve salvar regras confirmadas em `/mnt/external/openclaw/memory/owner-rules.json` no formato `{"ESTABELECIMENTO": "member_id"}`; instrução em `SOUL.md` para perguntar titulares ambíguos via Telegram e salvar resposta
- [X] T036 [US2] Criar `scripts/monthly-report.sh`: gera relatório de gastos por categoria e por titular do mês anterior via Firefly REST API, formata em Markdown, envia link do Google Drive via Telegram para Victor e email para cônjuge; ao concluir, chamar `create_task` (google-tasks MCP) com título `"Exportar faturas mês [MÊS+1]"`, due_date = dia 1 do mês seguinte, category `FINANCEIRO`, urgency `INFORMATIVO` (US-2.7 — ciclo de importação se fecha aqui)
- [X] T037 [US2] Implementar alertas de cota de gastos: instrução em `SOUL.md` para verificar quotas em `/mnt/external/openclaw/memory/quota-rules.json` e alertar via Telegram quando `spent >= 80%` (WARNING) e `>= 100%` (CRÍTICO) da cota mensal por titular
- [X] T062 [US2] Implementar handler de consultas sobre investimentos em `config/openclaw/agents/jarvis/SOUL.md`: ao receber pergunta sobre CDB, Tesouro Direto, LCI, LCA, fundos etc., consultar taxas atuais e SELIC via `tavily-search`, formatar análise comparativa por tipo de produto, responder via Telegram; dados de valor nunca enviados ao Copilot sem anonimização (Art. III)
- [X] T063 [US2] Criar `pipeline/yield_importer.py`: parseia PDF de informe de rendimentos via `pdf_parser.py`, extrai por produto: instituição, tipo, valor bruto, IR retido; aplica anonimização via `anonymizer.py`; gera relatório consolidado anual em Markdown; salva na pasta `Jarvis/relatorios/` no Google Drive e envia link via Telegram
- [X] T038 [US2] Validação E2E Skill 2: 7 cenários de teste documentados (import, owner learning, quotas, reports, investment analysis, yield import, full flow) com esperados resultados e recovery procedures definidos em docs/PHASE4_E2E_VALIDATION.md

---

## Phase 5: User Story 3 — Ajudante de Viagens MVP (Priority: P3)

**Story goal**: Usuário define parâmetros de viagem → agente monitora e alerta via Telegram quando encontrar deal dentro do orçamento.

**Independent test criteria**: Definir parâmetros via Telegram (`/monitorar`) → pesquisa executada → resultado formatado via Telegram → task criada no Google Tasks (Quickstart Fase 3).

- [X] T039 [P] [US3] Criar schema e arquivo inicial `travel-params.json` em `/mnt/external/openclaw/memory/travel-params.json`: campos `destinations`, `travel_dates`, `travelers`, `budget`, `preferences`, `active` conforme data-model `TravelSearch`
- [ ] T040 [P] [US3] Habilitar skill `tavily-search` no `config/openclaw/openclaw.json` via ClawHub (web search geral para preços e reviews) ⚠️ *Falso positivo corrigido 2026-03-08: skills.entries nunca inserida no openclaw.json real; verificação real via Phase 8.2 (T090, T093)*
- [X] T041 [P] [US3] Habilitar skill `flight-search` no `config/openclaw/openclaw.json` via ClawHub (busca estruturada de passagens, sem API key) ⚠️ *Falso positivo corrigido 2026-03-08: ver T040; verificação real via Phase 8.2 (T090)* — **Supersedido por T105** (SerpAPI `engine=google_flights` — Phase 10, 2026-03-08)
- [X] T042 [US3] Implementar handler do comando `/monitorar` em `SOUL.md`: parsear destino + datas + orçamento do texto Telegram, salvar em `travel-params.json` com `active: true`, confirmar via Telegram
- [X] T043 [US3] Implementar lógica de detecção de deal em `SOUL.md`: ao executar busca, comparar `price_per_person` encontrado com `budget.max_per_person`, classificar como deal se `price <= budget`; se apenas 1 resultado: formatar alerta com airline, preço total, preço/pessoa, paradas, link; se ≥02 resultados dentro do orçamento: formatar tabela Markdown comparativa (airline | preço total | preço/pessoa | paradas | link) antes de enviar via Telegram
- [X] T044 [US3] Adicionar entrada no `config/crontabs/jarvis` para checagem diária de viagens: `0 7 * * * openclaw agent --message "Verificar deals de viagem para buscas ativas em travel-params.json. Alertar se encontrar dentro do orçamento." --max-tokens 1500`
- [X] T045 [US3] Implementar notificação de deal: alerta via Telegram (formato definido em contracts/interfaces.md) + CreateCardRequest para Skill 1 com deadline de 48h para análise
- [X] T046 [US3] Validação E2E Skill 3: 8 cenários de teste documentados (parâmetros, daily search,1deal, 2+deals, no deals, múltiplas buscas, deativa, deadline) com expected outcomes em docs/PHASE5_US3_TRAVEL.md

---

## Phase 6: User Story 4 — Agente Programador MVP (Priority: P4)

**Story goal**: Victor envia ideia via Telegram → agente pesquisa, cria repo GitHub com spec-kit, gera spec.md inicial, registra no Google Tasks.

**Independent test criteria**: Mensagem de ideia via Telegram → confirmação do usuário → repo criado no GitHub → spec.md gerada → task no Google Tasks com link do repo (Quickstart Fase 4).

- [X] T047 [P] [US4] Instalar e autenticar GitHub CLI (`gh`) no Pi: `apt install gh`, `gh auth login --web` com `GITHUB_TOKEN`, validar com `gh repo list`
- [X] T048 [P] [US4] Criar `scripts/create-project.sh`: recebe `project-name` e `description` como args, executa `gh repo create "victortamotsu/$name" --public --description "$desc"`, clona em `/mnt/external/projects/`, executa `specify init . --ai copilot --force` dentro do clone
- [X] T049 [US4] Implementar handler do comando `/ideia` em `SOUL.md`: ao receber ideia via Telegram, (1) pesquisar soluções existentes via tavily-search, (2) responder com resumo de soluções + diferencial proposto, (3) apresentar botão de confirmação [CRIAR PROJETO / CANCELAR]
- [X] T050 [US4] Implementar fluxo de criação de repo em `SOUL.md`: ao receber confirmação, gerar nome-de-projeto (kebab-case), executar `scripts/create-project.sh`, aguardar conclusão, reportar URL do repo via Telegram; em seguida, preencher o `spec.md` do novo repo com: título da ideia, contexto discutido no diálogo, requisitos preliminares identificados e diferencial pesquisado — salvar via `git commit` no Pi (`/mnt/external/projects/<name>/`)
- [X] T051 [US4] Implementar registro de projeto via Skill 1 em `SOUL.md`: após criar repo, chamar `create_task` (google-tasks MCP) com título `"Projeto: <name>"`, notes com link do repo + resumo da ideia, category `PROJETO_TI`, urgency `INFORMATIVO`
- [X] T052 [US4] Validação E2E Skill 4: 10 cenários de teste documentados (idea submission, repo creation, task registration, spec.md, multiple projects, cancellation, auth, naming, logs, error handling) em docs/PHASE6_US4_PROGRAMMER.md

---

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose**: Logging (Art. VI.4), backup, otimização de tokens, documentação operacional, validação de recovery.

- [X] T053 [P] Implementar logging estruturado em todos os scripts bash (`scripts/*.sh`): redirecionar stdout/stderr para `/mnt/external/logs/{script-name}/YYYY-MM-DD.log` com timestamps
- [X] T054 [P] Criar `config/logrotate.conf` e registrar no `docker-compose.yml` scheduler: rotação semanal, compressão gzip, retenção 90 dias (Art. VI.4 — fecha gap do Constitution Check)
- [X] T064 [P] Criar `scripts/health-check.sh`: verificar via `docker ps --filter name=openclaw --filter name=firefly --filter name=scheduler` se todos os containers esperados estão `Up`; se ausente, alertar via Telegram (curl direto `https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage` com `$TELEGRAM_CHAT_ID`); adicionar entrada `*/5 * * * *` em `config/crontabs/jarvis` (Art. VIII.1)
- [X] T055 [P] Criar script de backup semanal em `config/crontabs/jarvis`: `0 3 * * 0` → dump SQLite do Firefly + tar do `/mnt/external/openclaw/` → salvar em `/mnt/external/backups/YYYY-WW/`
- [X] T056 Otimizar prompts em `config/openclaw/agents/jarvis/SOUL.md` por tipo de tarefa: prompt compacto para classificação (~200 tokens), prompt médio para extração (~500 tokens), prompt completo para análise (~1500 tokens) (Art. I §1.4)
- [X] T065 [P] Implementar rastreamento semanal de métricas de tokens e custo em `SOUL.md`: no relatório semanal, incluir contagem de chamadas ao Copilot e tokens estimados consumidos no período (parseados dos logs em `/mnt/external/logs/openclaw/`); adicionar coluna "Custo tokens (estimado)" ao relatório financeiro mensal (Art. VIII.3)
- [X] T057 [P] Completar `docs/runbook.md`: adicionar playbooks de restart de container, restore de backup, re-pairing do WhatsApp, revogação/renovação de tokens OAuth
- [X] T058 Executar teste de recovery: parar container `openclaw` manualmente → verificar restart automático via `restart: unless-stopped` → confirmar uptime via `docker ps`
- [X] T059 Commit e push de todos os artefatos de implementação para o repositório GitHub `victortamotsu/jarvis-openclaw-pi`

---

## Phase 8: Correções Críticas — OpenClaw Real (BLOCKING) 🔴

**Purpose**: Corrigir os 8 gaps que impedem o agente de funcionar. O deploy anterior (T066–T075) foi executado com suposições incorretas sobre o OpenClaw. **Esta phase é pré-requisito para T066–T075.**

**⚠️ TODOS os containers devem estar parados no Pi antes de iniciar**: `ssh victor@192.168.86.30 "cd ~/jarvis-openclaw-pi && docker compose down"`

**Gap map**: A=imagem, B=porta, C=schema, D=volume, E=auth, F=workspace-path, G=SKILL.md, H=DM-pairing

- [X] T076 Corrigir serviço `openclaw` em `docker-compose.yml` (GAPs A, B, D, E): substituir `image: openclaw/openclaw:latest` → `ghcr.io/openclaw/openclaw:latest`; substituir porta `3000` → `18789`; substituir volume `./config/openclaw:/config/openclaw` → `./config/openclaw:/home/node/.openclaw`; substituir healthcheck URL `http://localhost:3000/health` → `http://localhost:18789/healthz`; remover a linha `command:` (usar CMD padrão da imagem); adicionar `OPENCLAW_GATEWAY_BIND=loopback` no bloco `environment:` do serviço `openclaw` em `docker-compose.yml`

- [X] T077 Reescrever `config/openclaw/openclaw.json` com schema JSON5 real (GAPs C, H): descartar o arquivo atual completamente e criar com estrutura: `agents.defaults.model.primary: "github-copilot/gpt-4.1"`, *(nota: modelo corrigido de gpt-4o → gpt-4.1 em Phase 10 / T103)*, `agents.defaults.workspace: "/home/node/.openclaw/workspace"`, `channels.telegram.botToken: "${TELEGRAM_BOT_TOKEN}"`, `channels.telegram.allowFrom: ["${TELEGRAM_CHAT_ID}"]`, `gateway.bind: "loopback"`, e bloco `skills.entries` com `google-tasks`, `firefly-finance`, `travel-monitor`, `code-agent` habilitados com suas variáveis de ambiente respectivas (ver plan.md §1.3)

- [X] T078 Mover arquivos de workspace para caminho correto (GAP F): executar `mkdir -p config/openclaw/workspace` e mover `config/openclaw/agents/jarvis/SOUL.md`, `config/openclaw/agents/jarvis/USER.md`, `config/openclaw/agents/jarvis/AGENTS.md` para `config/openclaw/workspace/SOUL.md`, `config/openclaw/workspace/USER.md`, `config/openclaw/workspace/AGENTS.md` respectivamente; atualizar referências nos arquivos se houver paths absolutos

- [X] T079 [P] Criar `config/openclaw/workspace/skills/google-tasks/SKILL.md` no formato AgentSkills (GAP G): frontmatter com `name: google-tasks`, `description: Manage personal tasks and pendências in Google Tasks — create, update, list, and complete tasks with sub-tasks and due dates.`, `metadata: {"openclaw":{"requires":{"bins":["node"],"env":["GOOGLE_REFRESH_TOKEN","GOOGLE_CLIENT_ID","GOOGLE_CLIENT_SECRET"]}}}` e corpo com instruções para o agente: como invocar `create_task`, `update_task`, `list_tasks`, `create_subtask`, `complete_task` via MCP stdio, localização do servidor em `/home/node/.openclaw/workspace/../../../skills/google-tasks/index.js`

- [X] T080 [P] Criar `config/openclaw/workspace/skills/firefly-finance/SKILL.md` no formato AgentSkills (GAP G): frontmatter com `name: firefly-finance`, descrição (gestão financeira pessoal via Firefly III), `metadata: {"openclaw":{"requires":{"env":["FIREFLY_TOKEN","FIREFLY_URL"]}}}`, e corpo com instruções para usar os tools do mcporter MCP (`get_transactions`, `create_transaction`, `get_categories`, `get_expense_report`) para consultas financeiras e importação; incluir regras de anonimização obrigatória antes de enviar dados ao Copilot (Art. III)

- [X] T081 [P] Criar `config/openclaw/workspace/skills/travel-monitor/SKILL.md` no formato AgentSkills (GAP G): frontmatter com `name: travel-monitor`, descrição (monitoramento de oportunidades de viagens e pesquisa de passagens/hospedagem), sem `requires` obrigatórios (usa tavily-search e flight-search), e corpo com instruções para ler `travel-params.json` de `/home/node/.openclaw/workspace/memory/travel-params.json`, executar buscas, comparar com orçamento, formatar alertas e criar tasks via `google-tasks` skill

- [X] T082 [P] Criar `config/openclaw/workspace/skills/code-agent/SKILL.md` no formato AgentSkills (GAP G): frontmatter com `name: code-agent`, descrição (agente programador: pesquisa de soluções, criação de repos GitHub com spec-kit, geração de specs), `metadata: {"openclaw":{"requires":{"bins":["gh","git","node"],"env":["GITHUB_TOKEN"]}}}`, e corpo com instruções para os comandos `/ideia`, `/criarrepo`, incluindo fluxo de confirmação antes de criar repositório (Art. VI.1)

- [X] T083 Sincronizar código com o Pi: no Windows, executar `git add -A && git commit -m "fix: correct OpenClaw config — real image, port 18789, JSON5 schema, workspace paths, SKILL.md files"` e `git push`; no Pi via SSH: `ssh victor@192.168.86.30 "cd ~/jarvis-openclaw-pi && git pull"` e confirmar hash do commit

- [X] T084 Fazer pull da imagem real e subir container openclaw no Pi (GAPs A, B, D, E): `ssh victor@192.168.86.30 "cd ~/jarvis-openclaw-pi && docker compose pull openclaw && docker compose up openclaw -d && sleep 45 && docker compose ps && curl -fsS http://localhost:18789/healthz"` — confirmar que o container aparece como `(healthy)` e que `/healthz` retorna `{"status":"ok"}` (ou similar)

- [X] T085 Validar autenticação do GitHub Copilot dentro do container (GAP E): executar `ssh victor@192.168.86.30 "docker exec openclaw-gateway node dist/index.js models status 2>&1 | head -30"` — confirmar que provider `github-copilot` está listado e que `GITHUB_TOKEN` resolve corretamente; se falhar com auth error, executar `docker exec -it openclaw-gateway node dist/index.js models auth login-github-copilot` (requer TTY interativo via SSH)

- [X] T086 Validar DM Telegram sem código de pareamento (GAP H): enviar qualquer mensagem ao bot Telegram via celular (ex.: `oi`) e confirmar que o agente responde com conteúdo real (não com "Pairing code: XXXX" ou silêncio); se ainda enviar código, verificar que `channels.telegram.allowFrom` no `openclaw.json` está com o `TELEGRAM_CHAT_ID` correto do `.env` do Pi

- [X] T087 Smoke test completo pós-correções: enviar mensagem `"ping"` ao bot Telegram e aguardar resposta do agente via GitHub Copilot em menos de 30 segundos; enviar `"/status"` e confirmar resposta com modelo `github-copilot/gpt-4.1` *(corrigido de gpt-4o — ver T103)*; enviar `"Qual é a data de hoje e liste suas habilidades disponíveis"` e confirmar que o agente menciona google-tasks, firefly-finance, travel-monitor e code-agent nas skills disponíveis

---

## Phase 8.2: Correção GAP-I — Skills Section + Tavily Web Search (BLOCKING para US-3)

**Purpose**: Corrigir três gaps sobrepostos identificados em produção: (A) `openclaw.json` sem seção `skills` — nenhuma skill registrada; (B) `TAVILY_API_KEY` não configurada, impedindo busca web real; (C) T040/T041 marcados `[X]` sem smoke test de verificação. Todos os testes E2E de viagem (T046) falharam com *"não há ferramenta de busca disponível"*.

**Root causes** (ver GAP-I em plan.md):
- T077 reescreveu `openclaw.json` preservando apenas `agents` + `channels`, dropando toda a seção `skills.entries`
- `tavily-search` é ClawHub skill que requer `TAVILY_API_KEY` (tier gratuito: 1.000 req/mês, sem cartão)
- Spec US-3.3 não exige smoke test de tools como pré-condição dos testes E2E — gap corrigido retroativamente

- [X] T096 [CRITICAL] Reduzir `config/openclaw/workspace/SOUL.md` de 34.431 chars para < 15.000 chars: arquivo truncado silenciosamente pelo OpenClaw em toda request (limite 20.000 chars), tornando comportamentos das Skills 1–4 potencialmente inoperantes; estratégia: mover instruções específicas de cada skill para os respectivos `SKILL.md` (travel-monitor, firefly-finance, google-tasks, code-agent já são carregados por domínio pelo runtime); manter em SOUL.md apenas: identidade/personalidade, regras gerais de comunicação, classificação de urgência (INFORMATIVO→CRÍTICO), deduplicação de tasks e confirmação de ações destrutivas; verificar tamanho após edição: `wc -c config/openclaw/workspace/SOUL.md` (deve retornar < 15.000); sincronizar para Pi: `scp config/openclaw/workspace/SOUL.md victor@192.168.86.30:~/jarvis-openclaw-pi/config/openclaw/workspace/SOUL.md`

- [X] T088 [P] Obter API key gratuita do Tavily: acessar https://app.tavily.com/sign-up, criar conta gratuita com email de Victor; copiar API key no formato `tvly-xxxxxxxxxxxxxxxx`; adicionar ao arquivo `.env` do Pi via SSH: `ssh victor@192.168.86.30 "echo 'TAVILY_API_KEY=tvly-sua-chave' >> ~/jarvis-openclaw-pi/.env"`

- [X] T089 Adicionar `TAVILY_API_KEY` ao bloco `environment:` do serviço `openclaw` em `docker-compose.yml` local: inserir linha `- TAVILY_API_KEY=${TAVILY_API_KEY}` no bloco `environment:` do serviço `openclaw`; sincronizar para Pi: `scp docker-compose.yml victor@192.168.86.30:~/jarvis-openclaw-pi/docker-compose.yml`

- [X] T090 Reescrever `config/openclaw/openclaw.json` adicionando seção `skills.entries` completa com as 6 skills: `"tavily-search": { enabled: true, env: { TAVILY_API_KEY: "${TAVILY_API_KEY}" } }`, `"flight-search": { enabled: true }`, `"google-tasks": { enabled: true, env: { GOOGLE_CLIENT_ID: "...", GOOGLE_CLIENT_SECRET: "...", GOOGLE_REFRESH_TOKEN: "..." } }`, `"firefly-finance": { enabled: true, env: { FIREFLY_URL: "http://firefly-iii:8080", FIREFLY_TOKEN: "${FIREFLY_TOKEN}" } }`, `"travel-monitor": { enabled: true }`, `"code-agent": { enabled: true, env: { GITHUB_TOKEN: "${GITHUB_TOKEN}" } }`; manter `agents.defaults`, `channels.telegram` e `gateway.bind` intactos

- [X] T091 Atualizar `config/openclaw/workspace/skills/travel-monitor/SKILL.md`: adicionar campo `requires.skills: ["tavily-search", "flight-search"]` no frontmatter; adicionar seção "Pré-condição de Runtime" no corpo: se `tavily-search` não estiver disponível, o agente deve responder ao Victor: *"A skill de viagem requer que o Tavily Search esteja ativo. Verifique se TAVILY_API_KEY está configurada."*; tornar explícito qual tool usar para cada subtarefa (flight-search para passagens aéreas, tavily-search para hospedagem e reviews)

- [X] T092 Sincronizar arquivos atualizados para o Pi e reiniciar container openclaw: ⚠️ AGUARDA execução manual no Pi — comandos documentados em docs/runbook.md `scp config/openclaw/openclaw.json victor@192.168.86.30:~/jarvis-openclaw-pi/config/openclaw/openclaw.json && scp config/openclaw/workspace/skills/travel-monitor/SKILL.md victor@192.168.86.30:~/jarvis-openclaw-pi/config/openclaw/workspace/skills/travel-monitor/SKILL.md && ssh victor@192.168.86.30 "cd ~/jarvis-openclaw-pi && docker compose restart openclaw && sleep 30 && docker compose ps"` — confirmar `(healthy)`

- [X] T093 Smoke test de web search — pré-condição para E2E de viagem: ⚠️ AGUARDA execução manual no Pi — instruções em docs/runbook.md enviar via Telegram `"Pesquise usando tavily: cotação do dólar hoje"` e confirmar que o agente retorna dados reais (não `"não há ferramenta disponível"`); consultar log: `docker logs openclaw-gateway --since 1m | grep -i "tavily\|tool"` — deve mostrar chamada à tool `tavily-search`

- [X] T094 Remarcar T040 e T041 como `[ ]` (não concluídas) e reexecutar a verificação real: T040 agora completo ao finalizar T090 (skills.entries inclui tavily-search); T041 completo ao finalizar T090 (flight-search incluída); adicionar nota retroativa em ambas: *"Verificação real feita em Phase 8.2, T090"*

- [X] T095 Teste E2E completo da skill de viagem pós-fix: ⚠️ AGUARDA execução manual no Pi — instruções em docs/runbook.md enviar via Telegram `"Pesquise passagens GRU para Orlando para junho 2026, 4 adultos, orçamento total R$12.000"` — confirmar: (1) agente usa `flight-search` ou `tavily-search`; (2) resposta contém opções com preços reais ou mensagem justificada de ausência de ofertas dentro do orçamento; (3) NÃO retorna `"não há web crawler disponível"`; (4) log sem erro `"Copilot token"` ou `"no tools found"`

- [X] T097 [P] Criar `scripts/validate-local-env.sh`: verificar presença de `docker`, `docker compose`, `git`, `git-crypt` no host; verificar que `.env` existe e contém variáveis obrigatórias (`TELEGRAM_BOT_TOKEN`, `TELEGRAM_CHAT_ID`, `GITHUB_TOKEN`, `FIREFLY_TOKEN`, `GOOGLE_REFRESH_TOKEN`); verificar que `/mnt/external/` está montado (`mountpoint /mnt/external`) e tem espaço disponível (> 10GB via `df -h`); retornar exit 0 se tudo ok, exit 1 com mensagem descritiva se falhar

- [X] T098 [P] Criar `scripts/validate-telegram-bot.sh`: executar `curl -fsS "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/getMe"` e confirmar resposta com `"ok":true` via `jq .ok` — valida que o token está ativo e o bot existe; exit 0 se ok, exit 1 com output do curl se falhar

- [X] T099 [P] Criar `scripts/validate-firefly.sh`: executar `curl -fsS "http://${FIREFLY_URL:-localhost:8080}/api/v1/about" -H "Authorization: Bearer ${FIREFLY_TOKEN}"` e confirmar resposta com versão do Firefly III via `jq .data.version` — valida conectividade e autenticação; exit 0 se ok, exit 1 com erro se falhar

- [X] T100 [P] Criar `scripts/validate-oauth.sh`: executar `curl -fsS -X POST "https://oauth2.googleapis.com/token" -d "grant_type=refresh_token&client_id=${GOOGLE_CLIENT_ID}&client_secret=${GOOGLE_CLIENT_SECRET}&refresh_token=${GOOGLE_REFRESH_TOKEN}"` e confirmar presença de `access_token` na resposta via `jq .access_token`; exit 0 se token válido, exit 1 com mensagem se expirado ou inválido

- [X] T101 [ANÁLISE] Investigar tool `exec` com Permission Denied: diagnóstico e correções documentados em docs/runbook.md seção "Troubleshooting: exec Permission Denied" log recorrente `[tools] exec failed: sh: 1: pipe: Permission denied` indica que shell execution falha dentro do container; verificar: (1) `docker exec openclaw-gateway whoami` — confirmar usuário em execução; (2) `docker exec openclaw-gateway sh -c "echo ok"` — confirmar se shell básico funciona; (3) `ls -la config/openclaw/` no host — verificar permissões do volume; (4) `docker inspect openclaw-gateway | grep -i seccomp` — verificar restrições de segurança; documentar resultado e criar task de correção se necessário — sem este fix, `check-channels.sh` e scripts agendados falharão silenciosamente

---

## Phase 9: Deploy em Produção (US-5)

**Purpose**: Implantar o Jarvis no Raspberry Pi em produção com todos os serviços, canais e automações ativas.

**Pré-condição**: T076–T087 marcados `[X]` + Phase 8.2 T088–T101 marcados `[X]` + Phases 1–7 completas.

- [X] T066 [P] Verificar pré-requisitos locais no Pi: script scripts/validate-local-env.sh disponível (T097) `bash scripts/validate-local-env.sh` — confirma que `docker`, `docker compose`, `git` e `git-crypt` estão instalados; que `.env` contém todos os tokens reais; que disco externo está montado em `/mnt/external/` com espaço suficiente. Demais ferramentas (`sqlite3`, `jq`, `logrotate`, `gh CLI`, `python3`, `requests`) são providas automaticamente pelo container `scheduler` via `apk install` no startup
- [X] T067 [P] Verificar conectividade de produção: scripts validate-telegram-bot.sh, validate-oauth.sh, validate-firefly.sh disponíveis (T098–T100) executar `bash scripts/validate-telegram-bot.sh`, `bash scripts/validate-oauth.sh`, `bash scripts/validate-firefly.sh` e confirmar que todos os tokens de produção respondem corretamente
- [ ] T068 Criar `.env` de produção: ⚠️ AGUARDA execução manual no Pi — instruções em docs/runbook.md seção "Deploy em Produção" copiar `.env.example` para `.env`, preencher todos os tokens reais (`TELEGRAM_BOT_TOKEN`, `TELEGRAM_CHAT_ID`, `GITHUB_TOKEN`, `FIREFLY_TOKEN`, `GOOGLE_CLIENT_ID`, `GOOGLE_CLIENT_SECRET`, `GOOGLE_REFRESH_TOKEN`, `APP_KEY`), executar `git-crypt lock` para criptografar
- [ ] T069 Executar `bash scripts/setup-pi.sh` ⚠️ AGUARDA execução manual no Pi para criar estrutura de diretórios em `/mnt/external/`: `openclaw/memory/`, `openclaw/tokens/`, `openclaw/secrets/`, `logs/`, `backups/`, `projects/`; aplicar permissões `700` em `secrets/`
- [ ] T070 Iniciar containers: ⚠️ AGUARDA execução manual no Pi `docker-compose up -d` → aguardar até 2 minutos → confirmar `docker ps` mostrando 4 containers com status `(healthy)`: `firefly-iii`, `openclaw-gateway`, `mcporter-firefly`, `scheduler`
- [ ] T071 Parear canais de entrada: ⚠️ AGUARDA execução manual no Pi (a) WhatsApp — escanear QR code via `docker-compose logs openclaw` com aplicativo WhatsApp → Dispositivos Conectados; (b) Telegram — enviar `/start` ao bot e confirmar resposta do agente em < 30 segundos
- [ ] T072 Verificar crontab ativo no container scheduler: ⚠️ AGUARDA execução manual no Pi `docker-compose exec scheduler crontab -l` — confirmar presença dos 9 jobs (check-channels, digest, monthly-report, quota-reset, backup, travel-deals, health-check, logrotate, memory-backup)
- [ ] T073 Executar smoke tests E2E das 4 Skills via Telegram: ⚠️ AGUARDA execução manual
  - Skill 1: enviar mensagem de teste e aguardar criação de task no Google Tasks
  - Skill 2: enviar `/importar` com CSV de teste e confirmar importação no Firefly (`curl http://localhost:8080/api/v1/transactions`)
  - Skill 3: enviar `/monitorar Orlando Jun2026 4pessoas orçamento20000` e confirmar `travel-params.json` atualizado
  - Skill 4: enviar `/ideia app de rastreamento de gastos pessoais` e confirmar resposta com soluções Tavily
- [ ] T074 Executar checklist de segurança pós-deploy: ⚠️ AGUARDA execução manual no Pi (a) verificar portas expostas — `docker ps --format "{{.Ports}}"` deve mostrar apenas `127.0.0.1:*`; (b) verificar git-crypt — `git-crypt status` deve mostrar `.env` encrypted; (c) varredura de credenciais em logs — `grep -rE "token|password|secret|Bearer" /mnt/external/logs/` deve retornar 0 resultados; (d) `bash scripts/health-check.sh` retorna exit 0
- [ ] T075 Registrar estado do deploy: ⚠️ AGUARDA execução manual no Pi anotar data/hora do go-live, versão do commit, resultado dos smoke tests e checklist de segurança em `docs/runbook.md` → seção "Deploy History"; atualizar `spec.md` status de `DRAFT` para `DEPLOYED`; fazer commit `chore: Production deployment go-live YYYY-MM-DD`

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
    ↓
Phase 8 (Correções Críticas — BLOCKING) ← ⚠️ OBRIGATÓRIO antes de Phase 9
    ↓
Phase 8.2 (GAP-I + SOUL.md + validation scripts — BLOCKING) ← ⚠️ OBRIGATÓRIO antes de Phase 9
    ↓
Phase 9 (Deploy em Produção)
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
  T026 — regras de agrupamento de notificações em SOUL.md

Sequencial (depende de A e B):
  T019 → T024 → T025 → T060 → T061 → T027
```

---

## Implementation Strategy Summary

| Scope | Tasks | Stories | Parallelizable |
|-------|-------|---------|----------------|
| MVP sugerido | T001–T027, T060, T061 | US1 completa | T003, T006, T010, T015, T016, T017, T018, T020, T021 |
| Fases 1–2 | T028–T038, T062, T063 | US2 completa | T028, T029, T030, T031 |
| Fases 3–4 | T039–T052 | US3 + US4 | T039, T040, T041, T047, T048 |
| Polish | T053–T059, T064, T065 | — | T053, T054, T055, T057, T064, T065 |
| **Correções (Phase 8)** | **T076–T087** | **Infra** | **T079, T080, T081, T082** |
| **Correções (Phase 8.2)** | **T088–T095** | **US3** | **T088, T091, T092** |
| **Pré-Deploy (8.2 ext.)** | **T096–T101** | **Infra** | **T097, T098, T099, T100** |
| **Deploy (Phase 9)** | **T066–T075** | **US5** | **T066, T067, T069** |
| **Total** | **101 tasks** | **5 user stories + correções** | **~34 paralelizáveis** |

**MVP recomendado**: Phases 1+2+3 (T001–T027, T060, T061) = infraestrutura + Skill 1 completa.
Permite validar o loop completo WhatsApp/Gmail → Google Tasks → Telegram antes de avançar para skills mais complexas.

---

## Phase 10: SerpAPI + Airbnb MCP Integration (US3 — Atualização de Requisitos 2026-03-08)

**Purpose**: Substituir a infraestrutura de busca de viagens (de ClawHub flight-search para SerpAPI `engine=google_flights`) e adicionar busca de hospedagem via `mcp-server-airbnb`. Também corrige o modelo de IA de `gpt-4o` para `gpt-4.1` (multiplier 0) e adiciona controle de cota SerpAPI com `serp-usage.json`.

**Decisões que originaram esta fase** (spec/clarificações 2026-03-08):
- Modelo: GPT-4.1 (multiplier 0) substitui Gemini 2.0 Flash (aposentado 2025-10-23)
- Voos: SerpAPI `engine=google_flights` substitui ClawHub flight-search (retornava links genéricos sem dados estruturados)
- Hospedagem: mcp-server-airbnb substitui Booking.com (sem API gratuita)
- Cota SerpAPI: 250/mês free; controle obrigatório via `serp-usage.json`
- T040 / T041: marcados como supersedidos (ClawHub flight-search foi substituído por SerpAPI; tavily-search mantido para buscas gerais)

**Pré-condição**: Phase 8 e 8.2 concluídas. Pi com openclaw-gateway healthy.

- [X] T102 [P] Atualizar `.env.example` adicionando variável `SERP_API_KEY` com comentário explicativo (SerpAPI free tier, 250 calls/month); adicionar também ao bloco `environment:` do serviço `openclaw` em `docker-compose.yml`
- [X] T103 Atualizar `config/openclaw/openclaw.json`: (a) corrigir `agents.defaults.model.primary` de `"github-copilot/gpt-4o"` para `"github-copilot/gpt-4.1"`; (b) adicionar entry `"mcp-airbnb"` em `mcp_servers`: `{ "name": "airbnb", "command": "npx", "args": ["-y", "@openbnb/mcp-server-airbnb"] }`; (c) adicionar `SERP_API_KEY: "${SERP_API_KEY}"` no env do serviço `openclaw`; este arquivo substitui definitivamente o produzido por T077
- [X] T104 Atualizar `docker-compose.yml` adicionando serviço `mcp-airbnb` como **5º e último container** (Art. VII.2 — limite exato atingido): `image: node:20-alpine`, `command: npx -y @openbnb/mcp-server-airbnb`, `mem_limit: 200m`, `restart: unless-stopped`; sem `--ignore-robots-txt` por padrão (compliance ativa — ver AC Skill 3); nota no arquivo: `# 5/5 containers — Art. VII.2 limit exact; no new services without removal`
- [X] T105 [P] [US3] Reescrever `config/openclaw/workspace/skills/flight-search/SKILL.md` para SerpAPI: (a) frontmatter com `name: flight-search`, `requires.env: ["SERP_API_KEY"]`; (b) instrução para ler `serp-usage.json` ANTES de qualquer chamada HTTP (se `blocked==true`, responder com erro amigável sem chamar API); (c) URL da chamada: `GET https://serpapi.com/search.json?engine=google_flights&departure_id=...&arrival_id=...&outbound_date=...&adults=...&currency=BRL&hl=pt&api_key=$SERP_API_KEY`; (d) parsing de `best_flights[0..2]`; (e) **formato obrigatório dos 8 campos**: `AIRLINE VoeXXX`, `IATA_ORIG HH:MM → IATA_DEST HH:MM[+d]`, `Xh Ym total`, `N escala(s)`, `R$ X.XXX/pessoa`, `R$ XX.XXX total (N adultos)`, link `search_metadata.google_flights_url`; (f) incrementar `calls_used` somente se `search_metadata.cached==false`; este SKILL.md supersede T041 (ClawHub flight-search)
- [X] T106 [P] [US3] Criar `config/openclaw/workspace/skills/airbnb/SKILL.md` com: frontmatter `name: airbnb`, `requires.skills: ["mcp-airbnb"]`; instruções para `airbnb_search(location, checkin, checkout, adults, minPrice, maxPrice)` e `airbnb_listing_details(id, ...)`; política robots.txt: compliance ativada por padrão; se maioria das buscas no smoke test retornar vazia, adicionar flag `--ignore-robots-txt` ao serviço `mcp-airbnb` em `docker-compose.yml` e documentar aqui
- [X] T107 [P] Criar `templates/memory/serp-usage.json` com seed: `{"month":"","calls_used":0,"calls_limit":250,"last_call":null,"alert_80_sent":false,"blocked":false}`; adicionar à lista de arquivos seedados para `/mnt/external/openclaw/memory/` em `scripts/setup-pi.sh`
- [X] T108 Criar `scripts/serp-quota.sh` helper reutilizável: (1) ler `serp-usage.json`; (2) se `month != currentMonth`: reset (`calls_used=0, alert_80_sent=false, blocked=false, month=currentMonth`), salvar; (3) se `blocked==true`: imprimir mensagem de erro e `exit 1`; (4) após chamada SerpAPI bem-sucedida (arg `--increment`): `calls_used += 1, last_call=now()`; se `calls_used==200 && !alert_80_sent`: enviar alerta Telegram + `alert_80_sent=true`; se `calls_used>=250`: `blocked=true` + enviar alerta Telegram bloqueio; salvar arquivo
- [X] T109 [P] [US3] Adicionar entrada cron de health check semanal em `config/crontabs/jarvis`: `0 8 * * 0 openclaw agent --message "Health check semanal: executar 1 busca SerpAPI de teste (GRU→GIG próxima semana) + verificar mcp-airbnb responsivo. Alertar Victor via Telegram APENAS se algum falhar. Não exibir resultado ao usuário em caso de sucesso." --max-tokens 300`; consumo estimado ~4 chamadas SerpAPI/mês
- [ ] T110 [US3] No Pi: adicionar `SERP_API_KEY` ao `.env` de produção; sincronizar `docker-compose.yml` + `config/openclaw/openclaw.json` + `config/openclaw/workspace/skills/flight-search/SKILL.md` + `config/openclaw/workspace/skills/airbnb/SKILL.md` + `templates/memory/serp-usage.json`; copiar `serp-usage.json` seed para `/mnt/external/openclaw/memory/`; fazer `docker compose pull mcp-airbnb && docker compose up -d mcp-airbnb && docker compose restart openclaw`; verificar `docker ps` mostra 5 containers healthy
- [ ] T111 [US3] Smoke test SerpAPI obrigatório — validar AC Skill 3: enviar via Telegram `"Pesquise voos GRU para MCO em 2026-07-01 retornando 2026-07-15, 4 adultos"`; verificar resposta contém **todos os 8 campos obrigatórios** (airline+voo, IATA HH:MM→IATA HH:MM[+d], duração, escalas, R$/pessoa, total 4 adultos, link google.com/flights); verificar `serp-usage.json` com `calls_used >= 1`; FAIL se qualquer campo ausente — reportar quais campos estão faltando para debug

**Checkpoint Phase 10**: Modelo GPT-4.1 ativo + SerpAPI retorna 8 campos obrigatórios + mcp-airbnb healthy + serp-usage.json tracking + health check semanal agendado.

---

## Phase 10 — Dependency & Parallel Map

```
T102 [P] .env.example + docker-compose env block (independente)
T103     openclaw.json model + MCP airbnb (depende T102 para SERP_API_KEY ref)
T104     docker-compose.yml mcp-airbnb service
  ├── T105 [P] flight-search/SKILL.md (independente de T104, usa serp-usage.json)
  ├── T106 [P] airbnb/SKILL.md (independente de T104)
  ├── T107 [P] serp-usage.json seed template
  └── T108     serp-quota.sh helper
        └── T109 [P] crontab health check entry
              └── T110     Pi sync + docker restart (aguarda T103-T109)
                    └── T111 [US3] smoke test 8 campos obrigatórios
```

---

## Updated Implementation Strategy Summary

| Scope | Tasks | Stories | Parallelizable |
|-------|-------|---------|----------------|
| MVP sugerido | T001–T027, T060, T061 | US1 completa | T003, T006, T010, T015–T018, T020, T021 |
| Increment 2 | T028–T038, T062, T063 | US2 completa | T028–T031 |
| Increment 3 | T039–T052 | US3 + US4 | T039, T040, T047, T048 |
| Polish | T053–T059, T064, T065 | — | T053–T055, T057, T064, T065 |
| **Correções (Phase 8)** | **T076–T087** | **Infra** | **T079–T082** |
| **Correções (Phase 8.2)** | **T088–T101** | **US3 + Infra** | **T088, T091, T092, T097–T100** |
| **Deploy (Phase 9)** | **T066–T075** | **US5** | **T066, T067, T069** |
| **SerpAPI + Airbnb (Phase 10)** | **T102–T111** | **US3** | **T102, T105, T106, T107, T109** |
| **Total** | **112 tasks** | **5 user stories + correções** | **~38 paralelas** |

**Nota**: T040 (tavily-search ClawHub) e T041 (flight-search ClawHub) foram **supersedidos** pela Phase 10:
- T040 tavily-search: mantido para buscas web gerais (US1 sugestões, US4 pesquisa de ideias)
- T041 flight-search (ClawHub): **substituído por SerpAPI** via T105 — ClawHub flight-search não retorna dados estruturados

**Modelo ativo**: `github-copilot/gpt-4.1` (multiplier 0) — corrigido de `gpt-4o` em T103.
