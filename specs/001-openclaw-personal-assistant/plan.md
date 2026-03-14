# Implementation Plan: Jarvis — Assistente Pessoal OpenClaw

**Branch**: `001-openclaw-personal-assistant` | **Date**: 2026-03-08 | **Spec**: [spec.md](spec.md)  
**Input**: Feature specification from `/specs/001-openclaw-personal-assistant/spec.md`

## Summary

Assistente pessoal de IA rodando em Raspberry Pi 4 (aarch64) com OpenClaw como runtime e GitHub Copilot Pro (GPT-4.1, multiplier 0) como LLM exclusivo. Interface principal via Telegram Bot. Quatro skills: (1) gestor de pendências via Google Tasks + Gmail + WhatsApp, (2) gestor financeiro via Firefly III, (3) buscador de viagens via SerpAPI Google Flights + Airbnb MCP, (4) agente programador via GitHub CLI. Custo adicional ao Copilot Pro existente: zero.

## Technical Context

**Language/Version**: Markdown (SKILL.md — prompts), JSON (config/data), Bash (scripts), YAML (docker-compose.yml); Node.js 20 (apenas container mcp-airbnb)  
**Primary Dependencies**:
- OpenClaw Gateway — runtime do agente (container `openclaw-gateway`)
- GitHub Copilot Pro — modelo `github-copilot/gpt-4.1` (multiplier 0, sem débito de premium requests)
- SerpAPI `engine=google_flights` — `SERP_API_KEY` em `.env`, 250 chamadas/mês free
- mcp-server-airbnb `@openbnb/mcp-server-airbnb` v0.1.3 — Node.js MCP via stdio, MIT, ARM64-nativo
- pdf-reader-mcp `@sylphx/pdf-reader-mcp` — parsing de faturas PDF no Pi
- Firefly III (SQLite) — gestão financeira
- Google Tasks API — sistema de pendências
- Telegram Bot API — canal principal de interação (bidirecional)
- openclaw-whatsapp / Baileys — leitura passiva de WhatsApp (input-only)

**Storage**:
- `/mnt/external/openclaw/memory/` — JSON: `travel-params.json`, `owner-rules.json`, `quota-rules.json`, `serp-usage.json` (novo — contador SerpAPI)
- Firefly III (SQLite em `/mnt/external/firefly/`) — transações financeiras
- Google Tasks (API) — pendências ativas
- Google Drive (API) — relatórios e imports

**Testing**: Smoke tests manuais via Telegram; cenários E2E documentados em `quickstart.md`; sem framework de testes automatizados (Constituição Art. VII.4 — soluções "boring e testadas")

**Target Platform**: Raspberry Pi 4, 4GB RAM, aarch64, Debian Bookworm, Docker 26+  
**Project Type**: Home server deployment / Personal AI assistant (configuração, não código-fonte tradicional)  
**Performance Goals**: < 30s resposta para consultas simples; < 5min para import de fatura PDF  
**Constraints**:
- < 3GB RAM total (todos os containers em operação) — Constituição Art. II.1
- 250 chamadas SerpAPI/mês (free tier) — Constituição Art. I.1
- GPT-4.1 multiplier 0 (nenhum débito de premium requests no Copilot Pro existente)
- Máximo 5 containers Docker simultâneos — Constituição Art. VII.2

**Scale/Scope**: 1 usuário (Victor), família de 4, ~200 mensagens/dia, 4 skills

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Artigo | Requisito | Status | Observação |
|--------|-----------|--------|------------|
| I.1 — Sem novas assinaturas | Todos os serviços gratuitos ou já pagos | ✅ PASS | SerpAPI free 250/mês; mcp-airbnb MIT open source; GPT-4.1 multiplier 0 |
| I.2 — Copilot como LLM exclusivo | Apenas GitHub Copilot como modelo de IA | ✅ PASS | `github-copilot/gpt-4.1` |
| I.4 — Token efficiency | Prompts compactos e contextos minimizados | ✅ PASS | Multiplier 0 elimina custo; SKILL.md devem ser compactos; SerpAPI retorna JSON estruturado (menos tokens que HTML scraping) |
| II.1 — < 3GB RAM | Budget de memória respeitado | ✅ PASS | Ver budget detalhado abaixo |
| II.2 — Pi como único runtime | Nada exclusivo de Windows/x86_64 | ✅ PASS | Node.js 20 disponível para ARM64; SerpAPI e Airbnb MCP são HTTP/stdio |
| III — Segurança de dados | Credenciais em .env; dados financeiros anonimizados antes do Copilot | ✅ PASS | `SERP_API_KEY` em .env; Airbnb MCP não processa dados sensíveis |
| VII.2 — ≤ 5 containers | Limite de containers Docker | ✅ PASS | openclaw(1) + firefly-iii(2) + mcporter(3) + scheduler(4) + mcp-airbnb(5) = 5 exato — sem margem para adição |

