---
name: flight-search
description: "Pesquisa passagens aéreas via SerpAPI Google Flights (dados estruturados). Use quando Victor pedir cotação de voos, passagens, comparar preços ou monitorar deals. Retorna 8 campos obrigatórios por opção."
metadata:
  openclaw:
    emoji: "✈️"
    requires:
      bins: ["curl", "python3"]
      env: ["SERP_API_KEY"]
---

# flight-search Skill

Pesquisa de passagens aéreas via **SerpAPI `engine=google_flights`** — retorna dados estruturados JSON com preços, horários, escalas e link direto ao Google Flights.

> Substituiu Tavily flight search (2026-03-08): Tavily retornava links genéricos sem dados estruturados.

## Quando Usar

- Victor pede cotação de voos (origem/destino/data)
- Monitoramento diário de deals (cron 07:00)
- Comparação de companhias aéreas

## Quando NÃO Usar

- Reserva/compra direta → redirecionar para `search_metadata.google_flights_url`
- Cota SerpAPI esgotada (`blocked=true` em `serp-usage.json`) → retornar mensagem de erro

## Pré-condição: Verificar Cota SerpAPI

**SEMPRE** verificar `serp-usage.json` ANTES de qualquer chamada HTTP:

```bash
USAGE_FILE="/mnt/external/openclaw/memory/serp-usage.json"
CURRENT_MONTH=$(date +%Y-%m)

# Verificar / resetar cota e checar bloqueio (python3 — sem jq)
QUOTA_STATUS=$(python3 - << 'PYEOF'
import json, sys
from datetime import datetime
f = "/mnt/external/openclaw/memory/serp-usage.json"
try:
    with open(f) as fp:
        d = json.load(fp)
except Exception:
    d = {"month": "", "calls_used": 0, "calls_limit": 250, "alert_80_sent": False, "blocked": False, "last_call": None}
cm = datetime.now().strftime("%Y-%m")
if d.get("month", "") != cm:
    d.update({"month": cm, "calls_used": 0, "alert_80_sent": False, "blocked": False, "last_call": None})
    with open(f, "w") as fp:
        json.dump(d, fp, indent=2)
used = int(d.get("calls_used", 0))
limit = int(d.get("calls_limit", 250))
if d.get("blocked", False) or used >= limit:
    print(f"BLOCKED:{used}")
else:
    print(f"OK:{used}")
PYEOF
)

if echo "$QUOTA_STATUS" | grep -q "^BLOCKED"; then
  CALLS_USED=$(echo "$QUOTA_STATUS" | cut -d: -f2)
  NEXT_MONTH=$(python3 -c "import datetime; d=datetime.date.today(); nm=datetime.date(d.year+(1 if d.month==12 else 0),d.month%12+1,1); print(nm.strftime('%B %Y'))" 2>/dev/null || echo "próximo mês")
  echo "⛔ Cota SerpAPI esgotada (${CALLS_USED}/250). Buscas de voo desativadas até 1º de ${NEXT_MONTH}."
  exit 1
fi
```

## Busca de Voos (SerpAPI Google Flights)

```bash
# Parâmetros obrigatórios
ORIGIN="GRU"        # IATA do aeroporto de origem
DEST="MCO"          # IATA do aeroporto de destino
DATE_OUT="2026-07-01"  # YYYY-MM-DD
DATE_RET="2026-07-15"  # YYYY-MM-DD (omitir para só-ida, type=2)
ADULTS=4
CURRENCY="BRL"

# Chamada SerpAPI Google Flights
RESPONSE=$(curl -fsS \
  "https://serpapi.com/search.json?engine=google_flights\
&departure_id=${ORIGIN}\
&arrival_id=${DEST}\
&outbound_date=${DATE_OUT}\
&return_date=${DATE_RET}\
&adults=${ADULTS}\
&currency=${CURRENCY}\
&hl=pt\
&type=1\
&api_key=${SERP_API_KEY}" 2>&1)

if [ $? -ne 0 ]; then
  echo "✗ Erro ao consultar SerpAPI. Verifique SERP_API_KEY."
  exit 1
fi
```

## Formato Obrigatório de Resposta (8 campos — AC Skill 3)

Extrair e formatar para cada opção em `best_flights[]`:

