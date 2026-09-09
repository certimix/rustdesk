# Guia de Configuração do Submódulo Criptográfico — `certimix/hbb_common`

Este documento orienta o processo de migração do submódulo compartilhado em Rust (`libs/hbb_common`) do repositório upstream original para a organização **`certimix`**, garantindo que as alterações de marca do **Zenydesk** permaneçam 100% reprodutíveis e sob controle da sua equipe.

---

## ⚠️ AVISO IMPORTANTE

> [!IMPORTANT]
> O script de rebranding (`branding/apply.sh` / `branding/apply.ps1`) **EXIGE** que o submódulo `libs/hbb_common` esteja devidamente inicializado no repositório antes da execução.
> Se o arquivo `libs/hbb_common/src/config.rs` não for localizado, o script abortará imediatamente com a mensagem:
> `submódulo não inicializado — rode git submodule update --init`

---

## 🛠️ Passo a Passo para Forkar e Vincular o Submódulo

### 1. Criar o Fork no GitHub
1. Acesse o repositório upstream original: **`https://github.com/rustdesk/hbb_common`**.
2. Clique no botão **Fork** no canto superior direito.
3. Escolha a sua organização ou conta no GitHub: **`certimix/hbb_common`**.

---

### 2. Atualizar o Ponteiro `.gitmodules` no Repositório do Cliente (`certimix/rustdesk`)

No terminal do seu repositório local do cliente RustDesk (`certimix/rustdesk`):

```bash
# 1. Abrir e atualizar a URL do submódulo no arquivo .gitmodules
nano .gitmodules
```

Altere a linha `url`:
```ini
[submodule "libs/hbb_common"]
	path = libs/hbb_common
	url = https://github.com/certimix/hbb_common.git
```

---

### 3. Sincronizar e Inicializar o Submódulo

Execute a sequência de comandos para aplicar o novo endereço remoto e baixar os arquivos da biblioteca:

```bash
# Sincronizar as novas URLs de submódulo configuradas no .gitmodules
git submodule sync

# Inicializar e atualizar os arquivos da pasta libs/hbb_common
git submodule update --init --remote libs/hbb_common

# Validar que a estrutura de arquivos do Rust foi carregada
ls -la libs/hbb_common/src/config.rs
```

---

### 4. Commitar o Novo Ponteiro do Submódulo no Git

```bash
# Adicionar a alteração do .gitmodules e o ponteiro atualizado
git add .gitmodules libs/hbb_common

# Commitar no repositório do cliente
git commit -m "chore: update hbb_common submodule pointer to certimix/hbb_common"

# Enviar para o GitHub
git push origin main
```

---

### 🚀 Resultado
A partir deste momento, todas as alterações efetuadas em `libs/hbb_common/src/config.rs` pelo script `./branding/apply.sh` serão persistidas diretamente no seu próprio repositório `certimix/hbb_common`.
