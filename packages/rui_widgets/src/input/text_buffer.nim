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
## Indices are byte offsets, matching Pango's indexFromPosition -- Pango speaks
## bytes. The text is UTF-8, so a character can be several bytes; every step
## the caret takes goes through `prevBoundary` / `nextBoundary`, which never
## land inside a character. `maxLength` counts characters, not bytes.

import std/[unicode, strutils, json]
from pango_text import charAttrs

proc isContinuation(c: char): bool {.inline.} =
  (ord(c) and 0xC0) == 0x80

proc isAscii(text: string): bool =
  for c in text:
    if ord(c) >= 0x80: return false
  true

# The caret moves over what a person calls a character -- a grapheme cluster:
# "e" plus a combining accent, a thumbs-up plus a skin tone, a family joined by
# zero-width joiners, a flag. Pango knows the rules (see pango_text.charAttrs).
# Plain ASCII, nearly all text, skips the question: one byte is one character,
# except that CRLF is one.

proc prevBoundary*(text: string, i: int): int =
  ## The start of the character (cluster) before byte offset `i`.
  result = clamp(i, 0, text.len)
  if result == 0:
    return
  if text.isAscii:
    dec result
    if result > 0 and text[result] == '\n' and text[result - 1] == '\r':
      dec result
    return
  let a = charAttrs(text)
  var k = a.byteAt.high
  while k > 0 and a.byteAt[k] >= result:
    dec k                               # the last codepoint that starts before `i`
  while k > 0 and not a.cursorStop[k]:
    dec k
  result = a.byteAt[k]

proc nextBoundary*(text: string, i: int): int =
  ## The start of the character (cluster) after the one at byte offset `i`.
  result = clamp(i, 0, text.len)
  if result == text.len:
    return
  if text.isAscii:
    inc result
    if result < text.len and text[result] == '\n' and text[result - 1] == '\r':
      inc result
    return
  let a = charAttrs(text)
  var k = 0
  while k < a.byteAt.high and a.byteAt[k] <= result:
    inc k                               # the first codepoint that starts after `i`
  while k < a.byteAt.high and not a.cursorStop[k]:
    inc k
  result = a.byteAt[k]

proc backspaceStart*(text: string, i: int): int =
  ## Where the text Backspace removes begins. Usually the cluster before the
  ## caret -- but for a combining mark it is just the mark (the accent comes off
  ## and the letter stays), which is Pango's `backspace_deletes_character`.
  let at = clamp(i, 0, text.len)
  if at == 0 or text.isAscii:
    return prevBoundary(text, at)
  let a = charAttrs(text)
  var k = a.byteAt.high
  while k > 0 and a.byteAt[k] > at:
    dec k
  if k > 0 and a.backspaceChar[k]:
    return a.byteAt[k - 1]
  prevBoundary(text, at)

proc isTypeable*(r: Rune): bool =
  ## Whether a typed codepoint is text rather than a control character.
  ## C0 controls, DEL and the C1 block are not; everything else is.
  let c = r.int32
  c >= 0x20 and c != 0x7F and not (c >= 0x80 and c <= 0x9F)

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
  if maxLength >= 0 and b.text.runeLen + s.runeLen > maxLength:
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
  let start = backspaceStart(b.text, b.cursor)
  b.text = b.text[0 ..< start] & b.text[b.cursor .. ^1]
  b.cursor = start
  true

proc deleteForward*(b: var TextBuffer): bool =
  ## Delete the selection, or the character after the caret.
  if b.deleteSelection():
    return true
  if b.cursor >= b.text.len:
    return false
  b.text = b.text[0 ..< b.cursor] & b.text[nextBoundary(b.text, b.cursor) .. ^1]
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

proc selectedText*(b: TextBuffer): string =
  ## The selected span, or "" when nothing is selected.
  if not b.hasSelection:
    return ""
  let (lo, hi) = b.selectionRange()
  b.text[lo ..< hi]

# ============================================================================
# Words
#
# A word is a run of letters, digits and underscores; everything else --
# spaces, punctuation -- separates words. Classified per rune, so "שלום" and
# "naïve" are one word each. Pango's PangoLogAttr would add dictionary word
# breaking for scripts without spaces (Thai, CJK); that is on TODO.md.
# ============================================================================

proc runeAt(text: string, i: int): Rune =
  var r: Rune
  fastRuneAt(text, i, r, doInc = false)
  r

proc isWordRune(r: Rune): bool =
  r.isAlpha or (r.int32 < 128 and char(r.int32) in {'0'..'9', '_'})

proc isWordAt(text: string, i: int): bool =
  i >= 0 and i < text.len and text.runeAt(i).isWordRune

proc prevWordStart*(text: string, i: int): int =
  ## Ctrl+Left: back over any separators, then to the start of the word.
  result = clamp(i, 0, text.len)
  while result > 0 and not text.isWordAt(prevBoundary(text, result)):
    result = prevBoundary(text, result)
  while result > 0 and text.isWordAt(prevBoundary(text, result)):
    result = prevBoundary(text, result)

proc nextWordEnd*(text: string, i: int): int =
  ## Ctrl+Right: over any separators, then to the end of the word.
  result = clamp(i, 0, text.len)
  while result < text.len and not text.isWordAt(result):
    result = nextBoundary(text, result)
  while result < text.len and text.isWordAt(result):
    result = nextBoundary(text, result)

