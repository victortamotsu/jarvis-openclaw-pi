# OpenClaw no Raspberry Pi - Pesquisa

## 1. Repositório Git Inicializado ✅

```bash
Initialized empty Git repository in C:/Users/victo/Projetos/estudos/.git/
```

---

## 2. Docker OpenClaw no Raspberry Pi

### Resumo
**SIM**, é possível instalar OpenClaw em um container Docker do Raspberry Pi, com poucas contraindicações.

### Requisitos Docker
- **Docker Desktop** ou **Docker Engine** + **Docker Compose v2**
- **Mínimo 2 GB de RAM** para build da imagem (1 GB pode causar OOM com saída 137)
- Espaço em disco suficiente para imagens + logs

### Considerações para Raspberry Pi

#### ✅ Compatíveis:
1. **Arquitetura suportada**: Raspberry Pi roda em ARM, e Docker está disponível para ARM
2. **Instalação via Docker Compose**: O script `docker-setup.sh` funciona normalmente
3. **Low-resource friendly**: Opções de otimização disponíveis:
   - Reduzir cache de browsers: `PLAYWRIGHT_BROWSERS_PATH` configurável
   - Limitar recursos: memória, CPU, I/O em `docker-compose.yml`
   - Usar imagem base leve: `bookworm-slim` (padrão)

#### ⚠️ Contraindicações/Limitações:

1. **Recursos limitados**: 
   - Raspberry Pi 4 com 2-4 GB é limite mínimo
   - Raspberry Pi 5 recomendado para melhor performance
   - Compilação de imagem é lenta em ARM

2. **Browser (Playwright)**:
   - Por padrão, não instala Chromium (usa base não-root)
   - Para ativar browser, precisa:
     ```bash
     export OPENCLAW_DOCKER_APT_PACKAGES="chromium-browser"
     ./docker-setup.sh
     ```
   - Consumo de memória é alto para Chromium

3. **Permissões**:
   - Imagem roda como usuário `node` (UID 1000)
   - Certifique-se de que diretórios montados têm permissões corretas:
     ```bash
     sudo chown -R 1000:1000 ~/.openclaw
     ```

### Quick Start Docker no Raspberry Pi

```bash
# 1. Clonar ou preparar o repositório
cd /path/to/openclaw

# 2. Executar setup (com otimizações para Pi)
export OPENCLAW_HOME_VOLUME="openclaw_home"  # Persiste /home/node
export OPENCLAW_DOCKER_APT_PACKAGES="git curl"  # Apenas ferramentas essenciais
./docker-setup.sh

# 3. Aguardar build (pode demorar bastante em Pi)
# Monitorar com: docker build progress

# 4. Acessar Gateway
# Abrir http://127.0.0.1:18789/ e colar o token gerado
```

---

## 3. Gateway do OpenClaw

### O que é o Gateway?

O **Gateway** é o **control plane central** do OpenClaw - um serviço único que:
- ✅ Gerencia todas as conexões (WhatsApp, Telegram, Slack, Discord, Signal, iMessage, etc.)
- ✅ Executa o agente IA
- ✅ Coordena com múltiplos dispositivos (nodes)
- ✅ Fornece a API WebSocket única para clients e devices

### Arquitetura de Gateway

```
┌─────────────────────────────────────────────────────────────┐
│             Mensageria Externa (WhatsApp/Telegram/etc)      │
└──────────────────────┬──────────────────────────────────────┘
                       │
                       ▼
        ┌──────────────────────────────────┐
        │    Gateway Daemon (18789)        │
        │  - WebSocket Control Plane       │
        │  - Executa Agent IA              │
        │  - Gerencia Sessions             │
        │  - Coordena Nodes                │
        └──────────┬──────────────────────┘
                   │
        ┌──────────┼──────────┬──────────┐
        │          │          │          │
        ▼          ▼          ▼          ▼
    macOS App   iOS Node   Android    Linux/Node
                            Node        Host


Bind padrão: 127.0.0.1:18789 (loopback)
```

### Como Funciona com Múltiplos Dispositivos

#### Cenário: OpenClaw no Raspberry Pi executando ações no Desktop Windows

