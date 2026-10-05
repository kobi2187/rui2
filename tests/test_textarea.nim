## TextArea — the multi-line half of the text widgets
##
## The line arithmetic is plain procs over a string, so it can be checked
## without a window. What is not checked here is Pango's caret geometry, which
## needs one.

import std/unittest
import rui
import std/[monotimes, unicode, times, strutils]
from raylib import KeyboardKey

suite "finding the lines":

  test "an empty string is one empty line, not no lines":
    check lineStarts("") == @[0]
    check lineOf("", 0) == 0
    check lineEnd("", 0) == 0

  test "a single line with no newline":
    check lineStarts("hello") == @[0]
    check lineEnd("hello", 0) == 5

  test "a newline starts a line":
    check lineStarts("ab\ncd") == @[0, 3]
    check lineEnd("ab\ncd", 0) == 2     # not counting the newline itself
    check lineEnd("ab\ncd", 1) == 5

  test "a trailing newline means a final empty line":
    check lineStarts("ab\n") == @[0, 3]
    check lineEnd("ab\n", 1) == 3

  test "consecutive newlines are empty lines":
    check lineStarts("a\n\nb") == @[0, 2, 3]
    check lineEnd("a\n\nb", 1) == 2      # the empty line

suite "where an offset sits":

  const text = "one\ntwo\nthree"

  test "the line an offset falls on":
    check lineOf(text, 0) == 0
    check lineOf(text, 3) == 0           # the newline belongs to the line before
    check lineOf(text, 4) == 1
    check lineOf(text, 8) == 2
    check lineOf(text, 13) == 2

  test "the column within that line":
    check columnOf(text, 0) == 0
    check columnOf(text, 2) == 2
    check columnOf(text, 4) == 0         # start of line 1
    check columnOf(text, 6) == 2

suite "moving between lines":

  test "the same column on the next line":
    const text = "hello\nworld"
    check indexAtLineColumn(text, 1, 2) == 8      # 'r'
    check columnOf(text, indexAtLineColumn(text, 1, 2)) == 2

  test "a short line clamps to its end rather than overshooting":
    # Overshooting would land on the line *after* the short one, which reads as
    # the caret skipping a line.
    const text = "long line here\nab\nanother"
    let target = indexAtLineColumn(text, 1, 10)
    check lineOf(text, target) == 1
    check target == lineEnd(text, 1)

  test "moving above the first line stays on it":
    const text = "one\ntwo"
    check lineOf(text, indexAtLineColumn(text, -1, 1)) == 0

  test "moving below the last line stays on it":
    const text = "one\ntwo"
    check lineOf(text, indexAtLineColumn(text, 99, 1)) == 1

  test "an empty line is reachable and has one position":
    const text = "a\n\nb"
    let target = indexAtLineColumn(text, 1, 5)
    check lineOf(text, target) == 1
    check columnOf(text, target) == 0

suite "a run of Up/Down keeps its column":

  test "passing through a short line does not drift left":
    const text = "long line here\nab\nanother line"
    # Caret at column 10 of line 0.
    let first = verticalMove(text, 10, -1, down = true)
    check lineOf(text, first.index) == 1
    check first.index == lineEnd(text, 1)          # clamped on the short line
    check first.goalColumn == 10                   # ...but still aiming for 10
    let second = verticalMove(text, first.index, first.goalColumn, down = true)
    check lineOf(text, second.index) == 2
    check columnOf(text, second.index) == 10       # back at the column it left

  test "without a run the caret's own column is the goal":
    const text = "abcdef\nabcdef"
    let move = verticalMove(text, 3, -1, down = true)
    check move.goalColumn == 3
    check columnOf(text, move.index) == 3

  test "moving up works the same way":
    const text = "first line\nx\nthird line"
    let start = lineStarts(text)[2] + 7
    let up1 = verticalMove(text, start, -1, down = false)
    let up2 = verticalMove(text, up1.index, up1.goalColumn, down = false)
    check columnOf(text, up2.index) == 7

