# Focus mode — four iterations

**Curtain (1) shipped** as the app's focus mode — ⇧⌘F, described in
[`../design.md`](../design.md). The lab renders the real `FocusEditorSurface`, so this page
still shows exactly what ⇧⌘F opens; 2–4 remain unbuilt sketches.

A runnable storybook for the distraction-free editor sketched in
[`enhancements-plan.md`](enhancements-plan.md). Each frame is the real
`LiveMarkdownEditor` on real Liquid Glass, so the variants can be typed in and compared
rather than argued about.

```sh
swift run ThoughtStash --zen-lab          # opens the storybook instead of the panel
THOUGHTSTASH_ZEN_VARIANT=spotlight swift run ThoughtStash --zen-lab   # straight to one
```

`⌘1`–`⌘4` switch variants; plain digits still reach the editor. The lab never touches
`notes.json`, starts no capture service, and registers no global hotkey.

## The four

| # | Variant | Thesis | Enter | Exit |
| --- | --- | --- | --- | --- |
| 1 | **Curtain** ✅ | Full-window overlay over the editor; chrome appears only when the pointer reaches for the top edge | `⇧⌘F` from the note editor | `⎋` back to the editor, `⌘S` saves |
| 2 | **Desk** | A separate resizable window you leave open beside other apps, with one permanently quiet status line | `⇧⌘F` anywhere, or `⌘E` on a note | `⌘S` saves, `⌘W` closes |
| 3 | **Spotlight** | Typewriter scrolling with every block but the caret's faded to 24% | A toggle *inside* 1 or 2, not a fifth mode | inherits its host |
| 4 | **Bloom** | No overlay, no window: the composer grows upward until it is the whole panel | `⇧⌘F` while the composer has focus | `⎋` collapses, `⏎` still saves |

### 1 · Curtain

700 pt column, 19 pt text, a 34% scrim so the panel is still faintly present behind. Zero
chrome at rest. Moving the pointer above y=90 fades in one hairline capsule — section,
word and character count, `⌘S` — which fades back out 600 ms after the pointer leaves.

Shipped: one overlay state on `NoteEditor`, no window plumbing and no second save path.
⇧⌘F from the panel opens it directly — a composer draft wins, then the selected note, then
a new empty note — which covers the "I want this while writing in the main input prompt"
case without Bloom's separate surface. Keyboard-only reveal is ⌘ held; the bar also shows
itself for the first 2.2 seconds so the way out is never a secret.

### 2 · Desk

720 pt column, 18 pt text, no scrim, and an empty 28 pt drag region where a titlebar would
be — the window's identity is its text. Because it persists, it keeps a permanent 30 pt
status line (section menu, counts, save state) rather than making you hunt for state in a
window that has been open for an hour.

*Costs a second `NSWindowController` plus its own dirty-state, restore-on-quit, and
"which note is this window showing" bookkeeping.*

### 3 · Spotlight

660 pt column, 20 pt text. The caret is parked at 42% of the window height and the text
scrolls under it; everything outside the caret's block drops to 24% alpha; the column
dissolves into the background at the top and bottom edges instead of being clipped. One
accent tick in the left margin marks the typewriter line — the only chrome in the variant.

Block, not line: consecutive non-blank lines stay lit together, so a list or a wrapped
paragraph doesn't strobe as the caret moves through it.

*Both halves already exist — `LiveMarkdownEditor` gained `dimsUnfocusedText` and
`typewriter` for this storybook, defaulted off, so the sheet editor is unchanged.*

### 4 · Bloom

390 pt — panel width. The note list stays where it is at 16% opacity behind a 2.5 pt blur,
the composer's glass and accent focus ring expand to fill the panel, and the `⏎ SAVE` chip
stays put at the bottom. This is the one that answers "I want it while creating a note
through the main input prompt": nothing moves to a new surface, so capture-then-write stays
a single gesture.

*Panel-local. Reuses the composer's draft and its Return-to-save flow verbatim.*

## Where this landed

**Curtain shipped**, reached from both entry points rather than only the editor: ⇧⌘F inside
the `⌘E` sheet, and ⇧⌘F from the panel, which hands the composer's draft straight into it.
That turned out to cover the composer case well enough that **Bloom** was not built — one
focus surface, two ways in, instead of two surfaces.

**Spotlight** stays a sketch. Its two halves exist as `dimsUnfocusedText` and `typewriter`
on `LiveMarkdownEditor` and are off in the shipped mode; wiring them to a preference is a
small follow-up once the dimming does a visible-range-only pass.

**Desk** is held. A window that stays open beside other apps is a different
product than a panel that appears and gets out of the way, and it drags in window
restoration, per-window dirty state, and a second answer to "where is my note." Worth
revisiting only if long-form writing turns out to be the main use rather than an occasional
one.

## Still to check

- Long notes: Spotlight's dimming restyles the whole text storage on every selection change.
  Fine at a few KB; needs a visible-range-only pass before it ships. Not on the shipped path.
- Small laptop screens: Curtain at 700 pt inside a 1280 pt window is comfortable; below
  ~900 pt the column should shrink rather than the margins collapsing.
- VoiceOver: the bar's buttons stay in the hierarchy at zero opacity, so they are reachable,
  but an invisible focused control is still wrong. Reveal on VoiceOver focus is unsolved.
- Reduce Motion: the shipped mode drops the bar's slide and the sheet's resize spring.
- Unsaved-change recovery: Curtain inherits the editor's discard confirmation, and a
  composer draft is only cleared once a save consumes it.