**Arquitetura:**
```
Raspberry Pi (Gateway)     ←→    Desktop Windows (Node Host)
             ↓                              ↓
      Gateway WS @18789             Node conectede
      - Gerencia AI                  - Executa system.run
      - Channels (WhatsApp, etc)     - Executa commands
      - Sessions                     - Acesso a desktop local
```

#### Passo a Passo de Configuração:

##### 1️⃣ **Raspberry Pi: Iniciar o Gateway**
```bash
# No Raspberry Pi
openclaw gateway --port 18789 --verbose

# Ou em modo daemon
openclaw gateway install
```

##### 2️⃣ **Desktop Windows: Conectar como Node Host**

O Desktop se conecta ao Gateway do Raspberry Pi como um **Node Host** remoto:

```bash
# No Desktop Windows (em WSL2 recomendado)
# Criar túnel SSH primeiro
ssh -N -L 18790:127.0.0.1:18789 user@raspberry-pi

# Em outro terminal, conectar como node
export OPENCLAW_GATEWAY_TOKEN="<token-do-gateway>"
openclaw node run --host 127.0.0.1 --port 18790 --display-name "Windows Desktop"
```

##### 3️⃣ **Raspberry Pi: Aprovar o Node**
```bash
# No Raspberry Pi
openclaw devices list              # Listar conexões pendentes
openclaw devices approve <requestId>  # Aprovar o Windows

openclaw nodes status              # Ver nodes conectados
openclaw nodes describe --node "Windows Desktop"
```

##### 4️⃣ **Executar Ações no Desktop**

Agora qualquer comando pode ser **roteado para o Desktop Windows**:

```bash
# Executar comando no Desktop (em qualquer machine com acesso ao Gateway)
openclaw nodes run --node "Windows Desktop" -- powershell.exe Get-Process

# Configurar como default para exec
openclaw config set tools.exec.node "Windows Desktop"
openclaw config set tools.exec.host node

# Agora qualquer exec vai pro Windows
openclaw agent --message "Abra o Chrome e navegue para example.com"
```

### Fluxo de Requisição

```
1. Mensagem chega no Telegram → Gateway recebe
2. Gateway executa Agent IA
3. Agent decide chamar "system.run" no Node do Windows
4. Gateway encaminha para o Node via WebSocket (node.invoke)
5. Node executa comando localmente no Windows
6. Resultado retorna ao Gateway
7. Gateway responde no Telegram
```

### Conectividade

#### Opção 1: SSH Tunnel (Recomendado para privacidade)
```bash
# Terminal A (manter aberto):
ssh -N -L 18789:127.0.0.1:18789 user@raspberry-pi

# Terminal B:
openclaw nodes run --host 127.0.0.1 --port 18789 -- whoami
```

#### Opção 2: Tailscale (Mais fácil)
```bash
# No Raspberry Pi
openclaw config set gateway.tailscale.mode serve  # Serve via Tailscale

# No Windows, conectar via Tailnet (automático se em mesma rede Tailscale)
openclaw node run --host raspberry-pi.local --port 18789
```

#### Opção 3: VPN
- Manter Gateway em loopback (mais seguro)
- Conectar via VPN (e.g., WireGuard) como "LAN virtual"

### Segurança

✅ **Padrões de Segurança OpenClaw:**
- Gateway vinculado a `loopback` por padrão (sem acesso público)
- Autenticação obrigatória: token ou senha
- Pairing de dispositivos: novos nodes precisam aprovação
- SSH tunnel recomendado para acesso remoto
- Nenhuma exposição de Internet pública recomendada (use Tailscale Serve/Funnel se precisar)

### Comandos Úteis do Gateway

```bash
# Status e Health
openclaw gateway status
openclaw gateway status --deep
openclaw health

# Pairing
openclaw devices list
openclaw devices approve <requestId>
openclaw nodes status

# Nodes
openclaw nodes describe --node <name>
openclaw nodes run --node <name> -- <command>

# Configuração
openclaw config get gateway
openclaw config set gateway.mode local
```

---

## 4. Casos de Uso Práticos

### Use Case 1: Smart Home Automation
```
Raspberry Pi (no Home)  ←→  IoT Devices
      ↓
   Gateway
      ↓
   Telegram/WhatsApp
      ↓
   User (controla casa via chat)
```

### Use Case 2: Servidor + Desktop Client
```
Raspberry Pi (VPS na Cloud)  ←→  Desktop Windows (Node)
        ↓
    Bot Telegram/Discord
        ↓
    Executa tasks no Desktop quando message chega
```

