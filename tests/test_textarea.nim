## TextArea — the multi-line half of the text widgets
##
## The line arithmetic is plain procs over a string, so it can be checked
## without a window. What is not checked here is Pango's caret geometry, which
## needs one.

import std/unittest
import rui

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
