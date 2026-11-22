'use strict';

const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs/promises');
const os = require('node:os');
const path = require('node:path');
const { BridgeServer } = require('../bridge/bridge-server.cjs');
const { parseBundle, buildQuickApplyPlan } = require('../bridge/quick-apply.cjs');
const { formatProjectMarkdown } = require('../bridge/project-export.cjs');

test('scaffold previews implied folders and refuses to replace existing instances', () => {
  const source = '--!strict\nprint("ready")';
  const raw = JSON.stringify({ v: 1, s: [['StarterPlayer/StarterPlayerScripts/Arena/Client', 'L', source]] });
  const fenced = '\x60\x60\x60json\n' + raw + '\n\x60\x60\x60';
  assert.equal(parseBundle(fenced)[0].source, source);
  const nodes = new Map([
    ['starter', { id: 'starter', parentId: 'game', name: 'StarterPlayer', className: 'StarterPlayer' }],
    ['client', { id: 'client', parentId: 'starter', name: 'StarterPlayerScripts', className: 'StarterPlayerScripts' }],
  ]);
  const plan = buildQuickApplyPlan(raw, nodes);
  assert.equal(plan.summary.create, 1);
  assert.equal(plan.entries[0].className, 'LocalScript');
  assert.deepEqual(plan.entries[0].missingFolders, ['Arena']);
  nodes.set('arena', { id: 'arena', parentId: 'client', name: 'Arena', className: 'Folder' });
  nodes.set('occupied', { id: 'occupied', parentId: 'arena', name: 'Client', className: 'Folder' });
  assert.match(buildQuickApplyPlan(raw, nodes).errors[0].message, /already exists/);
  const item = JSON.parse(raw).s[0];
  assert.throws(() => parseBundle(JSON.stringify({ v: 1, s: [item, item] })), /Duplicate scaffold path/);
});

test('Markdown groups scripts by path and keeps fences, text and unavailable sources distinct', () => {
  const source = '--!strict\n~~~~\nprint("ok")';
  const result = formatProjectMarkdown('Arena', [
    { path: ['Workspace', 'Arena', 'Server'], className: 'Script', source },
    { path: ['Workspace', 'Arena', 'Shared'], className: 'ModuleScript', source: '' },
    { path: ['StarterGui', 'Client'], className: 'LocalScript' },
  ]);
  assert.equal(result.count, 3);
  assert.equal(result.unavailable, 1);
  assert.equal(result.markdown.split('\n').filter(line => line === '    "Arena"/').length, 1);
  assert.ok(result.markdown.includes('~~~~~luau\n' + source + '\n~~~~~'));
  assert.match(result.markdown, /Source unavailable in Studio\./);
});

test('requests a read-only Studio export and ignores a stale reply', async (t) => {
  const storageDir = await fs.mkdtemp(path.join(os.tmpdir(), 'rogoal-export-'));
  t.after(() => fs.rm(storageDir, { recursive: true, force: true }));
  const bridge = new BridgeServer({ storageDir });
  bridge.pair({ code: bridge.pairingCode, studioRunId: 'integration-test', protocolVersion: 2,
    projectExport: true, placeName: 'Arena' });
  await bridge.applyOperation({ type: 'ready' });
  const pending = bridge.exportProject();
  assert.throws(() => bridge.exportProject(), /already in progress/);
  const { command } = bridge.session.projectExportRequest;
  await bridge.applyOperation({ type: 'projectExport', opId: 'stale', scripts: [] });
  assert.equal(bridge.session.projectExportRequest.command, command);
  await bridge.applyOperation({ type: 'projectExport', opId: command.opId, scripts: [
    { path: ['ReplicatedStorage', 'Unindexed'], className: 'ModuleScript', source: 'return {}' },
  ] });
  assert.match((await pending).markdown, /Unindexed/);
  const interrupted = bridge.exportProject();
  const rejection = assert.rejects(interrupted, /disconnected during export/);
  await bridge.disconnect();
  await rejection;
});
