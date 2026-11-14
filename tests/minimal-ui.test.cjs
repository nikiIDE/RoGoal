'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { initialWindowBounds } = require('../electron/window-bounds.cjs');
const read = (file) => fs.readFileSync(path.join(__dirname, '..', file), 'utf8');

test('default desktop window is compact and centered rather than maximized', () => {
  const bounds = initialWindowBounds({x:0,y:0,width:1920,height:1040});
  assert.equal(bounds.width,1080);
  assert.equal(bounds.height,700);
  assert.equal(bounds.x,420);
  assert.equal(bounds.y,170);
  assert.equal(bounds.minWidth,840);
  assert.equal(bounds.minHeight,540);
});

test('startup geometry fits scaled, small and offset display work areas', () => {
  for (const [width,height,x,y] of [[1366,728,0,0],[1024,600,0,0],[800,560,0,40],[1536,824,-1536,0],[640,480,120,80]]) {
    const bounds = initialWindowBounds({x,y,width,height});
    assert.ok(Number.isInteger(bounds.width) && Number.isInteger(bounds.height));
    assert.ok(bounds.width <= width*.9 && bounds.height <= height*.9);
    assert.ok(bounds.minWidth <= bounds.width && bounds.minHeight <= bounds.height);
    assert.ok(bounds.x >= x && bounds.y >= y);
    assert.ok(bounds.x+bounds.width <= x+width && bounds.y+bounds.height <= y+height);
  }
});

test('invalid display dimensions use safe defaults without allowing NaN or negative sizes', () => {
  for (const area of [undefined,null,{}, {width:NaN,height:Infinity}, {width:-5,height:0,x:NaN,y:Infinity}]) {
    const bounds = initialWindowBounds(area);
    assert.equal(bounds.width,1080);
    assert.equal(bounds.height,700);
    assert.ok(Object.values(bounds).every(Number.isFinite));
  }
  assert.equal(initialWindowBounds({width:1,height:1}).width,1);
});

test('native window uses computed work area with sandbox and context isolation intact', () => {
  const main = read('electron/main.cjs');
  assert.match(main,/initialWindowBounds\(screen.getPrimaryDisplay\(\).workArea\)/);
  assert.match(main,/nodeIntegration: false/);
  assert.match(main,/contextIsolation: true/);
  assert.match(main,/sandbox: true/);
  assert.match(main,/windowStyleForTheme\('studio'\)/);
});

test('all UI glyphs use a single neutral outline family and reject inherited keys', async () => {
  // Load the standalone, dependency-free ESM even though the desktop package is CJS.
  const { icon } = await import('data:text/javascript;base64,'+Buffer.from(read('renderer/icons.js')).toString('base64'));
  for (const name of ['home','import','Folder','Script','LocalScript','ModuleScript','Players','Camera','Frame','__proto__','constructor','<script>']) {
    const svg = icon(name,16);
    assert.match(svg,/stroke="currentColor"/);
    assert.match(svg,/stroke-width="1.5"/);
    assert.doesNotMatch(svg,/#[0-9a-f]{3,8}|<script>|\[object|function /i);
  }
  assert.match(icon('Script', '<svg>'), /width="16"/);
});

test('home is text-first, all interface labels are English and themes use product names', () => {
  const html=read('index.html');
  assert.match(html,/<html lang="en">/);
  assert.match(html,/<body data-theme="studio">/);
  assert.doesNotMatch(html,/Discord|sparkles|dashboard-kicker|compose-symbol|dashboard-signoff/);
  for (const id of ['dashboardBrowse','dashboardCompose','dashboardSearch','dashboardRecovery','dashboardLayout']) {
    assert.match(html,new RegExp('id="'+id+'"'));
  }
  assert.match(html,/<option value="studio">Studio<\/option>/);
  assert.match(html,/id="layoutToggle"[^>]*>Layout<\/button>/);
  assert.match(html,/id="themeToggle"[^>]*>Appearance<\/button>/);
});

test('plugin applies the shared Studio widget palette by default', () => {
  const theme=read('plugin/source/UI/Theme.lua');
  assert.match(read("plugin/source/Config/Defaults.lua"), /Theme = "Studio"/);
  assert.match(theme, /Studio = \{\s*Background = Color3.fromRGB\(37, 37, 37\)/);
  assert.match(theme, /Theme.ApplyPreset\("Studio"\)/);
});

test('release documentation is bilingual and every package version agrees', () => {
  const pkg=JSON.parse(read('package.json')), lock=JSON.parse(read('package-lock.json'));
  const notes=read(`docs/RELEASE_${pkg.version.replaceAll('.','_')}.md`);
  assert.match(pkg.version, /^\d+\.\d+\.\d+$/);
  assert.equal(lock.version, pkg.version);
  assert.equal(lock.packages[''].version, pkg.version);
  assert.ok(notes.startsWith(`# RoGoal v${pkg.version} - `));
  assert.match(notes,/^## PT-BR$/m);
  assert.match(notes,/^## English$/m);
  assert.ok(read('plugin/source/Config/Defaults.lua').includes(`Version = "${pkg.version}"`));
});
