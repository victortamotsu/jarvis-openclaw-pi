---
name: code-agent
description: Agente programador do Victor — pesquisar soluções técnicas, criar repositórios GitHub com spec-kit, prototipar projetos a partir de ideias recebidas via Telegram.
metadata:
  openclaw:
    requires:
      bins:
        - gh
        - git
        - node
      env:
        - GITHUB_TOKEN
---

# code-agent Skill

Use esta skill quando Victor enviar uma ideia de projeto ou pedir ajuda com programação.

## Quando Usar

- Victor envia mensagem com `/ideia` ou descreve um projeto para criar
- Victor pede `/criarrepo` com nome e descrição
- Victor faz pergunta técnica de programação
- Victor pede para pesquisar uma solução técnica

## Comandos Suportados

### `/ideia {descrição}`
Analisa uma ideia de projeto e cria um spec inicial:
1. Pesquisa via `tavily-search` se já existe solução similar open-source
2. Gera um spec resumido (problema, solução proposta, tech stack sugerido)
3. **PEDE CONFIRMAÇÃO antes de criar o repo**: "Quer que eu crie o repositório `{nome}` no GitHub? (sim/não)"
4. Se confirmado: executa `/criarrepo`

### `/criarrepo {nome} {descrição}`
Cria um repositório GitHub:
1. Executa: `gh repo create {nome} --private --description "{descrição}"` 
2. Clona localmente em `/tmp/{nome}`
3. Inicializa spec-kit se disponível
4. Cria task no Google Tasks: `📦 Novo projeto: {nome}` com link do repo
5. Reporta link do repo via Telegram

### Perguntas técnicas
Responda diretamente usando o modelo (github-copilot/gpt-4o).
Para pesquisas de biblioteca ou framework, use `tavily-search` primeiro.

## Regras de Segurança (Art. VI)

1. **SEMPRE** pedir confirmação antes de criar repositório
2. **NUNCA** fazer push de código com credenciais em texto puro
3. **NUNCA** criar repositório público sem confirmação explícita
4. Repositórios criados são **privados por padrão**

## Exemplo de Fluxo

```
Victor: /ideia app de controle de gastos com voz
Jarvis: Pesquisando... [busca tavily]
        Encontrei 3 projetos similares: voice-expense-tracker, VoiceMoney, SpendVoice.
        Sugestão: React Native + Whisper API + Firefly III.
        Quer que eu crie o repositório `voice-expense-tracker-pi`? (sim/não)
Victor: sim
Jarvis: ✅ Repo criado: github.com/victor/voice-expense-tracker-pi
        Task adicionada: 📦 Novo projeto: voice-expense-tracker-pi
```
