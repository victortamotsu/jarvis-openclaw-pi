# Spec: Jarvis — Assistente Pessoal OpenClaw de Baixo Custo

> **Feature ID**: 001-openclaw-personal-assistant
> **Status**: DRAFT
> **Autor**: Victor
> **Data**: 2026-03-01

---

## 1. Visão Geral

Criar um assistente pessoal de IA operando em um Raspberry Pi 4 (4GB RAM) usando OpenClaw como plataforma, GitHub Copilot como modelo exclusivo e **Telegram como interface principal de interação** (WhatsApp apenas como canal de leitura). O assistente deve ser **custo ~zero** (sem assinaturas além do GitHub Copilot Pro já existente) e cobrir quatro domínios: gestão de pendências, finanças pessoais, viagens e prototipagem de projetos.

---

## 2. Personas

| Persona | Descrição |
|---------|-----------|
| **Victor (Usuário)** | Desenvolvedor bancário, pai de família (4 pessoas), power user de tecnologia. Interage com o agente via **Telegram** no celular. WhatsApp é monitorado passivamente para captura de pendências. Quer economizar tempo e dinheiro. |
| **Cônjuge** | Compartilha conta corrente e cartão de crédito. Recebe relatórios de gastos por email. Não interage com o agente diretamente. |
| **Familiares (filhos)** | Possuem cartões de crédito adicionais. Podem ter cotas de gasto monitoradas. |

---

## 3. User Stories

### 3.1 Skill 1 — Gestor de Assuntos e Pendências Omnichannel

**US-1.1**: Como Victor, quero que o agente leia minhas mensagens do WhatsApp (passivamente) e emails do Gmail para que eu não perca assuntos que exigem ação de médio/longo prazo.

**US-1.2**: Como Victor, quero que assuntos identificados sejam organizados automaticamente como tasks no **Google Tasks** com labels por tipo (pessoal, profissional, financeiro, saúde, casa, etc.) para que eu tenha uma visão consolidada das minhas pendências.

**US-1.3**: Como Victor, quero que cada task tenha sub-tasks para as ações pendentes e uma data de lembrete configurada no Google Tasks para que eu receba alertas nativos no celular.

**US-1.4**: Como Victor, quero que o agente identifique se já existe uma task aberta para o assunto antes de criar uma nova, para evitar duplicatas.

**US-1.5**: Como Victor, quero que o agente atualize tasks existentes com novas informações (nova mensagem recebida, resposta dada, compromisso assumido) para manter o histórico vivo.

**US-1.6**: Como Victor, quero que assuntos classificados como URGENTE/CRÍTICO me alertem imediatamente via **Telegram** para que eu tome medidas a tempo.

**US-1.7**: Como Victor, quero que o agente sugira respostas baseadas no histórico da task e em pesquisas na web para que eu economize tempo na redação.

**US-1.8**: Como Victor, quero que o agente marque automaticamente tasks como resolvidas quando detectar uma resposta final ou confirmação no canal original.

**Critérios de Aceite — Skill 1**:
- [ ] Agente lê mensagens do WhatsApp passivamente a cada 15 minutos (leitura, sem envio)
- [ ] Agente lê emails do Gmail a cada 15 minutos (ou via push notification)
- [ ] Mensagens de curto prazo (ex.: "ok", "obrigado", "chego em 5 min") são ignoradas
- [ ] Mensagens que exigem ação de médio/longo prazo criam task no Google Tasks
- [ ] Tasks possuem: título, notas contextuais, lista de tarefas (task list), sub-tasks de ações, data de vencimento
- [ ] Deduplicação: busca por task existente antes de criar nova (match por assunto + contato)
- [ ] Updates em tasks existentes incluem timestamp e resumo da atualização nas notas
- [ ] Classificação de urgência: INFORMATIVO / AÇÃO NECESSÁRIA / URGENTE / CRÍTICO
- [ ] URGENTE e CRÍTICO geram alerta imediato via **Telegram**
- [ ] Sugestões de resposta são geradas sob demanda (comando do usuário via Telegram)
- [ ] Agente tem acesso a ferramentas de pesquisa web (Tavily ou similar)

