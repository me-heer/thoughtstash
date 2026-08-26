# Thought Stash design

## Product principles

- **Capture without context switching.** Double-tap Shift from any app to save selected text. With no selection, show Thought Stash and focus the composer.
- **Keyboard first.** Every note and section operation has a menu command and shortcut. Pointer controls remain available, but are not required. List navigation is anchored the way platform lists are — a cursor the arrows move, an anchor a ⇧-extended range grows from — and stepping down past the last note hands focus to the composer rather than sticking to the end.
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

⇧⌘F takes that sheet into **focus mode**: the sheet's own header, divider and footer drop
away, the text takes a 700-point column over a scrimmed glass window, and the only chrome
left is one hairline capsule that returns when it is reached for — pointer near the top
edge, ⌘ held, or the first two seconds after entering, so the way out is never hidden. ⎋
steps back to the ordinary editor rather than discarding the note; leaving the sheet is
still Cancel's job. ⇧⌘F from the panel opens focus mode directly: a composer draft wins —
you are already mid-sentence — then the selected note, then a new empty note. The draft
stays in the composer until a save consumes it, so cancelling gives it back.

## Identity

The app icon is a fanned deck of three note cards on a graphite ground, the front card's
title line carrying the accent. The accent lands on the title because that is the app's
one structural rule made visible: the first meaningful Markdown line of a note becomes its
card title. Artwork lives in `Icon/AppIcon.svg`; `Scripts/make-icon.sh` renders it to
`Resources/AppIcon.icns`, which is checked in so an ordinary build needs no librsvg.

The menu-bar item is the same deck reduced to what survives at 17 points: the solid front
card under the tilted top edge of the card behind it. Two cards in outline collide at that
size, so the back one is an edge rather than a shape. It is drawn in `StatusItemGlyph`
rather than shipped as an asset because it has to be a template image to invert correctly
in light and dark menu bars.

The name appears in the window in two places, both set in New York and both pinned to
`.serif` regardless of the user's `AppFontTheme`, so the wordmark keeps its face when the
rest of the app is switched to sans or mono. That exception is deliberate.

The first is the empty state, which is onboarding: it renders only while `notes.isEmpty`,
so it is gone after the first capture and never returns.

The second is the header, which is the actual mark. The title row and the search field are
the same row: the name sits on the left with a circular search button and the overflow
control on the right, and pressing ⌘F or the button morphs the row into the search field
via a shared `glassEffectID`. Escape collapses it back; a field with a query in it stays
open so a filtered list keeps an obvious way out.

That shape was chosen because it costs nothing. A search field that is empty almost all of
the time does not need to hold a full-width row open for a state you are in for seconds,
and trading it for a button buys a permanent wordmark at zero vertical cost. The wordmark
is set at 20 points — roughly 1.5x the 14-point note title — because at anything near body
size it reads as a stray label rather than a title.

Two AppKit details the header depends on. `.borderlessButton` menus size themselves to
their glyph and ignore the label's frame, and `.glassEffect` on such a menu — or on its
label — renders nothing; the overflow control therefore pins its own 34-point frame and
draws the glass behind itself, or it ends up a bare glyph beside a search button that has
a full disc. And Escape is routed from `NotesKeyMonitor` through `.stashEscape` rather than
closing the window directly, because what Escape means now depends on view state.

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
| Extend selection up / down | ⇧⌘↑ / ⇧⌘↓ or ⇧⌘K / ⇧⌘J |
| Copy selected notes | ⌥⌘C |
| Copy selected as numbered list | ⇧⌘C |
| Mark selected done / not done | ⌘D |
| Edit selected note | ⌘E |
| Focus mode / leave focus mode | ⇧⌘F / ⎋ |
| Expand selected note | ⌥⌘Return |
| Merge selected notes | ⇧⌘M |
| Move selected notes to previous / next section | ⌥⌘← / ⌥⌘→ or ⌥⌘K / ⌥⌘J |
| Delete selected notes | ⌘Delete |
| Delete active section | ⌥⌘Delete |
| Save a note | ⌘S |
| Hide Thought Stash / cancel a dialog | Escape |
| Reveal local notes file | ⇧⌘R |
| Show keyboard shortcut guide | ⌘/ |

Commands are also listed in the macOS **Notes** menu, and the in-app keyboard shortcut guide (`⌘/`, or via the overflow menu), so shortcuts remain discoverable. All three read from a single `ShortcutMap` source of truth so they cannot drift out of sync.

## Iteration checklist

- Keep the compact panel readable at its 360-point minimum width.
- Re-run `Scripts/make-icon.sh` after editing `Icon/AppIcon.svg`; the `.icns` is a build artifact that happens to be checked in.
- Preserve captured formatting through save, reload, merge, and copy.
- Maintain visible focus and selection states for keyboard navigation.
- Prefer direct manipulation in the window; use the full editor for multiline writing and Markdown preview.
- Test global capture after signing/installing because macOS permissions attach to the app's code identity.
- Thought Stash requires macOS 26+ for Liquid Glass; there is no fallback path for older systems.
- Save feedback is mechanical, not decorative: keep the whole Return response under ~400ms so a burst of captures never queues up behind its own animation. Every part restarts from a save counter rather than accumulating.
- Under Reduce Motion the save still confirms itself with a stationary accent flash and a cross-fading card. Silence is not an acceptable reduced state.
- Ambient shortcut hints must stay hover/state-conditional — never occupy permanent layout space, since the panel must stay usable at 360 points wide. The header wordmark is the one sanctioned exception, and it earns it by replacing the search row rather than adding to it: net layout cost is zero. Anything else asking for permanent space has to clear the same bar.