suite "the widget":

  test "it constructs and seeds from initialText":
    let ta = newTextArea(initialText = "hello\nworld")
    check ta.text == "hello\nworld"
    check ta.cursorPos == 0

  test "it starts with nothing selected":
    # -1, not 0: an empty selection at 0 would make the first keystroke delete.
    let ta = newTextArea()
    check ta.selectionStart == -1

  test "it sizes itself to visibleLines":
    let ta = newTextArea(visibleLines = 3, padding = 4.0, fontSize = 14.0)
    ta.layout()
    check ta.bounds.height > 0
    check ta.bounds.width > 0

    let taller = newTextArea(visibleLines = 10, padding = 4.0, fontSize = 14.0)
    taller.layout()
    check taller.bounds.height > ta.bounds.height

  test "it is focusable, since it takes keys":
    check newTextArea().focusable

  test "it scripts like any other widget":
    let ta = newTextArea(initialText = "x")
    check ta.getTypeName() == "TextArea"
    let res = ta.handleScriptAction("write", %*{"value": "typed"})
    check res["success"].getBool()
    check ta.text == "typed"

  test "Down, Down through a short line comes back to the column":
    let ta = newTextArea(initialText = "long line here\nab\nanother line")
    ta.focused = true
    ta.cursorPos = 10
    proc press(k: KeyboardKey) =
      discard ta.handleInput(GuiEvent(kind: evKeyDown, key: k,
                                      timestamp: getMonoTime()))
    press(KeyboardKey.Down)
    check lineOf(ta.text, ta.cursorPos) == 1
    press(KeyboardKey.Down)
    check columnOf(ta.text, ta.cursorPos) == 10

  test "a sideways move starts a new run":
    let ta = newTextArea(initialText = "long line here\nab\nanother line")
    ta.focused = true
    ta.cursorPos = 10
    proc press(k: KeyboardKey) =
      discard ta.handleInput(GuiEvent(kind: evKeyDown, key: k,
                                      timestamp: getMonoTime()))
    press(KeyboardKey.Down)                    # clamped to column 2
    press(KeyboardKey.Left)                    # column 1, run over
    press(KeyboardKey.Down)
    check columnOf(ta.text, ta.cursorPos) == 1

suite "typing beyond ASCII":

  test "a typed codepoint is inserted whole":
    let ta = newTextArea()
    ta.focused = true
    for r in "שלום é".runes:
      discard ta.handleInput(GuiEvent(kind: evChar, rune: r,
                                      timestamp: getMonoTime()))
    check ta.text == "שלום é"
    check ta.cursorPos == ta.text.len

  test "an event built with only char still types it":
    let ta = newTextArea()
    ta.focused = true
    discard ta.handleInput(GuiEvent(kind: evChar, char: 'x',
                                    timestamp: getMonoTime()))
    check ta.text == "x"

  test "Left steps back over a whole character":
    let ta = newTextArea(initialText = "a€")
    ta.focused = true
    ta.cursorPos = ta.text.len
    discard ta.handleInput(GuiEvent(kind: evKeyDown, key: KeyboardKey.Left,
                                    timestamp: getMonoTime()))
    check ta.cursorPos == 1

  test "columns count characters, so Up/Down line them up":
    const text = "éé|\nab|"
    check columnOf(text, 4) == 2                       # after "éé" (4 bytes)
    check indexAtLineColumn(text, 1, 2) == lineStarts(text)[1] + 2
    check verticalMove(text, 4, -1, down = true).index == lineStarts(text)[1] + 2