### 3.2 Skill 2 — Gestor Financeiro e Fiscal

**US-2.1**: Como Victor, quero importar faturas de cartão de crédito (PDF) e extratos bancários (CSV) para o Firefly III para que eu tenha todas as finanças centralizadas.

**US-2.2**: Como Victor, quero que o agente identifique o titular de cada transação no cartão de crédito (eu, cônjuge, filho 1, filho 2) para que eu saiba quem gasta o quê.

**US-2.3**: Como Victor, quero receber relatórios mensais de gastos por categoria e por pessoa via **Telegram** ou email para acompanhar a saúde financeira da família.

**US-2.4**: Como Victor, quero que o agente crie alertas de cota por pessoa/cartão para que eu saiba quando alguém está perto de exceder o limite definido.

**US-2.5**: Como Victor, quero poder perguntar ao agente sobre gastos específicos, comparações e projeções para tomar decisões financeiras informadas.

**US-2.6**: Como Victor, quero que o agente analise meus investimentos (CDB, Tesouro Direto, etc.) e sugira otimizações baseado em taxas e cenários de mercado.

**US-2.7**: Como Victor, quero que o agente crie uma pendência mensal no Skill 1 para me lembrar de exportar faturas e extratos, completando o ciclo de importação.

**Critérios de Aceite — Skill 2**:
- [ ] Pipeline de importação: usuário exporta PDF/CSV → salva no Google Drive → avisa o agente → agente processa
- [ ] CSV importado no Firefly III com categorização automática
- [ ] PDF de fatura parseado e transações extraídas (com identificação de titular quando possível)
- [ ] Transações sem titular identificável são marcadas como `[NEEDS CLARIFICATION]` e perguntadas ao usuário
- [ ] Relatório mensal gerado automaticamente no dia 5 de cada mês (ou sob demanda)
- [ ] Alertas de cota disparam via **Telegram** quando atingir 80% e 100% do limite
- [ ] Consultas em linguagem natural retornam dados do Firefly III (ex.: "quanto gastei com alimentação em fevereiro?")
- [ ] Informe de rendimentos pode ser importado para análise consolidada anual
- [ ] Dados financeiros sensíveis são anonimizados antes de enviar ao GitHub Copilot (mascarar nomes, valores exatos)
- [ ] Integração com Firefly III via MCP (mcporter) ou API REST direta

### 3.3 Skill 3 — Ajudante de Viagens

**US-3.1**: Como Victor, quero informar períodos de interesse (férias, feriados) e destinos favoritos (Orlando, NYC, Disney, Londres, Paris, Roma) para que o agente monitore oportunidades.

**US-3.2**: Como Victor, quero que o agente analise emails promocionais e grupos de viagens em busca de deals para que eu não perca ofertas.

**US-3.3**: Como Victor, quero que o agente pesquise passagens aéreas e hospedagem para 4 pessoas nos períodos informados para encontrar os melhores preços.

**US-3.4**: Como Victor, quero que deals interessantes me sejam reportados via **Telegram** com resumo e link, e uma task criada no Google Tasks para análise.

**US-3.5**: Como Victor, quero poder definir condições (preço máximo, número de conexões, tipo de hospedagem, localização) para filtrar resultados.

**Critérios de Aceite — Skill 3**:
- [ ] Parâmetros persistentes: destinos, datas-alvo, orçamento máximo por trecho, requisitos de hospedagem
- [ ] Monitoramento de emails promocionais com keywords de viagem
- [ ] Pesquisa sob demanda em fontes: Google Flights (via skill), Booking, Airbnb
- [ ] Alertas via **Telegram** quando encontrar deal dentro dos parâmetros
- [ ] Task criada no Google Tasks (via Skill 1) com detalhes da oferta e deadline para decisão
- [ ] Comparativo de preços quando múltiplas opções existirem (tabela ou doc no Drive)
- [ ] Checagem periódica (diária ou configurável) nos períodos próximos às datas-alvo

### 3.4 Skill 4 — Agente Programador

