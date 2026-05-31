# KokoroBar macOS App

KokoroBar is a personal macOS menu bar app for reading clipboard or selected text through the local Kokoro FastAPI backend.

## Build a Personal App Bundle

From `macos`:

```sh
scripts/build_app.sh
```

This creates:

```text
macos/dist/KokoroBar.app
```

You can move it to `/Applications`. The bundle is marked as a menu bar agent, so it does not appear as a normal Dock app. The backend source is copied into `Contents/Resources/backend`; a prepared `.venv` and model files are included if they already exist under `backend`.

## Run From Source

Start the backend first:

```sh
cd ../backend
scripts/run.sh
```

In another terminal:

```sh
cd ../macos
swift run KokoroBar
```

You can also open the package in Xcode:

```sh
open Package.swift
```

Then run the `KokoroBar` executable target.

## Menu Bar Commands

- Read Clipboard
- Save Clipboard Audio...
- Read Selected Text
- Stop Speaking
- Start Backend / Stop Backend
- Check Backend
- Settings
- Quit

The global shortcut is `Cmd+Shift+R`. It tries selected text first and falls back to clipboard text.

## Settings

- Backend URL: defaults to `http://127.0.0.1:8880`
- Backend folder
- Voice selection
- Speed slider
- Auto-start backend toggle
- Backend log access
- Generated-audio cache refresh/clear

Auto-start uses the configured backend folder. It works with this repository layout or the backend copied into the app bundle. It expects `uv` or a prepared backend `.venv`.

## Accessibility Permission

Reading selected text uses macOS Accessibility APIs. Enable permission in:

System Settings > Privacy & Security > Accessibility

Add or enable the running app or terminal/Xcode process. Clipboard reading works without Accessibility permission.

## Known Limitations

- Selected text depends on the focused app exposing `AXSelectedText`.
- The generated `.app` is unsigned. macOS may require right-click > Open the first time.
- Pause/resume, queues, and long-text chunk management are not implemented yet.
