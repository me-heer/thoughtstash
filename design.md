# Thought Stash design

## Product principles

- **Capture without context switching.** Double-tap Shift from any app to save selected text. With no selection, show Thought Stash and focus the composer.
- **Keyboard first.** Every note and section operation has a menu command and shortcut. Pointer controls remain available, but are not required.
- **Local and durable.** Thought Stash has no account, analytics, or network sync. Notes live in `~/Library/Application Support/Thought Stash/notes.json`.
- **Quiet, temporary UI.** Thought Stash is a compact notes window that should appear reliably, accept input immediately, and get out of the way.

## Visual direction

Thought Stash targets macOS 26+ and uses Apple's native Liquid Glass material (`.glassEffect()`, `GlassEffectContainer`) throughout rather than a hand-rolled translucency layer. The compact, approximately 390-point-wide floating panel:

- true glass material background and controls, with pointer-reactive (`interactive`) glass on note cards, the composer, and top-bar controls
- rounded glass search field and circular glass overflow control, tinted while focused
- small uppercase, tracked, collapsible section labels followed by hairline dividers
- glass note cards with hover glow and a vivid accent-color outline for selected cards
- a glass rounded composer anchored at the bottom whose feedback is deliberately mechanical ("Stamp"): the accent ring snaps on at full strength the moment the composer takes focus rather than fading in, a `⏎ SAVE` chip appears beside the send button once there is text, and pressing Return depresses the whole composer like a keycap while a hairline accent ring ripples out from the caret and the new card drops in from above on a spring
- the composer's Markdown preview animates open/closed as it detects Markdown
- fluid motion throughout: animated panel show/hide (fade + slide), animated note insertion/removal/reordering, animated section collapse, and a bouncy checkmark toggle
- an in-app keyboard shortcut guide (`⌘/`, or via the overflow menu) and ambient shortcut hints (composer, empty states, note rows on hover/selection) keep the keyboard-first workflow discoverable without adding permanent chrome
- restrained typography and spacing; hierarchy comes from glass surfaces, motion, and alignment rather than decoration

Editing opens a spacious, focused document sheet with live Markdown styling. Headings, emphasis, lists, quotes, and code render in place as the source is typed, with syntax markers kept subtly visible so cursor movement remains stable. Every note is one Markdown document: its first meaningful line is the card title and the remaining lines form the preview. There is no separate title field or note type.

## Content model

- **Note:** Markdown text entered in the composer, the full editor, or captured from another app. The first meaningful line is displayed as its title.
- **Captured rich text:** optional RTF stored alongside the plain-text fallback. RTF is used for display and copying so bold, italic, links, and other source formatting survive capture.
- **Section:** ordered grouping for notes.

Existing JSON files remain compatible. Legacy separately stored titles are migrated into the first line of note text when loaded.

## Capture flow

```diagram
┌──────────────────┐   double modifier   ┌────────────────────┐
│ Any macOS app    │────────────────────▶│ CGEventTap thread  │
└────────┬─────────┘                     └─────────┬──────────┘
         │ selected content                        │ valid down/up sequence
         ▼                                         ▼
┌──────────────────┐   Cmd-C + polling   ┌────────────────────┐
│ System clipboard │────────────────────▶│ Rich capture       │
└──────────────────┘                     └─────────┬──────────┘
                                                  │ RTF/HTML + plain fallback
                                                  ▼
                                        ┌────────────────────┐
                                        │ Local JSON store   │
                                        └────────────────────┘
```

The event tap is listen-only, runs on a dedicated run loop, re-enables itself after timeout, and is recreated after wake/session activation. Triggering occurs after the second modifier is released so the synthetic copy command is not contaminated by a held Shift key. Clipboard reads poll briefly for slower applications, then restore the user's previous clipboard. Accessibility-selected text is the plain-text fallback.

Secure Input can intentionally prevent macOS from exposing global keyboard events. In that case, **Show Thought Stash** and **Capture Selected Text** remain available from the menu-bar icon.

## Keyboard map

| Action | Shortcut |
| --- | --- |
| Capture selection / show and focus composer | Shift, Shift |
| Focus quick composer | ⌘N |
| Insert newline in quick composer | ⇧Return |
| New note in full editor | ⇧⌘N |
| New section | ⌥⌘N |
| Search | ⌘F |
| Select previous / next note | ⌘↑ / ⌘↓ or ⌘K / ⌘J |
| Copy selected notes | ⌥⌘C |
| Copy selected as numbered list | ⇧⌘C |
| Mark selected done / not done | ⌘D |
| Edit selected note | ⌘E |
| Expand selected note | ⌥⌘Return |
| Merge selected notes | ⇧⌘M |
| Move selected notes to next section | ⌥⌘→ |
| Delete selected notes | ⌘Delete |
| Delete active section | ⌥⌘Delete |
| Save a note | ⌘S |
| Hide Thought Stash / cancel a dialog | Escape |
| Reveal local notes file | ⇧⌘R |
| Show keyboard shortcut guide | ⌘/ |

Commands are also listed in the macOS **Notes** menu, and the in-app keyboard shortcut guide (`⌘/`, or via the overflow menu), so shortcuts remain discoverable. All three read from a single `ShortcutMap` source of truth so they cannot drift out of sync.

## Iteration checklist

- Keep the compact panel readable at its 360-point minimum width.
- Preserve captured formatting through save, reload, merge, and copy.
- Maintain visible focus and selection states for keyboard navigation.
- Prefer direct manipulation in the window; use the full editor for multiline writing and Markdown preview.
- Test global capture after signing/installing because macOS permissions attach to the app's code identity.
- Thought Stash requires macOS 26+ for Liquid Glass; there is no fallback path for older systems.
- Save feedback is mechanical, not decorative: keep the whole Return response under ~400ms so a burst of captures never queues up behind its own animation. Every part restarts from a save counter rather than accumulating.
- Under Reduce Motion the save still confirms itself with a stationary accent flash and a cross-fading card. Silence is not an acceptable reduced state.
- Ambient shortcut hints must stay hover/state-conditional — never occupy permanent layout space, since the panel must stay usable at 360 points wide.
