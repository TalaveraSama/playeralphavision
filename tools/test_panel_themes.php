<?php
// Ejecutar: php tools/test_panel_themes.php (sin sesiones, servidor ni escrituras reales).
$source = file_get_contents(__DIR__ . '/../aapanel-alphavision/index.php');
$start = strpos($source, 'function nova_default()');
$end = strpos($source, 'function nova_bump(');
eval(substr($source, $start, $end - $start));
function check($ok, $message) { if (!$ok) throw new RuntimeException($message); }

$old = [
  'theme' => ['active' => 'ambar', 'available' => [
    ['id' => 'ambar', 'name' => 'Mi ámbar', 'primaryColor' => '#123456'],
    ['id' => 'nova', 'name' => 'Mi NOVA'],
    ['id' => 'custom', 'layout' => 'grid', 'name' => 'Personalizado'],
  ]],
  'xtream' => ['server' => 'example.invalid:80'],
  'branding' => ['appName' => 'Mi marca'],
];
$config = nova_normalize($old);
$themes = array_column($config['theme']['available'], null, 'id');
check(isset($themes['nova2'], $themes['nova3'], $themes['custom']), 'Faltan temas');
check($themes['ambar']['name'] === 'Mi ámbar', 'Se cambió la marca');
check($themes['ambar']['primaryColor'] === '#123456', 'Se sobrescribieron colores');
check($themes['nova2']['lightButtons'] === true, 'Nova2 incorrecto');
check($themes['nova3']['layout'] === 'nova', 'Nova3 no usará el sidebar');
check($config['theme']['active'] === 'ambar', 'Se cambió el tema actual al migrar');
check($config['xtream']['server'] === $old['xtream']['server'], 'Se cambió el servidor');
$config['theme']['active'] = 'nova3';
check(nova_normalize($config) === $config, 'La migración no es idempotente');
check(nova_normalize([])['theme']['active'] === 'nova3', 'Predeterminado nuevo incorrecto');
$ids = array_column(nova_normalize($config)['theme']['available'], 'id');
check(count($ids) === count(array_unique($ids)), 'Temas duplicados');
foreach (['nova2', 'nova3'] as $id) {
  $assets = json_decode(file_get_contents(__DIR__ . '/../assets/config.json'), true);
  $assetThemes = array_column($assets['theme']['available'], null, 'id');
  check($themes[$id] === $assetThemes[$id], 'Preset diferente de la APK: ' . $id);
}
echo "OK: migración por ID, presets, temas personalizados, selección y configuración preservados\n";
