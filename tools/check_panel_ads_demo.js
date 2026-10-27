// Run from repository root: node tools/check_panel_ads_demo.js
const fs = require('fs');
const vm = require('vm');
const assert = require('assert');
const source = fs.readFileSync('aapanel-alphavision/index.php', 'utf8');
const script = source.match(/<script>([\s\S]*?)<\/script>/)[1].replace(/\nload\(\);\n/, '\n');
const elements = {};
const context = vm.createContext({
  document: {getElementById: id => elements[id] ||= {innerHTML:''}, querySelectorAll: () => []},
  confirm: () => true, alert: () => {},
});
vm.runInContext(script, context);
const run = text => vm.runInContext(text, context);
run(`S = {ads:{ads:[{id:'real',type:'message',text:'Conservar',enabled:true}],
  placements:{interstitial:{enabled:true,maxPerHour:3}}}, usageReminder:{enabled:true,intervalMinutes:240}};
  tab='anuncios'; draw();`);
assert(elements.form.innerHTML.includes('Manual rápido'));
assert(elements.form.innerHTML.includes('Cargar 3 avisos'));
const before = run('JSON.stringify(S)');
context.confirm = () => false;
run('loadAdDemo()');
assert.equal(run('JSON.stringify(S)'), before);
context.confirm = () => true;
run('loadAdDemo(); loadAdDemo();');
assert.equal(run('S.ads.ads.length'), 4);
assert.equal(run('S.ads.ads[0].text'), 'Conservar');
assert.equal(run('S.usageReminder.intervalMinutes'), 240);
assert.equal(run('S.ads.placements.interstitial.enabled'), false);
assert.equal(run('S.ads.placements.interstitial.maxPerHour'), 3);
assert.equal(run('S.ads.placements.overlay.maxPerHour'), 12);
assert.equal(run('S.ads.inPlayerSeconds'), 60);
assert(run('S.ads.ads.filter(ad=>AD_DEMO_IDS.includes(ad.id)).every(ad=>ad.enabled && ad.type==="message" && ad.text.length>20 && !ad.mediaUrl)'));
assert(!run('adHtml(S.ads.ads[1],1)').includes('data-p="ads.ads.1.mediaUrl"'));
assert(run('adHtml({type:"image",mediaUrl:""},0)').includes('data-p="ads.ads.0.mediaUrl"'));
assert(!run('adHtml({type:"message",text:"<script>alert(1)</script>"},0)').includes('<script>'));
run('removeAdDemo()');
assert.equal(run('S.ads.ads.length'), 1);
assert.equal(run('S.ads.ads[0].id'), 'real');
assert.equal(run('S.ads.enabled'), true);
run('S.ads.ads=[]; loadAdDemo(); removeAdDemo();');
assert.equal(run('S.ads.ads.length'), 0);
assert.equal(run('S.ads.enabled'), false);
assert.equal(run('S.ads.inPlayer'), false);
console.log('OK: manual, confirmed demo, no duplicates/deletion of real ads, placement caps, cleanup, conditional fields and escaped preview');
