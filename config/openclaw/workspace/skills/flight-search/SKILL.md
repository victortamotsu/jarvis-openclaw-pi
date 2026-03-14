---
name: flight-search
description: "Pesquisa passagens aéreas via SerpAPI Google Flights (dados estruturados). Use quando Victor pedir cotação de voos, passagens, comparar preços ou monitorar deals. Retorna preço, companhia, horários, duração, escalas e link direto."
metadata:
  openclaw:
    emoji: "✈️"
    requires:
      bins: ["curl", "python3"]
      env: ["SERP_API_KEY"]
---

# flight-search Skill

Pesquisa de passagens aéreas via **SerpAPI `engine=google_flights`** — dados estruturados com preços, horários, escalas e link direto ao Google Flights.

## Quando Usar

- Victor pede cotação de voos, passagens aéreas ou comparação de preços
- Monitoramento de deals (cron 07:00)

## Quando NÃO Usar

- Reserva/compra direta → redirecionar para o link do Google Flights retornado
- Hospedagem → usar `airbnb` skill

## Aeroportos Padrão do Victor

| Origem padrão | `GRU` | Guarulhos, São Paulo |
|---------------|-------|----------------------|
| Moeda | `BRL` | Real brasileiro |
| Adultos padrão | `1` | Ajustar conforme pedido |

## Comandos

**REGRA**: Execute o script abaixo EXATAMENTE como está. Substitua apenas as variáveis no topo (ORIGIN, DEST, DATE_OUT, DATE_RET, ADULTS). NÃO reescreva o bloco Python.

### Busca Ida e Volta

```bash
ORIGIN="GRU"
DEST="FCO"
DATE_OUT="2026-09-05"
DATE_RET="2026-09-20"
ADULTS=1

RESPONSE=$(curl -fsS "https://serpapi.com/search.json?engine=google_flights&departure_id=${ORIGIN}&arrival_id=${DEST}&outbound_date=${DATE_OUT}&return_date=${DATE_RET}&adults=${ADULTS}&currency=BRL&hl=pt&type=1&api_key=${SERP_API_KEY}") && echo "$RESPONSE" | python3 - << 'PYEOF'
import json, sys
from datetime import datetime, timezone

data = json.load(sys.stdin)
err = data.get("error")
if err:
    print(f"❌ SerpAPI erro: {err}")
    sys.exit(1)

flights = data.get("best_flights", []) + data.get("other_flights", [])
link = data.get("search_metadata", {}).get("google_flights_url", "https://www.google.com/flights")

f = "/mnt/external/openclaw/memory/serp-usage.json"
try:
    with open(f) as fp:
        usage = json.load(fp)
    cm = datetime.now().strftime("%Y-%m")
    if usage.get("month", "") != cm:
        usage.update({"month": cm, "calls_used": 0, "alert_80_sent": False, "blocked": False, "last_call": None})
    cached = data.get("search_metadata", {}).get("cached", False)
    if not cached:
        usage["calls_used"] = usage.get("calls_used", 0) + 1
        usage["last_call"] = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    with open(f, "w") as fp:
        json.dump(usage, fp, indent=2)
    used = usage["calls_used"]
    limit = usage.get("calls_limit", 250)
except Exception:
    used, limit = "?", 250

if not flights:
    print("❌ Nenhum voo encontrado. Tente outras datas ou verifique os códigos IATA.")
    sys.exit(0)

print(f"✈️  Voos encontrados ({used}/{limit} créditos SerpAPI usados este mês)\n")
for i, opt in enumerate(flights[:3], 1):
    legs = opt.get("flights", [])
    if not legs:
        continue
    first, last = legs[0], legs[-1]
    airline = first.get("airline", "?")
    dep_iata = first.get("departure_airport", {}).get("id", "?")
    dep_time = (first.get("departure_airport", {}).get("time") or "")[-5:]
    arr_iata = last.get("arrival_airport", {}).get("id", "?")
    arr_time_raw = last.get("arrival_airport", {}).get("time") or ""
    arr_time = arr_time_raw[-5:]
    overnight = "+1" if arr_time_raw[:10] > (first.get("departure_airport", {}).get("time") or "")[:10] else ""
    total_min = opt.get("total_duration", 0)
    duration = f"{total_min // 60}h{total_min % 60:02d}" if total_min else "?"
    stops = len(opt.get("layovers", []))
    stop_label = "direto" if stops == 0 else f"{stops} escala(s)"
    price = opt.get("price", 0)
    adults_n = int(data.get("search_parameters", {}).get("adults", 1))
    total = price * adults_n
    print(f"✈️  Opção {i} — {airline}")
    print(f"   {dep_iata} {dep_time} → {arr_iata} {arr_time}{overnight} | {duration} | {stop_label}")
    print(f"   💰 R$ {price:,.0f}/pessoa | R$ {total:,.0f} total ({adults_n} adulto(s))")
    print(f"   🔗 {link}\n")
PYEOF
```

### Busca Só-Ida

```bash
ORIGIN="GRU"
DEST="FCO"
DATE_OUT="2026-09-05"
ADULTS=1

RESPONSE=$(curl -fsS "https://serpapi.com/search.json?engine=google_flights&departure_id=${ORIGIN}&arrival_id=${DEST}&outbound_date=${DATE_OUT}&adults=${ADULTS}&currency=BRL&hl=pt&type=2&api_key=${SERP_API_KEY}") && echo "$RESPONSE" | python3 - << 'PYEOF'
import json, sys
data = json.load(sys.stdin)
err = data.get("error")
if err:
    print(f"❌ SerpAPI erro: {err}"); sys.exit(1)
flights = data.get("best_flights", []) + data.get("other_flights", [])
link = data.get("search_metadata", {}).get("google_flights_url", "https://www.google.com/flights")
for i, opt in enumerate(flights[:3], 1):
    legs = opt.get("flights", [])
    if not legs: continue
    first, last = legs[0], legs[-1]
    total_min = opt.get("total_duration", 0)
    duration = f"{total_min // 60}h{total_min % 60:02d}" if total_min else "?"
    stops = len(opt.get("layovers", []))
    print(f"✈️  Opção {i} — {first.get('airline','?')}")
    print(f"   {first['departure_airport']['id']} → {last['arrival_airport']['id']} | {duration} | {'direto' if stops==0 else str(stops)+' escala(s)'}")
    print(f"   💰 R$ {opt.get('price',0):,.0f}\n   🔗 {link}\n")
PYEOF
```

## Resposta Esperada (exemplo)

```
✈️  Voos encontrados (2/250 créditos SerpAPI usados este mês)

✈️  Opção 1 — LATAM Airlines
   GRU 23:20 → FCO 14:35+1 | 13h15 | 1 escala(s)
   💰 R$ 4.820/pessoa | R$ 4.820 total (1 adulto(s))
   🔗 https://www.google.com/flights?...
```

## Códigos IATA Comuns

| Cidade | Código |
|--------|--------|
| São Paulo (Guarulhos) | GRU |
| Roma | FCO |
| Paris | CDG |
| Lisboa | LIS |
| Milão | MXP |
| Madrid | MAD |
| Miami | MIA |
| Orlando | MCO |
| Nova York | JFK |
| Tokyo | NRT |

## Notas de Segurança

- Nunca exibir `SERP_API_KEY` na saída
- Cota: 250 buscas/mês gratuitas — o script registra o consumo automaticamente em `/mnt/external/openclaw/memory/serp-usage.json`