proc wordAt*(text: string, i: int): tuple[a, b: int] =
  ## The word around byte offset `i`, for a double-click. On a separator it is
  ## just that one character, which is what a double-click on a space selects.
  let at = clamp(i, 0, text.len)
  if not text.isWordAt(at):
    if at > 0 and text.isWordAt(prevBoundary(text, at)):
      return (prevWordStart(text, at), at)          # clicked just past a word
    return (at, nextBoundary(text, at))
  var a = at
  while a > 0 and text.isWordAt(prevBoundary(text, a)):
    a = prevBoundary(text, a)
  (a, nextWordEnd(text, at))

proc selectRange*(b: var TextBuffer, a, z: int) =
  ## Select a..z with the caret at z.
  b.selStart = clamp(a, 0, b.text.len)
  b.selEnd = clamp(z, 0, b.text.len)
  b.cursor = b.selEnd

proc deleteWordBack*(b: var TextBuffer): bool =
  ## Ctrl+Backspace: the selection, or back to the start of the word.
  if b.deleteSelection():
    return true
  let start = prevWordStart(b.text, b.cursor)
  if start == b.cursor:
    return false
  b.text = b.text[0 ..< start] & b.text[b.cursor .. ^1]
  b.cursor = start
  true

proc deleteWordForward*(b: var TextBuffer): bool =
  ## Ctrl+Delete: the selection, or on to the end of the word.
  if b.deleteSelection():
    return true
  let stop = nextWordEnd(b.text, b.cursor)
  if stop == b.cursor:
    return false
  b.text = b.text[0 ..< b.cursor] & b.text[stop .. ^1]
  true

# ============================================================================
# Pasting
# ============================================================================

proc fitPaste*(s: string, multiline: bool, room: int, breaks = -1): string =
  ## What of a pasted string a field can take. A single-line field turns line
  ## breaks into spaces rather than refusing the paste; `room` (characters,
  ## -1 for unlimited) and `breaks` (new lines allowed, -1 for unlimited)
  ## truncate rather than refuse, which is what desktop fields do with an
  ## over-long paste.
  result = s.replace("\r\n", "\n").replace('\r', '\n')
  if not multiline:
    result = result.replace('\n', ' ')
  elif breaks >= 0:
    var seen = 0
    for i, c in result:
      if c == '\n':
        if seen == breaks:
          result.setLen(i)
          break
        inc seen
  if room >= 0 and result.runeLen > room:
    result = result.runeSubStr(0, room)

proc paste*(b: var TextBuffer, s: string, multiline: bool,
            maxLength = -1, maxLines = -1): bool =
  ## Replace the selection with as much of `s` as fits.
  discard b.deleteSelection()
  let room = if maxLength < 0: -1 else: max(0, maxLength - b.text.runeLen)
  let breaks = if maxLines < 0: -1 else: max(0, maxLines - 1 - b.text.count('\n'))
  let fitted = fitPaste(s, multiline, room, breaks)
  if fitted.len == 0:
    return false
  b.insert(fitted)

# ============================================================================
# Undo
#
# Every edit records the state it replaced. A run of typing is one step: a
# keystroke that inserts right where the previous one left the caret joins
# that step instead of starting a new one, so Ctrl+Z takes back a word, not a
# letter. Moving the caret, deleting, pasting, or typing a space ends the run.
# ============================================================================

type
  Snapshot* = object
    text*: string
    cursor*, selStart*, selEnd*: int

  EditHistory* = object
    undoStack*: seq[Snapshot]
    redoStack*: seq[Snapshot]
    inRun: bool       ## the last recorded edit was typing
    runEnd: int       ## where that run left the caret

const HistoryLimit* = 200

proc snapshot*(b: TextBuffer): Snapshot =
  Snapshot(text: b.text, cursor: b.cursor, selStart: b.selStart, selEnd: b.selEnd)

proc restore*(b: var TextBuffer, s: Snapshot) =
  b.text = s.text
  b.cursor = s.cursor
  b.selStart = s.selStart
  b.selEnd = s.selEnd

proc isTyping(before, after: Snapshot): bool =
  ## One or more characters inserted at the caret, none of them a separator,
  ## with nothing selected beforehand.
  let grew = after.text.len - before.text.len
  if grew <= 0 or before.selStart >= 0 and before.selStart != before.selEnd:
    return false
  if after.cursor != before.cursor + grew:
    return false
  for r in after.text[before.cursor ..< after.cursor].runes:
    if not r.isWordRune:
      return false
  true

proc record*(h: var EditHistory, before, after: Snapshot) =
  ## Note an edit. Call it for every operation, text-changing or not: a caret
  ## move is what ends a typing run.
  if after.text == before.text:
    h.inRun = false
    return
  let typing = isTyping(before, after)
  if typing and h.inRun and before.cursor == h.runEnd:
    h.runEnd = after.cursor            # same step, extended
    return
  h.undoStack.add before
  if h.undoStack.len > HistoryLimit:
    h.undoStack.delete(0)
  h.redoStack.setLen(0)
  h.inRun = typing
  h.runEnd = after.cursor

proc undo*(h: var EditHistory, b: var TextBuffer): bool =
  if h.undoStack.len == 0:
    return false
  h.redoStack.add b.snapshot
  b.restore(h.undoStack.pop())
  h.inRun = false
  true

proc redo*(h: var EditHistory, b: var TextBuffer): bool =
  if h.redoStack.len == 0:
    return false
  h.undoStack.add b.snapshot
  b.restore(h.redoStack.pop())
  h.inRun = false
  true

proc `%`*(h: EditHistory): JsonNode =
  ## What a script sees: how far back and forward it can go, not the text.
  %*{"undo": h.undoStack.len, "redo": h.redoStack.len}
