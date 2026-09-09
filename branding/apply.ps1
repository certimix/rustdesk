# =============================================================================
# Zenydesk / Brand Application Script for Windows PowerShell
# Idempotent rebranding tool: Can be executed multiple times safely.
# =============================================================================

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RootDir = Split-Path -Parent $ScriptDir

# Submodule Initialization Guard Check
$ConfigRs = Join-Path $RootDir "libs\hbb_common\src\config.rs"
if (-not (Test-Path $ConfigRs)) {
    Write-Host "submódulo não inicializado — rode git submodule update --init" -ForegroundColor Red
    exit 1
}

$EnvFile = Join-Path $ScriptDir "brand.env"
if (-not (Test-Path $EnvFile)) {
    Write-Warning "$EnvFile not found. Falling back to brand.env.example"
    $EnvFile = Join-Path $ScriptDir "brand.env.example"
}

Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host " Applying Rebranding from: $EnvFile" -ForegroundColor Cyan
Write-Host "=================================================================" -ForegroundColor Cyan

# Parse Env File
$BrandConfig = @{}
Get-Content $EnvFile | ForEach-Object {
    $line = $_.Trim()
    if ($line -and -not $line.StartsWith("#")) {
        $parts = $line.Split("=", 2)
        if ($parts.Count -eq 2) {
            $key = $parts[0].Trim()
            $val = $parts[1].Trim().Trim('"').Trim("'")
            $BrandConfig[$key] = $val
        }
    }
}

$BrandName = if ($BrandConfig["BRAND_NAME"]) { $BrandConfig["BRAND_NAME"] } else { "Zenydesk" }
$BrandSlug = if ($BrandConfig["BRAND_SLUG"]) { $BrandConfig["BRAND_SLUG"] } else { "zenydesk" }
$RendezvousServer = if ($BrandConfig["RENDEZVOUS_SERVER"]) { $BrandConfig["RENDEZVOUS_SERVER"] } else { "api.zenydesk.com.br" }
$RsPubKey = if ($BrandConfig["RS_PUB_KEY"]) { $BrandConfig["RS_PUB_KEY"] } else { "YOUR_HOSTINGER_VPS_ED25519_PUBLIC_KEY_HERE" }
$ApiServer = if ($BrandConfig["API_SERVER"]) { $BrandConfig["API_SERVER"] } else { "https://api.zenydesk.com.br" }
$AndroidPackageId = if ($BrandConfig["ANDROID_PACKAGE_ID"]) { $BrandConfig["ANDROID_PACKAGE_ID"] } else { "com.zenydesk.client" }
$MacOsBundleId = if ($BrandConfig["MACOS_BUNDLE_ID"]) { $BrandConfig["MACOS_BUNDLE_ID"] } else { "com.zenydesk.client" }
$WindowsServiceName = if ($BrandConfig["WINDOWS_SERVICE_NAME"]) { $BrandConfig["WINDOWS_SERVICE_NAME"] } else { "ZenydeskService" }

$script:Errors = 0

Write-Host "Brand Name: $BrandName"
Write-Host "Brand Slug: $BrandSlug"
Write-Host "Rendezvous Server: $RendezvousServer"
Write-Host "API Server: $ApiServer"
Write-Host "-----------------------------------------------------------------"

# Helper for safe file updates with 5% shrinkage guard check
function Write-FileSafely ($FilePath, $FileLabel, $PatternName, $BeforeContent, $AfterContent, $SearchTerm) {
    $linesBefore = ($BeforeContent -split "`r?\n").Count
    $linesAfter = ($AfterContent -split "`r?\n").Count

    # Check 5% shrinkage guard: if file loses >5% of lines, abort immediately
    if ($linesBefore -gt 10) {
        $minLines = [math]::Floor($linesBefore * 0.95)
        if ($linesAfter -lt $minLines) {
            $lostLines = $linesBefore - $linesAfter
            Write-Host "[ABORTADO] $FileLabel perdeu $lostLines linhas — provável truncamento" -ForegroundColor Red
            $script:Errors++
            return $false
        }
    }

    if ($BeforeContent -ne $AfterContent) {
        Set-Content -Path $FilePath -Value $AfterContent -NoNewline
        Write-Host "[OK] Padrão '$PatternName' atualizado em $FileLabel" -ForegroundColor Green
        return $true
    } else {
        if ($AfterContent.Contains($SearchTerm)) {
            Write-Host "[IDEMPOTENTE] Padrão '$PatternName' já aplicado em $FileLabel" -ForegroundColor Gray
            return $true
        } else {
            Write-Host "[FALHOU] Padrão '$PatternName' não encontrado em $FileLabel" -ForegroundColor Red
            $script:Errors++
            return $false
        }
    }
}