suite "one text widget, limited by properties":
  ## Label, TextInput and TextArea are one type. What differs is properties,
  ## and getTypeName reports the role they give a widget.

  proc key(w: TextArea, k: KeyboardKey): bool =
    w.handleInput(GuiEvent(kind: evKeyDown, key: k, timestamp: getMonoTime()))

  proc typeText(w: TextArea, s: string) =
    for r in s.runes:
      discard w.handleInput(GuiEvent(kind: evChar, rune: r,
                                     timestamp: getMonoTime()))

  test "Label and TextInput are TextArea":
    check newLabel(text = "x") of TextArea
    check newTextInput() of TextArea
    check Label is TextArea
    check TextInput is TextArea

  test "the reported type follows the limiting properties":
    check newLabel(text = "x").getTypeName() == "Label"
    check newTextInput().getTypeName() == "TextInput"
    check newTextArea().getTypeName() == "TextArea"
    let w = newTextArea()
    w.multiline = false
    check w.getTypeName() == "TextInput"
    w.editable = false
    check w.getTypeName() == "Label"

  test "a Label takes no input, so it cannot swallow a click":
    let l = newLabel(text = "caption")
    l.focused = true
    check not l.focusable
    check not l.handleInput(GuiEvent(kind: evMouseDown,
                                     mousePos: Point(x: 1, y: 1)))
    check not l.key(KeyboardKey.Backspace)
    l.typeText("z")
    check l.text == "caption"

  test "a Button's caption does not take its clicks":
    let b = newButton(text = "Go")
    b.layout()
    let caption = b.children[1]
    check caption.getTypeName() == "Label"
    check not caption.handleInput(GuiEvent(kind: evMouseDown,
                                           mousePos: Point(x: 1, y: 1)))

  test "a TextInput submits on Enter instead of adding a line":
    var submitted = ""
    let t = newTextInput(onSubmit = proc(s: string) = submitted = s)
    t.focused = true
    t.typeText("hi")
    check t.key(KeyboardKey.Enter)
    check t.text == "hi"
    check submitted == "hi"

  test "a TextInput leaves Up and Down to focus navigation":
    let t = newTextInput(initialText = "one line")
    t.focused = true
    check not t.key(KeyboardKey.Up)
    check not t.key(KeyboardKey.Down)

  test "maxLines stops Enter at the limit":
    let a = newTextArea(maxLines = 2)
    a.focused = true
    a.typeText("a")
    discard a.key(KeyboardKey.Enter)
    a.typeText("b")
    discard a.key(KeyboardKey.Enter)      # would be a third line
    check a.text == "a\nb"

  test "maxLength limits every role that edits":
    let t = newTextInput(maxLength = 3)
    t.focused = true
    t.typeText("abcdef")
    check t.text == "abc"

  test "a read-only TextArea keeps its frame but refuses edits":
    let a = newTextArea(initialText = "fixed", editable = false)
    a.focused = true
    a.typeText("x")
    check a.text == "fixed"
    check a.framed

  test "a Label sizes to its text with no padding; an input pads":
    let l = newLabel(text = "same", fontSize = 14.0)
    let t = newTextInput(initialText = "same", padding = 8.0)
    l.layout()
    t.layout()
    check t.bounds.height == l.bounds.height + 16.0

  test "a Label re-measures when its text changes":
    let l = newLabel(text = "a", fontSize = 14.0)
    l.layout()
    let w1 = l.bounds.width
    l.text = "a much longer caption"
    l.layout()
    check l.bounds.width > w1

  test "a Label's text is what a script writes":
    let l = newLabel(text = "before")
    discard l.handleScriptAction("write", %*{"value": "after"})
    check l.text == "after"
    check l.getScriptableState()["type"].getStr() == "Label"

