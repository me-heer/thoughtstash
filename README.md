# Thought Stash

A local-only, native macOS scratchpad for AI-assisted work. Select text in any app and double-tap Shift to capture it.

## Build and run

```sh
./Scripts/build-app.sh
open "dist/Thought Stash.app"
```

For development, use `swift run ThoughtStash`. Run the test suite with `swift test`.

On first capture, macOS asks for Accessibility access. Enable Thought Stash in **System Settings → Privacy & Security → Accessibility**, then try the shortcut again.

Notes are stored as readable JSON at `~/Library/Application Support/Thought Stash/notes.json`.

## Included

- Global selected-text capture with a configurable double-modifier shortcut
- Floating native panel and menu bar item
- Local JSON storage with no account, sync, or tracking
- Sections, search, Markdown rendering, editing, completion, and deletion
- Multi-select, merge, move, copy, and numbered-list copy
