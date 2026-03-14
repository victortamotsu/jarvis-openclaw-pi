# Research: Jarvis — Assistente Pessoal OpenClaw

> Complementa OPENCLAWPI_RESEARCH.md com análise técnica de viabilidade e decisões pendentes.

---

## 1. Decisões Técnicas ~~Pendentes~~ Resolvidas

### 1.1 ~~Google Keep vs Alternativas~~ — **DECIDIDO: Google Tasks**

| Opção | API Oficial | Gratuita | Mobile Push | Kanban/Checklist | Risco |
|-------|------------|----------|-------------|------------------|-------|
| **Google Keep (Gog)** | ❌ Não-oficial | ✅ | ✅ Nativo Android | ✅ Labels + Checkboxes | 🔴 API pode quebrar |
| **Google Tasks** | ✅ Oficial | ✅ | ✅ Nativo Android | ⚠️ Apenas listas | 🟢 Estável |
| **Todoist** | ✅ Oficial | ✅ (até 5 proj) | ✅ App nativo | ✅ Labels + Priorities | 🟢 Estável |
| **Notion** | ✅ Oficial | ✅ (free tier) | ⚠️ App lento | ✅ Databases/Kanban | 🟢 Estável |
| **Trello** | ✅ Oficial | ✅ (free tier) | ✅ App nativo | ✅ Kanban nativo | 🟢 Estável |

**Recomendação**: ~~Usar Google Tasks como source-of-truth~~ **DECIDIDO**: Google Tasks é a source-of-truth.
- API oficial: https://developers.google.com/tasks
- Suporta: listas (task lists), tasks, sub-tasks, datas de vencimento, notas
- Limitações vs Keep: sem labels, sem imagens, sem cores — mas API estável elimina risco
- Push notifications nativas no Android via app Google Tasks
- Integração natural com Google Calendar

**Alternativa descartada**: Google Keep via Gog (API não-oficial, risco de quebra).

---

### 1.2 ~~WhatsApp Integration~~ — **DECIDIDO: Telegram Principal + WhatsApp Leitura**

| Opção | Tipo | Risco de Ban | Custo | Confiabilidade |
|-------|------|-------------|-------|----------------|
| **openclaw-whatsapp (QR)** | Web scraping / Baileys | 🔴 Alto | Grátis | ⚠️ Instável |
| **WhatsApp Business Cloud API** | Oficial Meta | 🟢 Zero | Grátis (1000 msg/mês) | ✅ Estável |
| **Telegram Bot** | Oficial | 🟢 Zero | Grátis | ✅ Muito estável |
| **Hybrid: Telegram primário + WhatsApp leitura** | Misto | 🟡 Médio | Grátis | ✅ Boa |

**Análise detalhada WhatsApp Business Cloud API**:
- Desde 2023, Meta permite contas business para uso pessoal/micro-empresa
- 1000 conversas/mês gratuitas (mais que suficiente)
- Requer: número de telefone dedicado (pode ser chip pré-pago barato ~R$15)
- Requer: conta Meta Business (gratuita, mas burocrática)
- **Não pode usar o mesmo número do WhatsApp pessoal**

**Recomendação**: ~~Usar WhatsApp Business Cloud API com número secundário~~ **DECIDIDO**: Arquitetura híbrida:

**Telegram (canal principal — bidirecional)**:
- Bot criado via BotFather (gratuito, instantâneo)
- API oficial: https://core.telegram.org/bots/api
- Webhook ou long polling para receber mensagens
- Suporta: inline keyboards, rich text, botões de confirmação, imagens, documentos
- Zero risco de ban
- Usuário interage com o agente **exclusivamente** via Telegram

**WhatsApp (canal secundário — leitura passiva)**:
- Integração via openclaw-whatsapp/Baileys (QR pairing)
- O agente **apenas lê** mensagens recebidas no WhatsApp pessoal do Victor
- NUNCA envia mensagens pelo WhatsApp (minimiza risco de ban)
- Usado para captar pendências, compromissos e assuntos mencionados por terceiros
- Se a integração WhatsApp quebrar ou der ban, o sistema continua funcional via Telegram + Gmail

