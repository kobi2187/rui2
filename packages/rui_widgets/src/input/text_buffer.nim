## An editable line of text, with a caret and a selection.
##
## Split out of textinput.nim, where the editing lived inside `on_char` and
## `on_key_down`. Three of those branches -- typing over a selection,
## backspacing over one, and the Delete key -- each spelled out the same
## "replace the selected range" arithmetic, and none of them could be exercised
## without a window and a focused widget.
##
## `selStart < 0` means no selection, and `selStart == selEnd` means an empty
## one, which is what a click leaves behind before a drag has happened. Both
## count as "nothing selected" for editing; only the first survives a
## mouse-up. The operations return `true` when they changed the text, so the
## caller knows whether to fire onChange -- moving the caret is not a change.
##
## Indices are byte offsets, matching Pango's indexFromPosition. That is fine
## for the ASCII range the widget currently accepts on input, and is the
## representation to keep when it accepts more: Pango speaks bytes.

type
  TextBuffer* = object
    text*: string
    cursor*: int
    selStart*: int   ## -1 when there is no selection
    selEnd*: int

proc initTextBuffer*(text: string; cursor = 0; selStart = -1;
                     selEnd = -1): TextBuffer =
  TextBuffer(text: text, cursor: cursor, selStart: selStart, selEnd: selEnd)

proc hasSelection*(b: TextBuffer): bool =
  ## An empty selection is not a selection: a plain click sets both ends to the
  ## caret, and that must not make the next keystroke delete anything.
  b.selStart >= 0 and b.selStart != b.selEnd

proc selectionRange*(b: TextBuffer): tuple[a, b: int] =
  ## The selected span, low end first, so a backwards drag reads the same as a
  ## forwards one.
  (min(b.selStart, b.selEnd), max(b.selStart, b.selEnd))

proc clearSelection*(b: var TextBuffer) =
  b.selStart = -1
  b.selEnd = -1

proc deleteSelection*(b: var TextBuffer): bool =
  ## Remove the selected span and leave the caret where it started.
  if not b.hasSelection:
    return false
  let (lo, hi) = b.selectionRange()
  b.text = b.text[0 ..< lo] & b.text[hi .. ^1]
  b.cursor = lo
  b.clearSelection()
  true

proc insert*(b: var TextBuffer, s: string, maxLength = -1): bool =
  ## Type over the selection, if any. `maxLength` of -1 is unlimited, and the
  ## limit is checked after the selection is removed -- replacing ten selected
  ## characters with one must work in a full field.
  discard b.deleteSelection()
  if maxLength >= 0 and b.text.len + s.len > maxLength:
    return false
  b.text.insert(s, b.cursor)
  b.cursor += s.len
  true

proc backspace*(b: var TextBuffer): bool =
  ## Delete the selection, or the character before the caret.
  if b.deleteSelection():
    return true
  if b.cursor <= 0:
    return false
  b.text = b.text[0 ..< b.cursor - 1] & b.text[b.cursor .. ^1]
  b.cursor -= 1
  true

proc deleteForward*(b: var TextBuffer): bool =
  ## Delete the selection, or the character after the caret.
  if b.deleteSelection():
    return true
  if b.cursor >= b.text.len:
    return false
  b.text = b.text[0 ..< b.cursor] & b.text[b.cursor + 1 .. ^1]
  true

proc moveCursor*(b: var TextBuffer, to: int, extend: bool) =
  ## Move the caret, extending the selection when shift is held.
  ##
  ## The anchor is the existing selection's start if there is one, so
  ## shift-arrow twice grows the same selection rather than starting a new one
  ## each time. Without shift the selection goes away, which is what makes a
  ## plain arrow key collapse a selection instead of dragging it along.
  let anchor = if b.selStart >= 0: b.selStart else: b.cursor
  b.cursor = clamp(to, 0, b.text.len)
  if extend:
    b.selStart = anchor
    b.selEnd = b.cursor
  else:
    b.clearSelection()

proc selectAll*(b: var TextBuffer) =
  b.selStart = 0
  b.selEnd = b.text.len
  b.cursor = b.text.len

proc placeCursor*(b: var TextBuffer, at: int) =
  ## Put the caret down at a click, starting an empty selection there so a drag
  ## has an anchor.
  b.cursor = clamp(at, 0, b.text.len)
  b.selStart = b.cursor
  b.selEnd = b.cursor

proc dragTo*(b: var TextBuffer, at: int) =
  b.cursor = clamp(at, 0, b.text.len)
  b.selEnd = b.cursor

proc endDrag*(b: var TextBuffer) =
  ## A click without a drag leaves no selection behind.
  if b.selStart == b.selEnd:
    b.clearSelection()
