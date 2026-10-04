# RUI2 — roadmap and principles

What it takes to go from "a solid alpha" to **the GUI toolkit people pick**.
**The work itself is tracked in GitHub issues** (label `roadmap`; bugs found on the
way are issues too). This file keeps what issues do not: the principles that decide
what gets built. [STATUS.md](STATUS.md) says what works today; [ROADMAP.md](ROADMAP.md)
is the phase history.

**Where RUI2 is already strong:** retained widgets with per-widget texture
caching, push-based `Link[T]` reactivity with O(1) invalidation, Pango text
(Unicode, BiDi, shaping), 48 widgets, keyboard focus groups, a scripting
protocol plus headless frames for testing, and a codebase under a complexity
gate. The open gaps (see the issues) are what stands between that and Qt/Flutter-level trust.

## Principles (they decide what gets built, and in what order)

1. **Instantaneous and beautiful.** A change must land inside one frame at
   10,000 widgets, and every widget ships with a considered look in every
   brand. Speed is measured (`tools/bench.sh`, docs/PERFORMANCE.md), not
   assumed.
2. **Full Unicode text.** Shaping, BiDi, emoji and combining marks, CJK input
   (IME), grapheme-aware editing. Text is never second-class.
3. **Accessibility: low priority.** Screen-reader support is not a goal for
   now (#17 stays parked); don't spend effort there.
4. **Integrates, but looks the same everywhere.** Drag and drop in and out,
   clipboard, system dark/light preference -- yes. Native file dialogs and
   native-looking widgets -- no: the drawn FileDialog stays, so an app looks
   identical on every platform.
5. **Open to new widgets, each small and focused.** Innovate freely: nothing
   has to copy a platform widget, and there are tons in the box. A widget does
   one job; the ceiling is a chart or a kanban board, and only data-backed
   grids and tables are bigger. Anything larger (a text editor with
   highlighting, a rich-text editor) is built from our primitives by the app,
   not shipped.
6. **Lean on raylib.** It is a game engine: batching, double buffering,
   shaders, render textures, MSAA, texture filtering, event waiting. Reuse
   what it has before writing our own (what it does *not* cull or smooth for
   us is listed under #8 and #18). Animation and effects use it directly.
7. **Preferences are the user's; themes are the author's.** How the person
   works with applications (navigation keys, motion, scroll speed, caret
   blink, double-click speed) is one per-user file shared by every RUI app,
   with stable defaults an app cannot override. Looks and the app's own
   behaviour are the theme, set by the author. docs/preferences.md.
8. **The DSL is the API, and it stays transparent.** `ui:` is plain sugar over
   constructors, props are named and typed, there is no hidden state. A new
   user should be able to read an example and write the next one.

Legend: **P0** blocks real apps · **P1** expected of any modern toolkit ·

---

---

## Where the work is

| Topic | Issue |
|---|---|
| Typing latency (bug) | [#42](https://github.com/kobi2187/rui2/issues/42) |
| Layout: measure/arrange, spans, RTL, overlay hit-testing | [#43](https://github.com/kobi2187/rui2/issues/43) |
| Text: Thai/CJK words, wrap while editing, IME | [#44](https://github.com/kobi2187/rui2/issues/44) |
| `Link` thread safety | [#45](https://github.com/kobi2187/rui2/issues/45) |
| Themes: describe, round-trip, transitions, hot-reload | [#46](https://github.com/kobi2187/rui2/issues/46) |
| Reactivity: `bind`, `LinkSeq` | [#47](https://github.com/kobi2187/rui2/issues/47) |
| HiDPI | [#48](https://github.com/kobi2187/rui2/issues/48) |
| Performance | [#49](https://github.com/kobi2187/rui2/issues/49) |
| Effects (shadows, blur, gradients) | [#50](https://github.com/kobi2187/rui2/issues/50) |
| Developer experience | [#51](https://github.com/kobi2187/rui2/issues/51) |
| Platform integration | [#52](https://github.com/kobi2187/rui2/issues/52) |
| Widgets | [#53](https://github.com/kobi2187/rui2/issues/53) |
| Code health | [#54](https://github.com/kobi2187/rui2/issues/54) |
| Release (CI on Windows/macOS, v0.2.0) | [#55](https://github.com/kobi2187/rui2/issues/55) |
| Accessibility (parked) | [#56](https://github.com/kobi2187/rui2/issues/56) |
| Split into repos / publish to Nimble | [#35](https://github.com/kobi2187/rui2/issues/35), [#36](https://github.com/kobi2187/rui2/issues/36) |