**Alternativa descartada**: WhatsApp Business Cloud API (requer número dedicado, Meta Business account, burocracia desnecessária).

---

### 1.3 MCP Firefly III — Estado Atual

**Pesquisa realizada**: Não existe MCP oficial para Firefly III mantido pela comunidade MCP.

**Opções disponíveis**:
1. **API REST direta**: Firefly III tem uma API REST completa e bem documentada
   - Endpoint: `http://localhost:<port>/api/v1/`
   - Auth: Personal Access Token
   - Documentação: https://api-docs.firefly-iii.org/
   
2. **Criar MCP wrapper**: Criar um servidor MCP stdio que encapsula a API REST
   - Seria um projeto do Skill 4 (agente programador) como dogfooding
   
3. **Usar skill api-gateway**: Configurar chamadas REST genéricas via skill

**Recomendação**: Fase 2 usa API REST direta via skill customizada ou api-gateway. Fase futura: criar MCP como projeto spec-driven (dogfooding do Skill 4).

---

### 1.4 Modelos de IA — GitHub Copilot Exclusivo

> **DECIDIDO**: GitHub Copilot Pro é o único modelo. Ollama descartado (Pi não tem capacidade, e usuário preferiu não usar).

| Tarefa | Complexidade | Modelo | Tokens ~estimados |
|--------|-------------|--------|-------------------|
| Classificar mensagem (urgente/normal) | Baixa | GitHub Copilot | ~200 |
| Extrair dados de email/mensagem | Média | GitHub Copilot | ~500 |
| Gerar resumo diário | Média | GitHub Copilot | ~1000 |
| Analisar fatura CSV | Média | GitHub Copilot (dados anonimizados) | ~2000 |
| Sugerir resposta contextual | Alta | GitHub Copilot | ~1500 |
| Análise financeira complexa | Alta | GitHub Copilot (dados anonimizados) | ~3000 |
| Parse PDF de fatura | Alta | pdfplumber (local, sem IA) | N/A |
| Gerar spec de projeto | Alta | GitHub Copilot | ~5000 |

**Estimativa mensal de tokens**:
- Checagens periódicas (96/dia × 30 × ~300 tokens): ~864k tokens
- Interações diretas (~10/dia × 30 × ~1000 tokens): ~300k tokens  
- Relatórios e análises (~5/mês × ~5000 tokens): ~25k tokens
- **Total estimado: ~1.2M tokens/mês**

GitHub Copilot Pro não cobra por token (modelo subscription), então **custo adicional = R$ 0**.

---

### 1.5 Flight Search Backend — **DECIDIDO: SerpAPI Google Flights**

| Opção | ARM64 | Dados estruturados | Custo | Estabilidade Pi |
|-------|-------|-------------------|-------|----------------|
| **SerpAPI `engine=google_flights`** | ✅ HTTP puro | ✅ JSON estruturado | ✅ 250/mês free | ✅ Alta |
| Playwright + scraping Google Flights | ❌ Sem imagem ARM64 | ✅ Se implementado | Grátis mas inviável | ❌ 400-600MB RAM extra; Pi tem ~550MB livre |
| Tavily generic search | ✅ HTTP puro | ❌ Links genéricos (Kayak, Decolar) | ✅ Free tier | ✅ Alta, mas inadequada |
| Google Flights API oficial | N/A | ✅ | ❌ Sem API pública | N/A |

**Decisão**: SerpAPI `engine=google_flights`
- **Rationale**: Retorna JSON estruturado com `best_flights[].flights[].{airline, flight_number, departure_airport.{id,time}, arrival_airport.{id,time}, duration}`, `best_flights[].price`, `best_flights[].layovers[]`, e `search_metadata.google_flights_url`. Exatamente o que o AC exige. Tavily só retornava links de comparadores (Kayak, Decolar, LATAM "a partir de R$"), sem dados estruturados — impede formato de saída obrigatório.
- **API key**: `c899c4d126f8b200009ecd8945b5f788aad8e90bb67beb7221a859b9c4276fff` (em `.env` como `SERP_API_KEY`)
- **Limite**: 250 chamadas/mês free; cached searches são gratuitas e não contam
- **Alternativas descartadas**: Playwright (sem imagem ARM64 para Docker; 400-600MB RAM inviável no Pi); Tavily (inadequada para dados estruturados de voo)