**RAM Budget estimado (operação normal):**

```
OS + system:                ~500MB
firefly-iii (SQLite):       ~200MB
openclaw-gateway:           ~600MB
scheduler:                  ~150MB
mcp-airbnb (Node.js 20):    ~150MB
mcporter-firefly:           ~100MB
Buffer/cache:               ~300MB
─────────────────────────────────
Total estimado:             ~2.0GB  (de 3.8GB disponíveis) ✅ margem de 1.8GB
```

**Post-Phase 1 Re-check**: ✅ Nenhuma violação nova introduzida pelo design de Fase 1. O 5º container (mcp-airbnb) é exatamente o limite — nenhum novo container pode ser adicionado sem remover um existente.

## Project Structure

### Documentation (this feature)

```text
specs/001-openclaw-personal-assistant/
├── plan.md              ← Este arquivo (saída do /speckit.plan)
├── research.md          ← Fase 0 (last update: 2026-03-08)
├── data-model.md        ← Fase 1 (last update: 2026-03-08)
├── quickstart.md        ← Fase 1 (last update: 2026-03-08)
├── contracts/
│   └── interfaces.md    ← Fase 1 (last update: 2026-03-08)
└── tasks.md             ← Fase 2 (saída do /speckit.tasks — NÃO criado por /speckit.plan)
```

### Source Code (deploy no Pi — ~/jarvis-openclaw-pi/)

```text
~/jarvis-openclaw-pi/
├── docker-compose.yml                    ← 5 serviços Docker
├── .env                                  ← git-crypt (nunca commitado em texto claro)
│   # SERP_API_KEY=...
│   # TELEGRAM_BOT_TOKEN=...
│   # GOOGLE_OAUTH_CLIENT_ID/SECRET=...
│   # FIREFLY_TOKEN=...
│   # GITHUB_TOKEN=...
├── config/
│   └── openclaw/
│       ├── openclaw.json                 ← model: "github-copilot/gpt-4.1", skills config
│       └── workspace/
│           ├── SOUL.md                   ← Personalidade e regras do agente (inclui proibição de web_search)
│           ├── USER.md                   ← Perfil do Victor
│           └── skills/
│               ├── flight-search/
│               │   └── SKILL.md          ← REESCRITA: SerpAPI Google Flights (engine=google_flights)
│               ├── airbnb/               ← NOVA skill
│               │   └── SKILL.md          ← Airbnb MCP via mcp-server-airbnb
│               ├── pending/
│               │   └── SKILL.md          ← Skill 1: Google Tasks + Gmail + WhatsApp
│               ├── finance/
│               │   └── SKILL.md          ← Skill 2: Firefly III REST API
│               └── programmer/
│                   └── SKILL.md          ← Skill 4: GitHub CLI + spec-kit
└── /mnt/external/openclaw/memory/        ← Disco externo (dados persistentes)
    ├── travel-params.json
    ├── owner-rules.json
    ├── quota-rules.json
    └── serp-usage.json                   ← NOVO: contador de chamadas SerpAPI/mês
```

**Structure Decision**: O projeto é um deployment de configuração (não código-fonte compilável). Os artefatos entregáveis são SKILL.md (prompts), YAML/JSON de configuração, e scripts Bash. A estrutura acima reflete o repositório real no Pi.

## Complexity Tracking

Nenhuma violação da Constituição — nenhuma justificativa necessária.

> **Nota de risco**: Com 5 containers exatamente no limite (Art. VII.2), qualquer nova integração futura exigirá ou remover um container existente ou aprovar uma exceção à Constituição via clarificação explícita.
