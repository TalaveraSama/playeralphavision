// Ejecutar: node tools/check_panel_theme_ui.js
const fs = require('fs');
const vm = require('vm');
const assert = require('assert');
const source = fs.readFileSync('aapanel-alphavision/index.php', 'utf8');
const script = source.match(/<script>([\s\S]*?)<\/script>/)[1];
new Function(script);
const sandbox = { document: {getElementById: () => ({})} };
vm.createContext(sandbox);
vm.runInContext(script.replace(/\nload\(\);\n/, '\n'), sandbox);
vm.runInContext(`
  let redraws = 0;
  draw = () => redraws++;
  S = {theme: {active: 'nova', available: [
    {id:'nova', primaryColor:'#111111'}, {id:'nova2'}, {id:'nova3'}
  ]}, branding: {primaryColor:'#222222'}};
  selectTheme('nova3');
  preset('#456BFF', '#000000', '#0D0D0F');
`, sandbox);
assert.equal(vm.runInContext('S.theme.active', sandbox), 'nova3');
assert.equal(vm.runInContext('S.theme.available[2].primaryColor', sandbox), '#456BFF');
assert.equal(vm.runInContext('S.theme.available[0].primaryColor', sandbox), '#111111');
assert.equal(vm.runInContext('S.branding.primaryColor', sandbox), '#222222');
assert.equal(vm.runInContext('redraws', sandbox), 2);
vm.runInContext("selectTheme('no-existe')", sandbox);
assert.equal(vm.runInContext('S.theme.active', sandbox), 'nova3');
assert(source.includes("if (el.dataset.p === 'theme.active') draw();"));
assert(!source.includes('S.theme.available[0].primaryColor='));
console.log('OK: sintaxis JS, selección Nova3, edición del tema activo y redibujado');
