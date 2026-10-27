#requires -Version 5.1
[CmdletBinding()]
param(
  [string]$KeystorePath = (Join-Path $env:USERPROFILE 'AlphaVisionKeys\alphavision-release.jks'),
  [ValidatePattern('^[A-Za-z0-9_-]+$')][string]$KeyAlias = 'alphavision'
)
$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false
$root = Split-Path -Parent $PSScriptRoot
$propertiesPath = Join-Path $root 'android\key.properties'
$tempKey = $null
$tempProperties = $null
$password = $null
$confirm = $null
$exitCode = 0
$secretName = 'NOVA_SIGNING_' + [guid]::NewGuid().ToString('N')

function Read-PlainSecret([string]$Prompt) {
  $secure = Read-Host $Prompt -AsSecureString
  $pointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
  try { return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($pointer) }
  finally {
    [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($pointer)
    $secure.Dispose()
  }
}
function Invoke-KeytoolChecked([string]$Tool, [string[]]$ToolArguments) {
  $previous = $ErrorActionPreference
  $PSNativeCommandUseErrorActionPreference = $false
  try {
    # keytool normally prints certificate information and warnings on stderr.
    $ErrorActionPreference = 'Continue'
    # Work around JDK localized certificate formatting errors (es locale).
    $javaLocale = @('-J-Duser.language=en', '-J-Duser.country=US')
    & $Tool @javaLocale @ToolArguments 2>&1 | ForEach-Object {
      $message = if ($_ -is [System.Management.Automation.ErrorRecord]) { $_.Exception.Message } else { $_.ToString() }
      if ($message -and $message -ne 'System.Management.Automation.RemoteException') { Write-Host $message }
    }
    return $LASTEXITCODE
  } finally { $ErrorActionPreference = $previous }
}
function Escape-Property([string]$Value) {
  # Java properties escapes, including spaces and punctuation in passwords.
  return $Value.Replace('\', '\\').Replace("`r", '\r').Replace("`n", '\n').Replace("`t", '\t').Replace(' ', '\ ').Replace('=', '\=').Replace(':', '\:').Replace('#', '\#').Replace('!', '\!')
}
try {
  if (-not (Test-Path -LiteralPath (Join-Path $root 'pubspec.yaml'))) {
    throw 'Coloca este script en la carpeta tools de tu proyecto Flutter.'
  }
  $gradle = Get-Content -LiteralPath (Join-Path $root 'android\app\build.gradle.kts') -Raw
  if ($gradle -notmatch 'signingConfigs.getByName\("production"\)' -or $gradle -match 'signingConfigs.getByName\("debug"\)') {
    throw 'Primero aplica la configuracion Gradle de firma de produccion. Consulta GUIA_FIRMA_ANDROID.md. No se creara ninguna clave.'
  }
  $KeystorePath = [IO.Path]::GetFullPath($KeystorePath)
  if ((Test-Path -LiteralPath $propertiesPath) -or (Test-Path -LiteralPath $KeystorePath)) {
    throw 'Ya existe key.properties o la clave de destino. No se sobrescribe nada. Conserva tu firma existente; revisa GUIA_FIRMA_ANDROID.md.'
  }
  $keytool = $null
  $found = Get-Command keytool.exe -CommandType Application -ErrorAction SilentlyContinue
  if ($found) { $keytool = $found.Source }
  $candidates = @()
  if ($env:JAVA_HOME) { $candidates += Join-Path $env:JAVA_HOME 'bin\keytool.exe' }
  if ($env:ProgramFiles) { $candidates += Join-Path $env:ProgramFiles 'Android\Android Studio\jbr\bin\keytool.exe' }
  if ($env:LOCALAPPDATA) { $candidates += Join-Path $env:LOCALAPPDATA 'Programs\Android Studio\jbr\bin\keytool.exe' }
  if (-not $keytool) {
    foreach ($candidate in $candidates) {
      if (Test-Path -LiteralPath $candidate) { $keytool = $candidate; break }
    }
  }
  if (-not $keytool) { throw 'No encuentro keytool. Instala Android Studio/JDK o configura JAVA_HOME y vuelve a ejecutar.' }

  Write-Host ''
  Write-Host 'NOVA - crear firma de produccion' -ForegroundColor Cyan
  Write-Host "Clave: $KeystorePath"
  Write-Host "Configuracion: $propertiesPath"
  Write-Host 'Si ya distribuiste/publicaste con otra clave, cancela y conserva esa clave.' -ForegroundColor Yellow
  Write-Host 'Este asistente NO compila, publica ni sube tus secretos a Internet.'
  if ((Read-Host 'Crear una firma NUEVA? Escribe CREAR para continuar') -cne 'CREAR') {
    throw 'Cancelado sin crear una firma.'
  }
  $password = Read-PlainSecret 'Contrasena nueva (minimo 12 caracteres ASCII, sin espacios)'
  $confirm = Read-PlainSecret 'Repite la contrasena'
  if ($password -cne $confirm) { throw 'Las contrasenas no coinciden. No se creo la clave.' }
  if ($password.Length -lt 12 -or $password -match '[^\x21-\x7E]') {
    throw 'Usa al menos 12 caracteres: letras, numeros y simbolos ASCII, sin espacios ni tildes.'
  }
  $confirm = $null
  New-Item -ItemType Directory -Force -Path (Split-Path -Parent $KeystorePath) | Out-Null
  $tempKey = Join-Path (Split-Path -Parent $KeystorePath) ('.nova-' + [guid]::NewGuid().ToString('N') + '.jks')
  $tempProperties = Join-Path $root ('android\.nova-signing-' + [guid]::NewGuid().ToString('N') + '.tmp')
  # Password is NOT placed in command-line arguments. The temporary child-process
  # environment variable is deleted in finally; key.properties is local plaintext.
  [Environment]::SetEnvironmentVariable($secretName, $password, 'Process')
  $code = Invoke-KeytoolChecked -Tool $keytool -ToolArguments @('-genkeypair', '-v', '-keystore', $tempKey, '-storetype', 'JKS', '-keyalg', 'RSA', '-keysize', '2048', '-validity', '10000', '-alias', $KeyAlias, '-dname', 'CN=Alpha Vision Android Release', '-storepass:env', $secretName, '-keypass:env', $secretName)
  if ($code -ne 0 -or -not (Test-Path -LiteralPath $tempKey)) { throw 'keytool no pudo crear la clave. No se escribio key.properties.' }
  # Preserve the generated private key BEFORE any certificate-display check.
  # File.Move never overwrites an existing destination.
  [IO.File]::Move($tempKey, $KeystorePath)
  $tempKey = $null
  # No verbose X509/date formatting: only verify the store and requested alias.
  $code = Invoke-KeytoolChecked -Tool $keytool -ToolArguments @('-list', '-keystore', $KeystorePath, '-alias', $KeyAlias, '-storepass:env', $secretName)
  if ($code -ne 0) { throw 'No se pudo verificar el almacen. La clave se conservo en la ruta final; no la borres. Consulta la guia para completar key.properties.' }

  $text = "storeFile=$(Escape-Property ($KeystorePath.Replace('\', '/')))`r`nstorePassword=$(Escape-Property $password)`r`nkeyAlias=$(Escape-Property $KeyAlias)`r`nkeyPassword=$(Escape-Property $password)`r`n"
  [IO.File]::WriteAllText($tempProperties, $text, (New-Object Text.UTF8Encoding($false)))
  $text = $null
  [IO.File]::Move($tempProperties, $propertiesPath)
  $tempProperties = $null
  Write-Host ''
  Write-Host 'LISTO: clave creada, almacen verificado y key.properties configurado.' -ForegroundColor Green
  Write-Host 'La misma contrasena se uso para el almacen y para la clave.'
  Write-Host 'Ahora ejecuta admin_panel\Generar APK.cmd como siempre.'
  Write-Host 'Conserva dos copias cifradas del JKS y guarda la contrasena por separado.' -ForegroundColor Yellow
  Write-Host 'No compartas key.properties ni el JKS. Las versiones debug anteriores pueden requerir desinstalacion.'
} catch {
  # Do not echo exception/native arguments that could contain secret values.
  Write-Host ('ERROR: ' + $_.Exception.Message) -ForegroundColor Red
  if (Test-Path -LiteralPath $KeystorePath) {
    Write-Host 'Existe un almacen en la ruta indicada: CONSERVALO. No lo borres para volver a empezar.' -ForegroundColor Yellow
  }
  $exitCode = 1
} finally {
  [Environment]::SetEnvironmentVariable($secretName, $null, 'Process')
  # Never delete a private-key file, even if keytool failed after writing one.
  if ($tempKey -and (Test-Path -LiteralPath $tempKey)) {
    Write-Host "Archivo de clave temporal conservado para revision: $tempKey" -ForegroundColor Yellow
  }
  if ($tempProperties -and (Test-Path -LiteralPath $tempProperties)) {
    Remove-Item -LiteralPath $tempProperties -Force -ErrorAction SilentlyContinue
  }
  $password = $null; $confirm = $null
}
exit $exitCode
