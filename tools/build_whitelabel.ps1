#requires -Version 5.1
<#
.SYNOPSIS
  Genera el APK de marca blanca a partir de la configuración del panel.

.DESCRIPTION
  1. Lee admin_panel\config.json (o el que indiques con -ConfigPath).
  2. Lo copia a assets\config.json, que es lo que se graba dentro del APK.
  3. Ajusta la versión en pubspec.yaml y lib\core\app_info.dart.
  4. Compila el APK de release (y opcionalmente uno por arquitectura).
  5. Deja los resultados en la carpeta dist\.

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File .\tools\build_whitelabel.ps1
.EXAMPLE
  powershell -ExecutionPolicy Bypass -File .\tools\build_whitelabel.ps1 -Version 1.0.1 -SplitAbi
#>
param(
  [string]$ConfigPath = '',
  [string]$Brand = '',
  [string]$Version = '',
  [string]$AppId = '',
  [string]$PythonPath = '',
  [switch]$SplitAbi,
  [switch]$SkipBuild
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'flutter_logged.ps1')

function Info($m) { Write-Host "[marca] $m" -ForegroundColor Cyan }
function Ok($m) { Write-Host "[marca] $m" -ForegroundColor Green }
function Warn($m) { Write-Host "[marca] $m" -ForegroundColor Yellow }
function Fail($m) { Write-Host "[marca] $m" -ForegroundColor Red; exit 1 }

$toolsDir = $PSScriptRoot
if ([string]::IsNullOrEmpty($toolsDir)) { $toolsDir = (Get-Location).Path }
$projectRoot = Split-Path -Parent $toolsDir
if (-not (Test-Path -LiteralPath (Join-Path $projectRoot 'pubspec.yaml'))) {
  $projectRoot = (Get-Location).Path
}
if (-not (Test-Path -LiteralPath (Join-Path $projectRoot 'pubspec.yaml'))) {
  Fail "No encuentro pubspec.yaml. Ejecuta el script desde la carpeta del proyecto."
}
Info "Proyecto: $projectRoot"

# ---------------------------------------------------------------- entorno
$candidates = @('C:\src\flutter\bin', 'C:\flutter\bin', (Join-Path $env:LOCALAPPDATA 'flutter\bin'))
if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
  foreach ($path in $candidates) {
    if (Test-Path -LiteralPath (Join-Path $path 'flutter.bat')) { $env:Path = "$path;$env:Path"; break }
  }
}
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
  foreach ($path in @('C:\src\PortableGit\cmd', 'C:\Program Files\Git\cmd')) {
    if (Test-Path -LiteralPath (Join-Path $path 'git.exe')) { $env:Path = "$path;$env:Path"; break }
  }
}
if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
  Fail 'Flutter no está en el PATH. Instálalo o ajusta la ruta en este script.'
}
if (-not $env:ANDROID_HOME) {
  $sdk = Join-Path $env:LOCALAPPDATA 'Android\Sdk'
  if (Test-Path -LiteralPath $sdk) { $env:ANDROID_HOME = $sdk; $env:ANDROID_SDK_ROOT = $sdk }
}
$versionLog = Join-Path $projectRoot 'build\whitelabel-flutter-version.log'
$versionCode = Invoke-FlutterLogged -Arguments @('--version') -LogPath $versionLog
if ($versionCode -ne 0) { Fail "Flutter no pudo arrancar. Revisa $versionLog" }
Info ("Flutter: " + (Get-Content -LiteralPath $versionLog -Encoding UTF8 | Select-Object -First 1))

