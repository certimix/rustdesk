#!/usr/bin/env bash
# =============================================================================
# Zenydesk / Brand Application Script for RustDesk Client Rebranding
# Idempotent rebranding tool: Can be executed multiple times safely.
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Submodule Initialization Guard Check
CONFIG_RS="$ROOT_DIR/libs/hbb_common/src/config.rs"
if [ ! -f "$CONFIG_RS" ]; then
  echo "submódulo não inicializado — rode git submodule update --init"
  exit 1
fi

# Load configuration file (brand.env or fallback to brand.env.example)
ENV_FILE="$SCRIPT_DIR/brand.env"
if [ ! -f "$ENV_FILE" ]; then
  echo "[WARNING] $ENV_FILE not found. Falling back to $SCRIPT_DIR/brand.env.example"
  ENV_FILE="$SCRIPT_DIR/brand.env.example"
fi

echo "================================================================="
echo " Applying Rebranding from: $ENV_FILE"
echo "================================================================="

# Export env vars
set -o allexport
source "$ENV_FILE"
set +o allexport

# Sanity checks & defaults
BRAND_NAME="${BRAND_NAME:-Zenydesk}"
BRAND_SLUG="${BRAND_SLUG:-zenydesk}"
BRAND_DOMAIN="${BRAND_DOMAIN:-zenydesk.com}"
BRAND_SUPPORT_EMAIL="${BRAND_SUPPORT_EMAIL:-suporte@zenydesk.com}"
RENDEZVOUS_SERVER="${RENDEZVOUS_SERVER:-api.zenydesk.com.br}"
RS_PUB_KEY="${RS_PUB_KEY:-YOUR_HOSTINGER_VPS_ED25519_PUBLIC_KEY_HERE}"
API_SERVER="${API_SERVER:-https://api.zenydesk.com.br}"
ANDROID_PACKAGE_ID="${ANDROID_PACKAGE_ID:-com.zenydesk.client}"
MACOS_BUNDLE_ID="${MACOS_BUNDLE_ID:-com.zenydesk.client}"
WINDOWS_SERVICE_NAME="${WINDOWS_SERVICE_NAME:-ZenydeskService}"

ERRORS=0

echo "Brand Name: $BRAND_NAME"
echo "Brand Slug: $BRAND_SLUG"
echo "Rendezvous Server: $RENDEZVOUS_SERVER"
echo "API Server: $API_SERVER"
echo "-----------------------------------------------------------------"

# Helper for safe file updates with 5% shrinkage guard check
write_file_safely() {
  local full_path="$1"
  local file_label="$2"
  local pattern_name="$3"
  local before_content="$4"
  local after_content="$5"
  local search_term="$6"

  local lines_before=$(echo "$before_content" | wc -l)
  local lines_after=$(echo "$after_content" | wc -l)

  # Check 5% shrinkage guard: if file loses >5% of lines, abort immediately
  if [ "$lines_before" -gt 10 ]; then
    local min_lines=$(( lines_before * 95 / 100 ))
    if [ "$lines_after" -lt "$min_lines" ]; then
      local lost_lines=$(( lines_before - lines_after ))
      echo "[ABORTADO] $file_label perdeu $lost_lines linhas — provável truncamento"
      ERRORS=$((ERRORS + 1))
      return 1
    fi
  fi

  if [ "$before_content" != "$after_content" ]; then
    echo "$after_content" > "$full_path"
    echo "[OK] Padrão '$pattern_name' atualizado em $file_label"
    return 0
  else
    if echo "$after_content" | grep -qF "$search_term"; then
      echo "[IDEMPOTENTE] Padrão '$pattern_name' já aplicado em $file_label"
      return 0
    else
      echo "[FALHOU] Padrão '$pattern_name' não encontrado em $file_label"
      ERRORS=$((ERRORS + 1))
      return 1
    fi
  fi
}

# 1. Section-aware Cargo.toml
update_cargo() {
  local full_path="$ROOT_DIR/Cargo.toml"
  local before="$(cat "$full_path")"
  local after="$(awk -v slug="$BRAND_SLUG" -v name="$BRAND_NAME" -v bundle="$MACOS_BUNDLE_ID" '
    BEGIN { section = "" }
    /^\[.*\]/ { section = $0 }
    section == "[package]" && /^name =/ { print "name = \"" slug "\""; next }
    section == "[package]" && /^default-run =/ { print "default-run = \"" slug "\""; next }
    section == "[lib]" && /^name =/ { print "name = \"lib" slug "\""; next }
    section == "[[bin]]" && /^name = "(rustdesk|cxdesk|zenydesk)"/ { print "name = \"" slug "\""; next }
    section == "[package.metadata.winres]" && /^ProductName =/ { print "ProductName = \"" name "\""; next }
    section == "[package.metadata.winres]" && /^OriginalFilename =/ { print "OriginalFilename = \"" slug ".exe\""; next }
    section == "[package.metadata.bundle]" && /^name =/ { print "name = \"" name "\""; next }
    section == "[package.metadata.bundle]" && /^identifier =/ { print "identifier = \"" bundle "\""; next }
    { print }
  ' "$full_path")"

  write_file_safely "$full_path" "Cargo.toml" "package_manifest" "$before" "$after" "$BRAND_SLUG" || true
}