---

### 1.6 Accommodation Search — **DECIDIDO: Airbnb MCP (mcp-server-airbnb)**

| Opção | ARM64 | Integração | Custo | Estabilidade |
|-------|-------|-----------|-------|-------------|
| **mcp-server-airbnb** (`@openbnb/mcp-server-airbnb`) | ✅ Node.js puro | ✅ MCP stdio | ✅ Grátis / MIT | 🟡 robots.txt policy |
| Booking.com | N/A | ❌ Sem API pública gratuita | ❌ Requer parceria | N/A |
| Google Hotels via SerpAPI | ✅ HTTP | ✅ JSON estruturado | ⚠️ Consome cota SerpAPI | 🟢 |  
| Airbnb via Tavily | ✅ HTTP | ❌ Links genéricos | ✅ Free tier | 🟡 |

**Decisão**: `@openbnb/mcp-server-airbnb` v0.1.3 (MIT License)
- **Rationale**: Único MCP open-source disponível para acomodações com dados estruturados. Node.js puro → ARM64-nativo. Booking.com removido do escopo (sem API gratuita disponível).
- **Run command**: `npx -y @openbnb/mcp-server-airbnb` (default: robots.txt compliance ativada)
- **robots.txt policy**: Iniciar com compliance ativada (padrão). Se smoke test da Fase 3 revelar falha na maioria das buscas de acomodação, **reconfigurar permanentemente** com `--ignore-robots-txt` e documentar decisão.
- **Tools disponíveis**: `airbnb_search(location, checkin, checkout, adults, ...)` e `airbnb_listing_details(id, ...)`
- **Container**: Node.js 20 Alpine, ~150MB RAM, arm64 compatível
- **Alternativa descartada**: Booking.com (sem API pública gratuita; removido do escopo do feature)

---

### 1.7 Modelo de IA — **DECIDIDO: GPT-4.1 (multiplier 0)**

| Modelo | Disponível | Multiplier | Observação |
|--------|-----------|-----------|------------|
| **GPT-4.1** | ✅ | **0** ← **escolhido** | Zero débito de premium requests |
| GPT-4o | ✅ | 0 | Opção válida, GPT-4.1 preferido |
| GPT-5 mini | ✅ | 0 | Capacidade inferior |
| Gemini 3 Flash | ✅ | 0.33 | Cobrado em premium requests — rejeitado |
| Gemini 3 Pro | ✅ | 1.0 | Cobrado em premium requests — rejeitado |
| Gemini 2.0 Flash | ❌ RETIRED 2025-10-23 | N/A | Foi removido; não disponível |
| Claude Sonnet 4.x | ✅ | 1.0 | Cobrado em premium requests — rejeitado |

**Decisão**: `github-copilot/gpt-4.1` (multiplier 0)
- **Rationale**: Único modelo com capacidade adequada E multiplier 0. Gemini 2.0 Flash foi aposentado em 2025-10-23 (confirmado na documentação oficial GitHub Copilot 2026-03-08). Gemini 3 Flash rejeitado pois multiplier 0.33 debitaria premium requests do plano Copilot Pro existente. GPT-4.1 tem multiplier 0 → custo adicional = R$ 0.
- **Fonte verificada**: `https://docs.github.com/pt/copilot/reference/ai-models/supported-models` (consultado 2026-03-08)

---

### 1.8 SerpAPI Quota Management — **DECIDIDO: Alert 80% + Block 100%**

**Problema**: SerpAPI free tier limita 250 chamadas/mês. Sem controle, o agente pode esgotar a cota com monitoramentos automáticos, bloqueando buscas sob demanda do usuário.