# ---------------------------------------------------------------- config
$brandsDir = Join-Path $projectRoot 'admin_panel\brands'
if ([string]::IsNullOrEmpty($ConfigPath)) {
  if ($Brand) {
    $ConfigPath = Join-Path $brandsDir "$Brand.json"
    if (-not (Test-Path -LiteralPath $ConfigPath)) {
      Fail "No existe la marca '$Brand'. Archivos disponibles: $((Get-ChildItem -LiteralPath $brandsDir -Filter '*.json' -ErrorAction SilentlyContinue | ForEach-Object { $_.BaseName }) -join ', ')"
    }
  } else {
    $available = @(Get-ChildItem -LiteralPath $brandsDir -Filter '*.json' -ErrorAction SilentlyContinue)
    if ($available.Count -eq 1) {
      $ConfigPath = $available[0].FullName
      Info "Marca detectada: $($available[0].BaseName)"
    } elseif ($available.Count -gt 1) {
      Fail ("Hay varias marcas: " + (($available | ForEach-Object { $_.BaseName }) -join ', ') + ". Indica cuál con -Brand (ejemplo: -Brand ibw-tv)")
    } else {
      $fromPanel = Join-Path $projectRoot 'admin_panel\config.json'
      if (Test-Path -LiteralPath $fromPanel) {
        $ConfigPath = $fromPanel
      } else {
        Fail "No hay marcas en admin_panel\brands. Crea una desde el panel de administración."
      }
    }
  }
}
if (-not (Test-Path -LiteralPath $ConfigPath)) { Fail "No existe el archivo: $ConfigPath" }

$rawJson = Get-Content -LiteralPath $ConfigPath -Raw -Encoding UTF8
try {
  $config = $rawJson | ConvertFrom-Json
} catch {
  Fail "El archivo $ConfigPath no es un JSON válido: $($_.Exception.Message)"
}
Info "Configuración: $ConfigPath"

# Copia de seguridad propia de esta marca, por si hay que volver atrás.
$brandId = [System.IO.Path]::GetFileNameWithoutExtension($ConfigPath)
$backupPath = Join-Path $brandsDir "$brandId.ultimo-usado.json"
try {
  if (-not (Test-Path -LiteralPath $brandsDir)) {
    New-Item -ItemType Directory -Force -Path $brandsDir | Out-Null
  }
  if ([System.IO.Path]::GetFullPath($backupPath) -ne [System.IO.Path]::GetFullPath($ConfigPath)) {
    Copy-Item -LiteralPath $ConfigPath -Destination $backupPath -Force
    Info "Copia de seguridad: admin_panel\brands\$brandId.ultimo-usado.json"
  }
} catch {
  Warn 'No se pudo crear la copia de seguridad de la configuración.'
}

$appName = if ($config.branding.appName) { $config.branding.appName } else { 'Xtream Player' }
$server = if ($config.xtream.server) { $config.xtream.server } else { '(vacío: el usuario lo escribirá)' }
Info "Marca: $appName"
Info "Servidor grabado: $server"

# ------------------------------------------------- nombre bajo el icono
# Android (móvil y TV) e iOS toman el nombre visible del manifiesto/plist.
$xmlName = $appName -replace '&', '&amp;' -replace '<', '' -replace '>', '' -replace '"', ''
try {
  $manifestPath = Join-Path $projectRoot 'android\app\src\main\AndroidManifest.xml'
  $manifest = [System.IO.File]::ReadAllText($manifestPath)
  $manifest = $manifest -replace 'android:label="[^"]*"', ('android:label="' + $xmlName + '"')
  [System.IO.File]::WriteAllText($manifestPath, $manifest, (New-Object System.Text.UTF8Encoding($false)))

  $plistPath = Join-Path $projectRoot 'ios\Runner\Info.plist'
  if (Test-Path -LiteralPath $plistPath) {
    $plist = [System.IO.File]::ReadAllText($plistPath)
    $plist = $plist -replace '(?s)(<key>CFBundleDisplayName</key>\s*<string>)[^<]*(</string>)', ('${1}' + $xmlName + '${2}')
    [System.IO.File]::WriteAllText($plistPath, $plist, (New-Object System.Text.UTF8Encoding($false)))
  }
  Ok "Nombre bajo el icono: $xmlName"
} catch {
  Warn "No se pudo cambiar el nombre del icono: $($_.Exception.Message)"
}

