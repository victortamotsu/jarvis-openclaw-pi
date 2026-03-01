# Quickstart: Validação Rápida por Fase

> Cenários mínimos para validar cada fase antes de avançar.

---

## Fase 0 — Infra (PASS/FAIL)

| # | Teste | Comando/Ação | Resultado Esperado |
|---|-------|-------------|-------------------|
| 0.1 | OpenClaw Gateway sobe no Pi | `docker compose up openclaw` | Container healthy em < 60s |
| 0.2 | GitHub Copilot funciona como modelo | `openclaw agent --message "ping"` | Resposta "pong" ou texto livre |
| 0.3 | Telegram Bot funciona | Enviar mensagem ao bot / `curl Telegram API getMe` | Bot responde ou retorna info |
| 0.4 | WhatsApp leitura passiva | Scan QR code (Baileys/openclaw-whatsapp) | Agente lê mensagem teste (sem enviar) |
| 0.5 | Google OAuth funciona | `gog auth` → `gog gmail list` | Lista 5 emails recentes |
| 0.6 | Google Tasks API funciona | `curl Tasks API /users/@me/lists` | Retorna task lists |
| 0.7 | Firefly III acessível | `curl http://localhost:8080/api/v1/about -H "Authorization: Bearer $TOKEN"` | JSON com versão Firefly |
| 0.8 | Disco externo montado | `df -h /mnt/external` | Disco 2TB visível |

---

## Fase 1 — Gestor de Pendências (Cenário E2E)

**Cenário**: Victor recebe email do encanador com orçamento de caixa d'água.

1. **Email chega** no Gmail: "Bom dia Victor, o orçamento para limpeza da caixa d'água é R$350, com garantia de 30 dias."
2. **Agente detecta** (checagem periódica ou push): email requer ação de médio prazo
3. **Agente cria task** no Google Tasks: "Orçamento limpeza caixa d'água - R$350"
   - Task list: CASA
   - Urgência: AÇÃO_NECESSÁRIA (nas notes)
   - Sub-task: "Comparar com outros orçamentos"
   - Sub-task: "Responder encanador"
   - Due date: D+3
4. **Agente envia alerta** via **Telegram**: "📋 Nova pendência: Orçamento caixa d'água (R$350). Task criada no Google Tasks."
5. **Victor pede via Telegram**: "sugira resposta para o orçamento da caixa d'água"
6. **Agente sugere** via Telegram: "Obrigado pelo orçamento. Encontrei outros na faixa de R$300. Você ofereceria garantia de 3 meses?"

**PASS se**: Task criada com dados corretos + Alerta recebido no Telegram + Sugestão gerada

---

## Fase 2 — Gestor Financeiro (Cenário E2E)

**Cenário**: Victor exporta extrato CSV e fatura PDF do mês.

1. **Victor exporta** CSV da conta corrente e salva no Google Drive pasta "Jarvis/imports"
2. **Victor avisa via Telegram**: "importar extrato fevereiro"
3. **Agente detecta** arquivo no Drive, baixa e processa
4. **Agente importa** no Firefly III com categorização automática
5. **Agente identifica** 3 transações sem titular claro → pergunta ao Victor
6. **Victor responde via Telegram**: "Loja Games é do filho, Salon é da esposa"
7. **Agente aprende** regras e salva na memória
8. **Victor pergunta via Telegram**: "quanto gastamos com alimentação em fevereiro?"
9. **Agente consulta** Firefly III e responde via Telegram: "R$ 2.847 total. Victor: R$1.200, Cônjuge: R$1.647"

**PASS se**: CSV importado + Categorização + Consulta funciona + Regras salvas

---

## Fase 3 — Viagens (Cenário E2E)

**Cenário**: Victor quer monitorar passagens para Orlando em julho.

1. **Victor via Telegram**: "monitorar voos GRU-MCO julho 2026, 4 pessoas, máximo R$3000 por pessoa"
2. **Agente salva** parâmetros na memória persistente
3. **Agente pesquisa** via Flight Search skill
4. **Agente encontra** deal a R$2.800/pessoa com LATAM
5. **Agente envia Telegram**: "✈️ DEAL: GRU→MCO LATAM R$2.800/pessoa (4x = R$11.200). 1 parada. Link: ..."
6. **Agente cria task** no Google Tasks: "Deal Orlando Jul/2026 - R$11.200" com due date de 48h

**PASS se**: Parâmetros salvos + Busca retorna resultados + Alerta enviado via Telegram + Task criada

---

## Fase 4 — Programador (Cenário E2E)

**Cenário**: Victor tem uma ideia de app.

1. **Victor via Telegram**: "ideia: criar um app que monitora preços de produtos em sites brasileiros e alerta quando cai"
2. **Agente pesquisa** soluções existentes (web search)
3. **Agente responde via Telegram**: "Existem X soluções similares. Diferencial pode ser: integração com Mercado Livre API + alertas Telegram. Quer que eu crie o projeto?" [Botão: SIM / NÃO]
4. **Victor**: toca "SIM"
5. **Agente cria repo** no GitHub: `victor/price-monitor-br`
6. **Agente inicializa** spec-driven com spec.md preenchida
7. **Agente cria task** no Google Tasks: "Projeto: Price Monitor BR" com link do repo nas notes

**PASS se**: Pesquisa feita + Repo criado + Spec gerada + Task criada