**Decisão**: Contador local persistente em `serp-usage.json`

```json
{
  "month": "2026-03",
  "calls_used": 45,
  "calls_limit": 250,
  "last_call": "2026-03-08T14:32:00Z",
  "alert_80_sent": false,
  "blocked": false
}
```

**Política**:
- Antes de cada chamada SerpAPI: ler `serp-usage.json`, verificar `blocked`
- Se `calls_used >= 200` (80%): enviar alerta Telegram (uma vez por mês, `alert_80_sent`)
- Se `calls_used >= 250` (100%): definir `blocked = true`; retornar erro amigável "Cota SerpAPI esgotada. Reseta em 1º do mês."
- Reset automático: quando `month != currentMonth` → zerar contador
- Cached searches do SerpAPI não contam (resposta `search_metadata.cached = true`) → não incrementar

**Rationale**: Evita surpresa de bloqueio. 80% de alerta dá margem para o usuário decidir suspender monitoramentos automáticos se necessário. 100% de bloqueio é defensivo para não ultrapassar o free tier.

**Health check semanal**: 1 SerpAPI + ping Airbnb MCP → ~4 chamadas SerpAPI/mês. Alerta Telegram **apenas se falhar**. Não envia confirmação de sucesso (silencioso).

---

## 2. Arquitetura Docker no Raspberry Pi

### 2.1 Inventário de Containers

```yaml
# docker-compose.yml (conceitual)
services:
  # Já existente
  firefly-iii:
    image: fireflyiii/core:latest
    mem_limit: 256m
    volumes:
      - /mnt/external/firefly:/var/www/html/storage
    
  # Novo - OpenClaw Gateway
  openclaw:
    image: openclaw/openclaw:latest  # ou build local
    mem_limit: 1g
    ports:
      - "127.0.0.1:18789:18789"
    volumes:
      - /mnt/external/openclaw:/home/node/.openclaw
      - /mnt/external/openclaw-workspace:/home/node/workspace
    environment:
      - GITHUB_TOKEN=${GITHUB_TOKEN}
      - TELEGRAM_BOT_TOKEN=${TELEGRAM_BOT_TOKEN}
    depends_on:
      - firefly-iii

  # Novo - Telegram Bot webhook receiver (se usar webhook ao invés de long polling)
  # Nota: pode ser integrado no próprio OpenClaw via skill

  # Novo - Cron scheduler
  scheduler:
    image: alpine:latest
    mem_limit: 64m
    volumes:
      - ./crontabs:/etc/crontabs
    # Roda scripts que chamam openclaw CLI periodicamente
```

### 2.2 Layout de Disco

```
SD Card (64GB):
├── /boot                     # Sistema
├── /var/lib/docker/           # Imagens Docker (layers)
└── /etc/                     # Configurações

Disco Externo 2TB (/mnt/external):
├── firefly/                  # Dados Firefly III
│   ├── database.sqlite
│   └── uploads/
├── openclaw/                 # Home do OpenClaw
│   ├── openclaw.json         # Config principal
│   ├── memory/               # Knowledge graph / ontology
│   └── skills/               # Skills instaladas
├── openclaw-workspace/       # Workspace do agente
│   ├── config/
│   │   └── mcporter.json
│   └── imports/              # CSVs, PDFs para processamento
├── logs/                     # Logs centralizados
│   ├── openclaw/
│   ├── firefly/
│   └── scheduler/
└── backups/                  # Backups semanais
    ├── openclaw-config/
    └── firefly-db/
```

---

## 3. Skills ClawHub — Mapeamento

