# 🛠️ Guia de Compilação & Build Automatizado dos Aplicativos ZenyDesk

Este guia explica como compilar e publicar automaticamente os executáveis clientes do **ZenyDesk** para Windows, macOS, Linux e Android utilizando o GitHub Actions no repositório fork `certimix/rustdesk`.

---

## 🚀 1. Configuração Inicial dos Secrets no GitHub

No repositório `certimix/rustdesk`, acesse `Settings > Secrets and variables > Actions > Repository secrets` e cadastre as seguintes variáveis:

| Secret Name | Exemplo de Valor | Descrição |
| :--- | :--- | :--- |
| `BRAND_NAME` | `Zenydesk` | Nome exibido no aplicativo e no instalador |
| `BRAND_SLUG` | `zenydesk` | Identificador único e prefixo do binário (`zenydesk-1.3.2-x86_64.exe`) |
| `API_SERVER` | `https://api.zenydesk.com.br` | Rota da API Backend SaaS para envio de auditoria |
| `RENDEZVOUS_SERVER` | `api.zenydesk.com.br` | Endereço do seu servidor de sinalização `hbbs` |
| `RS_PUB_KEY` | `Chave_Ed25519_Gerada_na_VPS` | Chave pública de criptografia do servidor |
| `ANDROID_PACKAGE_ID` | `com.zenydesk.client` | Package ID para Android |
| `MACOS_BUNDLE_ID` | `com.zenydesk.client` | Bundle Identifier para macOS |

---

## 📦 2. Disparando a Compilação Automática (Release)

Existem duas formas de disparar a geração automática dos instaladores:

### Opção A — Disparo Manual (workflow_dispatch)
1. Acesse a aba **Actions** no repositório `certimix/rustdesk`.
2. Clique no workflow **Build the flutter version of the RustDesk**.
3. Clique em **Run workflow** e selecione a branch `main`.

### Opção B — Criação de uma Tag de Release (Recomendado)
Sempre que você criar uma nova tag de versão no Git:
```bash
git tag v1.3.2
git push origin v1.3.2
```
O pipeline do GitHub Actions será iniciado automaticamente, compilará todas as plataformas e publicará a Release pública no endereço:
`https://github.com/certimix/rustdesk/releases/latest`

---

## 🔍 3. Como Conferir se o Rebranding foi Aplicado com Sucesso

Após o término da execução do workflow:

1. **Baixe o executável Windows (`zenydesk-1.3.2-x86_64.exe`)**:
   - Clique com o botão direito ➔ **Propriedades** ➔ **Detalhes**.
   - Verifique se o **Nome do Produto** e **Descrição do Arquivo** exibem `Zenydesk`.
2. **Execute o aplicativo**:
   - A barra de título deve exibir `Zenydesk`.
   - Acesse **Configurações ➔ Rede** no app e confirme se o **Servidor ID/Relay** aponta para `api.zenydesk.com.br`.
3. **Verifique a compilação do hbb_common**:
   - O log do GitHub Actions no passo `Run Rebranding Application Script` deve exibir:
     `[SUCESSO] Compilação do hbb_common verificada com sucesso!`