# ------------------------------------------- banner del lanzador de TV
# Android TV y Fire TV muestran este banner (320x180). Si la marca lo trae
# incrustado en la configuración (campo "tvBanner"), se usa tal cual: así no
# hace falta Python. Si no, se intenta generar con Python.
$bannerTarget = Join-Path $projectRoot 'android\app\src\main\res\drawable\tv_banner.png'
$bannerData = if ($config.tvBanner) { "$($config.tvBanner)" } else { '' }
$bannerScript = Join-Path $projectRoot 'tools\make_tv_banner.py'
$pythonExe = $null

if ($bannerData -like 'data:image/*;base64,*') {
  try {
    $base64 = $bannerData.Substring($bannerData.IndexOf(',') + 1)
    [System.IO.File]::WriteAllBytes($bannerTarget, [System.Convert]::FromBase64String($base64))
    Ok 'Banner de TV aplicado desde la configuración.'
  } catch {
    Warn "El banner de TV de la configuración no es válido: $($_.Exception.Message)"
  }
} else {
  if ($PythonPath -and (Test-Path -LiteralPath $PythonPath)) {
    $pythonExe = $PythonPath
  } else {
    # Solo sirve un Python con Pillow: make_tv_banner.py la necesita.
    $tryPy = {
      param($exe)
      if (-not $exe -or -not (Test-Path -LiteralPath $exe)) { return $false }
      $prev = $ErrorActionPreference
      $ErrorActionPreference = 'Continue'
      & $exe -c "import PIL" *> $null
      $okPil = ($LASTEXITCODE -eq 0)
      $ErrorActionPreference = $prev
      return $okPil
    }
    foreach ($candidate in @('python', 'python3', 'py')) {
      $found = Get-Command $candidate -ErrorAction SilentlyContinue
      if (-not $found) { continue }
      if ($found.Source -like '*WindowsApps*') { continue }
      if (-not (& $tryPy $found.Source)) { continue }
      $pythonExe = $found.Source
      break
    }
    if (-not $pythonExe) {
      # Rutas habituales (Python del sistema, store o el que usa el proyecto).
      $guess = @(
        (Join-Path $env:LOCALAPPDATA 'Programs\Python'),
        'C:\Python313', 'C:\Python312', 'C:\Python311',
        (Join-Path $env:USERPROFILE '.dsh\dsh-runtimes\dsh-primary-runtime\dependencies\python')
      )
      foreach ($g in $guess) {
        foreach ($exe in @((Join-Path $g 'python.exe'))) {
          if (& $tryPy $exe) { $pythonExe = $exe; break }
        }
        if ($pythonExe) { break }
        if (Test-Path -LiteralPath $g) {
          $deep = Get-ChildItem -LiteralPath $g -Filter 'python.exe' -Recurse -ErrorAction SilentlyContinue |
            Select-Object -First 3
          foreach ($d in $deep) {
            if (& $tryPy $d.FullName) { $pythonExe = $d.FullName; break }
          }
        }
        if ($pythonExe) { break }
      }
    }
  }
  if ($pythonExe -and (Test-Path -LiteralPath $bannerScript)) {
    $previous = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    & $pythonExe $bannerScript $ConfigPath *> $null
    $bannerCode = $LASTEXITCODE
    $ErrorActionPreference = $previous
    if ($bannerCode -eq 0) {
      Ok 'Banner de TV generado con esta marca.'
    } else {
      Warn 'No se pudo generar el banner de TV (se conserva el actual).'
    }
  } else {
    Warn 'Sin banner en la configuración y sin Python: se conserva el banner actual.'
    Info 'Abre el panel (pestaña Marca) y pulsa «Generar banner de TV» para incrustarlo.'
  }
}

