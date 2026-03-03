# Constituição do Projeto — Jarvis (Assistente Pessoal OpenClaw)

> Princípios invioláveis que governam todo o desenvolvimento deste projeto.

---

## Artigo I — Custo Zero (ou Quase Zero) Como Restrição Fundamental

1.1. **Nenhuma assinatura nova** será criada para este projeto. Os únicos serviços pagos permitidos são os que o usuário já possui: GitHub Copilot Pro e infraestrutura doméstica existente.

1.2. **GitHub Copilot é o modelo exclusivo**. Nenhum outro modelo de IA será usado neste projeto. Se uma tarefa não for viável com Copilot, a abordagem da tarefa deve ser repensada (ex.: usar CSV ao invés de PDF parsing com IA).

1.3. **Cada decisão técnica deve justificar custo == 0** ou apresentar alternativa gratuita antes de propor solução paga.

1.4. **Token efficiency é métrica de primeira classe**. Prompts devem ser otimizados, contextos minimizados, e respostas cacheadas sempre que possível.

---

## Artigo II — Raspberry Pi 4 (4GB) É o Limite

2.1. O sistema completo (OpenClaw Gateway + skills + containers auxiliares) **não pode exceder 3GB de RAM** em operação normal, reservando 1GB para o sistema operacional e outros serviços (Firefly III, etc.).

2.2. **O Raspberry Pi é o único ambiente de execução**. O Desktop Windows só será usado como última alternativa para tarefas comprovadamente impossíveis no Pi (ex.: build de imagens muito pesadas). Toda funcionalidade deve ser projetada para rodar no Pi.

2.3. **Armazenamento primário é o disco externo 2TB**, nunca o SD card de 64GB. O SD card deve conter apenas: OS, Docker Engine, e imagens base. Volumes de dados, logs e bancos de dados devem usar o HDD externo.

2.4. **Operações batch (importação Firefly, análise de faturas) devem ser agendadas em horários de baixa utilização** para evitar contenção de recursos.

---

## Artigo III — Segurança de Dados Pessoais

3.1. **Dados bancários e financeiros NUNCA trafegam para modelos cloud sem anonimização**. Quando dados sensíveis precisarem ser processados por IA, usar técnicas de anonimização prévia (substituir nomes, mascarar valores exatos) antes de enviar ao GitHub Copilot.

3.2. **Credenciais são gerenciadas via variáveis de ambiente** dentro de Docker secrets ou `.env` files com permissões restritas (600). Nunca hardcoded.

3.3. **O Gateway OpenClaw opera em loopback (127.0.0.1)** por padrão. Acesso remoto exclusivamente via SSH tunnel ou Tailscale.

3.4. **Tokens de API (GitHub, Meta/WhatsApp, Google OAuth) têm escopos mínimos** necessários para a função. Revisão trimestral de permissões.

3.5. **Nenhuma porta é exposta diretamente à internet**. Todo acesso externo passa por VPN (Tailscale) ou túnel SSH.

---

## Artigo IV — Canais de Comunicação: Telegram (Interação) + WhatsApp (Leitura)

4.1. **Telegram é o canal principal de interação humano-agente**. Toda funcionalidade deve ser acessível via mensagem de texto no Telegram Bot. A API oficial do Telegram é gratuita, estável e sem risco de ban.

4.2. **WhatsApp é canal de leitura (input-only)**. O agente monitora mensagens recebidas no WhatsApp pessoal do Victor para identificar pendências e assuntos. O agente NUNCA envia mensagens pelo WhatsApp — toda saída é via Telegram.

4.3. **Mensagens do agente devem ser concisas** (< 500 caracteres para alertas, < 2000 para relatórios). Conteúdo extenso vai para Google Drive com link compartilhado via Telegram.

4.4. **O agente deve ser conciso e evitar mensagens redundantes**. Mensagens INFORMATIVO devem ser agrupadas em resumo diário (digest às 22h, sem alerta push individual). AÇÃO NECESSÁRIA gera alerta individual direto. URGENTE/CRÍTICO geram alerta imediato; CRÍTICO repete a cada 15 minutos até confirmação explícita do usuário.