| Necessidade | Skill ClawHub | Stars | Notas |
|-------------|--------------|-------|-------|
| Gmail read/write | **Gog** (Google Workspace) | 74.6k | ✅ Cobre Gmail + Drive |
| Google Tasks | **Google Tasks API** (REST direto ou skill customizada) | N/A | ✅ API oficial, precisa implementar |
| Google Drive | **Gog** | (incluso) | ✅ Upload/download de arquivos |
| Telegram Bot | **Telegram Bot API** (skill customizada ou MCP) | N/A | ✅ API oficial, implementar |
| WhatsApp (leitura) | **openclaw-whatsapp** | 317 | ⚠️ QR pairing, apenas leitura |
| Web search | **Tavily Search** | 311 | ✅ Otimizado para IA |
| Flight search | **SerpAPI** `engine=google_flights` | N/A | ✅ 250/mês free; API key em .env; JSON estruturado |
| Accommodation | **mcp-server-airbnb** (@openbnb) | 392 | ✅ Node.js MCP; npx; ARM64 nativo |
| MCP support | **openclaw-mcp-plugin** | 3.8k | ✅ Conecta MCPs genéricos |
| Memory | **Ontology** | 206 | ✅ Knowledge graph |
| Self-improvement | **Self-improving-agent** | 939 | ✅ Aprende de erros |
| Browser automation | **playwright-mcp** | 11.7k | ⚠️ Pesado demais para Pi |

### Skills a implementar (custom):
- **Telegram Bot skill**: Receber/enviar mensagens via Bot API. Pode ser MCP stdio.
- **Google Tasks skill**: CRUD de tasks/listas via REST API. Pode ser MCP stdio.
- **Firefly III skill**: Wrapper da API REST. Pode ser MCP stdio.

### Skills adicionais a pesquisar:
- `[NEEDS RESEARCH]` Booking.com / Airbnb search skill
- `[NEEDS RESEARCH]` PDF parser skill para ARM (pdfplumber como fallback direto)
- `[NEEDS RESEARCH]` GitHub CLI integration skill

---

## 4. Open Finance Brasil — Análise de Viabilidade

> **CONCLUSÃO: NÃO VIÁVEL para uso pessoal.**

### O que é
Open Finance Brasil é uma iniciativa regulada pelo Banco Central do Brasil que permite o compartilhamento de dados financeiros entre instituições participantes, com consentimento do cliente.

### Por que não funciona para este projeto
1. **Apenas instituições financeiras autorizadas pelo BCB podem participar**. Não existe "developer API" aberta.
2. Instituições dos segmentos S1 e S2 têm participação obrigatória; demais podem ser voluntárias, mas **precisam ser autorizadas pelo Banco Central**.
3. O consumidor só pode compartilhar seus dados **entre instituições participantes** (ex.: do Banco A para o Banco B), não extrair para um app pessoal.
4. Não existe modelo TPP (Third Party Provider) como no PSD2 europeu — não há como um desenvolvedor individual se registrar.

### Alternativas pesquisadas
| Alternativa | Tipo | Custo | Viabilidade |
|-------------|------|-------|-------------|
| **Pluggy** | Agregador (screen scraping) | Pago (~R$99+/mês) | ❌ Viola princípio custo zero |
| **Belvo** | Agregador (Open Finance) | Pago | ❌ Viola princípio custo zero |
| **Exportação manual CSV/PDF** | Manual | Grátis | ✅ Abordagem atual |

### Decisão
Manter exportação manual de CSV/PDF como fluxo padrão. O agente cria lembrete mensal via Google Tasks (Skill 1) para o usuário exportar as faturas.

---

## 5. Segurança — Mapeamento de Dados Sensíveis

| Dado | Onde Armazenado | Modelo de Acesso | Proteção |
|------|----------------|------------------|----------|
| GitHub Token | Docker secret / .env | OpenClaw Gateway | File permission 600 |
| Google OAuth tokens | OpenClaw config (encrypted) | Gog skill | OAuth2 refresh |
| WhatsApp session | OpenClaw workspace | WhatsApp skill (leitura) | QR pairing temporal |
| Dados bancários (CSV) | Disco externo (imports/) | Firefly skill | Processado → deletado |
| Faturas PDF | Disco externo (imports/) | PDF parser | Processado → deletado |
| Firefly API token | Docker secret / .env | Firefly MCP/API | File permission 600 |
| Histórico de conversas | OpenClaw memory | Todas skills | Disco externo criptografado (futuro) |
| Telegram Bot Token | Docker secret / .env | Telegram skill | File permission 600 |

