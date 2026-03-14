---
name: firefly-finance
description: Gerencie as finanças pessoais do Victor via Firefly III — consultar transações, criar lançamentos, relatórios de gastos por categoria e conta.
metadata:
  openclaw:
    requires:
      env:
        - FIREFLY_TOKEN
        - FIREFLY_URL
---

# firefly-finance Skill

Use esta skill para consultar e registrar informações financeiras pessoais do Victor armazenadas no Firefly III.

## Quando Usar

- Usuário pergunta sobre gastos, saldo ou transações
- Usuário quer registrar uma despesa ou receita
- Pipeline importa extrato bancário via PDF
- Usuário pede relatório mensal de gastos

## ⚠️ Regras de Privacidade (OBRIGATÓRIAS — Art. III)

**ANTES de enviar qualquer dado ao modelo de IA (GitHub Copilot):**
1. Substitua valores exatos por faixas (`R$ 1.200` → `valor alto`)
2. Substitua nomes de estabelecimentos por categoria (`Mercado Extra` → `supermercado`)
3. Nunca inclua número de conta, agência, CPF, ou token de acesso em prompts
4. Registre no log qual dado foi anonimizado e por quê

## Tools Disponíveis (via mcporter MCP)

### `get_transactions`
Busca transações com filtros.
- `start_date` (obrigatório): Data início (YYYY-MM-DD)
- `end_date` (obrigatório): Data fim (YYYY-MM-DD)
- `category` (opcional): Filtrar por categoria (ex: `Alimentação`)
- `account_id` (opcional): ID da conta Firefly III

### `create_transaction`
Cria uma nova transação.
- `amount` (obrigatório): Valor (número positivo)
- `description` (obrigatório): Descrição curta
- `date` (obrigatório): Data (YYYY-MM-DD)
- `type` (obrigatório): `withdrawal` (despesa), `deposit` (receita), `transfer`
- `category_name` (opcional): Nome da categoria

### `get_categories`
Lista todas as categorias de despesas configuradas.

### `get_expense_report`
Gera relatório resumido de gastos.
- `month` (obrigatório): Mês no formato `YYYY-MM`
- `group_by` (opcional): `category` ou `account`

## Endpoint mcporter

O mcporter está disponível em `http://mcporter-firefly:3000` (rede Docker `jarvis`).

---

## Handler `/importar`

**Trigger**: Victor envia `/importar` via Telegram

```
1. Confirmar: "Procurando arquivo de importação..."
2. Buscar arquivo mais recente em Google Drive "Jarvis/imports/" (.csv, .pdf, .zip)
3. Executar: bash scripts/import-statement.sh <csv> <pdf>
4. Reportar via Telegram:
   ✅ X transações importadas
   Titulares: MEMBER_A (N), MEMBER_B (M)
   Período: YYYY-MM-DD a YYYY-MM-DD | Duplicatas: N | Erros: 0
5. Criar task "Verificar importação" due_date=hoje+1, urgency=ACAO_NECESSARIA
6. Em caso de erro → alerta CRITICO com motivo específico
```

---

## Aprendizado de Titulares

**Trigger**: transação com titular ambíguo durante import

```
1. "Amazon R$250" sem titular claro → enviar Telegram: "🤔 Quem pagou Amazon R$250?"
2. Victor responde com nome/número
3. Salvar em /mnt/external/openclaw/memory/owner-rules.json: {"AMAZON": "MEMBER_A"}
4. Confirmar: "✓ Amazon → Victor. Próximas vezes automático!"
```

Nas importações futuras: lookup por prefixo em `owner-rules.json` (confiança > 0.7) → automático.

---

## Alertas de Cota de Gastos

**Config**: `/mnt/external/openclaw/memory/quota-rules.json`

Após cada transação importada, recalcular `spent / monthly_limit`:
- **80–99%**: alerta `URGENTE` — "⚠️ Cota [MEMBER_A] em 85% (R$2.125/R$2.500)"
- **≥100%**: alerta `CRITICO` — "🚨 Cota estourada [MEMBER_A] (R$2.600/R$2.500)"

Auto-reset: no dia `reset_date` do JSON, zerar `current_spent`.

---

## Análise de Investimentos

**Trigger**: mensagem com "CDB", "Tesouro", "LCI", "LCA", "fundo", "aplicação", "investimento"

```
1. tavily-search: taxas CDB, Tesouro SELIC, LCI/LCA atuais
2. Montar tabela: Produto | Taxa | Liquidez | Risco
3. Enviar via Telegram com disclaimer obrigatório
```

⚠️ **NUNCA** revelar valores ou saldos de investimentos do Victor. Apenas taxas e dados públicos.

Disclaimer obrigatório: "⚠️ Dados públicos apenas. Consulte um advisor para decisão pessoal."

---

## Relatório Mensal (cron `0 9 5 * *`)

Dia 5 de cada mês às 9h:
1. `GET /transactions` no Firefly — mês anterior completo
2. Acumular por categoria e por membro (dados anonimizados para Copilot)
3. Gerar Markdown e carregar em Google Drive: `Jarvis/relatorios/YYYY-MM-gastos.md`
4. Enviar resumo + link Drive via Telegram
5. `create_task`: "Exportar faturas do próximo mês", due=dia 1 próximo mês, category=FINANCEIRO, urgency=INFORMATIVO