4.5. **Toda ação destrutiva (deletar task, enviar email, aprovar gasto) requer confirmação explícita** do usuário via Telegram antes de execução.

---

## Artigo V — Arquitetura de Agente Único com Skills Modulares

5.1. **Existe UM único agente OpenClaw**, não quatro agentes separados. As "habilidades" são implementadas como **skills** do mesmo agente, compartilhando contexto quando necessário.

5.2. **Skills se comunicam via tools do OpenClaw**, não via mensagens entre agentes separados. O agente decide qual skill acionar baseado no contexto.

5.3. **Cada skill tem escopo bem definido e documentado**. Overlaps entre skills devem ser resolvidos com uma skill "orquestradora" quando necessário.

5.4. **Memory (memória persistente) é gerenciada em duas camadas**:
  - **Contexto conversacional entre sessões**: usar as features nativas de memória do OpenClaw (`memory_search`/`memory_get`), que armazenam localmente no Pi.
  - **Dados estruturados de domínio** (regras de titulares, parâmetros de viagem, cotas, preferências): **arquivos JSON locais em `/mnt/external/openclaw/memory/`** são explicitamente permitidos — esta é a abordagem correta para dados de configuração específicos do domínio que não se encaixam em memória vetorial. Nenhuma skill ClawHub de memória é necessária para este caso (todas exigem overhead incompatível com o budget de RAM do Art. II.1 ou dependência de LLM para operações básicas).

---

## Artigo VI — Automação Com Supervisão Humana

6.1. **O agente opera em modo semi-autônomo**: coleta dados, analisa e sugere. **Nunca executa ações financeiras, envio de mensagens a terceiros ou alterações em sistemas sem aprovação**.

6.2. **Classificação de urgência segue escala definida**: INFORMATIVO → AÇÃO NECESSÁRIA → URGENTE → CRÍTICO. Apenas URGENTE e CRÍTICO geram alertas push.

6.3. **Checagens periódicas são event-driven quando possível** (webhook, push notification) e cron-based apenas como fallback, para minimizar uso de tokens.

6.4. **Toda ação do agente é logada** em arquivo persistente (disco externo) com timestamp, skill, ação e resultado. Retenção mínima de 90 dias.

---

## Artigo VII — Simplicidade e Incrementalismo

7.1. **O projeto é entregue em fases incrementais**, cada uma funcional e testável independentemente. A Fase 1 deve entregar valor em até 2 semanas.

7.2. **Máximo de 5 containers Docker** rodando simultaneamente no Pi (OS overhead + Firefly + OpenClaw + 2 auxiliares).

7.3. **Não usar frameworks ou abstrações que a skill do OpenClaw não exija**. Se uma skill ClawHub resolve, usar a skill — não reimplementar.

7.4. **Preferir soluções "boring" e testadas** sobre soluções elegantes e frágeis. Exemplo: cron + script bash > sistema de scheduling elaborado.

---

## Artigo VIII — Observabilidade

8.1. **Todo container expõe health check**. Um script de monitoramento simples roda a cada 5 minutos e alerta via Telegram se algum serviço cair.

8.2. **Logs são centralizados** no disco externo em formato texto legível (não binário). Rotação semanal com compressão.

8.3. **Métricas de custo (tokens consumidos, chamadas de API) são rastreadas** semanalmente pelo agente financeiro como parte do relatório de gastos.

---

## Artigo IX — Testes e Validação

9.1. **Cada skill é testada isoladamente** antes de integração com o agente principal.

9.2. **Testes usam dados reais anonimizados**, não mocks. Exemplo: fatura real com valores e nomes trocados.

9.3. **Validação final de cada fase é feita pelo usuário via Telegram**: o agente demonstra a capacidade e o usuário aprova ou solicita ajuste.

9.4. **Não existe deploy sem teste end-to-end** que valide: input (WhatsApp leitura ou Telegram comando) → processamento → ação no sistema alvo → resposta via Telegram.
