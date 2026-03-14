---
name: tavily-search
description: "Realiza buscas na web usando a API Tavily para obter resultados precisos e atualizados. Use quando o Victor pedir pesquisa de notícias, cotações, eventos, informações atuais ou qualquer consulta que exija dados em tempo real da internet."
metadata:
  openclaw:
    emoji: "🔍"
    requires:
      bins: ["curl", "python3"]
      env: ["TAVILY_API_KEY"]
---

# tavily-search Skill

Busca na web em tempo real via API Tavily. Retorna resultados com título, URL, conteúdo extraído e score de relevância.

## Quando Usar

- Victor pede informações atuais (cotações, notícias, eventos)
- Qualquer pergunta que exija dados mais recentes que o treinamento do modelo
- Pesquisas de preços, produtos, lugares, pessoas
- Verificação de fatos com fontes na web

## Quando NÃO Usar

- Perguntas que o modelo já sabe responder com certeza (matemática, conceitos)
- Pesquisa de passagens aéreas → use `flight-search`

## Comandos

**REGRA**: Copie os comandos EXATAMENTE como estão. NÃO reescreva o script Python.

### Busca Básica (padrão para maioria das consultas)

Substitua apenas `QUERY_AQUI` pela consulta desejada:

```bash
curl -s -X POST https://api.tavily.com/search \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${TAVILY_API_KEY}" \
  -d "{\"query\": \"QUERY_AQUI\", \"search_depth\": \"basic\", \"max_results\": 5, \"include_answer\": true}" \
  | python3 -c "import json,sys; d=json.load(sys.stdin); ans=d.get('answer',''); results=d.get('results',[]); print('RESPOSTA: '+ans); [print(str(n+1)+'. '+r.get('title','')+chr(10)+'   URL: '+r.get('url','')+chr(10)+'   '+r.get('content','')[:300]+chr(10)) for n,r in enumerate(results[:5])]"
```

### Busca Avançada

```bash
curl -s -X POST https://api.tavily.com/search \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${TAVILY_API_KEY}" \
  -d "{\"query\": \"QUERY_AQUI\", \"search_depth\": \"advanced\", \"max_results\": 8, \"include_answer\": true}" \
  | python3 -c "import json,sys; d=json.load(sys.stdin); ans=d.get('answer',''); results=d.get('results',[]); print('RESPOSTA: '+ans); [print(str(n+1)+'. '+r.get('title','')+chr(10)+'   URL: '+r.get('url','')+chr(10)+'   '+r.get('content','')[:400]+chr(10)) for n,r in enumerate(results[:8])]"
```

### Busca em Domínios Específicos

```bash
curl -s -X POST https://api.tavily.com/search \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${TAVILY_API_KEY}" \
  -d "{\"query\": \"QUERY_AQUI\", \"search_depth\": \"basic\", \"include_domains\": [\"bcb.gov.br\", \"g1.globo.com\", \"uol.com.br\"], \"max_results\": 5, \"include_answer\": true}" \
  | python3 -c "import json,sys; d=json.load(sys.stdin); ans=d.get('answer',''); results=d.get('results',[]); print('RESPOSTA: '+ans); [print(str(n+1)+'. '+r.get('title','')+chr(10)+'   URL: '+r.get('url','')+chr(10)+'   '+r.get('content','')[:300]+chr(10)) for n,r in enumerate(results[:5])]"
```

## Formato da Resposta

A API retorna JSON com:
- `answer` — resposta direta extraída pela IA (quando `include_answer: true`)
- `results[]` — lista com `title`, `url`, `content`, `score`

## Parâmetros da API

| Parâmetro | Valores | Descrição |
|-----------|---------|-----------|
| `search_depth` | `basic`, `advanced` | `basic` = rápido; `advanced` = mais completo |
| `max_results` | 1-20 | Número de resultados (padrão: 5) |
| `include_answer` | true/false | Resposta AI direta |
| `include_domains` | ["site.com"] | Restringe a domínios |
| `exclude_domains` | ["site.com"] | Exclui domínios |

## Notas de Segurança

- Nunca exiba o valor de `TAVILY_API_KEY` na saída
