# Unusual widgets from ordinary ones

Most new widgets need no widget type of their own and no drawing code. Put
real widgets together, then add behaviour to the result:

| You need | Use |
|---|---|
| Things on top of each other, pinned anywhere | `Stack`, `Positioned` |
| Only part of a widget shown, to the sub-pixel | `Clip(cut = EdgeInsets(...))` |
| Keys on a container | `.focusable()` and `.onKey(proc(k: KeyboardKey): bool)` |
| Any input on any widget | `.onEvent(proc(e: GuiEvent): bool)` (after the widget's own handling) |
| Something every frame, at a speed | `.onTick(proc(dt: float))` |
| Something every n seconds, or once later | `.every(n, action)`, `.after(n, action)` |
| Work that takes long, off the UI thread | `runInBackground(work, done)` |
| Values from threads of your own | `newMailbox(receive)`, `box.send(value)` ([state](store.md#from-other-threads)) |
| A widget that glides by fractions of a pixel | `.subpixel()` |
| Text by lines (a reader, a teleprompter) | `wrapLines(text, style, width)`, `lineHeight(style)` |
| A whole book, a page at a time, read lazily | `TextPager` over `newLinesSource` ([sources](sources.md#long-text-a-page-at-a-time)) |
| A whole book, scrolled | `TextView(source = ...)` |
| A wave, a ruler, a playhead, tracks of clips | the editor pieces on a shared axis ([editors](editors.md)) |
| Controls that show only when wanted | `HoverReveal` |
| Lights, glows, ants along an outline | `widget.adorn(...)` |
| Children that move instead of jumping | `.animateLayout()` |

Timers belong to their widget. They wait while it is hidden or behind a
modal, and they end when it is disposed. They are the app's own pace, so the
user's motion preference doesn't stop them; easing and decorations do obey it.

## Example: the wave reader

A line glides down the page. Above it the next page is already there, below
it the page you are reading. When the line reaches the bottom the next page is
whole, and the line starts again at the top
(`examples/widgets/wave_reader.nim`):

```nim
area = Stack(fit = StackFit.expand).focusable():
  below = Clip():  current = Label(text = thisPage, wrap = true)
  above = Clip():  next = Label(text = nextPage, wrap = true)
  rule = Positioned(left = 0, right = 0, top = 0, height = 2).subpixel():
    Rectangle(color = accent)

area.onTick(proc(dt: float) = move(speed * dt))       # each frame
area.onKey(proc(k: KeyboardKey): bool = ...)           # Up/Down a line, Space pauses

let book = newTextPager(newLinesSource("book.txt"), textStyle)
proc showPages() =                                     # each Label holds one page
  book.setArea(area.bounds.width, area.bounds.height)
  current.text = book.pageAt(here).get.text            # (blank while still being read)
  next.text = book.pageAt(nextStart()).get.text
book.source.attach(area, proc(c: SeqChange) = showPages())   # as paragraphs arrive

proc place() =
  above.cut = EdgeInsets(bottom: area.bounds.height - lineY)
  below.cut = EdgeInsets(top: lineY)
  rule.top = lineY
```

Both pages are real, wrapped Labels: a different font, a theme or a selection
works as it does anywhere else. The book is never loaded whole: the pager reads
only the paragraphs on the two pages (and a stretch ahead), in the background.

## When it really is a drawing

`Paint(onPaint = proc(area: Rect) = ...)` is a widget that is only a drawing,
made with rui_drawing's calls (`drawSdfBox`, `drawSdfSegment`, `drawStyledText`
and the rest). For a whole widget type, with props, state, events, layout and
render together, use `definePrimitive` (see any widget under
`packages/rui_widgets/src`).