# ------------------------------------------------- identificador de la app
# Cada marca necesita su propio `applicationId` para poder convivir instalada
# en el mismo móvil o televisor. Se toma de -AppId o de "packageId" del panel.
# Si la configuración lo perdió, se deduce de la marca para que dos marcas NUNCA
# compartan identificador (eso haría que una reemplazase a la otra).
$packageId = if ($AppId) { $AppId } elseif ($config.packageId) { "$($config.packageId)" } else { '' }
if (-not $packageId -and $brandId) {
  $slug = ($brandId -replace '[^a-zA-Z0-9]', '').ToLower()
  if ($slug) {
    $packageId = "com.$slug.app"
    Warn "La configuración no trae «packageId»: se usa $packageId (deducido de la marca)."
    Warn 'Abre el panel de esa marca, revisa «Identificador de la aplicación» y guarda.'
  }
}
if ($packageId) {
  if ($packageId -notmatch '^[a-zA-Z][a-zA-Z0-9_]*(\.[a-zA-Z][a-zA-Z0-9_]*)+$') {
    Warn "El identificador '$packageId' no es válido (ejemplo: com.ibwtv.app). Se mantiene el actual."
  } else {
    $gradlePath = Join-Path $projectRoot 'android\app\build.gradle.kts'
    $gradle = [System.IO.File]::ReadAllText($gradlePath)
    $gradle = $gradle -replace 'applicationId = "[^"]*"', ('applicationId = "' + $packageId + '"')
    [System.IO.File]::WriteAllText($gradlePath, $gradle, (New-Object System.Text.UTF8Encoding($false)))
    Ok "Identificador Android: $packageId"
  }
} else {
  Info 'Identificador Android: el que ya tenga el proyecto.'
}

# ---------------------------------------------------------------- versión
$pubspecPath = Join-Path $projectRoot 'pubspec.yaml'
$appInfoPath = Join-Path $projectRoot 'lib\core\app_info.dart'
$pubspec = [System.IO.File]::ReadAllText($pubspecPath)
$match = [regex]::Match($pubspec, '(?m)^version:\s*([0-9]+\.[0-9]+\.[0-9]+)\+([0-9]+)')
if (-not $match.Success) { Fail 'No puedo leer la versión de pubspec.yaml.' }
$currentVersion = $match.Groups[1].Value
$currentBuild = [int]$match.Groups[2].Value

$targetVersion = $currentVersion
if ($Version) {
  $targetVersion = $Version
} elseif ($config.update.enabled -and $config.update.latestVersion -and
          ([version]$config.update.latestVersion -gt [version]$currentVersion)) {
  $targetVersion = $config.update.latestVersion
}

$targetBuild = $currentBuild
if ($targetVersion -ne $currentVersion) { $targetBuild = $currentBuild + 1 }
$targetVersion = ($targetVersion -replace '[^0-9\.]', '')
if ($targetVersion -notmatch '^[0-9]+\.[0-9]+\.[0-9]+$') {
  $targetVersion = "$targetVersion.0"
}

$pubspec = $pubspec -replace '(?m)^version:\s*[0-9]+\.[0-9]+\.[0-9]+\+[0-9]+', "version: $targetVersion+$targetBuild"
[System.IO.File]::WriteAllText($pubspecPath, $pubspec, (New-Object System.Text.UTF8Encoding($false)))

$appInfo = [System.IO.File]::ReadAllText($appInfoPath)
$appInfo = $appInfo -replace "const String kAppVersion = '[^']*';", "const String kAppVersion = '$targetVersion';"
$appInfo = $appInfo -replace "const String kAppBuild = '[^']*';", "const String kAppBuild = '$targetBuild';"
[System.IO.File]::WriteAllText($appInfoPath, $appInfo, (New-Object System.Text.UTF8Encoding($false)))
Ok "Versión del APK: $targetVersion+$targetBuild"

