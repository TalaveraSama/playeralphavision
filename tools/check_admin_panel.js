// Comprueba el panel de administración:
//  1. que el JavaScript del panel no tenga errores de sintaxis;
//  2. que su DEFAULT_CONFIG tenga exactamente la misma estructura que
//     assets/config.json, que es lo que lee la app.
const fs = require('fs');

const panelPath = process.argv[2];
const assetPath = process.argv[3];

const html = fs.readFileSync(panelPath, 'utf8');
const scriptMatch = html.match(/<script>([\s\S]*?)<\/script>/);
if (!scriptMatch) {
  console.error('ERROR: no encuentro el bloque <script> en el panel.');
  process.exit(2);
}
const script = scriptMatch[1];

// 1) Sintaxis (new Function lanza SyntaxError si el script está roto).
try {
  new Function(script);
  console.log('OK  sintaxis del panel valida (' + script.split('\n').length + ' lineas)');
} catch (error) {
  console.error('ERROR de sintaxis en el panel: ' + error.message);
  process.exit(1);
}

// 2) Estructura del DEFAULT_CONFIG frente al config del APK.
const defMatch = script.match(/const DEFAULT_CONFIG = (\{[\s\S]*?\n\});/);
if (!defMatch) {
  console.error('ERROR: no encuentro DEFAULT_CONFIG.');
  process.exit(1);
}
const panelConfig = eval('(' + defMatch[1] + ')');
const appConfig = JSON.parse(fs.readFileSync(assetPath, 'utf8'));

function keyPaths(value, prefix, out) {
  if (Array.isArray(value)) {
    out.add(prefix + '[]');
    if (value.length && typeof value[0] === 'object') keyPaths(value[0], prefix + '[]', out);
    return out;
  }
  if (value && typeof value === 'object') {
    for (const key of Object.keys(value)) keyPaths(value[key], prefix ? prefix + '.' + key : key, out);
    return out;
  }
  out.add(prefix);
  return out;
}

const panelKeys = keyPaths(panelConfig, '', new Set());
const appKeys = keyPaths(appConfig, '', new Set());

const onlyPanel = [...panelKeys].filter((k) => !appKeys.has(k));
const onlyApp = [...appKeys].filter((k) => !panelKeys.has(k));

console.log('OK  claves del panel: ' + panelKeys.size + ' | claves del APK: ' + appKeys.size);
if (onlyPanel.length) console.log('AVISO solo en el panel: ' + onlyPanel.join(', '));
if (onlyApp.length) console.log('AVISO solo en el APK: ' + onlyApp.join(', '));

// Las claves de plantilla (listas vacías y ejemplos) pueden no coincidir: el
// panel declara `ads.ads` vacío y la configuración real trae creatividades.
const significant = (list) =>
  list.filter(
    (k) =>
      k !== 'ads.banner.creatives[]' &&
      k !== 'branding.loginBackgrounds[]' &&
      k !== 'theme.available[].heroTint' &&
      k !== 'theme.available[].lightButtons' &&
      !k.startsWith('ads.ads[]'),
  );
if (significant(onlyPanel).length || significant(onlyApp).length) {
  console.error('ERROR: el panel y la app no comparten el mismo esquema.');
  process.exit(1);
}
console.log('OK  el panel y la app comparten el mismo esquema de configuracion.');
