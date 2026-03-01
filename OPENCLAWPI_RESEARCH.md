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

---

## 5. Resumo Final

| Aspecto | Resposta |
|---------|----------|
| **Docker no Raspberry Pi?** | ✅ Sim, compatível. Mínimo Pi 4 com 2GB RAM |
| **Contraindicações?** | ⚠️ Compilação lenta, limite de memória, browser pesado |
| **O que é Gateway?** | Control plane central que coordena agente, canais e nodes |
| **Raspberry Pi → Desktop Windows?** | ✅ Sim, Desktop conecta como Node remoto via SSH/Tailscale |
| **Como executa ações?** | Node host expõe `system.run` que executa comandos localmente |
| **Segurança?** | ✅ Loopback + SSH tunnel (recomendado) ou Tailscale Serve |

---

## 6. Próximos Passos

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

## Referências Documentação

- Gateway: https://docs.openclaw.ai/gateway
- Docker: https://docs.openclaw.ai/install/docker
- Nodes: https://docs.openclaw.ai/nodes
- Remote Access: https://docs.openclaw.ai/gateway/remote
- Arquitetura: https://docs.openclaw.ai/concepts/architecture