```bash
# Incrementar cota somente se não é cached
CACHED=$(echo "$RESPONSE" | python3 -c "import json,sys; d=json.load(sys.stdin); print(str(d.get('search_metadata',{}).get('cached',False)).lower())" 2>/dev/null || echo "false")
if [ "$CACHED" = "false" ]; then
  python3 - << 'PYEOF'
import json, sys
from datetime import datetime
f = "/mnt/external/openclaw/memory/serp-usage.json"
with open(f) as fp:
    d = json.load(fp)
d["calls_used"] = d.get("calls_used", 0) + 1
d["last_call"] = datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%SZ")
with open(f, "w") as fp:
    json.dump(d, fp, indent=2)
print(f"[serp-quota] Incrementado: {d['calls_used']}/{d.get('calls_limit', 250)}", file=sys.stderr)
PYEOF
fi

# Parsear e formatar resultado
echo "$RESPONSE" | python3 - << 'EOF'
import json, sys, re

data = json.loads(sys.stdin.read())
flights = data.get("best_flights", []) + data.get("other_flights", [])
link = data.get("search_metadata", {}).get("google_flights_url", "")

if not flights:
    print("❌ Nenhum voo encontrado para os parâmetros informados.")
    sys.exit(0)

for i, opt in enumerate(flights[:3], 1):
    legs = opt.get("flights", [])
    if not legs:
        continue

    first = legs[0]
    last = legs[-1]
    airline = first.get("airline", "?")
    flight_num = first.get("flight_number", "")
    dep_iata = first.get("departure_airport", {}).get("id", "?")
    dep_time = first.get("departure_airport", {}).get("time", "?")[-5:]  # HH:MM
    arr_iata = last.get("arrival_airport", {}).get("id", "?")
    arr_time = last.get("arrival_airport", {}).get("time", "?")

    # Calcular +d (pernoite)
    dep_date = first.get("departure_airport", {}).get("time", "")[:10]
    arr_date = last.get("arrival_airport", {}).get("time", "")[:10]
    overnight = f"+{(len(arr_date) and len(dep_date) and (arr_date > dep_date) and 1 or 0)}" if arr_date > dep_date else ""
    arr_time_fmt = arr_time[-5:] + overnight

    total_min = opt.get("total_duration", 0)
    duration = f"{total_min // 60}h{total_min % 60:02d}" if total_min else "?"
    stops = len(opt.get("layovers", []))
    stop_label = "direto" if stops == 0 else f"{stops} escala(s)"
    price_pp = opt.get("price", 0)
    adults = int(data.get("search_parameters", {}).get("adults", 1))
    total = price_pp * adults

    print(f"\n✈️  Opção {i}: {airline} {flight_num}")
    print(f"   {dep_iata} {dep_time} → {arr_iata} {arr_time_fmt} | {duration} | {stop_label}")
    print(f"   💰 R$ {price_pp:,.0f}/pessoa | R$ {total:,.0f} total ({adults} adultos)")
    print(f"   🔗 {link}")
EOF
```

## Regras de Comportamento

1. **Cota primeiro**: Verificar `serp-usage.json` antes de qualquer chamada HTTP — sem exceções
2. **Cached = grátis**: Se `search_metadata.cached=true`, não incrementar `calls_used`
3. **Máximo 3 opções**: Retornar `best_flights[0..2]` — não sobrecarregar a resposta
4. **Link obrigatório**: Sempre incluir `search_metadata.google_flights_url`
5. **Fallback**: Se SerpAPI indisponível (HTTP 5xx), informar Victor e sugerir acesso manual ao Google Flights
6. **Booking.com**: Fora de escopo — não pesquisar hospedagem nesta skill (usar airbnb skill)
```

### Alerta de Promoção (uso pelo scheduler)

```bash
BUDGET_BRL=5000
ORIGIN="GRU"
DEST="Lisboa"

curl -s -X POST https://api.tavily.com/search \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${TAVILY_API_KEY}" \
  -d "{\"query\": \"passagem ${ORIGIN} ${DEST} abaixo R$ ${BUDGET_BRL} promoção hoje\", \"search_depth\": \"basic\", \"max_results\": 5, \"include_answer\": true}" \
  | python3 -c "import json,sys; d=json.load(sys.stdin); ans=d.get('answer',''); results=d.get('results',[]); print('RESUMO: '+ans); [print(str(n+1)+'. '+r.get('title','')+' — '+r.get('url','')) for n,r in enumerate(results[:5])]"
```

## Parâmetros de Viagem do Victor

Os parâmetros salvos estão em:
```
/home/node/.openclaw/workspace/memory/travel-params.json
```

Sempre verificar esses parâmetros antes de apresentar resultados ao usuário.

## Limitações

- Os preços retornados são estimativas extraídas de texto web — podem desatualizar rapidamente
- Para preços exatos, direcionar o Victor ao link do site de compra
- Datas de voo precisam ser especificadas pelo Victor (não inferir)

## Notas de Segurança

- Nunca exibir `TAVILY_API_KEY` na saída