# --------------------------------------------------- configuración en el APK
$assetsPath = Join-Path $projectRoot 'assets\config.json'
$assetsFull = [System.IO.Path]::GetFullPath($assetsPath)
$configFull = [System.IO.Path]::GetFullPath($ConfigPath)
if ($assetsFull -eq $configFull) {
  Info 'La configuración ya está en assets\config.json.'
} else {
  Copy-Item -LiteralPath $ConfigPath -Destination $assetsPath -Force
  Ok 'Configuración copiada a assets\config.json'
}

if ($SkipBuild) { Ok 'Listo (sin compilar por -SkipBuild).'; exit 0 }

# ---------------------------------------------------------------- compilar
Push-Location $projectRoot
$previousPreference = $ErrorActionPreference
# El helper captura stderr como texto; solo el código de salida decide si
# Flutter falló. Los errores reales de archivos/scripts siguen deteniendo todo.
$ErrorActionPreference = 'Stop'
$logPath = Join-Path $projectRoot 'build\whitelabel-build.log'
try {
  New-Item -ItemType Directory -Force -Path (Split-Path -Parent $logPath) | Out-Null

  # A ZIP overlay does not remove files deleted from the new source tree.
  # Preserve only the two retired adapters as non-.kt backups before Gradle.
  $nativeDir = Join-Path $projectRoot 'android\app\src\main\kotlin\com\xtreamplayer\xtream_player'
  foreach ($required in @('VlcPlayerHost.kt', 'VlcTexturePlayer.kt', 'VlcStreamGateway.kt')) {
    if (-not (Test-Path -LiteralPath (Join-Path $nativeDir $required) -PathType Leaf)) {
      Fail "Actualizacion VLC incompleta: falta $required. Extrae el ZIP completo en una carpeta nueva."
    }
  }
  foreach ($obsolete in @('Media3TexturePlayer.kt', 'Media3PlayerHost.kt')) {
    $obsoletePath = Join-Path $nativeDir $obsolete
    if (Test-Path -LiteralPath $obsoletePath -PathType Leaf) {
      $backupName = $obsolete + '.bak-vlc-' + [Guid]::NewGuid().ToString('N')
      Rename-Item -LiteralPath $obsoletePath -NewName $backupName -ErrorAction Stop
      Warn "Fuente antigua retirada de compilacion: $obsolete (copia: $backupName)."
    }
  }

  Info 'Descargando dependencias...'
  $pubLog = Join-Path $projectRoot 'build\whitelabel-pub-get.log'
  $code = Invoke-FlutterLogged -Arguments @('pub', 'get') -LogPath $pubLog
  if ($code -ne 0) {
    Get-Content -LiteralPath $pubLog -Encoding UTF8 -ErrorAction SilentlyContinue | ForEach-Object { Write-Host $_ }
    Fail "No se pudieron descargar las dependencias. Detalle en $pubLog"
  }

  # Se borran APKs de compilaciones anteriores: antes se copiaban restos
  # viejos a dist\ (arm32/arm64 con versiones antiguas).
  Get-ChildItem -LiteralPath (Join-Path $projectRoot 'build\app\outputs\flutter-apk') -Filter '*.apk' -ErrorAction SilentlyContinue |
    Remove-Item -Force -ErrorAction Stop
  Info 'Compilando APK universal... (puede tardar unos minutos)'
  $code = Invoke-FlutterLogged -Arguments @('build', 'apk', '--release') -LogPath $logPath
  Get-Content -LiteralPath $logPath -Encoding UTF8 -ErrorAction SilentlyContinue | ForEach-Object { Write-Host $_ }
  if ($code -ne 0) { Fail "La compilación falló (código $code). Detalle en build\whitelabel-build.log" }

  # Preservar la universal antes de otra invocación de Gradle.
  $stagingDir = Join-Path $projectRoot 'build\whitelabel-apks'
  New-Item -ItemType Directory -Force -Path $stagingDir | Out-Null
  Get-ChildItem -LiteralPath $stagingDir -Filter '*.apk' -ErrorAction SilentlyContinue |
    Remove-Item -Force -ErrorAction Stop
  $universalApk = Join-Path $projectRoot 'build\app\outputs\flutter-apk\app-release.apk'
  if (-not (Test-Path -LiteralPath $universalApk)) { Fail 'Flutter terminó sin generar app-release.apk.' }
  Copy-Item -LiteralPath $universalApk -Destination $stagingDir -Force -ErrorAction Stop
  Ok 'APK universal generado y protegido antes de compilar por arquitectura.'

  # APKs por arquitectura SIEMPRE: si no se generan, dist\ reutiliza los de
  # una compilacion anterior y se reparten versiones viejas.
  Info 'Compilando APK por arquitectura...'
  $splitLog = Join-Path $projectRoot 'build\whitelabel-split-abi.log'
  Info "Este segundo paso también puede tardar varios minutos. Registro: $splitLog"
  $code = Invoke-FlutterLogged -Arguments @('build', 'apk', '--release', '--split-per-abi') -LogPath $splitLog
  Get-Content -LiteralPath $splitLog -Encoding UTF8 -ErrorAction SilentlyContinue | ForEach-Object { Write-Host $_ }
  if ($code -ne 0) {
    Warn "Falló la compilación por arquitectura (código $code); se entrega solo la universal. Detalle en $splitLog"
  } else {
    foreach ($abi in @('armeabi-v7a', 'arm64-v8a', 'x86_64')) {
      $splitApk = Join-Path $projectRoot "build\app\outputs\flutter-apk\app-$abi-release.apk"
      if (Test-Path -LiteralPath $splitApk) {
        Copy-Item -LiteralPath $splitApk -Destination $stagingDir -Force -ErrorAction Stop
      } else { Warn "No se encontró el APK $abi; no se reutilizará uno anterior." }
    }
  }
} finally {
  $ErrorActionPreference = $previousPreference
  Pop-Location
}

