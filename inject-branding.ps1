param(
    [string]$MasterIcon = "C:\Users\SUPORTE 3\Downloads\CXDesk\web\public\logo-icon.png",
    [string]$MasterLogo = "C:\Users\SUPORTE 3\Downloads\CXDesk\web\public\logo.png",
    [string]$RepoRoot = "C:\Users\SUPORTE 3\Downloads\rustdesk-client"
)

Add-Type -AssemblyName System.Drawing

function Resize-Bitmap {
    param([System.Drawing.Image]$img, [int]$width, [int]$height)
    $dest = New-Object System.Drawing.Bitmap $width, $height
    $g = [System.Drawing.Graphics]::FromImage($dest)
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
    $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $g.DrawImage($img, 0, 0, $width, $height)
    $g.Dispose()
    return $dest
}

function Save-Png {
    param([System.Drawing.Bitmap]$bmp, [string]$path)
    $dir = [System.IO.Path]::GetDirectoryName($path)
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    $bmp.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
    Write-Host " [PNG] $path ($($bmp.Width)x$($bmp.Height))" -ForegroundColor Green
}

function Save-MultiResIco {
    param([System.Drawing.Image]$srcImg, [int[]]$sizes, [string]$outPath)
    $dir = [System.IO.Path]::GetDirectoryName($outPath)
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    
    $pngBytesList = New-Object System.Collections.Generic.List[byte[]]
    $sizeList = New-Object System.Collections.Generic.List[int]

    foreach ($s in $sizes) {
        $bmp = Resize-Bitmap $srcImg $s $s
        $ms = New-Object System.IO.MemoryStream
        $bmp.Save($ms, [System.Drawing.Imaging.ImageFormat]::Png)
        $bmp.Dispose()
        $pngBytesList.Add($ms.ToArray())
        $sizeList.Add($s)
        $ms.Dispose()
    }

    $count = $pngBytesList.Count
    $fs = [System.IO.File]::Create($outPath)
    $bw = New-Object System.IO.BinaryWriter($fs)

    # ICONHEADER: Reserved (0), Type (1), Count
    $bw.Write([uint16]0)
    $bw.Write([uint16]1)
    $bw.Write([uint16]$count)

    # Offset starts after header (6 bytes) + entries (16 bytes each)
    $offset = 6 + (16 * $count)

    for ($i = 0; $i -lt $count; $i++) {
        $s = $sizeList[$i]
        $data = $pngBytesList[$i]
        $w = if ($s -ge 256) { 0 } else { [byte]$s }
        $h = if ($s -ge 256) { 0 } else { [byte]$s }

        $bw.Write([byte]$w)        # Width
        $bw.Write([byte]$h)        # Height
        $bw.Write([byte]0)         # Colors
        $bw.Write([byte]0)         # Reserved
        $bw.Write([uint16]1)       # Planes
        $bw.Write([uint16]32)      # Bits per pixel
        $bw.Write([uint32]$data.Length) # Image size in bytes
        $bw.Write([uint32]$offset) # Offset
        $offset += $data.Length
    }

    for ($i = 0; $i -lt $count; $i++) {
        $bw.Write($pngBytesList[$i])
    }

    $bw.Close()
    $fs.Close()
    Write-Host " [ICO] $outPath (Sizes: $($sizes -join ','))" -ForegroundColor Cyan
}

Write-Host "=== INICIANDO INJECAO DE BRANDING ZENYDESK ===" -ForegroundColor Magenta

$srcIcon = [System.Drawing.Image]::FromFile($MasterIcon)
$srcLogo = [System.Drawing.Image]::FromFile($MasterLogo)

# 1. Gerar .ICO (Windows Executavel, Tray e Runner)
$icoSizes = @(16, 24, 32, 48, 64, 128, 256)
Save-MultiResIco $srcIcon $icoSizes "$RepoRoot\res\icon.ico"
Save-MultiResIco $srcIcon @(16, 24, 32, 48) "$RepoRoot\res\tray-icon.ico"
Save-MultiResIco $srcIcon $icoSizes "$RepoRoot\flutter\windows\runner\resources\app_icon.ico"

# 2. Gerar PNGs Desktop (Linux, macOS, Web)
$pngMap = @{
    "$RepoRoot\res\32x32.png"        = 32
    "$RepoRoot\res\64x64.png"        = 64
    "$RepoRoot\res\128x128.png"      = 128
    "$RepoRoot\res\128x128@2x.png"   = 256
    "$RepoRoot\res\icon.png"         = 512
    "$RepoRoot\res\mac-icon.png"     = 512
    "$RepoRoot\res\mac-tray-dark-x2.png"  = 44
    "$RepoRoot\res\mac-tray-light-x2.png" = 44
    "$RepoRoot\flutter\assets\logo.png"       = 512
    "$RepoRoot\flutter\assets\logo_light.png" = 512
    "$RepoRoot\flutter\assets\logo_dark.png"  = 512
    "$RepoRoot\branding\assets\logo-icon.png" = 512
}
foreach ($path in $pngMap.Keys) {
    $sz = $pngMap[$path]
    $bmp = Resize-Bitmap $srcIcon $sz $sz
    Save-Png $bmp $path
    $bmp.Dispose()
}

# 3. Gerar Mipmaps Android (ic_launcher, round, foreground)
$androidMipmaps = @{
    "mipmap-mdpi"    = 48
    "mipmap-hdpi"    = 72
    "mipmap-xhdpi"   = 96
    "mipmap-xxhdpi"  = 144
    "mipmap-xxxhdpi" = 192
}
$androidDir = "$RepoRoot\flutter\android\app\src\main\res"
foreach ($m in $androidMipmaps.Keys) {
    $sz = $androidMipmaps[$m]
    $bmp = Resize-Bitmap $srcIcon $sz $sz
    Save-Png $bmp "$androidDir\$m\ic_launcher.png"
    Save-Png $bmp "$androidDir\$m\ic_launcher_round.png"
    Save-Png $bmp "$androidDir\$m\ic_launcher_foreground.png"
    $bmp.Dispose()
}

# 4. Gerar AppIcon set do iOS
$iosAppIconDir = "$RepoRoot\flutter\ios\Runner\Assets.xcassets\AppIcon.appiconset"
if (Test-Path $iosAppIconDir) {
    $iosSizes = @(20, 29, 40, 58, 60, 76, 80, 87, 120, 152, 167, 180, 1024)
    foreach ($sz in $iosSizes) {
        $bmp = Resize-Bitmap $srcIcon $sz $sz
        Save-Png $bmp "$iosAppIconDir\app_icon_$sz.png"
        $bmp.Dispose()
    }
}

$srcIcon.Dispose()
$srcLogo.Dispose()

Write-Host "=== INJECAO DE ICONES CONCLUIDA COM SUCESSO! ===" -ForegroundColor Magenta
