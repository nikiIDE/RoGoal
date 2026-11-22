# RoGoal

RoGoal is a Windows Luau workbench for Roblox Studio. The Electron app includes Monaco, a synchronized Explorer, search across scripts, split editing, recovery snapshots, Quick Apply for previewing and importing script bundles, and Project context for preparing AI scaffold prompts and exporting Places as Markdown.

The Studio plugin opens as a dockable widget. The two apps pair with a six-digit code and communicate over `127.0.0.1:38471`. Script history, drafts, and recovery snapshots are stored locally.

## Install on Windows

1. Download the Windows installer and `RoGoal.rbxmx` from the [latest release](https://github.com/nikiIDE/RoGoal/releases/latest).
2. Run the installer. With Roblox Studio closed, place `RoGoal.rbxmx` in `%LOCALAPPDATA%\Roblox\Plugins`. Disable older copies of the bridge plugin before pairing.
3. Open RoGoal on Windows and select **Plugins → RoGoal** in Roblox Studio. Enter the code displayed by the Windows app. Allow the plugin to access its localhost endpoint when Studio prompts you.

The Windows app reuses the previous bridge data directory so existing drafts, preferences and backups remain available. The Studio widget has separate **Pair** and **Session** tabs. Its settings menu controls the theme and motion.

## Build from source

Use Node.js 22 or newer and Python 3.10 or newer.

```powershell
npm ci
python scripts/build_plugin.py
npm run build
npm run package:win
```

The Studio model is written to `RoGoal.rbxmx`. The Windows x64 installer and its update metadata are written to `release/`. Use `npm run dev` to launch the development app.

## Tests

```powershell
npm test
python -m unittest discover -s tests -p test_plugin_build.py -v
python -m pip install -r tests/browser/requirements.txt
python -m playwright install chromium
npm run test:ui
npm run test:ui:workspace
```

The Playwright suites simulate a Studio connection and exercise Monaco, the Explorer, and recovery flows. GitHub Actions runs workspace validation and can build and publish a release using the **Build and publish Windows release** workflow.

See the [workspace controls](docs/WORKSPACE.md) and [release notes](docs/RELEASE_0_6_0.md). This repository continues the [original bridge](https://github.com/nikis-gif/CursorBridge) and retains its proprietary `UNLICENSED` status.