---

## 6. Referência Cruzada

- Constituição: `../../.specify/memory/constitution.md`
- Especificação: `./spec.md`
- Plano de implementação: `./plan.md`

---

## 7. Atualizações Pós-Clarificação (2026-03-03)

Decisões coletadas na sessão `/speckit.clarify`. Substituem ou complementam seções anteriores.

### 7.1 Firefly III: MCP primário + REST fallback *(atualiza §1.3)*

| Camada | Mecanismo | Uso |
|--------|-----------|-----|
| **Primária** | `mcporter` (MCP server) | Consultas em linguagem natural via OpenClaw agent tools |
| **Fallback** | Firefly III REST API direto | Operações de importação e casos não cobertos pelo MCP |

**Decisão**: MCP como interface padrão do agente, preparando ambiente para outros MCPs futuros (Google Tasks MCP, Telegram MCP, etc.). REST como fallback operacional nos scripts do pipeline.

### 7.2 Gmail: Skill nativa OpenClaw primária *(atualiza §3)*

| Prioridade | Mecanismo | Condição |
|-----------|-----------|----------|
| **1ª** | Skill Gmail nativa (ClawHub) | Disponível e cobrindo os scopes necessários |
| **2ª** | Gmail API REST (OAuth 2.0) | Skill indisponível ou insuficiente |

**Justificativa**: Consistência com WhatsApp (skill nativa) e visão de usar skills ClawHub como interface padrão de integrações; mantém número de componentes custom ao mínimo.

### 7.3 Armazenamento de credenciais: `.env` + `git-crypt` *(atualiza §5)*

- **Mecanismo**: Arquivo `.env` com todos os tokens e secrets
- **Criptografia em repouso**: `git-crypt` (ou `sops` como alternativa)
- **Permissões**: 600 no Pi host
- **Montagem**: Volume Docker no `docker-compose.yml`
- **Commitado**: Sim, mas como binário criptografado (legível apenas com chave GPG)
- **Nunca em plain text**: `.env.example` é o template commitado; `.env` real é criptografado

### 7.4 WhatsApp: Skill nativa OpenClaw *(confirma §3, atualiza deployment)*

- **Deployment**: Skill nativa `openclaw-whatsapp` rodando dentro do runtime OpenClaw
- **Sem container Docker separado**: economiza ~100-150MB de RAM e simplifica orquestração
- **QR pairing**: executado via interface do OpenClaw no setup inicial
- **Fallback**: se skill quebrar ou ser banida, sistema continua via Telegram + Gmail

### 7.5 Gatilho de importação PDF/CSV: comando `/importar` via Telegram

- **Fluxo**: Usuário salva PDF/CSV na pasta `Jarvis/imports/` do Google Drive → envia `/importar` no Telegram
- **Ação do agente**: busca arquivo mais recente na pasta configurada → executa pipeline de importação
- **Sem monitoramento assíncrono do Drive**: evita polling contínuo e reduz uso de tokens
- **Confirmação**: agente responde no Telegram com resultado da importação (sucesso/erro/itens importados)

---

## 8. Gaps Críticos — OpenClaw Real vs Implementação Anterior (2026-03-07)

> Pesquisa realizada consultando `npm info openclaw`, `docs.openclaw.ai/install/docker`, `docs.openclaw.ai/concepts/model-providers` e `docs.openclaw.ai/providers/github-copilot`.

### 8.1 Imagem Docker — CORRIGIDO

**Decisão**: `ghcr.io/openclaw/openclaw:latest` (GitHub Container Registry)  
**Racional**: A imagem `openclaw/openclaw` no Docker Hub retorna 404. A imagem oficial é publicada no GHCR.  
**Alternativa rejeitada**: Build local do repo (lento num Pi ARM64, desnecessário com imagem pré-compilada disponível).

### 8.2 Porta Padrão do Gateway — CORRIGIDO

