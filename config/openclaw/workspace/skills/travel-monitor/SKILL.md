---
name: travel-monitor
description: Monitore oportunidades de viagens para o Victor — pesquisar passagens, hospedagem, comparar preços com orçamento salvo, e alertar sobre deals atrativos.
metadata:
  openclaw:
    requires:
      env: []
      skills:
        - tavily-search
        - flight-search
---

# travel-monitor Skill

Use esta skill para pesquisar e monitorar preços de viagens de acordo com o perfil e orçamento do Victor.

## Quando Usar

- Victor pede pesquisa de passagens ou hospedagem
- Scheduler aciona verificação periódica de preços (cron diário)
- Victor pergunta sobre status de monitoramento de viagem

## Parâmetros de Viagem

Os parâmetros de viagem do Victor estão armazenados em:
```
/home/node/.openclaw/workspace/memory/travel-params.json
```

Formato esperado:
```json
{
  "destinations": ["Lisboa", "Buenos Aires", "Tóquio"],
  "origin": "GRU",
  "budget_brl": 5000,
  "flexible_dates": true,
  "months": ["junho", "julho", "outubro"],
  "adults": 1
}
```

Se o arquivo não existir, pergunte ao Victor quais destinos e orçamento quer monitorar e crie o arquivo.

## Tools Disponíveis

### `tavily-search` (via skill embutida)
Pesquisa preços atuais em sites de viagem.
- Query: `"passagem aérea GRU para {destino} {mês} 2026 preço miles pontos"`
- Inclua comparação de milhas (Smiles, Livelo, TudoAzul) quando disponível

### `google-tasks` (via skill google-tasks)
Cria task quando encontrar deal abaixo do orçamento:
- Título: `✈️ DEAL: GRU → {destino} R$ {valor} — válido até {data}`
- Urgência: `ACAO_NECESSARIA`

## Critério de Deal

Alertar via `google-tasks` quando:
1. Preço encontrado ≤ 80% do `budget_brl` configurado, OU
2. Disponibilidade de voo em milhas com menos de 30.000 pontos (Smiles/Latam)

## Formato do Alerta

```
✈️ DEAL ENCONTRADO
{Origem} → {Destino}
Preço: R$ {valor} ({economia}% abaixo do orçamento)
Datas: {data_ida} - {data_volta}
Source: {link}
```

---

## Pré-condição de Runtime

Esta skill depende de `tavily-search` (busca de hospedagem/reviews) e `flight-search` (passagens).

Se `tavily-search` não estiver disponível (TAVILY_API_KEY ausente), responder ao Victor:

> "A skill de viagem requer que o Tavily Search esteja ativo. Verifique se TAVILY_API_KEY está configurada no `.env` e no container `openclaw`."

Não tentar executar busca sem as skills de busca ativas — retornar mensagem justificada em vez de erro silencioso.

---

## Handler `/monitorar`

**Formato**: `/monitorar <destino> <datas> <orçamento>`

**Exemplo**: `/monitorar Orlando 01/06-15/06 5000`

```
1. Parsear: destino(s), datas (inicio/fim), orçamento por pessoa, viajantes (default: 4)
2. Criar entrada em travel-params.json:
   {
     "id": "orlando-jun2026-<hash3>",
     "active": true,
     "destinations": ["Orlando"],
     "travel_dates": {"start": "2026-06-01", "end": "2026-06-15"},
     "travelers": {"adults": 2, "children": 2, "total": 4},
     "budget": {"max_per_person": 5000, "currency": "BRL"},
     "created_at": "<now>",
     "deals_found": []
   }
3. Confirmar via Telegram:
   "✅ Monitorando Orlando (01-15 jun) para 4 viajantes, orçamento R$5.000/pessoa
   🔍 Busca automática diária às 7h. Alerta se deal encontrado!"
```

---

## Detecção de Deals (cron `0 7 * * *`)

Para cada busca com `active: true` em `travel-params.json`:

```
1. Executar busca em paralelo:
   - flight-search: passagens para o destino/datas
   - tavily-search: "cheap flights {destino} {mês} 2026"
2. Filtrar por orçamento: price_per_person <= budget.max_per_person = DEAL ✅
3. Se nenhum deal: log silencioso — sem alerta
4. Se 1 deal: alerta simples (airline, preço, conexões, link)
5. Se ≥2 deals: tabela Markdown comparativa
6. Criar task no google-tasks:
   - title: "✈️ Analisar deal: {destino} R${price}/pessoa"
   - due_date: hoje+2 (válido 48h)
   - urgency: URGENTE
```

**Ferramentas por subtarefa**:
- Passagens aéreas → `flight-search`
- Hospedagem e reviews → `tavily-search`
- Criação de task lembrete → `google-tasks`
