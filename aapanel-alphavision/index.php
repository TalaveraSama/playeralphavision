<?php
/**
 * NOVA TV · panel de administración (para aaPanel, con PHP).
 *
 * - Guarda la configuración en config.json DEL SERVIDOR (no descarga nada).
 * - Sube los APK a updates/ y numera la versión siguiente solo (1.2.0 → 1.2.1).
 * - Publica el bloque "update" para que las apps instaladas avisen y descarguen.
 *
 * Sube esta carpeta tal cual a tu sitio:  www/tusitio/aapanel-novatv
 * Necesita permisos de escritura (775) para config.json y updates/.
 */

declare(strict_types=1);

$DIR     = __DIR__;
$CONFIG  = $DIR . '/config.json';
$UPDATES = $DIR . '/updates';
/* ------------------------------------------------------------- seguridad */
$PASSWORD  = 'nova-2026';   // <-- CAMBIA ESTA CLAVE
$SESSION_H = 12;            // horas que dura la sesión abierta
$LOCK      = $DIR . '/panel.lock';

session_set_cookie_params([
  'httponly' => true,
  'samesite' => 'Strict',
  'secure'   => (!empty($_SERVER['HTTPS']) && $_SERVER['HTTPS'] !== 'off'),
]);
session_name('novapanel');
session_start();
header('X-Robots-Tag: noindex, nofollow');
header('X-Frame-Options: DENY');
header('Referrer-Policy: no-referrer');

function nova_logged(int $hours): bool {
  if (empty($_SESSION['nova_ok'])) return false;
  if ((time() - (int)($_SESSION['nova_time'] ?? 0)) > $hours * 3600) return false;
  $_SESSION['nova_time'] = time();
  return true;
}