### Use Case 3: Multi-Local Setup
```
               Tailscale VPN
                    │
    ┌───────────────┼───────────────┐
    │               │               │
Raspberry Pi    Desktop Windows   Mac Mini
(Gateway)       (Node)            (Node)
    ↓               ↓               ↓
  Agent         system.run      system.run
  Channels      (Windows)       (Mac)
```

## 5. Resumo Final - Parte 1 (Docker + Gateway)

| Aspecto | Resposta |
|---------|----------|
| **Docker no Raspberry Pi?** | ✅ Sim, compatível. Mínimo Pi 4 com 2GB RAM |
| **Contraindicações?** | ⚠️ Compilação lenta, limite de memória, browser pesado |
| **O que é Gateway?** | Control plane central que coordena agente, canais e nodes |
| **Raspberry Pi → Desktop Windows?** | ✅ Sim, Desktop conecta como Node remoto via SSH/Tailscale |
| **Como executa ações?** | Node host expõe `system.run` que executa comandos localmente |
| **Segurança?** | ✅ Loopback + SSH tunnel (recomendado) ou Tailscale Serve |

---

## 6. GitHub Copilot como Modelo de IA no OpenClaw

### Resposta: ✅ SIM, É Suportado!

OpenClaw **suporta nativamente** GitHub Copilot como modelo de IA.

### Configuração GitHub Copilot

#### Provider
- **ID**: `github-copilot`
- **Autenticação**: `COPILOT_GITHUB_TOKEN` / `GH_TOKEN` / `GITHUB_TOKEN`

#### Setup Rápido

```bash
# Passo 1: Autenticar com GitHub
# Certifique-se de que você tem um token GitHub com acesso a Copilot
export GITHUB_TOKEN="your-github-token"

# Passo 2: Configurar como modelo padrão
openclaw onboard --auth-choice github  # Se disponível na wizard

# Ou editar a configuração manualmente
```

#### Configuração Manual (`~/.openclaw/openclaw.json`)

```json
{
  "agents": {
    "defaults": {
      "model": {
        "primary": "github-copilot/copilot"
      }
    }
  },
  "env": {
    "GITHUB_TOKEN": "${COPILOT_GITHUB_TOKEN}"
  }
}
```

#### Via CLI

```bash
# Listar modelos disponíveis
openclaw models list

# Definir como modelo padrão
openclaw models set github-copilot/copilot

# Verificar status
openclaw models status
```

### Alternativas: Outros Modelos Suportados

Se GitHub Copilot não atender, OpenClaw suporta **+50 provedores**:

| Provedor | Recomendação | Custo |
|----------|--------------|-------|
| **Anthropic (Claude)** | ⭐⭐⭐ Melhor longo-contexto | Pago |
| **OpenAI (GPT-5.2, Codex)** | ⭐⭐⭐ Bom para coding | Pago |
| **OpenRouter** | ⭐⭐ Múltiplos modelos | Varia |
| **Ollama** | ⭐⭐⭐ Local (Pi-friendly!) | Grátis |
| **Groq** | ⭐⭐⭐ Rápido | Pago |
| **Mistral** | ⭐⭐ Boa relação custo-benefício | Pago |
| **Google Gemini** | ⭐⭐ Bom multimodal | Pago |
| **Cerebras** | ⭐⭐ Rápido | Pago |
| **xAI (Grok)** | ⭐ Novo | Pago |

### Usando Ollama no Raspberry Pi (Alternativa Local)

Se quiser **0 custos** e rodar tudo local:

```bash
# 1. Instalar Ollama
curl https://ollama.ai/install.sh | sh

# 2. Baixar modelo leve
ollama pull llama2:7b  # ~4GB, roda em Pi 4

# 3. Configurar OpenClaw
openclaw models set ollama/llama2
```

Arquivo config:
```json
{
  "agents": {
    "defaults": {
      "model": {
        "primary": "ollama/llama2"
      }
    }
  }
}
```

### Comparação: GitHub Copilot vs Alternativas para Raspberry Pi

