# Focus mode — four iterations

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
| 1 | **Curtain** | Full-window overlay over the editor; chrome appears only when the pointer reaches for the top edge | `⇧⌘F` from the note editor | `⎋` back to the editor, `⌘S` saves |
| 2 | **Desk** | A separate resizable window you leave open beside other apps, with one permanently quiet status line | `⇧⌘F` anywhere, or `⌘E` on a note | `⌘S` saves, `⌘W` closes |
| 3 | **Spotlight** | Typewriter scrolling with every block but the caret's faded to 24% | A toggle *inside* 1 or 2, not a fifth mode | inherits its host |
| 4 | **Bloom** | No overlay, no window: the composer grows upward until it is the whole panel | `⇧⌘F` while the composer has focus | `⎋` collapses, `⏎` still saves |

### 1 · Curtain

700 pt column, 19 pt text, a 34% scrim so the panel is still faintly present behind. Zero
chrome at rest. Moving the pointer above y=90 fades in one hairline capsule — section,
word and character count, `⌘S` — which fades back out 600 ms after the pointer leaves.

*Costs one overlay state on `NoteEditor`. No window plumbing, no second save path.*

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

## Recommendation

Ship **Bloom + Curtain**, with **Spotlight** as a toggle inside both.

They cover the two entry points you named without inventing a third surface: Bloom is the
composer path, Curtain is the `⌘E` path, and both stay inside the panel's promise of quiet,
temporary UI. Spotlight is a preference, not a mode — it changes how text renders, not where
it lives.

**Desk** is the one to hold. A window that stays open beside other apps is a different
product than a panel that appears and gets out of the way, and it drags in window
restoration, per-window dirty state, and a second answer to "where is my note." Worth
revisiting only if long-form writing turns out to be the main use rather than an occasional
one.

## Still to check

- Long notes: Spotlight's dimming restyles the whole text storage on every selection change.
  Fine at a few KB; needs a visible-range-only pass before it ships.
- Small laptop screens: Curtain at 700 pt inside a 1280 pt window is comfortable; below
  ~900 pt the column should shrink rather than the margins collapsing.
- VoiceOver and keyboard-only: chrome that appears on pointer hover must also appear on
  focus. Curtain's bar currently reveals on hover only.
- Reduce Motion: Bloom's grow-into-the-panel needs a cross-fade fallback, same rule as the
  save animation.
- Unsaved-change recovery: Curtain inherits the editor's discard confirmation; Bloom
  currently would not have one.
