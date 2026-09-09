#!/usr/bin/env bash
# =================================================================
#  Script de Implantação Automática ZenyDesk em VPS (Ubuntu/Debian)
# =================================================================
set -e

echo "================================================================="
echo " 🚀 Iniciando Implantação da VPS do ZenyDesk (API + DB + hbbs/hbbr)"
echo "================================================================="

# 1. Instalar Docker e Docker Compose se necessário
if ! command -v docker &> /dev/null; then
    echo "[PASSO 1] Instalando Docker..."
    curl -fsSL https://get.docker.com | sh
    systemctl enable --now docker
fi

if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
    echo "[PASSO 1.1] Instalando Docker Compose..."
    apt-get update && apt-get install -y docker-compose-plugin
fi

# 2. Configurar Firewall (UFW) para abrir as portas necessárias
echo "[PASSO 2] Configurando regras de Firewall (UFW)..."
ufw allow 80/tcp comment 'HTTP Web & Certificados SSL'
ufw allow 443/tcp comment 'HTTPS API & Web Portal'
ufw allow 21115:21119/tcp comment 'RustDesk Signal & Relay TCP'
ufw allow 21116/udp comment 'RustDesk Signal UDP'
ufw --force enable || true

# 3. Criar arquivo de variáveis de ambiente .env se não existir
if [ ! -f "server/.env" ]; then
    echo "[PASSO 3] Criando server/.env com credenciais de produção..."
    JWT_SECRET_GEN=$(openssl rand -hex 32 2>/dev/null || echo "zenydesk_super_secret_jwt_key_2026_production")
    MONGO_PASS_GEN=$(openssl rand -hex 16 2>/dev/null || echo "zenydesk_mongo_pass_2026")
    
    cat <<EOF > server/.env
PORT=3000
NODE_ENV=production
TZ=UTC
ZENYDESK_DEFAULT_TZ=America/Sao_Paulo
PUBLIC_HOST=api.zenydesk.com.br
MONGO_ROOT_USER=zenydesk_admin
MONGO_ROOT_PASSWORD=${MONGO_PASS_GEN}
JWT_SECRET=${JWT_SECRET_GEN}
CORS_ALLOWED_ORIGINS=https://zenydesk.com.br,https://api.zenydesk.com.br,http://localhost:5173
SOURCE_REPO_URL=https://github.com/certimix/ZenyDesk
EOF
fi

# 4. Iniciar Contêineres Docker (MongoDB, API, hbbs, hbbr, Caddy Proxy)
echo "[PASSO 4] Subindo pilha de contêineres Docker..."
cd server
docker compose up -d --build

# 5. Extrair Chave Pública Ed25519 do hbbs da VPS
echo "[PASSO 5] Extraindo chave pública Ed25519 do servidor hbbs..."
sleep 5
KEY_FILE="data/id_ed25519.pub"
if [ -f "$KEY_FILE" ]; then
    PUB_KEY=$(cat "$KEY_FILE")
    echo "-----------------------------------------------------------------"
    echo "🔑 CHAVE PÚBLICA DO SEU SERVIDOR DE SINALIZAÇÃO (RS_PUB_KEY):"
    echo "$PUB_KEY"
    echo "-----------------------------------------------------------------"
    echo "Para aplicar ao aplicativo cliente, adicione a chave acima em"
    echo "branding/brand.env na variável RS_PUB_KEY e rode ./branding/apply.sh"
else
    echo "[AVISO] Chave hbbs em geração... Verifique server/data/id_ed25519.pub após iniciar."
fi

echo "================================================================="
echo " ✅ VPS do ZenyDesk Implantada com Sucesso!"
echo " Portal Web: https://zenydesk.com.br"
echo " API Backend: https://api.zenydesk.com.br/api"
echo " Auditoria: https://api.zenydesk.com.br/api/audit/conn"
echo "================================================================="
