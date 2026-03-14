---
name: airbnb
description: "Pesquisa acomodações no Airbnb via MCP (mcp-airbnb). Use quando Victor pedir hospedagem, apartamentos ou casas para alugar por temporada. Retorna listagens com preços, avaliações e link direto."
metadata:
  openclaw:
    emoji: "🏠"
    requires:
      skills: ["mcp-airbnb"]
---

# airbnb Skill

Pesquisa de acomodações via **MCP `mcp-airbnb`** (`@openbnb/mcp-server-airbnb`). Acessa dados públicos do Airbnb de forma estruturada, respeitando a política de robots.txt.

> Esta skill complementa `flight-search`: busca hospedagem enquanto flight-search cuida de passagens.

## Quando Usar

- Victor pede opções de hospedagem em uma cidade
- Planejamento de viagem com datas de check-in/check-out definidas
- Verificar detalhes de uma listagem específica (fotos, comodidades, avaliações)
- Combinação com `flight-search` para orçamento completo de viagem

## Quando NÃO Usar

- Reserva direta → redirecionar para o link do Airbnb
- Hotéis ou pousadas não listados no Airbnb → usar `tavily-search`
- Voos → usar `flight-search`

## Como Usar: airbnb_search

```
Tool: airbnb_search
Parameters:
  location:  string    # Ex: "Orlando, FL", "Lisboa, Portugal"
  checkin:   string    # YYYY-MM-DD
  checkout:  string    # YYYY-MM-DD
  adults:    integer   # número de adultos
  minPrice:  integer   # preço mínimo USD/noite (opcional)
  maxPrice:  integer   # preço máximo USD/noite (opcional)
  cursor:    string    # paginação (opcional)
```

**Exemplo de uso:**
```
airbnb_search(
  location="Orlando, FL, USA",
  checkin="2026-07-01",
  checkout="2026-07-15",
  adults=4,
  maxPrice=250
)
```

## Como Usar: airbnb_listing_details

```
Tool: airbnb_listing_details
Parameters:
  id: string   # ID da listagem (obtido via airbnb_search)
```

Use esta ferramenta para obter:
- Comodidades detalhadas (piscina, cozinha equipada, Wi-Fi etc.)
- Avaliações e comentários de hóspedes
- Políticas de cancelamento
- Fotos adicionais

## Formato de Resposta

Para cada listagem retornada por `airbnb_search`, apresentar:

```
🏠 [Nome da propriedade]
   📍 [Endereço/bairro]
   💰 R$ [preço/noite] (~USD X/noite) · [total para N noites]
   ⭐ [Avaliação] ([N] avaliações)
   👥 Até [X] hóspedes · [N] quartos · [N] banheiros
   🔗 https://www.airbnb.com/rooms/[id]
```

**Mostrar no máximo 5 listagens** na resposta padrão. Se Victor pedir mais, usar paginação.

## Política de Robots.txt

O MCP `mcp-airbnb` respeita o `robots.txt` do Airbnb por padrão (sem flag `--ignore-robots-txt`).
- ✅ Listagens públicas → permitido
- ✅ Resultados de busca públicos → permitido
- ❌ Dados privados de reservas → fora de escopo

## Fluxo Combinado: Viagem Completa

Quando Victor pedir planejamento de viagem completo:

1. `flight-search` → cotação de passagens (verificar cota SerpAPI primeiro)
2. `airbnb_search` → opções de hospedagem com datas correspondentes
3. Apresentar resumo com custo total estimado (voos + hospedagem)
4. Links diretos para cada reserva

## Tratamento de Erros

- **MCP instável**: Se `mcp-airbnb` não responder, informar Victor e sugerir acesso direto ao `airbnb.com`
- **Sem resultados**: Ampliar datas ou remover filtro de preço
- **Moeda**: Airbnb retorna USD por padrão; converter para BRL usando taxa atual se solicitado