**US-4.1**: Como Victor, quero enviar ideias de projetos via **Telegram** para que o agente pesquise soluções e dê feedback.

**US-4.2**: Como Victor, quero que o agente crie repositórios no GitHub com estrutura spec-driven para que ideias virem projetos rastreáveis.

**US-4.3**: Como Victor, quero que o agente crie a spec inicial do projeto baseada na ideia discutida para que eu tenha um ponto de partida estruturado.

**US-4.4**: Como Victor, quero que cada projeto seja registrado como task no Google Tasks (via Skill 1) para acompanhamento.

**Critérios de Aceite — Skill 4**:
- [ ] Recebe ideia via **Telegram** e inicia diálogo de refinamento
- [ ] Pesquisa web por soluções existentes, bibliotecas e referências
- [ ] Cria repositório no GitHub via GitHub CLI/API
- [ ] Inicializa projeto com template spec-driven (spec-kit)
- [ ] Gera spec.md preliminar baseado no diálogo
- [ ] Registra projeto no Google Tasks com link do repo e status
- [ ] Operações pesadas (clone, build) rodam no próprio Pi; Desktop Windows é último recurso comprovado

---

## 4. Requisitos Não-Funcionais

### 4.1 Custo
| Item | Custo Esperado |
|------|---------------|
| GitHub Copilot Pro | Já possui (existente) |
| Raspberry Pi 4 + storage | Já possui (existente) |
| Google Workspace (Tasks, Gmail, Drive) | Grátis (conta pessoal) |
| Telegram Bot | Grátis (API oficial) |
| WhatsApp (leitura passiva) | Grátis (conta pessoal) |
| OpenClaw | Open source / grátis |
| Firefly III | Open source / grátis |
| Skills ClawHub | Gratuitas |
| **Total adicional** | **R$ 0/mês** |

### 4.2 Performance
- Tempo de resposta para consultas simples: < 30 segundos
- Tempo de processamento de fatura (PDF → Firefly): < 5 minutos
- Checagem periódica de canais: a cada 15 minutos (configurável)
- RAM total do projeto (todos containers): < 3GB

### 4.3 Disponibilidade
- O sistema deve operar 24/7 no Raspberry Pi
- Downtime aceitável: até 1 hora/mês para manutenção
- Recovery: reinício automático de containers via `restart: unless-stopped`

### 4.4 Segurança
- Ver Constituição, Artigo III
- OAuth tokens criptografados em repouso
- Nenhuma porta exposta à internet pública
- Dados financeiros anonimizados antes de enviar ao GitHub Copilot

---

## 5. Análise de Gaps e Riscos

### 🔴 GAPS CRÍTICOS (Impedem Funcionamento)

**GAP-1: ~~Google Keep não tem API pública oficial~~ — RESOLVIDO**
- **Decisão**: Usar **Google Tasks API** (API oficial, estável, gratuita).
- Tasks API suporta: listas, tasks, sub-tasks, datas de vencimento, notas.
- Limitada em comparação ao Keep (sem labels, sem imagens), mas API oficial elimina risco de quebra.
- Referência: https://developers.google.com/tasks

**GAP-2: ~~WhatsApp Personal vs Business API~~ — RESOLVIDO**
- **Decisão**: **Telegram** é canal principal de interação (API oficial, bots gratuitos, sem risco de ban).
- **WhatsApp** é mantido como fonte de leitura passiva (input-only) via openclaw-whatsapp/Baileys.
- O agente NUNCA envia mensagens pelo WhatsApp — toda saída é via Telegram.
- Risco de ban do WhatsApp é minimizado por ser apenas leitura (sem envio de mensagens).

**GAP-3: RAM insuficiente para todos os serviços simultâneos**
- **Impacto**: Pi 4 com 4GB precisa rodar: OS (~500MB) + Firefly III + PostgreSQL (~300MB) + OpenClaw Gateway + Node.js (~400MB) + skills + eventuais modelos locais
- **Risco**: OOM killer mata containers, sistema instável
- **Mitigação proposta**: 
  - Firefly III usar SQLite ao invés de PostgreSQL (-200MB)
  - OpenClaw com limites de memória (`mem_limit: 1g` no docker-compose)
  - GitHub Copilot é o único modelo (sem Ollama — economiza RAM)
  - Monitoramento de memória com alertas via Telegram