| Aspecto | GitHub Copilot | Anthropic | Ollama Local |
|---------|---|---|---|
| **Custo** | Pago (Pro) | Pago | Grátis |
| **Internet** | ✅ Requer | ✅ Requer | ❌ Nunca |
| **Latência** | ~500ms | ~200ms | <100ms |
| **Qualidade Coding** | ⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐ |
| **RAM Pi** | N/A | N/A | ~3GB mín |
| **Setup** | Simples | Simples | Moderado |

### Recomendações para Seu Setup (Raspberry Pi)

1. **Se quer usar cloud + custo baixo**: 
   - GitHub Copilot Pro (recomendado) ✅
   - Ou Groq API (muito rápido)

2. **Se quer máxima privacidade + sem custos**:
   - Ollama local (llama2 ou mistral) com Pi 4+

3. **Se quer melhor qualidade (sem orçamento)**:
   - Anthropic Claude Opus com Raspberry Pi
   - (mais lento para processing, mas outputs melhores)

---

## 7. Próximos Passos

1. **Setup Raspberry Pi**:
   - Instalar Node.js 22+
   - `npm install -g openclaw@latest`
   - `openclaw onboard --install-daemon`

2. **Docker (Opcional)**:
   - Se preferir containerizado: `./docker-setup.sh`

3. **Conectar Desktop Windows**:
   - Instalar OpenClaw em WSL2
   - Setup SSH tunnel para Pi
   - `openclaw node run --host <pi-ip> --port 18789`

4. **Testar Comunicação**:
   ```bash
   openclaw devices approve <windows-id>
   openclaw nodes run --node "Windows" -- echo "Hello from Pi"
   ```

## 8. Resumo Final - GitHub Copilot no Raspberry Pi

| Pergunta | Resposta |
|---------|----------|
| **GitHub Copilot é suportado?** | ✅ Sim, provider `github-copilot` |
| **Como configurar?** | Defina `GITHUB_TOKEN` e configure em `openclaw.json` |
| **Custa mais algo?** | ❌ Só o que você já paga no Copilot Pro |
| **Funciona no Raspberry Pi?** | ✅ Sim (requer internet, não usa recursos locais) |
| **Alternativas gratuitas?** | ✅ Ollama local (llama2, mistral) |
| **Melhor escolha?** | Depende de orçamento e privacidade (ver tabela acima) |

---

---

## 9. O que é ClawHub?

### Resumo
**ClawHub** é o **registro público de skills (habilidades)** para OpenClaw - um marketplace de extensões que permitem estender a capacidade do agente IA com novas funcionalidades prontas para usar.

### Endereço
- 🌐 **Website**: https://clawhub.ai/
- 📦 **Repositório**: https://github.com/openclaw/clawhub

### O que você encontra no ClawHub

| Tipo | Exemplos | Uso |
|------|----------|-----|
| **Integrações** | Trello, Slack, Google Workspace, GitHub | Conectar com serviços externos |
| **Utilidades** | Weather, Summarize, Web Search (Tavily) | Funcionalidades gerais |
| **Conhecimento** | Answer Overflow, Ontology | Gerenciar memória e contexto |
| **Automação** | Self-improving-agent, Proactive-agent | Padrões de automação avançada |
| **Controle de Hardware** | Sonos, Calendarios (CalDAV) | IoT e dispositivos |

### Skills Populares (Estatísticas Atuais)

1. **Self-improving-agent** ⭐ 939 - Captura erros e aprende com correções
2. **Ontology** ⭐ 206 - Grafo tipado de conhecimento para memória estruturada
3. **Gog** ⭐ 586 - Google Workspace CLI (Gmail, Sheets, Docs, etc)
4. **Tavily Search** ⭐ 311 - Busca web otimizada para IA
5. **Trello** ⭐ 82 - Gerenciar quadros, listas e cards
6. **Slack** ⭐ 75 - Controlar Slack completamente

### Como Instalar Skills

#### 1️⃣ Instalação Rápida (Uma linha)

```bash
# Instalar uma skill específica
npx clawhub@latest install sonoscli

# Ou com outros package managers
pnpm clawhub@latest install slack
bun clawhub@latest install tavily-search
```

#### 2️⃣ Atualizar Skills Instaladas

```bash
# Atualizar todas as skills
clawhub update --all

# Sincronizar (scan + publicar atualizações)
clawhub sync --all
```

#### 3️⃣ Onde as Skills Vão

Por padrão, skills são instaladas em:
- `./skills/` (no diretório atual)
- Ou na pasta do workspace configurado do OpenClaw

