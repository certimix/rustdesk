# 🔐 Guia de Assinatura Digital de Código (Code Signing) — ZenyDesk

Este documento detalha o que é necessário para assinar digitalmente os instaladores e binários executáveis do **ZenyDesk** para Windows, macOS e Android em versões de produção comercial.

> [!NOTE]
> **Fase Inicial (Suporte Direto)**: Nas primeiras versões entregues aos clientes atendidos pela Certimix, a assinatura digital **NÃO é obrigatória**. O instalador pode ser executado normalmente orientando o cliente a clicar em **"Mais informações ➔ Executar assim mesmo"** na tela do Windows SmartScreen.

---

## 🪟 1. Windows (Executáveis `.exe` e `.msi`)

### O que é exigido:
- **Certificado Digital de Código (Code Signing EV - Extended Validation)**.
- Fornecedores autorizados: DigiCert, Sectigo, GlobalSign.
- **Custo aproximado**: ~US$ 300 a US$ 400 por ano.

### Por que assinar:
- Elimina a tela azul de aviso do **Windows Defender SmartScreen** ("O Windows protegeu o seu PC / Aplicativo não reconhecido").
- Garante a identidade da sua empresa e integridade do executável.

---

## 🍎 2. macOS (Pacotes `.dmg`)

### O que é exigido:
- **Conta Apple Developer Program** (Apple Developer ID Certificate).
- **Custo**: US$ 99 por ano.
- **Notarização Apple**: O binário `.dmg` é submetido aos servidores da Apple via comando `xcrun notarytool` para receber o selo de notarização do Gatekeeper.

### Por que assinar:
- Sem a notarização, o macOS Gatekeeper bloqueia a abertura do aplicativo exibindo a mensagem *"O aplicativo não pode ser aberto porque o desenvolvedor não pode ser verificado"*.

---

## 🤖 3. Android (Aplicativo `.apk`)

### O que é exigido:
- **Keystore Própria (Chave de Assinatura)**.
- **Custo**: **GRATUITO** (Gerado localmente via utilitário `keytool` do Java JDK).

### Como gerar a Keystore Android:
```bash
keytool -genkey -v -keystore zenydesk-release-key.jks -keyalg RSA -keysize 2048 -validity 10000 -alias zenydesk
```

> [!CAUTION]
> **AVISO CRÍTICO DE SEGURANÇA**:
> Guarde o arquivo `zenydesk-release-key.jks` e suas senhas em local ultra-seguro (com o mesmo cuidado da sua chave SSH privada `id_ed25519`).
> **Se você perder esta chave de assinatura, será IMPOSSÍVEL atualizar o aplicativo Android no Google Play Store ou nas máquinas dos clientes no futuro.**

---

## ⚙️ Como ativar a assinatura no pipeline GitHub Actions (`flutter-build.yml`)

Quando adquirir os certificados, cadastre no GitHub (`Settings > Secrets and variables > Actions > Secrets`):

- `ANDROID_SIGNING_KEY`: Conteúdo base64 do arquivo `.jks`.
- `MACOS_P12_BASE64`: Conteúdo base64 do certificado Apple `.p12`.
- `WINDOWS_CERTIFICATE_BASE64`: Conteúdo base64 do certificado EV Windows `.pfx`.
- `WINDOWS_CERT_PASSWORD`: Senha da chave privada do certificado.