- **Budget estimado de RAM**:
  ```
  OS + system:        ~500MB
  Firefly III (SQLite): ~200MB
  OpenClaw Gateway:    ~500MB
  Skills runtime:      ~300MB
  Buffer/cache:        ~500MB
  ─────────────────────────
  Total:              ~2.0GB (de 3.8GB disponíveis) ✅ viável com margem
  ```

### 🟡 GAPS IMPORTANTES (Degradam Experiência)

**GAP-4: Parsing de PDF de faturas em ARM**
- **Impacto**: Skill 2 depende de extrair dados de PDFs de faturas bancárias
- **Risco**: OCR/parsing de PDF é CPU-intensivo e pode ser lento no Pi
- **Mitigação proposta**: 
  - Fase 1: Usar apenas CSV (que já é exportável do banco)
  - Fase 2: PDF parsing via pdfplumber (Python) direto no Pi (primeiro tentar no Pi)
  - Fase 3: Se comprovadamente impossível no Pi, delegar para Desktop Windows como último recurso

**GAP-5: Scheduling/cron para checagens periódicas**
- **Impacto**: Agente precisa verificar canais a cada 15 min, criar relatórios mensais, etc.
- **Risco**: OpenClaw não tem scheduling nativo
- **Mitigação proposta**: 
  - Usar **cron do Linux** (host) que executa `openclaw agent --message "checar canais"` via CLI
  - Ou container com cron que faz HTTP requests para o Gateway
  - Manter simples (Constituição Art. VII)

**GAP-6: Memória persistente entre sessões do agente**
- **Impacto**: Agente precisa lembrar parâmetros de viagem, cotas de gastos, preferências
- **Risco**: Cada invocação do agente pode perder contexto
- **Mitigação proposta**: 
  - Instalar skill **Ontology** (206 ⭐) para knowledge graph persistente
  - Ou **Self-improving-agent** (939 ⭐) para aprendizado incremental
  - Dados críticos salvos em arquivo JSON no disco externo (fallback simples)
  - OpenClaw memory features nativos (se disponíveis na versão)

**GAP-7: Identificação de titular em transações de cartão**
- **Impacto**: Faturas de cartão adicional listam todas as transações juntas
- **Risco**: Sem dados explícitos, agente não consegue atribuir gastos
- **Mitigação proposta**: 
  - Regras por estabelecimento (ex.: "loja X é sempre filho 1")
  - Pergunta ao usuário para transações ambíguas
  - Aprendizado incremental: uma vez classificado, lembrar para futuro

### 🟢 OPORTUNIDADES DE MELHORIA

**OPP-1: ~~Telegram como canal adicional/backup~~ — PROMOVIDO A CANAL PRINCIPAL**
- Telegram é agora o canal PRINCIPAL de interação (ver Constituição Art. IV)
- API oficial, bots gratuitos, sem risco de ban
- Inline keyboards e rich formatting para UX rica

**OPP-2: Otimização de prompts para GitHub Copilot**
- GitHub Copilot é o único modelo — otimizar prompts por tipo de tarefa
- Tarefas simples (classificação, extração): prompts compactos, poucos tokens
- Tarefas complexas (análise financeira, redação): contexto rico, chain-of-thought
- Monitorar uso de tokens para evitar throttling

**OPP-3: Dashboard web local (Fase futura)**
- Criar uma interface web local (acessível via Tailscale) para visualizar:
  - Pendências consolidadas
  - Dashboard financeiro
  - Status dos agentes
  - Logs e métricas

**OPP-4: ~~Integração banco → Firefly via Open Finance~~ — DESCARTADO**
- **Pesquisa realizada**: Open Finance Brasil **não é acessível para pessoas físicas/desenvolvedores**.
- Apenas instituições financeiras autorizadas pelo Banco Central podem participar (segmentos S1/S2 obrigatórios, outros voluntários mas precisam ser autorizados).
- Consumidores só podem compartilhar dados ENTRE instituições participantes, não extrair para apps pessoais.
- Existem agregadores pagos (Pluggy, Belvo) mas violam o princípio de custo zero.
- **Conclusão**: Manter o fluxo manual (exportar CSV/PDF do banco).