# 2. Rust Core Config (libs/hbb_common/src/config.rs)
update_hbb_config() {
  local full_path="$ROOT_DIR/libs/hbb_common/src/config.rs"
  local content="$(cat "$full_path")"

  # Pattern 1: APP_NAME
  local before_app="$content"
  local after_app="$(echo "$content" | sed -E "s#pub static ref APP_NAME: RwLock<String> = RwLock::new\(\"[^\"]*\"\.to_owned\(\)\);#pub static ref APP_NAME: RwLock<String> = RwLock::new(\"${BRAND_NAME}\".to_owned());#g")"
  write_file_safely "$full_path" "config.rs" "APP_NAME" "$before_app" "$after_app" "$BRAND_NAME" || true
  content="$(cat "$full_path")"

  # Pattern 2: BUILTIN_SETTINGS (api-server) - Injected inside lazy_static! preserving 4-space indentation
  local before_builtin="$content"
  local after_builtin="$(perl -0777 -pe '
    my $api = "'"$API_SERVER"'";
    s/    pub static ref BUILTIN_SETTINGS: RwLock<HashMap<String, String>> = (Default::default\(\)|RwLock::new\(\{\n\s*let mut m = HashMap::new\(\);\n\s*m\.insert\("api-server"\.to_string\(\), "[^"]*"\.to_string\(\)\);\n\s*m\n\s*\}\));/    pub static ref BUILTIN_SETTINGS: RwLock<HashMap<String, String>> = RwLock::new({\n        let mut m = HashMap::new();\n        m.insert("api-server".to_string(), "$api".to_string());\n        m\n    });/g
  ' "$full_path")"
  write_file_safely "$full_path" "config.rs" "BUILTIN_SETTINGS (api-server)" "$before_builtin" "$after_builtin" "api-server" || true
  content="$(cat "$full_path")"

  # Pattern 3 & 4: RENDEZVOUS_SERVERS & RS_PUB_KEY
  if [[ "$RS_PUB_KEY" == *"YOUR_"* ]] || [[ -z "$RS_PUB_KEY" ]]; then
    echo "[MODO VALIDAÇÃO] RS_PUB_KEY é placeholder. Mantendo servidor público (rs-ny.rustdesk.com)."
  else
    echo "[PRODUÇÃO] Aplicando servidor próprio ($RENDEZVOUS_SERVER) e RS_PUB_KEY."
    local before_servers="$content"
    local after_servers="$(echo "$content" | sed -E "s#pub const RENDEZVOUS_SERVERS: &\[&str\] = &\[[^\]]*\];#pub const RENDEZVOUS_SERVERS: \&[\&str\] = \&[\"$RENDEZVOUS_SERVER\"];#g")"
    write_file_safely "$full_path" "config.rs" "RENDEZVOUS_SERVERS" "$before_servers" "$after_servers" "$RENDEZVOUS_SERVER" || true
    content="$(cat "$full_path")"

    local before_key="$content"
    local after_key="$(echo "$content" | sed -E "s#pub const RS_PUB_KEY: &str = \"[^\"]*\";#pub const RS_PUB_KEY: \&str = \"$RS_PUB_KEY\";#g")"
    write_file_safely "$full_path" "config.rs" "RS_PUB_KEY" "$before_key" "$after_key" "$RS_PUB_KEY" || true
  fi
}

# 3. Flutter Manifest
update_pubspec() {
  local full_path="$ROOT_DIR/flutter/pubspec.yaml"
  local before="$(cat "$full_path")"
  local after="$(awk -v slug="$BRAND_SLUG" -v name="$BRAND_NAME" '
    /^name:/ { print "name: " slug; next }
    /^description:/ { print "description: \"" name " Remote Desktop Client\""; next }
    { print }
  ' "$full_path")"

  write_file_safely "$full_path" "pubspec.yaml" "flutter_manifest" "$before" "$after" "$BRAND_SLUG" || true
}

# 4. Android Config
update_gradle() {
  local full_path="$ROOT_DIR/flutter/android/app/build.gradle"
  local before="$(cat "$full_path")"
  local after="$(echo "$before" | sed -E "s#applicationId \"[^\"]*\"#applicationId \"$ANDROID_PACKAGE_ID\"#g" | sed -E "s#resValue \"string\", \"app_name\", \"[^\"]*\"#resValue \"string\", \"app_name\", \"$BRAND_NAME\"#g")"

  write_file_safely "$full_path" "build.gradle" "android_config" "$before" "$after" "$ANDROID_PACKAGE_ID" || true
}

# 5. macOS Config
update_mac_config() {
  local full_path="$ROOT_DIR/flutter/macos/Runner/Configs/AppInfo.xcconfig"
  local before="$(cat "$full_path")"
  local after="$(awk -v name="$BRAND_NAME" -v bundle="$MACOS_BUNDLE_ID" '
    /^PRODUCT_NAME =/ { print "PRODUCT_NAME = " name; next }
    /^PRODUCT_BUNDLE_IDENTIFIER =/ { print "PRODUCT_BUNDLE_IDENTIFIER = " bundle; next }
    { print }
  ' "$full_path")"

  write_file_safely "$full_path" "AppInfo.xcconfig" "macos_config" "$before" "$after" "$MACOS_BUNDLE_ID" || true
}

# 6. Section-aware Desktop Entries
update_desktop() {
  local file="$1"
  local full_path="$ROOT_DIR/$file"
  local before="$(cat "$full_path")"
  local after="$(awk -v name="$BRAND_NAME" -v slug="$BRAND_SLUG" '
    BEGIN { section = "" }
    /^\[.*\]/ { section = $0 }
    section == "[Desktop Entry]" && /^Name=/ { print "Name=" name; next }
    section == "[Desktop Entry]" && /^Exec=/ { gsub(/^Exec=(rustdesk|cxdesk|zenydesk)/, "Exec=" slug); print; next }
    section == "[Desktop Entry]" && /^TryExec=/ { gsub(/^TryExec=(rustdesk|cxdesk|zenydesk)/, "TryExec=" slug); print; next }
    section == "[Desktop Entry]" && /^Icon=/ { print "Icon=" slug; next }
    section == "[Desktop Entry]" && /^StartupWMClass=/ { print "StartupWMClass=" slug; next }
    section == "[Desktop Entry]" && /^MimeType=/ { gsub(/x-scheme-handler\/(rustdesk|cxdesk|zenydesk);/, "x-scheme-handler/" slug ";"); print; next }
    section ~ /^\[Desktop Action/ && /^Exec=/ { gsub(/^Exec=(rustdesk|cxdesk|zenydesk)/, "Exec=" slug); print; next }
    { print }
  ' "$full_path")"

  write_file_safely "$full_path" "$file" "desktop_entry" "$before" "$after" "$BRAND_SLUG" || true
}

# Execute updates
update_cargo
update_hbb_config
update_pubspec
update_gradle
update_mac_config
update_desktop "res/rustdesk.desktop"
update_desktop "res/rustdesk-link.desktop"

echo "-----------------------------------------------------------------"
if [ "$ERRORS" -gt 0 ]; then
  echo "[ERRO] Rebranding concluído com $ERRORS erro(s)."
  exit 1
else
  echo "[SUCESSO] Rebranding aplicado com sucesso a todos os alvos!"
fi

# 7. Final Compilation Verification Gate
echo "================================================================="
echo " Verificação Final de Compilação (Cargo)"
echo "================================================================="
if command -v cargo >/dev/null 2>&1; then
  echo "[CHECK] Executando verificação de compilação do hbb_common..."
  if cargo check -p hbb_common --manifest-path "$ROOT_DIR/Cargo.toml"; then
    echo "[SUCESSO] Compilação do hbb_common verificada com sucesso!"
  else
    echo "[ERRO CRÍTICO] O rebranding foi aplicado mas o código NÃO compila!"
    exit 1
  fi
else
  echo "[AVISO] cargo não encontrado — resultado NÃO verificado"
fi

echo "================================================================="
echo " Relatório de Conformidade AGPL-3.0 (Varredura por 'rustdesk')"
echo "================================================================="
grep -ri "rustdesk" \
  --include="*.rs" \
  --include="*.dart" \
  --include="*.toml" \
  --include="*.yaml" \
  --include="*.desktop" \
  --include="*.iss" \
  "$ROOT_DIR" 2>/dev/null | head -n 20 || true
