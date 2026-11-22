'use strict';

const { randomUUID } = require('node:crypto');

function finishExport(session, error, value) {
  const pending = session?.projectExportRequest;
  if (!pending) return;
  delete session.projectExportRequest;
  clearTimeout(pending.timer);
  if (error) pending.reject(error);
  else pending.resolve(value);
}

function requestExport({ session, ready }) {
  if (!ready || !session || session.suspended) throw new Error('Connect Roblox Studio before exporting.');
  if (!session.projectExport) throw new Error('Install the RoGoal 0.6.0 Studio plugin and pair again to export.');
  if (session.projectExportRequest) throw new Error('An export is already in progress.');
  return new Promise((resolve, reject) => {
    const timer = setTimeout(() => finishExport(session, new Error('Studio did not finish exporting within five minutes.')), 300_000);
    timer.unref();
    session.projectExportRequest = { command: { type: 'exportProject', opId: randomUUID() }, resolve, reject, timer };
  });
}

function fenced(value, language) {
  let size = 3;
  for (const match of value.matchAll(/(?:^|\n)[ \t]*~+/g)) size = Math.max(size, match[0].trimStart().length + 1);
  const fence = '~'.repeat(size);
  return `${fence}${language}\n${value}${value.endsWith('\n') ? '' : '\n'}${fence}`;
}

function formatProjectMarkdown(place, scripts) {
  if (!Array.isArray(scripts) || scripts.length > 10000) throw new Error('Invalid Studio export response.');
  for (const script of scripts) {
    if (!script || !Array.isArray(script.path) || !script.path.length ||
        script.path.some(name => typeof name !== 'string') ||
        !['Script', 'LocalScript', 'ModuleScript'].includes(script.className) ||
        (script.source !== undefined && typeof script.source !== 'string')) {
      throw new Error('Invalid script in Studio export response.');
    }
  }
  const ordered = [...scripts].sort((a, b) => {
    const length = Math.min(a.path.length, b.path.length);
    for (let index = 0; index < length; index++) {
      if (a.path[index] !== b.path[index]) return a.path[index] < b.path[index] ? -1 : 1;
    }
    return a.path.length - b.path.length;
  });
  const tree = ['game'];
  const sections = [];
  let previous = [];
  let unavailable = 0;
  ordered.forEach((script, index) => {
    const parent = script.path.slice(0, -1);
    let shared = 0;
    while (shared < parent.length && previous[shared] === parent[shared]) shared++;
    for (let i = shared; i < parent.length; i++) {
      tree.push(`${'  '.repeat(i + 1)}${JSON.stringify(parent[i])}/`);
    }
    tree.push(`${'  '.repeat(parent.length + 1)}${JSON.stringify(script.path.at(-1))} [${script.className}, #${index + 1}]`);
    previous = parent;
    if (script.source === undefined) unavailable++;
    sections.push(`### #${index + 1} · ${script.className}\n\n` +
      fenced(JSON.stringify(['game', ...script.path]), 'json') + '\n\n' +
      (script.source === undefined ? 'Source unavailable in Studio.' : fenced(script.source, 'luau')));
  });
  return {
    count: scripts.length, unavailable,
    markdown: ['# RoGoal project snapshot', fenced(JSON.stringify(place), 'text'),
      `${scripts.length} scripts. ${unavailable} sources unavailable.`,
      '## Script hierarchy', fenced(tree.join('\n'), 'text'),
      '## Script sources', ...sections].join('\n\n') + '\n',
  };
}

function acceptExport({ session }, operation) {
  if (session?.projectExportRequest?.command.opId !== operation.opId) return;
  try {
    if (operation.error) throw new Error(String(operation.error).slice(0, 500));
    finishExport(session, null, formatProjectMarkdown(session.placeName, operation.scripts));
  } catch (error) {
    finishExport(session, error);
  }
}

module.exports = { requestExport, acceptExport, finishExport, formatProjectMarkdown };