**Localização final:**
```
~/.openclaw/workspace/skills/<skill-name>/SKILL.md
```

### Estrutura de uma Skill

Cada skill é uma pasta com `SKILL.md`:

```markdown
---
name: my-awesome-skill
description: Descrição breve do que faz
metadata: {
  "openclaw": {
    "requires": { "env": ["API_KEY"] },
    "primaryEnv": "API_KEY"
  }
}
---

## Instruções para o Agent

Como usar a skill...
```

### Configuração no OpenClaw

Uma vez instalada, a skill é automaticamente detectada. Você pode customizar em `~/.openclaw/openclaw.json`:

```json
{
  "skills": {
    "entries": {
      "slack": {
        "enabled": true,
        "apiKey": {
          "source": "env",
          "provider": "default",
          "id": "SLACK_BOT_TOKEN"
        }
      },
      "trello": {
        "enabled": true,
        "env": {
          "TRELLO_KEY": "seu-key-aqui",
          "TRELLO_TOKEN": "seu-token"
        }
      }
    }
  }
}
```

### Skills no Raspberry Pi

✅ **Compatível**: O ClawHub funciona normalmente no Raspberry Pi

**Recomendações:**
- Use skills que **não requerem compilação pesada**
- Evite skills com **dependências de binários complexos** em ARM
- **Skills nativas JavaScript** funcionam melhor (exemplos: Slack, Tavily, GitHub)

### Security Notes

⚠️ **Importante - Trate skills como código não confiável:**

```bash
# Antes de usar uma skill, SEMPRE verifique:
1. Código da skill no repositório
2. Permissões solicitadas
3. Dependências externas
4. Reviews/estrelas da comunidade
```

**Usar em sandbox para skills untrusted:**
```json
{
  "agents": {
    "defaults": {
      "sandbox": {
        "mode": "non-main"  // Roda skills em container isolado
      }
    }
  }
}
```

### Procurar Skills

**Opções:**

1. **Website**: Acesse https://claalhub.ai/skills
2. **CLI**: 
   ```bash
   openclaw models list  # Listar skills instaladas
   ```
3. **No Chat**: Use o skill `find-skills`
   ```
   /find-skills <funcionalidade desejada>
   ```
   (O agente vai procurar no ClawHub automaticamente)

### Criar e Publicar Sua Skill

**Passos:**

1. Criar pasta com `SKILL.md`
2. Publicar em um repositório GitHub
3. Ir para https://clawhub.ai/upload
4. Fazer login com GitHub
5. Fazer upload da skill

**Exemplo:** Muitos usuários criaram skills customizadas e as compartilham!

### Diferença: Skills vs Plugins vs Tools

| Aspecto | Skills | Plugins | Tools |
|---------|--------|---------|-------|
| **O que é** | Instruções para agent | Extensões do core | Funções do gateway |
| **Quem cria** | Comunidade/usuários | Devs | Core OpenClaw |
| **Instalação** | Via `clawhub install` | Via plugin registry | Nativo |
| **Escopo** | Sistema prompt | Funcionalidade core | RPC gateway |

### Workflow Típico

```
1. User: "Posso integrar com Trello?"
   ↓
2. Agent: Chama skill "find-skills"
   ↓
3. ClawHub: Retorna "trello" como opção
   ↓
4. User: "/find-skills install trello"
   ↓
5. Agent instala skill automaticamente
   ↓
6. Agora pode usar Trello: "Crie task X no Trello"
```

---

## Referências Documentação

- ClawHub: https://clawhub.ai/
- Skills Doc: https://docs.openclaw.ai/tools/skills
- ClawHub Full Guide: https://docs.openclaw.ai/tools/clawhub
- Model Providers: https://docs.openclaw.ai/concepts/model-providers
- GitHub Copilot Setup: https://docs.openclaw.ai/providers/models (Built-in providers > GitHub Copilot)
- Ollama Setup: https://docs.openclaw.ai/providers/ollama
- Gateway: https://docs.openclaw.ai/gateway
- Docker: https://docs.openclaw.ai/install/docker
- Nodes: https://docs.openclaw.ai/nodes
- Remote Access: https://docs.openclaw.ai/gateway/remote
- Arquitetura: https://docs.openclaw.ai/concepts/architecture
