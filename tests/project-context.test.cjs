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
  assert.equal(bridge.getStatus().pluginVersion, null);
  bridge.updatePluginInfo(bridge.session, { projectExport: true, pluginVersion: '0.6.1' });
  assert.equal(bridge.getStatus().pluginVersion, '0.6.1');
  assert.equal(bridge.getStatus().projectExport, true);
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

test('AI response with surrounding prose reaches Studio and waits for its acknowledgement', async (t) => {
  const storageDir = await fs.mkdtemp(path.join(os.tmpdir(), 'rogoal-import-'));
  t.after(() => fs.rm(storageDir, { recursive: true, force: true }));
  const bridge = new BridgeServer({ storageDir });
  bridge.pair({
    code: bridge.pairingCode, studioRunId: 'integration-import', protocolVersion: 2,
    projectExport: true, placeName: 'Arena',
  });
  await bridge.applyOperation({ type: 'ready' });
  const fence = '\x60'.repeat(3);
  const payload = { v: 1, s: [
    ['ServerScriptService/Arena/Main', 'Script', 'print("ready")'],
    ['ServerScriptService/Arena/Rules', 'M', 'return {}'],
    ['StarterPlayer/StarterPlayerScripts/Arena/Hud', 'LocalScript', 'print("UI")'],
  ] };
  const response = ['Here is the starter project.', fence + 'json',
    JSON.stringify(payload), fence, 'Paste into RoGoal.'].join('\n');
  assert.throws(() => parseBundle(response + '\n' + response), /one JSON response/);
  const previewPromise = bridge.previewQuickApply(response);
  const request = bridge.pathResolution.command;
  await bridge.applyOperation({ type: 'resolvedPaths', opId: request.opId, errors: {}, nodes: [
    { id: 'server', parentId: 'game', name: 'ServerScriptService', className: 'ServerScriptService' },
    { id: 'starter', parentId: 'game', name: 'StarterPlayer', className: 'StarterPlayer' },
    { id: 'client', parentId: 'starter', name: 'StarterPlayerScripts', className: 'StarterPlayerScripts' },
  ] });
  const preview = await previewPromise;
  assert.equal(preview.ok, true);
  assert.equal(preview.summary.create, 3);
  const queued = await bridge.applyQuickApply(preview.token);
  const command = bridge.poll().commands.find(item => item.type === 'quickApply');
  assert.equal(command.opId, queued.opId);
  assert.deepEqual(command.entries.map(entry => [entry.className, entry.missingFolders, entry.scaffold]), [
    ['Script', ['Arena'], true], ['ModuleScript', ['Arena'], true], ['LocalScript', ['Arena'], true],
  ]);
  assert.equal(command.entries[0].source, '--!strict\nprint("ready")');
  const events = [];
  bridge.on('event', event => events.push(event));
  await bridge.applyOperation({ type: 'quickApplyResult', opId: command.opId, status: 'applied', results: [] });
  assert.equal(bridge.pendingQuickApply, null);
  assert.ok(events.some(event => event.type === 'quickApply' && event.status === 'applied' && event.count === 3));
  await bridge.disconnect();
});

test('organization creates folders and empty scripts using a dedicated import mode', async t => {
  const storageDir = await fs.mkdtemp(path.join(os.tmpdir(), 'rogoal-structure-'));
  t.after(() => fs.rm(storageDir, { recursive: true, force: true }));
  const bridge = new BridgeServer({ storageDir });
  bridge.pair({ code: bridge.pairingCode, studioRunId: 'structure-test', protocolVersion: 2, projectExport: true });
  await bridge.applyOperation({ type: 'ready' });
  const raw = JSON.stringify({ v: 2, items: [
    ['ServerScriptService/Game/Combat/CombatService', 'M'],
    ['ServerScriptService/Game/Combat', 'F'],
    ['ServerScriptService/Game', 'F'],
  ] });
  assert.throws(() => bridge.previewQuickApply(raw), /Game structure/);
  assert.throws(() => bridge.previewQuickApply(raw, {}, true), /Update RoGoal/);
  bridge.updatePluginInfo(bridge.session, { organizationImport: true });
  const legacy = JSON.stringify({ v: 1, s: [['ServerScriptService/Main', 'S', 'print(1)']] });
  assert.throws(() => bridge.previewQuickApply(legacy, {}, true), /Use Quick Apply for code/);
  assert.throws(() => parseBundle(JSON.stringify({ v: 2, items: [['ServerScriptService/Main', 'S', 'print(1)']] })), /Code is not accepted/);

  const pending = bridge.previewQuickApply(raw, {}, true);
  const request = bridge.pathResolution.command;
  await bridge.applyOperation({ type: 'resolvedPaths', opId: request.opId, errors: [], nodes: [
    { id: 'server', parentId: 'game', name: 'ServerScriptService', className: 'ServerScriptService' },
    { id: 'game-folder', parentId: 'server', name: 'Game', className: 'Folder' },
  ] });
  const result = await pending;
  assert.deepEqual(result.summary, { create: 2, modify: 0, unchanged: 1, errors: 0 });
  const job = await bridge.applyQuickApply(result.token);
  const command = bridge.poll().commands.find(item => item.type === 'quickApply');
  assert.equal(command.opId, job.opId);
  assert.deepEqual(command.entries.map(entry => [entry.className, entry.source, entry.organization]), [
    ['Folder', '', true], ['ModuleScript', '', true],
  ]);
  const events = [];
  bridge.on('event', event => events.push(event));
  await bridge.applyOperation({ type: 'quickApplyResult', opId: job.opId, status: 'applied', results: [] });
  assert.ok(events.some(event => event.type === 'quickApply' && event.organization && event.status === 'applied'));
  await bridge.disconnect();
});