**Decisão**: Porta `18789` (padrão do OpenClaw)  
**Racional**: A porta 3000 nunca foi documentada no OpenClaw — era um placeholder inventado. O gateway padrão roda em `:18789` e expõe `/healthz` e `/readyz`.  
**Health endpoint correto**: `curl http://localhost:18789/healthz`

### 8.3 Schema `openclaw.json` — REESCREVER

**Decisão**: JSON5 com chaves `agents.defaults.model.primary`, `channels.telegram.botToken`, `gateway.bind`  
**Racional**: O OpenClaw aplica validação estrita de schema. O arquivo atual usa chaves inventadas (`id`, `version`, `channels.default`, `skills[*].type`, `model_config`) que causam falha de inicialização.  
**Alternativa rejeitada**: Manter arquivo antigo e tentar adaptar — sem caminho de migração, schema é incompatível.

**Schema mínimo funcional:**
```json5
{
  agents: { defaults: { model: { primary: "github-copilot/gpt-4o" } } },
  channels: {
    telegram: {
      botToken: "${TELEGRAM_BOT_TOKEN}",
      allowFrom: ["${TELEGRAM_CHAT_ID}"],
    },
  },
  gateway: { bind: "loopback" },
}
```

### 8.4 Auth GitHub Copilot — VALIDADO

**Decisão**: Usar `GITHUB_TOKEN` como variável de ambiente (provider `github-copilot` aceita `COPILOT_GITHUB_TOKEN` / `GH_TOKEN` / `GITHUB_TOKEN`)  
**Racional**: O provider `github-copilot` é built-in no OpenClaw e troca o GitHub token por tokens da Copilot API automaticamente. Não requer login interativo quando o token está no ambiente.  
**Risco residual**: O Personal Access Token deve ter escopo `copilot` habilitado na conta GitHub. Validar com `docker exec openclaw-gateway node dist/index.js models status` no primeiro boot.  
**Alternativa para falha**: `openclaw models auth login-github-copilot` (requer TTY interativo uma vez).

### 8.5 Volume Mount Path — CORRIGIDO

**Decisão**: Montar `./config/openclaw` em `/home/node/.openclaw` (container roda como usuário `node`, UID 1000)  
**Racional**: O OpenClaw resolve config e workspace em `/home/node/.openclaw/` — caminho do home do usuário `node`.  
**Alternativa rejeitada**: `/config/openclaw` (caminho inventado que o OpenClaw nunca lê).

### 8.6 DM Pairing Policy Telegram — CORRIGIDO

**Decisão**: `channels.telegram.allowFrom: ["${TELEGRAM_CHAT_ID}"]`  
**Racional**: O padrão do OpenClaw é `dmPolicy: "pairing"` — remetentes desconhecidos recebem código de verificação e o bot não processa a mensagem. Victor enviaria mensagens mas nunca receberia resposta sem esta configuração.  
**Segurança**: Limitar `allowFrom` ao chat ID de Victor (Art. III) é mais seguro que `dmPolicy: "open"`.

### 8.7 Skills Format — AgentSkills SKILL.md

**Decisão**: Cada skill precisa de pasta com `SKILL.md` no formato AgentSkills em `<workspace>/skills/<name>/SKILL.md`  
**Racional**: O OpenClaw descobre skills via `SKILL.md` com frontmatter YAML. O arquivo de código (`index.js`) existe mas sem `SKILL.md` o agente não sabe da existência da skill.  
**Localização correta**: `config/openclaw/workspace/skills/<skill-name>/SKILL.md` (montado em `/home/node/.openclaw/workspace/skills/`)

### 8.8 Workspace Files Location — CORRIGIDO

**Decisão**: `config/openclaw/workspace/{SOUL.md,USER.md,AGENTS.md}`  
**Racional**: Arquivos de personalidade/contexto do agente pertencem ao workspace root: `/home/node/.openclaw/workspace/`. O caminho `config/openclaw/agents/jarvis/` nunca é lido pelo OpenClaw.  
**Ação**: Mover (não copiar) os arquivos existentes para o caminho correto.