function nova_login_page(string $error = ''): void {
  $e = $error !== '' ? '<p class="err">' . htmlspecialchars($error, ENT_QUOTES) . '</p>' : '';
  $form = <<<'HTML'
<!DOCTYPE html>
<html lang="es"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>NOVA TV · acceso</title>
<style>
 body{margin:0;height:100vh;display:flex;align-items:center;justify-content:center;background:#0A0F1A;color:#fff;
      font:15px/1.45 -apple-system,Segoe UI,Roboto,Arial,sans-serif}
 .card{background:#141D2E;border:1px solid #25324a;border-radius:16px;padding:28px 26px;width:320px}
 .logo{font-weight:900;letter-spacing:2px;color:#2FE0C0;font-size:22px;margin-bottom:14px}
 label{display:block;font-size:12px;color:#93A1B8;margin-bottom:6px}
 input{width:100%;box-sizing:border-box;background:#0d1524;color:#fff;border:1px solid #25324a;border-radius:9px;padding:11px}
 button{margin-top:14px;width:100%;border:0;border-radius:9px;background:#2FE0C0;color:#06121a;font-weight:800;padding:12px;cursor:pointer}
 .err{color:#F2564B;font-size:13px;margin:0 0 10px}
</style></head><body>
<form class="card" method="post" autocomplete="off">
  <div class="logo">NOVA</div>
  ERR
  <label>Clave del panel</label>
  <input type="password" name="pass" autofocus required>
  <input type="hidden" name="do" value="login">
  <button type="submit">Entrar</button>
</form></body></html>
HTML;
  echo str_replace('ERR', $e, $form);
}

$fails = ['n' => 0, 't' => 0];
if (is_file($LOCK)) {
  $tmp = json_decode((string)file_get_contents($LOCK), true);
  if (is_array($tmp)) $fails = array_replace($fails, $tmp);
}
$blocked = ((int)$fails['n'] >= 6) && (time() - (int)$fails['t'] < 900);

$loginError = '';
if ($blocked) {
  $loginError = 'Demasiados intentos. Espera 15 minutos.';
} elseif (($_POST['do'] ?? '') === 'login') {
  usleep(500000);
  if (hash_equals($PASSWORD, (string)($_POST['pass'] ?? ''))) {
    file_put_contents($LOCK, json_encode(['n' => 0, 't' => 0]), LOCK_EX);
    session_regenerate_id(true);
    $_SESSION['nova_ok'] = true;
    $_SESSION['nova_time'] = time();
    header('Location: ' . strtok((string)($_SERVER['REQUEST_URI'] ?? './'), '?'));
    exit;
  }
  $fails['n'] = ((int)$fails['n']) + 1;
  $fails['t'] = time();
  file_put_contents($LOCK, json_encode($fails), LOCK_EX);
  $loginError = 'Clave incorrecta.';
}

if (($_GET['do'] ?? '') === 'logout') {
  $_SESSION = [];
  session_destroy();
  header('Location: ./');
  exit;
}

if (!is_dir($UPDATES)) { @mkdir($UPDATES, 0775, true); }

function nova_default(): array {
  return [
    'schemaVersion' => 1,
    'remoteConfigUrl' => '',
    'packageId' => 'com.nova.ott',
    'tvBanner' => '',
    'tvBannerName' => 'Alpha Vision',
    'branding' => [
      'appName' => 'NOVA', 'logoUrl' => '', 'tagline' => 'Tu televisión, donde quieras',
      'primaryColor' => '#2FE0C0', 'loginBackgrounds' => [], 'loginBackgroundSeconds' => 8,
      'loginTitle' => 'Inicia sesión', 'loginSubtitle' => 'Introduce tu usuario y contraseña',
      'loginFooter' => '', 'supportUrl' => '', 'whatsappUrl' => '', 'telegramUrl' => '',
      'hideServerField' => true, 'heroSource' => 'mixed', 'heroMode' => 'auto', 'heroCategories' => '', 'heroItems' => '', 'showLiveSection' => true,
    ],
    'theme' => [
      'active' => 'nova3',
      'available' => [[
        'id' => 'nova', 'name' => 'NOVA', 'layout' => 'nova', 'primaryColor' => '#2FE0C0',
        'backgroundColor' => '#0A0F1A', 'surfaceColor' => '#141D2E', 'textColor' => '#FFFFFF',
        'brightness' => 'dark', 'useHero' => true, 'cardRadius' => 14,
        'lightButtons' => false, 'heroTint' => '#0E1626',
      ], [
        'id' => 'nova2', 'name' => 'Nova2', 'layout' => 'nova', 'primaryColor' => '#A78BFA',
        'backgroundColor' => '#08070E', 'surfaceColor' => '#171322', 'textColor' => '#F8F7FC',
        'brightness' => 'dark', 'useHero' => true, 'cardRadius' => 8,
        'lightButtons' => true, 'heroTint' => '#251044',
      ], [
        'id' => 'nova3', 'name' => 'Nova3', 'layout' => 'nova', 'primaryColor' => '#456BFF',
        'backgroundColor' => '#000000', 'surfaceColor' => '#0D0D0F', 'textColor' => '#F5F5F7',
        'brightness' => 'dark', 'useHero' => true, 'cardRadius' => 3,
        'lightButtons' => false, 'heroTint' => '#090909',
      ], [
        'id' => 'ambar', 'name' => 'Ámbar', 'layout' => 'rows', 'primaryColor' => '#F0A732',
        'backgroundColor' => '#0D0B07', 'surfaceColor' => '#1A1610', 'textColor' => '#FFF6E8',
        'brightness' => 'dark', 'useHero' => true, 'cardRadius' => 14,
        'lightButtons' => false, 'heroTint' => '#191007',
      ]],
    ],
    'xtream' => ['server' => '', 'userAgent' => 'AlphaVision-Player', 'streamToken' => ''],
    'usageReminder' => [
      'enabled' => true, 'intervalMinutes' => 240, 'countdownSeconds' => 10,
      'title' => 'Consejos',
      'message' => 'Ya usaste la app por {hours} horas. Te recomendamos descansar un poco por tu salud. La reproducción se cerrará después de {seconds} segundos. Pulsa «Continuar usando» si quieres seguir.',
      'buttonLabel' => 'Continuar usando',
    ],
    'ads' => [
      'enabled' => false, 'rotationSeconds' => 12, 'inPlayer' => false, 'inPlayerSeconds' => 0,
      'placements' => [
        'banner' => ['enabled' => true, 'maxPerHour' => 12],
        'interstitial' => ['enabled' => true, 'maxPerHour' => 3],
        'preroll' => ['enabled' => false, 'maxPerHour' => 6],
        'overlay' => ['enabled' => true, 'maxPerHour' => 2],
      ],
      'ads' => [],
    ],
    'update' => [
      'enabled' => false, 'latestVersion' => '1.2.0', 'minVersion' => '1.0.0',
      'apkUrl' => '', 'apkUrlArm32' => '', 'apkUrlArm64' => '', 'apkUrlX64' => '',
      'changelog' => '', 'forceUpdate' => false,
    ],
    'features' => [
      'search' => true, 'favorites' => true, 'epg' => true,
      'allowThemeSwitch' => true, 'showAccountInfo' => true, 'vlcPlayer' => true,
    ],
  ];
}

// Las listas de temas se migran por ID, nunca por posición: un config antiguo
// puede tener solo NOVA/Ámbar, en otro orden, o temas de marca personalizados.
function nova_normalize(array $data): array {
  if (isset($data['theme']) && !is_array($data['theme'])) $data['theme'] = [];
  $default = nova_default();
  $config = array_replace_recursive($default, $data);
  $presets = [];
  foreach ($default['theme']['available'] as $theme) $presets[$theme['id']] = $theme;
  $saved = $data['theme']['available'] ?? [];
  $themes = [];
  if (is_array($saved)) {
    foreach ($saved as $theme) {
      if (!is_array($theme) || !is_string($theme['id'] ?? null)) continue;
      $id = trim($theme['id']);
      if ($id === '' || isset($themes[$id])) continue;
      $theme['id'] = $id;
      $themes[$id] = array_replace($presets[$id] ?? [], $theme);
    }
  }
  foreach ($presets as $id => $theme) {
    if (!isset($themes[$id])) $themes[$id] = $theme;
  }
  // Estos IDs identifican armazones que requieren el layout NOVA en la APK.
  foreach (['nova2', 'nova3'] as $id) $themes[$id]['layout'] = 'nova';
  $config['theme']['available'] = array_values($themes);
  $active = $data['theme']['active'] ?? $default['theme']['active'];
  $config['theme']['active'] = is_string($active) && isset($themes[$active])
      ? $active : $default['theme']['active'];
  return $config;
}

function nova_load(string $file): array {
  if (!is_file($file)) return nova_normalize([]);
  $data = json_decode((string)file_get_contents($file), true);
  return nova_normalize(is_array($data) ? $data : []);
}

function nova_save(string $file, array $data): bool {
  $json = json_encode(nova_normalize($data), JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
  return $json !== false && file_put_contents($file, $json . "\n", LOCK_EX) !== false;
}

function nova_bump(string $version): string {
  $clean = preg_replace('/[^0-9.]/', '', $version);
  $parts = array_values(array_filter(explode('.', $clean !== '' ? $clean : '1.0.0'), 'strlen'));
  if (!$parts) $parts = ['1', '0', '0'];
  while (count($parts) < 3) $parts[] = '0';
  $last = count($parts) - 1;
  $parts[$last] = (string)(((int)$parts[$last]) + 1);
  return implode('.', array_slice($parts, 0, 3));
}

function nova_base(): string {
  $https = (!empty($_SERVER['HTTPS']) && $_SERVER['HTTPS'] !== 'off');
  $host  = $_SERVER['HTTP_HOST'] ?? 'localhost';
  $dir   = rtrim(str_replace('\\', '/', dirname($_SERVER['SCRIPT_NAME'] ?? '/')), '/');
  return ($https ? 'https' : 'http') . '://' . $host . $dir;
}

function nova_urls(): array {
  $base = nova_base();
  return ['config' => $base . '/config.json', 'updates' => $base . '/updates/', 'panel' => nova_base() . '/'];
}

function nova_out(array $payload): void {
  header('Content-Type: application/json; charset=utf-8');
  echo json_encode($payload, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
  exit;
}

function nova_list(string $dir): array {
  $out = [];
  foreach (glob($dir . '/*.apk') ?: [] as $file) {
    $name = basename($file);
    preg_match('/(\d+\.\d+\.\d+)/', $name, $m);
    $out[] = [
      'file' => $name, 'version' => $m[1] ?? '',
      'size' => round(filesize($file) / 1048576, 1),
      'date' => date('d/m/Y H:i', (int)filemtime($file)),
    ];
  }
  usort($out, static fn($a, $b) => strcmp($b['date'], $a['date']));
  return $out;
}

function nova_log(string $msg): void {
  $line = date('Y-m-d H:i:s') . '  ' . $msg . "\n";
  @file_put_contents(__DIR__ . '/activity.log', $line, FILE_APPEND | LOCK_EX);
}

/* --------------------------------------------------------------- API */
$action = (string)($_GET['action'] ?? $_POST['action'] ?? '');
if ($action !== '') {
  if (!nova_logged($SESSION_H)) {
    http_response_code(401);
    nova_out(['ok' => false, 'error' => 'sesión no iniciada']);
  }

  $config = nova_load($CONFIG);

  switch ($action) {
    case 'log':
      $lines = @file(__DIR__ . '/activity.log', FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES);
      nova_out(['ok' => true, 'log' => array_slice(array_reverse($lines ?: []), 0, 30)]);

    case 'restore':
      if (empty($_FILES['config']['tmp_name'])) nova_out(['ok' => false, 'error' => 'No llegó el archivo']);
      $raw  = (string)@file_get_contents((string)$_FILES['config']['tmp_name']);
      $data = json_decode($raw, true);
      if (!is_array($data)) nova_out(['ok' => false, 'error' => 'El archivo no es un config.json válido']);
      if (!nova_save($CONFIG, $data)) nova_out(['ok' => false, 'error' => 'No se pudo guardar config.json (revisa permisos)']);
      nova_log('Configuración restaurada desde archivo');
      nova_out(['ok' => true]);

    case 'load':
      nova_out(['ok' => true, 'config' => $config, 'versions' => nova_list($UPDATES), 'urls' => nova_urls()]);

    case 'save':
      $body = json_decode((string)file_get_contents('php://input'), true);
      if (!is_array($body)) nova_out(['ok' => false, 'error' => 'JSON no válido']);
      $config = nova_normalize($body);
      if (!nova_save($CONFIG, $config)) nova_out(['ok' => false, 'error' => 'No se pudo guardar config.json (revisa permisos)']);
      nova_log('Configuración guardada');
      nova_out(['ok' => true, 'urls' => nova_urls()]);

    case 'upload':
      if (empty($_FILES['apk']['tmp_name'])) nova_out(['ok' => false, 'error' => 'No llegó ningún archivo']);
      $apk = $_FILES['apk'];
      if (!preg_match('/\.apk$/i', (string)$apk['name'])) nova_out(['ok' => false, 'error' => 'Tiene que ser un .apk']);
      if ((int)$apk['size'] < 1048576) nova_out(['ok' => false, 'error' => 'El APK parece incompleto']);

      $first = empty($config['update']['apkUrlArm32'])
        && empty($config['update']['apkUrlArm64'])
        && empty($config['update']['apkUrl']);
      $version = $first
        ? nova_bump((string)($config['update']['latestVersion'] ?? '1.2.0'))
        : (string)($config['update']['latestVersion'] ?? '1.2.0');
      $target  = $UPDATES . '/nova-' . $version . '-' . bin2hex(random_bytes(3)) . '.apk';
      if (!move_uploaded_file($apk['tmp_name'], $target)) {
        nova_out(['ok' => false, 'error' => 'No se pudo guardar (revisa permisos de updates/)']);
      }

      // Arquitectura del APK: los nombres de carpeta del ZIP van en claro.
      $head = (string)@file_get_contents($target, false, null, 0, 2097152);
      $is64 = strpos($head, 'lib/arm64-v8a/') !== false;
      $is32 = strpos($head, 'lib/armeabi-v7a/') !== false;
      $isX64 = strpos($head, 'lib/x86_64/') !== false;
      $url  = nova_urls()['updates'] . basename($target);

      if ($is64 && !$is32 && !$isX64) {
        $config['update']['apkUrlArm64'] = $url;
        $slot = '64 bits';
      } elseif ($is32 && !$is64 && !$isX64) {
        $config['update']['apkUrlArm32'] = $url;
        $slot = '32 bits';
      } elseif ($isX64 && !$is64 && !$is32) {
        $config['update']['apkUrlX64'] = $url;
        $slot = 'x86_64';
      } else {
        $config['update']['apkUrl'] = $url;
        $slot = 'universal';
      }

      $config['update']['enabled']       = true;
      $config['update']['latestVersion'] = $version;
      nova_save($CONFIG, $config);
      nova_log('Subido y publicado ' . $version . ' (' . $slot . ')');
      nova_out(['ok' => true, 'version' => $version, 'slot' => $slot, 'file' => basename($target), 'versions' => nova_list($UPDATES)]);

    case 'publish':
      $body = json_decode((string)file_get_contents('php://input'), true);
      $file = basename((string)($body['file'] ?? ''));
      if ($file === '' || !is_file($UPDATES . '/' . $file)) nova_out(['ok' => false, 'error' => 'APK no encontrado']);
      preg_match('/(\d+\.\d+\.\d+)/', $file, $m);
      $url = nova_urls()['updates'] . $file;

      // Arquitectura del APK: primero por el nombre del archivo y, si no queda
      // claro, leyendo las carpetas lib/ del propio zip.
      $lower = strtolower($file);
      $is64 = strpos($lower, 'arm64') !== false;
      $is32 = strpos($lower, 'arm32') !== false || strpos($lower, 'armeabi') !== false;
      $isX64 = strpos($lower, 'x86_64') !== false;
      if (!$is64 && !$is32 && !$isX64) {
        $head = (string)@file_get_contents($UPDATES . '/' . $file, false, null, 0, 2097152);
        $is64 = strpos($head, 'lib/arm64-v8a/') !== false;
        $is32 = strpos($head, 'lib/armeabi-v7a/') !== false;
        $isX64 = strpos($head, 'lib/x86_64/') !== false;
      }

      $slot = 'universal';
      if ($is64 && !$is32 && !$isX64) {
        $config['update']['apkUrlArm64'] = $url;
        $slot = '64 bits';
      } elseif ($is32 && !$is64 && !$isX64) {
        $config['update']['apkUrlArm32'] = $url;
        $slot = '32 bits';
      } elseif ($isX64 && !$is64 && !$is32) {
        $config['update']['apkUrlX64'] = $url;
        $slot = 'x86_64';
      } else {
        $config['update']['apkUrl'] = $url;
      }

      $config['update']['enabled']       = true;
      $config['update']['latestVersion'] = (string)($body['latestVersion'] ?? ($m[1] ?? $config['update']['latestVersion']));
      $config['update']['minVersion']    = (string)($body['minVersion'] ?? $config['update']['minVersion']);
      $config['update']['changelog']     = (string)($body['changelog'] ?? $config['update']['changelog']);
      $config['update']['forceUpdate']   = (bool)($body['forceUpdate'] ?? false);
      nova_save($CONFIG, $config);
      nova_log('Publicado ' . basename($file) . ' (' . $slot . ')');
      nova_out(['ok' => true, 'slot' => $slot, 'update' => $config['update']]);

    case 'delete':
      $body = json_decode((string)file_get_contents('php://input'), true);
      $file = basename((string)($body['file'] ?? ''));
      $path = $UPDATES . '/' . $file;
      if ($file !== '' && is_file($path)) unlink($path);
      nova_log('Borrado ' . $file);
      nova_out(['ok' => true, 'versions' => nova_list($UPDATES)]);

    default:
      nova_out(['ok' => false, 'error' => 'acción desconocida']);
  }
}

if (!nova_logged($SESSION_H)) { nova_login_page($loginError); exit; }
?>
<!DOCTYPE html>
<html lang="es">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Alpha Vision · Panel</title>
<style>
  :root{--accent:#2FE0C0;--bg:#0A0F1A;--surface:#141D2E;--surface2:#1B2740;--text:#fff;--muted:#93A1B8;--line:#25324a}
  *{box-sizing:border-box}
  body{margin:0;background:var(--bg);color:var(--text);font:14px/1.45 -apple-system,Segoe UI,Roboto,Arial,sans-serif}
  header{display:flex;align-items:center;gap:14px;padding:13px 18px;border-bottom:1px solid var(--line);flex-wrap:wrap}
  .logo{font-weight:900;letter-spacing:2px;color:var(--accent);font-size:20px}
  .sp{flex:1}
  button{cursor:pointer;border-radius:9px;border:1px solid var(--line);background:var(--surface2);color:var(--text);
         padding:9px 14px;font-weight:600;font-size:13px}
  button.primary{background:var(--accent);border-color:var(--accent);color:#06121a;font-weight:800}
  button.mini{padding:4px 9px;font-size:12px}
  main{padding:16px 18px;max-width:1150px}
  nav{display:flex;gap:6px;flex-wrap:wrap;margin-bottom:14px}
  nav button{border-radius:999px}
  nav button.on{background:var(--accent);border-color:var(--accent);color:#06121a}
  section{background:var(--surface);border:1px solid var(--line);border-radius:14px;padding:16px 18px;margin-bottom:14px}
  section h2{margin:0 0 12px;font-size:14px;letter-spacing:.4px;text-transform:uppercase;color:var(--muted)}
  .row{display:grid;grid-template-columns:1fr 1fr;gap:12px}
  .row3{display:grid;grid-template-columns:1fr 1fr 1fr;gap:12px}
  label{display:block;font-size:12px;color:var(--muted);margin:10px 0 4px}
  input,select,textarea{width:100%;background:#0d1524;color:var(--text);border:1px solid var(--line);
        border-radius:9px;padding:9px 10px;font:inherit}
  input[type=color]{height:38px;padding:2px}
  textarea{min-height:64px}
  .check{display:flex;align-items:center;gap:8px;margin-top:10px}
  .check input{width:auto}
  .hint{font-size:12px;color:var(--muted);margin-top:8px}
  code{background:#0d1524;border:1px solid var(--line);border-radius:6px;padding:2px 7px;font-size:12px;word-break:break-all}
  table{width:100%;border-collapse:collapse;margin-top:10px;font-size:13px}
  th,td{text-align:left;padding:8px 6px;border-bottom:1px solid var(--line)}
  th{color:var(--muted);font-weight:600;font-size:12px}
  .pill{display:inline-block;padding:3px 9px;border-radius:999px;background:var(--surface2);color:var(--muted);font-size:11px}
  .ok{color:var(--accent)}
  .prev{max-height:64px;margin:8px 0;border-radius:8px;background:var(--surface2);object-fit:contain}
  .ad{border:1px dashed var(--line);border-radius:12px;padding:12px;margin-top:12px}
  .ad h3{margin:0 0 6px;font-size:13px;color:var(--accent)}
</style>
</head>
<body>
<header>
  <div class="logo">NOVA</div>
  <div>Panel <span class="pill">config.json + updates en el servidor</span></div>
  <div class="sp"></div>
  <button onclick="downloadJson()">Descargar config.json</button>
  <button id="btnSave" class="primary">Guardar en el servidor</button>
  <a href="?do=logout" style="color:var(--muted);font-size:12px;margin-left:8px">Salir</a>
</header>

<main>
  <nav id="tabs"></nav>
  <div class="hint" id="urls"></div>
  <div id="form"></div>
</main>

<script>
const q = s => '?action=' + s;
let S = null, VERSIONS = [], URLS = {}, tab = 'marca';

const TABS = [['dashboard','Panel'],['marca','Marca'],['imagenes','Imágenes'],['diseno','Diseño'],['anuncios','Anuncios'],['avisos','Avisos y descanso'],['update','Versión y APK']];
const get = p => p.split('.').reduce((a,k)=>a==null?a:a[k], S);
const set = (p,v) => { const ks=p.split('.'); let o=S; for(let i=0;i<ks.length-1;i++){ if(o[ks[i]]==null)o[ks[i]]={}; o=o[ks[i]]; } o[ks[ks.length-1]]=v; };
const esc = s => String(s==null?'':s).replace(/[&<>"]/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;'}[c]));
const inp = (l,p,t) => `<div><label>${l}</label><input type="${t||'text'}" data-p="${p}" value="${esc(get(p))}"></div>`;
const chk = (l,p) => `<div class="check"><input type="checkbox" data-p="${p}" ${get(p)?'checked':''}><span>${l}</span></div>`;

async function api(action, body, isForm){
  const r = await fetch(q(action), isForm ? {method:'POST', body} :
      (body ? {method:'POST', headers:{'Content-Type':'application/json'}, body:JSON.stringify(body)} : {}));
  return r.json();
}

function tabsHtml(){
  document.getElementById('tabs').innerHTML = TABS.map(([k,t]) =>
    `<button class="${tab===k?'on':''}" onclick="tab='${k}';draw()">${t}</button>`).join('');
}

function draw(){
  tabsHtml();
  document.getElementById('urls').innerHTML =
    `Config para la app: <code>${esc(URLS.config||'')}</code> &nbsp;·&nbsp; APK: <code>${esc(URLS.updates||'')}</code>
     <br>Pega la primera en <code>assets/config.json → remoteConfigUrl</code> del proyecto antes de compilar.`;
  // El editor de diseno trabaja sobre el TEMA ACTIVO (no siempre el primero).
  const _themes = (S.theme && Array.isArray(S.theme.available)) ? S.theme.available : [];
  let _ti = _themes.findIndex(x => String(x.id) === String(S.theme && S.theme.active));
  if (_ti < 0) _ti = 0;
  const t = 'theme.available.' + _ti + '.';
  let h = '';
  if (tab === 'dashboard') {
    const last = VERSIONS[0];
    h = `
    <section><h2>Panel</h2>
      <div class="row3">
        <div class="ad"><h3>Versión actual</h3>
          <p style="font-size:24px;margin:4px 0">${esc(get('update.latestVersion'))}</p>
          <span class="pill">${get('update.enabled')?'avisando':'pausado'}</span></div>
        <div class="ad"><h3>Usuarios conectados</h3>
          <p style="font-size:24px;margin:4px 0">—</p>
          <span class="pill">la app aún no reporta</span></div>
        <div class="ad"><h3>Último APK subido</h3>
          <p style="font-size:14px;margin:4px 0">${last?esc(last.file):'ninguno'}</p>
          <span class="pill">${last?esc(last.date)+' · '+esc(last.size)+' MB':''}</span></div>
      </div>
    </section>
    <section><h2>Respaldo / restauración</h2>
      <button class="primary" onclick="downloadJson()">Descargar config.json</button>
      <label style="margin-top:10px">Restaurar desde archivo</label>
      <input type="file" id="cfg" accept=".json">
      <button class="primary" style="margin-top:8px" onclick="restore()">Restaurar</button>
      <div class="hint">La restauración reemplaza TODO el config.json actual.</div>
    </section>
    <section><h2>Actividad reciente</h2>
      <div id="log">Cargando…</div>
    </section>`;
    renderLog();
  }
  else if (tab === 'marca') h = `
    <section><h2>Marca</h2>
      <div class="row">${inp('Nombre de la app','branding.appName')}${inp('Identificador Android','packageId')}</div>
      <div class="row">${inp('Frase','branding.tagline')}${inp('URL del logotipo','branding.logoUrl')}</div>
      <label>O sube el archivo del logo (PNG)</label>
      <input type="file" accept="image/*" onchange="fileToData(this,'branding.logoUrl')">
      <div class="row">${inp('Título del login','branding.loginTitle')}${inp('Subtítulo del login','branding.loginSubtitle')}</div>
      <div class="row">${inp('WhatsApp','branding.whatsappUrl')}${inp('Soporte','branding.supportUrl')}</div>
      ${chk('Servidor grabado (solo usuario y contraseña)','branding.hideServerField')}
      ${chk('Mostrar sección En vivo','branding.showLiveSection')}
    </section>
    <section><h2>Pestañas de la portada</h2>
      <div class="row">${inp('Pestaña 1 (Todo)','branding.tabAll')}${inp('Pestaña 2 (Series)','branding.tabSeries')}</div>
      <div class="row">${inp('Pestaña 3 (Películas)','branding.tabMovies')}${inp('Pestaña 4 (En vivo)','branding.tabLive')}</div>
      <div class="hint">Nombres de las pestañas del filtro de la portada. El campo vacío usa el valor por defecto.</div>
    </section>
    <section><h2>TMDB (tráileres)</h2>
      <div class="row">${inp('API key de TMDB','tmdb.apiKey')}</div>
      <div class="hint">Gratis en themoviedb.org → Ajustes → API. Se usa para el tráiler cuando el panel no lo trae.</div>
    </section>
    <section><h2>Servidor Xtream</h2>
      <div class="row">${inp('Panel (host:puerto)','xtream.server')}${inp('User-Agent','xtream.userAgent')}${inp('Access Token (XUI.one)','xtream.streamToken')}</div>
      <div class="hint">Este User-Agent es el que la app manda a los streams (XUI.one).</div>
    </section>
    <section><h2>Funciones</h2>
      ${chk('Búsqueda','features.search')}${chk('Favoritos / Mi lista','features.favorites')}
      ${chk('Guía EPG','features.epg')}${chk('Mostrar datos de la cuenta','features.showAccountInfo')}
      ${chk('Reproductor secundario libmpv (si ExoPlayer falla)','features.vlcPlayer')}
          </section>
    <section><h2>Reproductor</h2>
      <div class="row">${inp('Aviso de inactividad (horas, 0 = nunca)','player.idlePromptHours','number')}${inp('Mensaje del aviso','player.idlePromptMessage')}</div>
      ${chk('Modo prueba (aviso cada 60 s)','player.idlePromptTestMode')}
      <div class="hint">Cada X horas la app pregunta «¿sigues viendo?» en los canales en vivo. Con el modo prueba, cada 60 segundos (para verlo sin esperar).</div>
    </section>`;
  else if (tab === 'imagenes') {
    const bgs = get('branding.loginBackgrounds') || [];
    h = `
    <section><h2>Imágenes de la app</h2>
      <label>Logo del login</label>
      <div class="row"><input type="text" data-p="branding.logoUrl" value="${esc(get('branding.logoUrl'))}">
        <input type="file" accept="image/*" onchange="fileToData(this,'branding.logoUrl')"></div>
      <img class="prev" data-prev="branding.logoUrl" src="${esc(get('branding.logoUrl'))}">
      <label>Logo de la cabecera (barra superior y portada)</label>
      <div class="row"><input type="text" data-p="branding.headerLogoUrl" value="${esc(get('branding.headerLogoUrl'))}">
        <input type="file" accept="image/*" onchange="fileToData(this,'branding.headerLogoUrl')"></div>
      <img class="prev" data-prev="branding.headerLogoUrl" src="${esc(get('branding.headerLogoUrl'))}">
      <label>Logo de la pantalla de carga</label>
      <div class="row"><input type="text" data-p="branding.splashLogoUrl" value="${esc(get('branding.splashLogoUrl'))}">
        <input type="file" accept="image/*" onchange="fileToData(this,'branding.splashLogoUrl')"></div>
      <img class="prev" data-prev="branding.splashLogoUrl" src="${esc(get('branding.splashLogoUrl'))}">
      <div class="hint">Si dejas la cabecera o la carga vacías, se usa el logo del login.</div>
    </section>
    <section><h2>Fondos del login</h2>
      <input type="file" accept="image/*" multiple onchange="addBackgrounds(this)">
      <div class="hint">${bgs.length} imagen(es); rotan en el acceso cada ${esc(get('branding.loginBackgroundSeconds'))} s.</div>
      <div class="row3">${bgs.map((u,i)=>'<div class="ad"><img src="'+u+'" style="width:100%;border-radius:8px"><button class="mini" onclick="delBackground('+i+')">Quitar</button></div>').join('')}</div>
      <div class="row">${inp('Segundos por fondo','branding.loginBackgroundSeconds','number')}</div>
    </section>
    <section><h2>Nombre y textos</h2>
      <div class="row">${inp('Nombre de la app','branding.appName')}${inp('Frase','branding.tagline')}</div>
      <div class="row">${inp('Título del login','branding.loginTitle')}${inp('Subtítulo del login','branding.loginSubtitle')}</div>
      <label>Pie del login</label><input type="text" data-p="branding.loginFooter" value="${esc(get('branding.loginFooter'))}">
    </section>`;
  }
  else if (tab === 'diseno') h = `
    <section><h2>Temas de la app</h2>
      <div class="hint">Predeterminado de la marca: se aplica al arrancar en los equipos que usan el tema de la marca. Si alguien eligió un tema en la APK, debe pulsar «Volver al tema de la marca» en Perfil → Apariencia. Nova2/Nova3 requieren una APK que ya los incluya.</div>
      <div class="row">
        <div><label>Tema que carga la app</label>
          <select data-p="theme.active">
            ${_themes.map(x => `<option value="${esc(x.id)}" ${String(S.theme.active)===String(x.id)?'selected':''}>${esc(x.name||x.id)} (${esc(x.id)})</option>`).join('')}
          </select>
        </div>
        <div><label>Estilo de catalogo del tema</label>
          <select data-p="${t}layout" ${['nova2','nova3'].includes(String(S.theme.active))?'disabled':''}>
            ${['nova','rows','grid'].map(v=>`<option value="${v}" ${String(get(t+'layout'))===v?'selected':''}>${v}</option>`).join('')}
          </select>
        </div>
      </div>
      <div class="row3">
        <div><label>Acento</label><input type="color" data-p="${t}primaryColor" value="${esc(get(t+'primaryColor'))}"></div>
        <div><label>Fondo</label><input type="color" data-p="${t}backgroundColor" value="${esc(get(t+'backgroundColor'))}"></div>
        <div><label>Superficie</label><input type="color" data-p="${t}surfaceColor" value="${esc(get(t+'surfaceColor'))}"></div>
      </div>
      <div class="row3">
        <div><label>Texto</label><input type="color" data-p="${t}textColor" value="${esc(get(t+'textColor'))}"></div>
        <div><label>Radio de tarjetas</label><input type="number" data-p="${t}cardRadius" value="${esc(get(t+'cardRadius'))}"></div>
        <div><label>Acento de la marca</label><input type="color" data-p="branding.primaryColor" value="${esc(get('branding.primaryColor'))}"></div>
      </div>
      <div class="hint">Elegir tema predeterminado (pulsa Guardar después):
        <button class="mini" onclick="selectTheme('nova')">NOVA</button>
        <button class="mini" onclick="selectTheme('nova2')">Nova2 · cinematográfico</button>
        <button class="mini" onclick="selectTheme('nova3')">Nova3 · menú lateral TV</button>
      </div>
      <div class="hint">Colores del tema seleccionado:
        <button class="mini" onclick="preset('#2FE0C0','#0A0F1A','#141D2E')">NOVA</button>
        <button class="mini" onclick="preset('#2F6BFF','#0B0F17','#151C28')">Azul noche</button>
        <button class="mini" onclick="preset('#E50914','#0B0B0B','#161616')">Rojo</button>
        <button class="mini" onclick="preset('#F0A732','#0D0B07','#1A1610')">Ámbar</button>
      </div>
    </section>
    <section><h2>Cabecera destacada (banner)</h2>
      <div class="row3">
        <div><label>Modo del banner</label>
          <select data-p="branding.heroMode">
            ${['auto','random','manual'].map(v=>`<option value="${v}" ${get('branding.heroMode')===v?'selected':''}>${v==='auto'?'Automatico':(v==='random'?'Aleatorio':'Manual')}</option>`).join('')}
          </select></div>
        <div><label>Categorias (ids o nombres, separados por coma)</label>
          <input data-p="branding.heroCategories" value="${esc(get('branding.heroCategories'))}"></div>
        <div><label>Canales/titulos (ids o nombres, separados por coma)</label>
          <input data-p="branding.heroItems" value="${esc(get('branding.heroItems'))}"></div>
      </div>
      <div class="row3">
        <div><label>Contenido del banner</label><select data-p="branding.heroSource">${['mixed','movie','movies','series','live'].map(v=>`<option value="${v}" ${get('branding.heroSource')===v?'selected':''}>${v}</option>`).join('')}</select></div>
        ${inp('Anuncio cada N carátulas','branding.heroAdsEvery','number')}
      </div>
      ${chk('Insertar anuncios en el banner','branding.heroAds')}
      <div class="hint">Elige qué rota en el banner (mixto, películas, series o en vivo) y si se intercala un anuncio cada N carátulas.</div>
    </section>`;
  else if (tab === 'avisos') h = `
    <section><h2>Recordatorio de descanso</h2>
      ${chk('Activar recordatorio de descanso','usageReminder.enabled')}
      <div class="row">${inp('Mostrar después de (minutos, 240 = 4 horas)','usageReminder.intervalMinutes','number')}
        ${inp('Cuenta atrás (segundos, de 5 a 120)','usageReminder.countdownSeconds','number')}</div>
      <div class="row">${inp('Título','usageReminder.title')}${inp('Texto del botón','usageReminder.buttonLabel')}</div>
      <label>Nota que aparecerá sobre la reproducción</label>
      <textarea data-p="usageReminder.message">${esc(get('usageReminder.message'))}</textarea>
      <div class="hint">Variables: <code>{hours}</code>, <code>{minutes}</code>, <code>{seconds}</code>.
        Cuenta tiempo con la app iniciada en primer plano; cambiar de canal no reinicia el plazo.
        Continuar reinicia el intervalo. Sin respuesta, Android sale de la app; iOS vuelve a Inicio sin vídeo.
        Es independiente de Anuncios: funciona con la publicidad desactivada.
        Requiere APK 1.2.42 o posterior. Pulsa Guardar en el servidor.</div>
    </section>`;
  else if (tab === 'anuncios') {
    h = `<section><h2>Anuncios · empieza aquí</h2>
      <p>No necesitas llenar todas las casillas. Para un aviso sobre el vídeo basta con <b>Tipo: message</b>, <b>Texto</b> y <b>Activo</b>.</p>
      <button class="primary" onclick="loadAdDemo()">✨ Cargar 3 avisos de demostración</button>
      <button onclick="removeAdDemo()">Quitar avisos demo</button>
      <div class="hint">La demo añade mensajes sin borrar tus anuncios. Activa Overlay y pausa las otras ubicaciones para esta prueba.
        Nada se publica hasta pulsar <b>Guardar en el servidor</b>.</div>
      <details style="margin-top:16px"><summary><b>📖 Manual rápido: qué rellenar y para qué sirve cada casilla</b></summary>
        <h3>1 · Prueba sin imágenes ni enlaces</h3>
        <p>Pulsa Cargar demo → confirma → Guardar en el servidor → abre de nuevo la app y reproduce un vídeo con <b>Media3/ExoPlayer</b>.
          Verás mensajes de bienvenida, noche de cine y cuidado de la vista. Rotan cada 12 segundos durante hasta 60 segundos,
          siempre que no se hayan agotado los topes del dispositivo.</p>
        <h3>2 · Tu primer anuncio real</h3>
        <p>Pulsa Añadir aviso de texto sobre el vídeo, escribe tu mensaje y guarda. Ejemplo:
          <b>¡Hoy es noche de cine! Prepara tus palomitas y descubre una nueva historia.</b></p>
        <h3>3 · Interruptores y ubicaciones</h3>
        <ul><li><b>Anuncios activados:</b> interruptor general. Apagado = no sale publicidad.</li>
          <li><b>Avisos sobre Media3:</b> permite la franja del reproductor actual. Necesita también Overlay activo.</li>
          <li><b>Overlay:</b> aviso encima del vídeo, sin detenerlo. Acepta texto e imagen; no reproduce vídeos publicitarios encima.</li>
          <li><b>Interstitial:</b> anuncio de pantalla completa antes de abrir el reproductor.</li>
          <li><b>Banner / Preroll:</b> opciones del esquema compartido; activarlas no garantiza que cada pantalla o motor las implemente.
            Para esta prueba usa únicamente Overlay.</li>
          <li><b>Tope por hora:</b> impresiones máximas de esa ubicación en cada dispositivo, no cantidad de usuarios.
            Con 2/h la franja dejará de salir después de dos impresiones hasta la siguiente hora.</li></ul>
        <h3>4 · Campos del anuncio</h3>
        <ul><li><b>message:</b> solo necesita Texto. Título opcional; no requiere URL.</li>
          <li><b>image:</b> necesita una URL de imagen accesible o imagen base64. Texto opcional. No uses una página web como URL de imagen.</li>
          <li><b>video:</b> necesita URL directa del archivo de vídeo; no un enlace de YouTube. No se usa en esta franja Overlay.</li>
          <li><b>Etiqueta:</b> nombre interno para reconocerlo. <b>Activo:</b> permite mostrar ese anuncio.</li>
          <li><b>Opciones avanzadas:</b> ID único para contar impresiones; enlace opcional (la franja informativa no lo abre);
            duración y tiempo de cierre para pantalla completa; peso para selección de anuncios, no para ordenar la rotación Overlay;
            máximo diario vacío = sin límite diario. No cambies el ID para eludir topes.</li></ul>
        <h3>5 · Tiempo de la franja</h3>
        <p><b>Rotación</b> cambia de anuncio. <b>Franja visible</b> limita cuánto tiempo aparece desde abrir/cambiar el contenido.
          0 permite mantener la franja disponible, pero <b>no anula los topes</b>. Las ubicaciones comparten lista de anuncios;
          no hay una ubicación individual asignada a cada creativo.</p>
        <h3>6 · Si no aparece</h3>
        <p>Revisa Guardar, remoteConfigUrl, APK 1.2.42 o posterior, motor Media3, ambos interruptores y Overlay,
          Texto/URL, Activo y los topes diarios/horarios. Reabre la app para cargar la configuración.
          La vista previa del panel no prueba la descarga remota ni reinicia contadores.</p>
        <p>El aviso de <b>4 horas / Consejos</b> se configura en <b>Avisos y descanso</b>; no es publicidad y no requiere esta demo.</p>
      </details>
    </section><section><h2>Configuración de anuncios</h2>
      ${chk('Anuncios activados','ads.enabled')}${chk('Avisos sobre el vídeo (Media3 / iPhone)','ads.inPlayer')}
      <div class="row">${inp('Segundos por anuncio (rotación)','ads.rotationSeconds','number')}${inp('Franja visible en el reproductor (s, 0 = fija)','ads.inPlayerSeconds','number')}</div>
      <div class="hint"><b>Tamaños de imagen (TV):</b> Banner <b>728×90</b> · Interstitial <b>1920×1080</b> · Preroll <b>1280×720</b> (16:9) · Overlay <b>400×225</b>.
      En <b>Media3/ExoPlayer</b> activa también Overlay (sin vídeo publicitario encima). Los otros motores conservan su interfaz.
      El recordatorio de 4 horas se configura en <b>Avisos y descanso</b>, no aquí.
      Los avisos deben tener Texto y estar activos; una imagen necesita URL. Los topes se aplican por dispositivo.
      La <b>franja del reproductor</b> rota su contenido cada «segundos por anuncio»; si solo hay 1 anuncio no se nota el cambio (añade varios).</div>
      <div class="row3">
        ${plc('Banner','banner')}${plc('Interstitial','interstitial')}${plc('Preroll','preroll')}${plc('Overlay','overlay')}
      </div>
    </section>`;
    (get('ads.ads')||[]).forEach((ad,i) => h += adHtml(ad,i));
    h += `<button class="primary" onclick="addAd()">+ Añadir anuncio</button> <button onclick="addMessageAd()">+ Añadir aviso de texto sobre el vídeo</button>`;
  }
  else h = `
    <section><h2>Versión publicada</h2>
      <div class="row3">${inp('Versión','update.latestVersion')}${inp('Versión mínima','update.minVersion')}${inp('URL del APK universal (opcional)','update.apkUrl')}</div>
      <div class="row3">${inp('URL del APK 32 bits (Fire TV)','update.apkUrlArm32')}${inp('URL del APK 64 bits (móviles/box)','update.apkUrlArm64')}${inp('URL del APK x86_64 (emulador)','update.apkUrlX64')}</div>
      <div class="hint">Al subir un APK el panel detecta su arquitectura y rellena el campo que le toca. La app descarga sola el de su equipo: 64 bits, 32 bits o, si no hay, el universal.</div>
      ${chk('Avisar de nuevas versiones','update.enabled')}${chk('Obligatoria','update.forceUpdate')}
      <div class="hint">Sin URL la app <b>solo avisa</b>: no descarga ni instala nada.
        <button class="mini" onclick="soloAvisar()">Solo avisar</button></div>
      <h2 style="margin-top:14px">Descargar APK publicado</h2>
      <div class="row3">
        ${get('update.apkUrlArm32')?`<a class="primary" style="text-decoration:none" href="${esc(get('update.apkUrlArm32'))}" download>arm32 (Fire TV)</a>`:'<span class="hint">sin arm32</span>'}
        ${get('update.apkUrlArm64')?`<a class="primary" style="text-decoration:none" href="${esc(get('update.apkUrlArm64'))}" download>arm64 (móvil)</a>`:'<span class="hint">sin arm64</span>'}
        ${get('update.apkUrlX64')?`<a class="primary" style="text-decoration:none" href="${esc(get('update.apkUrlX64'))}" download>x86_64 (emulador)</a>`:'<span class="hint">sin x86_64</span>'}
      </div>
      <label>Novedades</label><textarea data-p="update.changelog">${esc(get('update.changelog'))}</textarea>
    </section>
    <section><h2>Subir APK nuevo</h2>
      <input type="file" id="apk" accept=".apk">
      <div class="hint">Al subirlo se guarda como <code>updates/nova-&lt;siguiente versión&gt;.apk</code> y se publica solo.</div>
      <button class="primary" style="margin-top:10px" onclick="upload()">Subir y publicar</button>
      <div id="uploadMsg" class="hint"></div>
    </section>
    <section><h2>APK en el servidor</h2>
      <table><thead><tr><th>Archivo</th><th>Versión</th><th>MB</th><th>Fecha</th><th></th></tr></thead><tbody>
      ${VERSIONS.map(v => `<tr><td>${esc(v.file)}</td><td>${esc(v.version)}</td><td>${esc(v.size)}</td><td>${esc(v.date)}</td>
        <td style="text-align:right"><button class="mini" onclick="publish('${esc(v.file)}')">Publicar</button>
        <button class="mini" onclick="delFile('${esc(v.file)}')">Borrar</button></td></tr>`).join('')}
      </tbody></table>
    </section>`;
  document.getElementById('form').innerHTML = h;
  document.querySelectorAll('[data-p]').forEach(el => el.addEventListener('input', () => {
    let v = el.type === 'checkbox' ? el.checked : el.value;
    if (el.type === 'number') v = v === '' ? null : Number(v);
    set(el.dataset.p, v);
    if (el.dataset.p === 'theme.active') draw();
    if (/^ads\.ads\.\d+\.type$/.test(el.dataset.p)) draw();
  }));
}

const plc = (title,key) => `<div class="ad"><h3>${title}</h3>
  <label>Tope por hora</label><input type="number" data-p="ads.placements.${key}.maxPerHour" value="${esc(get('ads.placements.'+key+'.maxPerHour'))}">
  <div class="check"><input type="checkbox" data-p="ads.placements.${key}.enabled" ${get('ads.placements.'+key+'.enabled')?'checked':''}><span>Activo</span></div></div>`;

const adHtml = (ad,i) => {
  const p='ads.ads.'+i+'.';
  const isMessage = ad.type === 'message';
  return `<div class="ad">
  <h3>${esc(ad.label || 'Anuncio '+(i+1))} <span class="pill">${esc(ad.type||'image')}</span>
    <button class="mini" style="float:right" onclick="delAd(${i})">Quitar</button></h3>
  <div class="row">
    <div><label>Tipo de anuncio</label><select data-p="${p}type">${['image','video','message'].map(v=>`<option value="${v}" ${ad.type===v?'selected':''}>${v==='message'?'message · Solo texto':v==='image'?'image · Imagen':'video · Vídeo'}</option>`).join('')}</select></div>
    <div><label>Etiqueta interna</label><input type="text" data-p="${p}label" value="${esc(ad.label)}" placeholder="Ej.: Promoción del fin de semana"></div>
  </div>
  ${isMessage ? '<div class="hint">Solo texto: no necesitas imagen, vídeo ni enlace.</div>' :
    `<label>URL directa del ${ad.type==='video'?'vídeo':'archivo de imagen'} (obligatoria)</label><input type="text" data-p="${p}mediaUrl" value="${esc(ad.mediaUrl)}" placeholder="https://tu-servidor/archivo.${ad.type==='video'?'mp4':'jpg'}">
    <div class="hint">Imagen: Overlay 400×225 · Banner 728×90 · pantalla completa 1920×1080. Los vídeos publicitarios no se muestran encima del vídeo principal.</div>`}
  <label>Título (opcional)</label><input type="text" data-p="${p}title" value="${esc(ad.title)}" placeholder="Ej.: Tu próxima historia empieza aquí">
  <label>${isMessage?'Texto del aviso (obligatorio)':'Texto (opcional)'}</label><textarea data-p="${p}text" placeholder="Escribe aquí lo que verá el usuario…">${esc(ad.text)}</textarea>
  <div class="check"><input type="checkbox" data-p="${p}enabled" ${ad.enabled!==false?'checked':''}><span>Activo</span></div>
  ${isMessage ? `<div style="padding:14px;background:#252b36;color:#fff;border-left:4px solid #00a9e8;border-radius:6px;margin:12px 0"><small>VISTA PREVIA · ejemplo, no emisión real</small><br>
    <b>${esc(ad.title||'')}</b> ${esc(ad.text||'Aquí aparecerá tu mensaje.')}<br><button class="mini" style="margin-top:8px" onclick="draw()">Actualizar vista previa</button></div>` : ''}
  <details><summary>Opciones avanzadas · normalmente puedes dejarlas como están</summary>
    <label>ID único (no lo repitas)</label><input type="text" data-p="${p}id" value="${esc(ad.id)}">
    <label>Enlace opcional (no se abre desde la franja Overlay)</label><input type="text" data-p="${p}clickUrl" value="${esc(ad.clickUrl)}">
    <div class="row3">
      <div><label>Duración pantalla completa (s)</label><input type="number" data-p="${p}durationSec" value="${esc(ad.durationSec)}"></div>
      <div><label>Permitir cerrar pantalla completa a los (s)</label><input type="number" data-p="${p}skipAfterSec" value="${esc(ad.skipAfterSec)}"></div>
      <div><label>Peso de selección (no orden Overlay)</label><input type="number" data-p="${p}weight" value="${esc(ad.weight)}"></div>
    </div>
    <label>Máximo diario por dispositivo (vacío = sin límite)</label><input type="number" min="0" data-p="${p}frequencyCapPerDay" value="${esc(ad.frequencyCapPerDay)}">
  </details>
</div>`; };

function addAd(){
  S.ads.ads = S.ads.ads || [];
  S.ads.ads.push({id:'anuncio-'+Date.now().toString(36)+'-'+Math.random().toString(36).slice(2,7),type:'image',label:'Publicidad',mediaUrl:'',clickUrl:'',
    title:'',text:'',durationSec:15,skipAfterSec:5,weight:3,frequencyCapPerDay:null,enabled:true,
    targeting:{mediaTypes:[],categories:[],keywords:[],hoursFrom:null,hoursTo:null}});
  draw();
}
function addMessageAd(){
  addAd();
  const ad = S.ads.ads[S.ads.ads.length - 1];
  ad.type = 'message'; ad.label = 'Aviso';
  S.ads.enabled = true; S.ads.inPlayer = true;
  S.ads.placements = S.ads.placements || {};
  S.ads.placements.overlay = S.ads.placements.overlay || {maxPerHour:2};
  S.ads.placements.overlay.enabled = true;
  if (!(S.ads.placements.overlay.maxPerHour > 0)) S.ads.placements.overlay.maxPerHour = 2;
  draw();
}
// Stable reserved IDs make loading the demo idempotent without touching real ads.
const AD_DEMO_IDS = ['demo-nova-bienvenida', 'demo-nova-cine', 'demo-nova-pausa'];
function loadAdDemo(){
  if (!confirm('Añadir 3 mensajes demo sin borrar tus anuncios. Se activará Overlay (12/h, 60 s, rotación 12 s) y se pausarán Banner, Interstitial y Preroll. Los demás anuncios activos también pueden rotar. Solo se publicará al Guardar. ¿Continuar?')) return;
  S.ads = S.ads || {};
  S.ads.ads = S.ads.ads || [];
  const demos = [
    {id:AD_DEMO_IDS[0],label:'DEMO · Bienvenida',title:'Bienvenido a tu momento favorito',text:'Desconecta de la rutina. Elige una historia y disfruta a tu manera.'},
    {id:AD_DEMO_IDS[1],label:'DEMO · Noche de cine',title:'Hoy el mejor plan está en casa',text:'Palomitas listas, luces bajas y una película por descubrir. ¡Que empiece la función!'},
    {id:AD_DEMO_IDS[2],label:'DEMO · Cuida tu vista',title:'Una pequeña pausa también es parte del plan',text:'Aparta la mirada de la pantalla unos segundos y relaja tus ojos. Tu bienestar también importa.'}
  ];
  for (const demo of demos) {
    if (!S.ads.ads.some(ad => ad.id === demo.id)) S.ads.ads.push(Object.assign({
      type:'message',mediaUrl:'',clickUrl:'',durationSec:12,skipAfterSec:0,weight:1,
      frequencyCapPerDay:null,enabled:true,
      targeting:{mediaTypes:[],categories:[],keywords:[],hoursFrom:null,hoursTo:null}
    },demo));
  }
  S.ads.enabled = true; S.ads.inPlayer = true;
  S.ads.rotationSeconds = 12; S.ads.inPlayerSeconds = 60;
  S.ads.placements = S.ads.placements || {};
  for (const key of ['banner','interstitial','preroll']) {
    S.ads.placements[key] = Object.assign({}, S.ads.placements[key], {enabled:false});
  }
  S.ads.placements.overlay = {enabled:true,maxPerHour:12};
  draw();
  alert('Demo preparada, todavía no publicada. Pulsa Guardar en el servidor. Después reabre la app y reproduce con Media3/ExoPlayer.');
}
function removeAdDemo(){
  if (!confirm('Quitar solo los 3 avisos con ID de demo. Si quedan anuncios reales, conservarán los ajustes activos de la prueba. Pulsa Guardar después. ¿Continuar?')) return;
  if (!S.ads) return;
  S.ads.ads = (S.ads.ads || []).filter(ad => !AD_DEMO_IDS.includes(ad.id));
  if (!S.ads.ads.length) { S.ads.enabled = false; S.ads.inPlayer = false; }
  draw();
}
function delAd(i){ S.ads.ads.splice(i,1); draw(); }
function selectTheme(id){
  if (!S.theme.available.some(theme => theme.id === id)) return;
  S.theme.active = id;
  draw();
}
function preset(ac,bg,sf){
  const theme = S.theme.available.find(theme => theme.id === S.theme.active);
  if (!theme) return;
  theme.primaryColor=ac; theme.backgroundColor=bg; theme.surfaceColor=sf;
  draw();
}

function fileToData(input, path){
  const f = input.files && input.files[0]; if (!f) return;
  const r = new FileReader();
  r.onload = () => {
    set(path, r.result);
    const el = document.querySelector('[data-p="' + path + '"]');
    if (el) el.value = '(imagen cargada: ' + f.name + ')';
    const pv = document.querySelector('[data-prev="' + path + '"]');
    if (pv) pv.src = r.result;
    alert('Logo cargado. Pulsa Guardar en el servidor.');
  };
  r.readAsDataURL(f);
}

function soloAvisar(){
  set('update.apkUrl', '');
  set('update.forceUpdate', false);
  set('update.enabled', true);
  draw();
  alert('Listo: la app avisará de la versión nueva sin descargar ni instalar.');
}

function addBackgrounds(input){
  const files = input.files || [];
  S.branding.loginBackgrounds = S.branding.loginBackgrounds || [];
  let pending = files.length;
  if (!pending) return;
  for (const f of files) {
    const r = new FileReader();
    r.onload = () => {
      S.branding.loginBackgrounds.push(r.result);
      if (--pending === 0) { draw(); alert('Fondos añadidos. Pulsa Guardar en el servidor.'); }
    };
    r.readAsDataURL(f);
  }
}

function delBackground(i){ S.branding.loginBackgrounds.splice(i, 1); draw(); }

async function restore(){
  const f = document.getElementById('cfg').files[0];
  if (!f) { alert('Elige un config.json.'); return; }
  const fd = new FormData(); fd.append('config', f);
  const r = await api('restore', fd, true);
  alert(r.ok ? 'Configuración restaurada.' : 'Error: ' + (r.error || 'desconocido'));
  if (r.ok) await load();
}
async function renderLog(){
  const r = await api('log');
  const el = document.getElementById('log');
  if (el) el.innerHTML = (r.log || []).map(l => '<div class="hint">' + esc(l) + '</div>').join('') || 'Sin actividad.';
}
function downloadJson(){
  const c = JSON.parse(JSON.stringify(S));
  const blob = new Blob([JSON.stringify(c, null, 2)], {type:'application/json'});
  const a = document.createElement('a');
  a.href = URL.createObjectURL(blob);
  a.download = 'config.json';
  a.click();
}

document.getElementById('btnSave').onclick = async () => {
  const r = await api('save', S);
  alert(r.ok ? 'Guardado en el servidor. La app lo cogerá al arrancar.'
             : 'Error: ' + (r.error || 'desconocido'));
};

async function upload(){
  const f = document.getElementById('apk').files[0];
  if (!f) { alert('Elige un APK.'); return; }
  document.getElementById('uploadMsg').textContent = 'Subiendo ' + f.name + '…';
  const fd = new FormData(); fd.append('apk', f);
  const r = await api('upload', fd, true);
  document.getElementById('uploadMsg').textContent = r.ok
    ? 'Publicada la versión ' + r.version + ' (' + r.file + ')'
    : 'Error: ' + (r.error || 'desconocido');
  if (r.ok) { VERSIONS = r.versions; await load(); }
}
async function publish(file){
  const r = await api('publish', {file: file, forceUpdate: get('update.forceUpdate') === true,
    minVersion: get('update.minVersion'), changelog: get('update.changelog')});
  if (r.ok) alert('Publicada la versión ' + r.update.latestVersion);
  await load();
}
async function delFile(file){
  if (!confirm('¿Borrar ' + file + '?')) return;
  const r = await api('delete', {file: file});
  if (r.ok) { VERSIONS = r.versions; await load(); }
}

async function load(){
  const r = await api('load');
  if (!r.ok) { document.body.innerHTML = '<p style="padding:20px">' + (r.error||'Error') + '</p>'; return; }
  S = r.config; VERSIONS = r.versions || []; URLS = r.urls || {};
  draw();
}
load();
</script>
</body>
</html>