suite "editing shortcuts":
  ## Clipboard through the in-memory seam; modifiers on the event.

  proc press(w: TextArea, k: KeyboardKey, mods: set[KeyMod] = {}): bool =
    w.handleInput(GuiEvent(kind: evKeyDown, key: k, mods: mods,
                           timestamp: getMonoTime()))

  proc typeText(w: TextArea, s: string) =
    for r in s.runes:
      discard w.handleInput(GuiEvent(kind: evChar, rune: r,
                                     timestamp: getMonoTime()))

  setup:
    useClipboard(memoryClipboard())

  test "Ctrl+A, Ctrl+C, Ctrl+V":
    let a = newTextInput(initialText = "copy me")
    let b = newTextInput()
    a.focused = true
    b.focused = true
    check a.press(KeyboardKey.A, {kmCtrl})
    check a.press(KeyboardKey.C, {kmCtrl})
    check clipboardText() == "copy me"
    check b.press(KeyboardKey.V, {kmCtrl})
    check b.text == "copy me"

  test "Ctrl+X cuts":
    let a = newTextArea(initialText = "cut this")
    a.focused = true
    discard a.press(KeyboardKey.A, {kmCtrl})
    discard a.press(KeyboardKey.X, {kmCtrl})
    check a.text == ""
    check clipboardText() == "cut this"

  test "pasting a paragraph into a TextInput keeps it on one line":
    setClipboardText("line one\nline two")
    let t = newTextInput()
    t.focused = true
    discard t.press(KeyboardKey.V, {kmCtrl})
    check t.text == "line one line two"

  test "Ctrl+Z undoes typing a word at a time; Ctrl+Shift+Z and Ctrl+Y redo":
    let a = newTextArea()
    a.focused = true
    a.typeText("hello world")
    check a.press(KeyboardKey.Z, {kmCtrl})
    check a.text == "hello "
    check a.press(KeyboardKey.Z, {kmShift, kmCtrl})
    check a.text == "hello world"
    discard a.press(KeyboardKey.Z, {kmCtrl})
    discard a.press(KeyboardKey.Y, {kmCtrl})
    check a.text == "hello world"

  test "an undo fires onChange, since the text changed":
    var seen = ""
    let a = newTextArea(onChange = proc(t: string) = seen = t)
    a.focused = true
    a.typeText("abc")
    discard a.press(KeyboardKey.Z, {kmCtrl})
    check seen == ""

  test "Ctrl+arrows move by word, Shift extends":
    let a = newTextInput(initialText = "one two three")
    a.focused = true
    discard a.press(KeyboardKey.Right, {kmCtrl})
    check a.cursorPos == 3
    discard a.press(KeyboardKey.Right, {kmCtrl, kmShift})
    check a.selectionStart == 3 and a.selectionEnd == 7

  test "Ctrl+Backspace deletes a word":
    let a = newTextInput(initialText = "one two")
    a.focused = true
    a.cursorPos = a.text.len
    discard a.press(KeyboardKey.Backspace, {kmCtrl})
    check a.text == "one "

  test "Ctrl+Enter submits a multi-line area":
    var got = ""
    let a = newTextArea(onSubmit = proc(t: string) = got = t)
    a.focused = true
    a.typeText("done")
    check a.press(KeyboardKey.Enter, {kmCtrl})
    check got == "done"
    check a.text == "done"                     # no newline added

  test "an unused Ctrl chord is left for the application":
    let a = newTextArea()
    a.focused = true
    check not a.press(KeyboardKey.Q, {kmCtrl})

  test "a double-click selects a word, a triple-click the line":
    let a = newTextArea(initialText = "first line\nsecond")
    a.layout()
    let t0 = getMonoTime()
    proc click(dt: int) =
      discard a.handleInput(GuiEvent(kind: evMouseDown,
        mousePos: Point(x: a.bounds.x + a.inset + 2, y: a.bounds.y + a.inset + 2),
        timestamp: t0 + initDuration(milliseconds = dt)))
      discard a.handleInput(GuiEvent(kind: evMouseUp,
        timestamp: t0 + initDuration(milliseconds = dt + 10)))
    click(0)
    click(100)
    check a.selectionStart == 0 and a.selectionEnd == 5     # "first"
    click(200)
    check a.selectionEnd == "first line".len                # the whole line
    click(2000)                                             # too slow: a click
    check a.selectionStart == -1 or a.selectionStart == a.selectionEnd

  test "editable text shows an I-beam; a label defers to its parent":
    let t = newTextInput()
    t.layout()
    check t.cursorShape == csText
    let l = newLabel(text = "x")
    l.layout()
    check l.cursorShape == csDefault
    let b = newButton(text = "Go")
    b.layout()
    check b.children[1].effectiveCursor == csArrow

