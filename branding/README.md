# Sistema de Rebranding Automatizado — Zenydesk Client

Este repositório fornece a infraestrutura completa de rebranding idempotente para aplicar a marca **Zenydesk** no fork do cliente RustDesk (`github.com/certimix/rustdesk`).

---

## 🚀 Como Aplicar o Rebranding

### 1. Configurar as Variáveis da Marca
Copie o arquivo de modelo `brand.env.example` para `brand.env`:

```bash
cp branding/brand.env.example branding/brand.env
```

Edite o arquivo `branding/brand.env` e defina o nome da sua marca, domínio e parâmetros de servidor.

---

### 2. Executar o Script Automatizado

#### Em Ambientes Linux / macOS / Git Bash:
```bash
chmod +x branding/apply.sh
./branding/apply.sh
```

#### Em Ambientes Windows PowerShell:
```powershell
.\branding\apply.ps1
```

O script é **idempotente**: você pode executá-lo múltiplas vezes sem risco de duplicar configurações ou corromper arquivos.

---

## 🧪 Fase 1: Validação Usando Servidores Públicos do RustDesk

Na fase inicial de testes e compilação do cliente, você pode validar o aplicativo conectando-se aos servidores públicos de sinalização do RustDesk antes de implantar sua VPS própria.

Edite o `branding/brand.env`:

```env
BRAND_NAME="Zenydesk"
BRAND_SLUG="zenydesk"
RENDEZVOUS_SERVER="rs-ny.rustdesk.com"
RS_PUB_KEY="O38B2Bclaj9ODF2xBDviA5B/s26zmaAga9RyIdNd7hE="
API_SERVER="https://api.zenydesk.com.br"
```

Em seguida, execute `./branding/apply.sh` e compile o cliente para testar a interface e conectividade.

---

## 🏢 Fase 2: Produção com Servidor VPS Próprio (Hostinger)

Quando a sua VPS Hostinger estiver no ar com o servidor `hbbs`/`hbbr` em execução:

1. Obtenha a chave pública gerada na VPS:
   ```bash
   cat /opt/zenydesk/server/data/id_ed25519.pub
   ```

2. Atualize o arquivo `branding/brand.env`:
   ```env
   BRAND_NAME="Zenydesk"
   BRAND_SLUG="zenydesk"
   RENDEZVOUS_SERVER="api.zenydesk.com.br"
   RS_PUB_KEY="SUA_CHAVE_ED25519_GERADA_NA_VPS_AQUI"
   API_SERVER="https://api.zenydesk.com.br"
   ```

3. Execute `./branding/apply.sh` e faça a compilação final dos instaladores `.exe`, `.dmg` e `.apk`.

---

## ⚖️ Conformidade de Licença AGPL-3.0

> [!IMPORTANT]
> **AGPL-3.0 SEÇÃO 13**: Em atendimento à licença GNU Affero General Public License v3.0, a aplicação rebrandeada inclui o link e a rota de transparência do código-fonte original e derivado (`/api/source`). Nenhuma referência residual que viole os termos da licença original deve permanecer nos binários distribuídos.