# ---------------------------------------------------------------- entregar
$distDir = Join-Path $projectRoot 'dist'
New-Item -ItemType Directory -Force -Path $distDir | Out-Null
$safeName = ($appName -replace '[^A-Za-z0-9\-_]', '-') -replace '-+', '-'
if ([string]::IsNullOrWhiteSpace($safeName)) { $safeName = 'app' }

# No dejar variantes anteriores de esta misma versión si hoy falló split ABI.
foreach ($suffix in @('', '-arm32', '-arm64', '-x86_64')) {
  $oldTarget = Join-Path $distDir "$safeName-$targetVersion$suffix.apk"
  if (Test-Path -LiteralPath $oldTarget) { Remove-Item -LiteralPath $oldTarget -Force -ErrorAction Stop }
}
$apkDir = $stagingDir
# Solo APK de release: los de depuración son enormes y no sirven para repartir.
$apks = Get-ChildItem -LiteralPath $apkDir -Filter '*.apk' -ErrorAction SilentlyContinue |
  Where-Object { $_.Name -notlike '*debug*' }
if (-not $apks) { Fail 'No se generó ningún APK de release.' }

foreach ($apk in $apks) {
  $abi = ''
  if ($apk.Name -match 'arm64-v8a') { $abi = '-arm64' }
  elseif ($apk.Name -match 'armeabi-v7a') { $abi = '-arm32' }
  elseif ($apk.Name -match 'x86_64') { $abi = '-x86_64' }
  $target = Join-Path $distDir "$safeName-$targetVersion$abi.apk"
  Copy-Item -LiteralPath $apk.FullName -Destination $target -Force
  $mb = [math]::Round($apk.Length / 1MB, 1)
  Ok "APK: $target ($mb MB)"
}

Write-Host ''
Ok 'Terminado. Reparte los APK de la carpeta dist\.'
Info 'Recuerda: los usuarios deben permitir "instalar apps de origen desconocido".'
exit 0
