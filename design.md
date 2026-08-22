# Copper design

## Product principles

- **Capture without context switching.** Double-tap Shift from any app to save selected text. With no selection, show Copper and focus the composer.
- **Keyboard first.** Every note and section operation has a menu command and shortcut. Pointer controls remain available, but are not required.
- **Local and durable.** Copper has no account, analytics, or network sync. Notes live in `~/Library/Application Support/Copper/notes.json`.
- **Quiet, temporary UI.** Copper is a floating utility panel rather than a destination app. It should appear reliably, accept input immediately, and get out of the way.

## Visual direction

Copper targets macOS 26+ and uses Apple's native Liquid Glass material (`.glassEffect()`, `GlassEffectContainer`) throughout rather than a hand-rolled translucency layer. The compact, approximately 390-point-wide floating panel:

- true glass material background and controls, with pointer-reactive (`interactive`) glass on note cards, the composer, and top-bar controls
- rounded glass search field and circular glass overflow control, tinted while focused
- small uppercase, tracked, collapsible section labels followed by hairline dividers
- glass note cards with hover glow and a vivid accent-color outline for selected cards
- a glass rounded composer anchored at the bottom, outlined with the accent color while focused, whose Markdown preview animates open/closed as it detects Markdown
- fluid motion throughout: animated panel show/hide (fade + slide), animated note insertion/removal/reordering, animated section collapse, and a bouncy checkmark toggle
- an in-app keyboard shortcut guide (`⌘/`, or via the overflow menu) and ambient shortcut hints (composer, empty states, note rows on hover/selection) keep the keyboard-first workflow discoverable without adding permanent chrome
- restrained typography and spacing; hierarchy comes from glass surfaces, motion, and alignment rather than decoration

Longform editing intentionally expands beyond the compact panel. It uses a split Markdown source and live preview, both rendered in glass panes, so writing and rendered structure remain visible together.

## Content model

- **Quick note:** short Markdown text entered in the composer or plain/rich text captured from another app.
- **Longform note:** titled Markdown document with a dedicated split editor and preview.
- **Captured rich text:** optional RTF stored alongside the plain-text fallback. RTF is used for display and copying so bold, italic, links, and other source formatting survive capture.
- **Section:** ordered grouping for quick and longform notes.

Existing JSON files remain compatible because longform and RTF fields are optional.

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

Secure Input can intentionally prevent macOS from exposing global keyboard events. In that case, **Show Copper** and **Capture Selected Text** remain available from the menu-bar icon.

## Keyboard map

| Action | Shortcut |
| --- | --- |
| Capture selection / show and focus composer | Shift, Shift |
| New quick note / focus composer | ⌘N |
| New longform note | ⇧⌘N |
| New section | ⌥⌘N |
| Search | ⌘F |
| Select previous / next note | ⌘↑ / ⌘↓ |
| Copy selected notes | ⌥⌘C |
| Copy selected as numbered list | ⇧⌘C |
| Mark selected done / not done | ⌘D |
| Edit selected note | ⌘E |
| Expand selected note | ⌥⌘Return |
| Merge selected notes | ⇧⌘M |
| Move selected notes to next section | ⌥⌘→ |
| Delete selected notes | ⌘Delete |
| Delete active section | ⌥⌘Delete |
| Save an editor | ⌘S or Return where appropriate |
| Cancel a dialog/editor | Escape |
| Reveal local notes file | ⇧⌘R |
| Show keyboard shortcut guide | ⌘/ |

Commands are also listed in the macOS **Notes** menu, and the in-app keyboard shortcut guide (`⌘/`, or via the overflow menu), so shortcuts remain discoverable. All three read from a single `ShortcutMap` source of truth so they cannot drift out of sync.

## Iteration checklist

- Keep the compact panel readable at its 360-point minimum width.
- Preserve captured formatting through save, reload, merge, and copy.
- Maintain visible focus and selection states for keyboard navigation.
- Prefer direct manipulation in the panel; reserve large sheets for longform writing.
- Test global capture after signing/installing because macOS permissions attach to the app's code identity.
- Copper requires macOS 26+ for Liquid Glass; there is no fallback path for older systems.
- Ambient shortcut hints must stay hover/state-conditional — never occupy permanent layout space, since the panel must stay usable at 360 points wide.