suite "keeping the caret in view":

  test "a caret inside the view does not scroll":
    check scrollToShow(0.0, 50.0, 1.0, 100.0, 300.0) == 0.0

  test "past the right edge scrolls just far enough":
    check scrollToShow(0.0, 150.0, 1.0, 100.0, 300.0) == 51.0

  test "before the left edge scrolls back to it":
    check scrollToShow(80.0, 20.0, 1.0, 100.0, 300.0) == 20.0

  test "never scrolls into blank space past the content":
    # The text shrank: the old offset would show nothing but padding.
    check scrollToShow(200.0, 10.0, 1.0, 100.0, 50.0) == 0.0

  test "short content never scrolls":
    check scrollToShow(0.0, 40.0, 1.0, 100.0, 60.0) == 0.0

suite "wrapping while editing":
  const Para = "The quick brown fox jumps over the lazy dog and keeps running " &
               "across the field until the evening comes."
  let font = textStyle(14.0, BLACK, "", false, false, false).pangoFont

  proc focusedArea(text: string, width: float32): TextArea =
    result = newTextArea(initialText = text, fontSize = 14.0, padding = 4.0)
    result.bounds = Rect(x: 0, y: 0, width: width, height: 200)
    result.layout()
    result.focused = true

  proc key(w: TextArea, k: KeyboardKey): bool =
    w.handleInput(GuiEvent(kind: evKeyDown, key: k, timestamp: getMonoTime()))

  test "without a width, visual lines are the hard lines":
    let lines = visualLines("one\ntwo\n\nfour", font, 0)
    var spans: seq[(int, int)]
    for l in lines: spans.add (l.start, l.stop)
    check spans == @[(0, 3), (4, 7), (8, 8), (9, 13)]

  test "a long paragraph breaks into lines that fit, and covers the text":
    let lines = visualLines(Para, font, 150)
    check lines.len > 2
    check lines[0].start == 0 and lines[^1].stop == Para.len
    for i in 1 ..< lines.len:
      check lines[i].start == lines[i - 1].stop          # contiguous
    for line in lines:
      let w = measureText(Para[line.start ..< line.stop].strip(leading = false),
                          textStyle(14.0, BLACK, "", false, false, false)).width
      check w <= 151

  test "hard lines still break where the newlines are":
    let lines = visualLines(Para & "\nshort", font, 150)
    check (lines[^1].start, lines[^1].stop) == (Para.len + 1, Para.len + 6)

  test "every wrapped line keeps its paragraph's direction":
    let mixed = "שלום עולם, a paragraph that starts in Hebrew and goes on in English for a while"
    let lines = visualLines(mixed & "\nEnglish first, then שלום", font, 120)
    check lines.len > 3
    for l in lines:
      if l.start < mixed.len: check l.dir == tdRtl
      else: check l.dir == tdLtr

  test "an editable TextArea wraps by default; a TextInput never does":
    let ta = focusedArea(Para, 160)
    check ta.linesOf.len > 2
    let input = newTextInput(initialText = Para)
    input.bounds = Rect(x: 0, y: 0, width: 160, height: 30)
    check input.linesOf.len == 1

  test "Down moves to the next line as drawn, inside one paragraph":
    let ta = focusedArea(Para, 160)
    let lines = ta.linesOf
    discard ta.key(Down)
    check visualLineOf(lines, ta.cursorPos) == 1
    check ta.cursorPos < Para.len                        # still the first paragraph

  test "End stops at the end of the drawn line, not the paragraph":
    let ta = focusedArea(Para, 160)
    let lines = ta.linesOf
    discard ta.key(End)
    check ta.cursorPos < lines[1].start
    check visualLineOf(lines, ta.cursorPos) == 0
    discard ta.key(Home)
    check ta.cursorPos == 0

  test "a click on the second drawn line lands in it":
    let ta = focusedArea(Para, 160)
    let lines = ta.linesOf
    let lineH = ta.contentOf.lineHeight
    let at = ta.indexAt(Point(x: 10, y: ta.textRect.y + lineH * 1.5))
    check visualLineOf(lines, at) == 1

  test "wrap = false keeps one line per paragraph":
    let ta = newTextArea(initialText = Para, wrap = false, fontSize = 14.0)
    ta.bounds = Rect(x: 0, y: 0, width: 160, height: 200)
    check ta.linesOf.len == 1