# 1. Section-aware Cargo.toml
function Update-CargoCustom {
    $FilePath = Join-Path $RootDir "Cargo.toml"
    $before = Get-Content $FilePath -Raw
    $lines = $before -split "`r?\n"
    $currentSection = ""
    $newLines = @()
    foreach ($line in $lines) {
        $trimmed = $line.Trim()
        if ($trimmed.StartsWith("[") -and $trimmed.EndsWith("]")) {
            $currentSection = $trimmed
            $newLines += $line
            continue
        }
        if ($currentSection -eq "[package]") {
            if ($line -match '^name\s*=') { $newLines += "name = `"$BrandSlug`""; continue }
            if ($line -match '^default-run\s*=') { $newLines += "default-run = `"$BrandSlug`""; continue }
        }
        if ($currentSection -eq "[lib]") {
            if ($line -match '^name\s*=') { $newLines += "name = `"lib$BrandSlug`""; continue }
        }
        if ($currentSection -eq "[[bin]]") {
            if ($line -match '^name\s*=\s*"(rustdesk|cxdesk|zenydesk)"') { $newLines += "name = `"$BrandSlug`""; continue }
        }
        if ($currentSection -eq "[package.metadata.winres]") {
            if ($line -match '^ProductName\s*=') { $newLines += "ProductName = `"$BrandName`""; continue }
            if ($line -match '^OriginalFilename\s*=') { $newLines += "OriginalFilename = `"$BrandSlug.exe`""; continue }
        }
        if ($currentSection -eq "[package.metadata.bundle]") {
            if ($line -match '^name\s*=') { $newLines += "name = `"$BrandName`""; continue }
            if ($line -match '^identifier\s*=') { $newLines += "identifier = `"$MacOsBundleId`""; continue }
        }
        $newLines += $line
    }
    $after = $newLines -join "`n"
    [void](Write-FileSafely $FilePath "Cargo.toml" "package_manifest" $before $after $BrandSlug)
}

# 2. Rust Core Config
function Update-HbbConfigCustom {
    $FilePath = Join-Path $RootDir "libs\hbb_common\src\config.rs"
    $content = Get-Content $FilePath -Raw

    # Pattern 1: APP_NAME
    $beforeApp = $content
    $afterApp = [regex]::Replace($content, 'pub static ref APP_NAME: RwLock<String> = RwLock::new\("[^"]*"\.to_owned\(\)\);', "pub static ref APP_NAME: RwLock<String> = RwLock::new(`"$BrandName`".to_owned());")
    [void](Write-FileSafely $FilePath "config.rs" "APP_NAME" $beforeApp $afterApp $BrandName)
    $content = Get-Content $FilePath -Raw

    # Pattern 2: BUILTIN_SETTINGS (api-server) - Injected inside lazy_static! preserving 4-space indentation
    $beforeBuiltin = $content
    $builtinReplacement = "    pub static ref BUILTIN_SETTINGS: RwLock<HashMap<String, String>> = RwLock::new({`n        let mut m = HashMap::new();`n        m.insert(`"api-server`".to_string(), `"$ApiServer`".to_string());`n        m`n    });"
    $afterBuiltin = [regex]::Replace($content, '(?m)^\s*pub static ref BUILTIN_SETTINGS: RwLock<HashMap<String, String>> = (Default::default\(\)|RwLock::new\(\{[\s\S]*?\n\s*\}\));', $builtinReplacement)
    [void](Write-FileSafely $FilePath "config.rs" "BUILTIN_SETTINGS (api-server)" $beforeBuiltin $afterBuiltin "api-server")
    $content = Get-Content $FilePath -Raw

    # Pattern 3 & 4: RENDEZVOUS_SERVERS & RS_PUB_KEY
    if ($RsPubKey.Contains("YOUR_") -or [string]::IsNullOrWhiteSpace($RsPubKey)) {
        Write-Host "[MODO VALIDAÇÃO] RS_PUB_KEY é placeholder. Mantendo servidor público (rs-ny.rustdesk.com)." -ForegroundColor Yellow
    } else {
        Write-Host "[PRODUÇÃO] Aplicando servidor próprio ($RendezvousServer) e RS_PUB_KEY." -ForegroundColor Green
        $beforeServers = $content
        $afterServers = [regex]::Replace($content, 'pub const RENDEZVOUS_SERVERS: &\[&str\] = &\[[^\]]*\];', "pub const RENDEZVOUS_SERVERS: &[&str] = &[`"$RendezvousServer`"];")
        [void](Write-FileSafely $FilePath "config.rs" "RENDEZVOUS_SERVERS" $beforeServers $afterServers $RendezvousServer)
        $content = Get-Content $FilePath -Raw

        $beforeKey = $content
        $afterKey = [regex]::Replace($content, 'pub const RS_PUB_KEY: &str = "[^"]*";', "pub const RS_PUB_KEY: &str = `"$RsPubKey`";")
        [void](Write-FileSafely $FilePath "config.rs" "RS_PUB_KEY" $beforeKey $afterKey $RsPubKey)
    }
}

# 3. Flutter Manifest
function Update-PubspecCustom {
    $FilePath = Join-Path $RootDir "flutter\pubspec.yaml"
    $before = Get-Content $FilePath -Raw
    $lines = $before -split "`r?\n"
    $newLines = @()
    foreach ($line in $lines) {
        if ($line -match '^name:') { $newLines += "name: $BrandSlug"; continue }
        if ($line -match '^description:') { $newLines += "description: `"$BrandName Remote Desktop Client`""; continue }
        $newLines += $line
    }
    $after = $newLines -join "`n"
    [void](Write-FileSafely $FilePath "pubspec.yaml" "flutter_manifest" $before $after $BrandSlug)
}

# 4. Android Config
function Update-GradleCustom {
    $FilePath = Join-Path $RootDir "flutter\android\app\build.gradle"
    $before = Get-Content $FilePath -Raw
    $after = [regex]::Replace($before, 'applicationId "[^"]*"', "applicationId `"$AndroidPackageId`"")
    $after = [regex]::Replace($after, 'resValue "string", "app_name", "[^"]*"', "resValue `"string`", `"app_name`", `"$BrandName`"")
    [void](Write-FileSafely $FilePath "build.gradle" "android_config" $before $after $AndroidPackageId)
}

# 5. macOS Config
function Update-MacConfigCustom {
    $FilePath = Join-Path $RootDir "flutter\macos\Runner\Configs\AppInfo.xcconfig"
    $before = Get-Content $FilePath -Raw
    $lines = $before -split "`r?\n"
    $newLines = @()
    foreach ($line in $lines) {
        if ($line -match '^PRODUCT_NAME =') { $newLines += "PRODUCT_NAME = $BrandName"; continue }
        if ($line -match '^PRODUCT_BUNDLE_IDENTIFIER =') { $newLines += "PRODUCT_BUNDLE_IDENTIFIER = $MacOsBundleId"; continue }
        $newLines += $line
    }
    $after = $newLines -join "`n"
    [void](Write-FileSafely $FilePath "AppInfo.xcconfig" "macos_config" $before $after $MacOsBundleId)
}

# 6. Desktop Entries
function Update-DesktopCustom ($RelativePath) {
    $FilePath = Join-Path $RootDir $RelativePath
    $before = Get-Content $FilePath -Raw
    $lines = $before -split "`r?\n"
    $currentSection = ""
    $newLines = @()
    foreach ($line in $lines) {
        $trimmed = $line.Trim()
        if ($trimmed.StartsWith("[") -and $trimmed.EndsWith("]")) {
            $currentSection = $trimmed
            $newLines += $line
            continue
        }
        if ($currentSection -eq "[Desktop Entry]") {
            if ($line -match '^Name=') { $newLines += "Name=$BrandName"; continue }
            if ($line -match '^Exec=') { $newLines += ($line -replace 'Exec=(rustdesk|cxdesk|zenydesk)', "Exec=$BrandSlug"); continue }
            if ($line -match '^TryExec=') { $newLines += ($line -replace 'TryExec=(rustdesk|cxdesk|zenydesk)', "TryExec=$BrandSlug"); continue }
            if ($line -match '^Icon=') { $newLines += "Icon=$BrandSlug"; continue }
            if ($line -match '^StartupWMClass=') { $newLines += "StartupWMClass=$BrandSlug"; continue }
            if ($line -match '^MimeType=') { $newLines += ($line -replace 'x-scheme-handler/(rustdesk|cxdesk|zenydesk);', "x-scheme-handler/$BrandSlug;"); continue }
        }
        if ($currentSection.StartsWith("[Desktop Action")) {
            if ($line -match '^Exec=') { $newLines += ($line -replace 'Exec=(rustdesk|cxdesk|zenydesk)', "Exec=$BrandSlug"); continue }
        }
        $newLines += $line
    }
    $after = $newLines -join "`n"
    [void](Write-FileSafely $FilePath $RelativePath "desktop_entry" $before $after $BrandSlug)
}

Update-CargoCustom
Update-HbbConfigCustom
Update-PubspecCustom
Update-GradleCustom
Update-MacConfigCustom
Update-DesktopCustom "res\rustdesk.desktop"
Update-DesktopCustom "res\rustdesk-link.desktop"

Write-Host "-----------------------------------------------------------------"
if ($script:Errors -gt 0) {
    Write-Host "[ERRO] Rebranding concluído com $script:Errors erro(s)." -ForegroundColor Red
    exit 1
} else {
    Write-Host "[SUCESSO] Rebranding aplicado com sucesso a todos os alvos!" -ForegroundColor Green
}

# 7. Final Compilation Verification Gate
Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host " Verificação Final de Compilação (Cargo)" -ForegroundColor Cyan
Write-Host "=================================================================" -ForegroundColor Cyan
$cargoCmd = Get-Command cargo -ErrorAction SilentlyContinue
if ($cargoCmd) {
    Write-Host "[CHECK] Executando verificação de compilação do hbb_common..." -ForegroundColor Yellow
    $CargoManifest = Join-Path $RootDir "Cargo.toml"
    cargo check -p hbb_common --manifest-path $CargoManifest
    if ($LASTEXITCODE -eq 0) {
        Write-Host "[SUCESSO] Compilação do hbb_common verificada com sucesso!" -ForegroundColor Green
    } else {
        Write-Host "[ERRO CRÍTICO] O rebranding foi aplicado mas o código NÃO compila!" -ForegroundColor Red
        $script:Errors++
        exit 1
    }
} else {
    Write-Host "[AVISO] cargo não encontrado — resultado NÃO verificado" -ForegroundColor Yellow
}

Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host " Relatório de Conformidade AGPL-3.0 (Varredura por 'rustdesk')" -ForegroundColor Cyan
Write-Host "=================================================================" -ForegroundColor Cyan
Get-ChildItem -Path $RootDir -Recurse -Include *.rs,*.dart,*.toml,*.yaml,*.desktop,*.iss -ErrorAction SilentlyContinue | ForEach-Object {
    $matches = Select-String -Path $_.FullName -Pattern "rustdesk" -CaseSensitive:$false
    if ($matches) {
        Write-Host "$($_.Name) : $($matches.Count) ocorrências de 'rustdesk'" -ForegroundColor Gray
    }
}