**OPP-5: Notificações diferenciadas por criticidade**
- Telegram: alertas URGENTE/CRÍTICO + resumos diários + interação bidirecional
- Email: relatórios semanais e mensais detalhados
- Google Tasks: tracking de pendências de longa duração
- Cada canal tem propósito claro

---

## 6. Escopo e Faseamento

### Fase 0 — Infraestrutura (Semana 1)
- Setup Docker no Pi (OpenClaw Gateway)
- Configurar GitHub Copilot como modelo exclusivo
- Configurar Tailscale/SSH para acesso remoto
- Setup Telegram Bot (BotFather, obter token, configurar webhook)
- Setup WhatsApp leitura passiva (QR pairing via openclaw-whatsapp/Baileys)
- Setup Google OAuth (Gmail + Drive + Tasks)
- Validação: enviar "ping" via Telegram e receber "pong"

### Fase 1 — Gestor de Pendências MVP (Semana 2-3)
- Leitura de emails do Gmail
- Leitura passiva de mensagens do WhatsApp
- Criação de tasks no Google Tasks
- Classificação básica (urgente vs normal)
- Alertas via Telegram
- Validação: email real → task criada → alerta recebido no Telegram

### Fase 2 — Gestor Financeiro MVP (Semana 4-5)
- Configurar MCP Firefly III (ou API REST)
- Pipeline de importação CSV → Firefly
- Relatório mensal básico de gastos
- Consultas em linguagem natural via Telegram
- Validação: importar extrato real → consultar gasto via Telegram

### Fase 3 — Ajudante de Viagens MVP (Semana 6-7)
- Configurar skill de busca de voos
- Parâmetros persistentes (destinos, datas, orçamento)
- Pesquisa sob demanda via Telegram
- Alertas quando encontrar deal
- Validação: busca real → resultado formatado → task criada

### Fase 4 — Agente Programador MVP (Semana 8)
- Integração GitHub CLI
- Criação de repo com spec-driven template
- Diálogo de refinamento de ideia via Telegram
- Registro de projeto no Google Tasks
- Validação: ideia via Telegram → repo criado → spec gerada

### Fase 5 — Integração e Polimento (Semana 9-10)
- Cross-skill communication refinada
- Otimização de tokens/prompts
- PDF parsing no Pi (pdfplumber)
- Dashboard web (OPP-3) se viável
- Documentação e automação de recovery

---

## 7. Premissas

1. O Raspberry Pi 4 (4GB) permanecerá ligado 24/7 com fonte estável e internet cabeada
2. O disco externo 2TB está conectado via USB 3.0 e montado automaticamente no boot
3. O usuário já possui GitHub Copilot Pro ativo na conta pessoal
4. O Firefly III já está rodando em container Docker no Pi
5. O usuário tem contas Google pessoais ativas (Gmail, Drive, Tasks)
6. O usuário possui conta no Telegram e irá criar um Bot via BotFather
7. O volume de mensagens diário é gerenciável (< 200 mensagens/dia entre WhatsApp e email)
8. As faturas bancárias são do Brasil (formato brasileiro de PDF/CSV)
9. O Desktop Windows está disponível na mesma rede/Tailscale como último recurso (não como dependência)

---

## 8. Exclusões (Fora de Escopo)

- Responder mensagens automaticamente em nome do usuário (apenas sugerir)
- Fazer operações bancárias (transferências, pagamentos)
- Acessar conta bancária diretamente (somente via exportação manual — Open Finance não é viável)
- Interação com familiares que não seja via relatório (cônjuge recebe email, não chat)
- Suporte a idiomas além de Português brasileiro
- Interface gráfica na Fase 1-4 (apenas Telegram + Google Tasks)
- Multi-tenancy (apenas um usuário: Victor)
- Envio de mensagens via WhatsApp (apenas leitura passiva)
