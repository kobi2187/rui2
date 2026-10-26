## A long text a page at a time (sources/text_pager.nim): pages fit the area,
## follow on with nothing lost or repeated, come from rows read only as far as
## they are needed, and wait (none) for rows still on their way.

import std/[unittest, options, strutils, os, sequtils]
import rui

const style = TextStyle(fontSize: 16)

type CountingSource = ref object of RowSource
  inner: MemorySource
  asked: int                      ## the highest row whose text was read

method count(s: CountingSource): int = s.inner.count
method cell(s: CountingSource, row, col: int): string =
  s.asked = max(s.asked, row)
  s.inner.cell(row, col)

proc paragraphs(n: int): seq[seq[string]] =
  for i in 0 ..< n:
    result.add @["Paragraph " & $i & ": " & "word ".repeat(5 + i mod 30).strip]

proc counting(rows: int): CountingSource =
  CountingSource(inner: newMemorySource(@["text"], paragraphs(rows)), asked: -1)

suite "TextPager":
  test "each page fits the area; together they are the whole text, in order":
    let src = newMemorySource(@["text"], paragraphs(40))
    let pager = newTextPager(src, style)
    pager.setArea(300, 200)
    var all: seq[string]
    var n = 0
    while true:
      let p = pager.page(n)
      if p.isNone: break
      let lines = p.get.split('\n')
      check lines.len <= pager.linesPerPage
      for l in lines: check measureText(l, style).width <= 301
      all.add lines
      inc n
    check pager.pageCount == some(n)
    var expected: seq[string]
    for r in 0 ..< 40: expected.add wrapLines(src.text(r), style, 300)
    check all == expected

  test "only the rows a page shows are read: page 0 of a long book reads its start":
    let src = counting(5000)
    let pager = newTextPager(src, style)
    pager.setArea(300, 200)
    check pager.page(0).isSome
    check src.asked < 20                  # a page's worth, not 5000
    check pager.pageCount.isNone          # the end is not known yet
    check pager.page(3).isSome
    check src.asked < 60

  test "pageAt opens the book anywhere without laying out what comes before":
    let src = counting(5000)
    let pager = newTextPager(src, style)
    pager.setArea(300, 200)
    let p = pager.pageAt(TextPos(row: 4000))
    check p.isSome and p.get.text.startsWith("Paragraph 4000")
    check pager.pagesFound == 1           # no pages before it were laid out
    check p.get.next.row > 4000

  test "a page whose rows are still being read is none until they arrive":
    let path = getTempDir() / "rui_pager_book.txt"
    var text = ""
    for p in paragraphs(3000): text.add p[0] & "\n"
    writeFile(path, text)
    defer: removeFile(path)
    let src = newLinesSource(path)
    defer: src.close()
    let pager = newTextPager(src, style)
    pager.setArea(300, 200)
    var got = none(string)
    for _ in 0 ..< 200:                   # the background reader brings it in
      got = pager.page(2)
      if got.isSome: break
      discard src.poll()
      sleep(5)
    check got.isSome
    check pager.page(0).get.startsWith("Paragraph 0")

  test "another size lays it out afresh; positions stay meaningful":
    let src = newMemorySource(@["text"], paragraphs(60))
    let pager = newTextPager(src, style)
    pager.setArea(300, 200)
    discard pager.page(5)
    let narrow = pager.page(0).get.split('\n').len
    pager.setArea(500, 200)
    check pager.pagesFound == 1
    check pager.page(0).get.split('\n').len <= narrow + 1

  test "following pages by position reaches the end, and atEnd says so":
    let src = newMemorySource(@["text"], paragraphs(25))
    let pager = newTextPager(src, style)
    pager.setArea(300, 200)
    var at = TextPos()
    var pages = 0
    while not pager.atEnd(at):
      let p = pager.pageAt(at)
      check p.isSome
      if p.isNone: break
      at = p.get.next
      inc pages
    var n = 0
    while pager.page(n).isSome: inc n
    check pages == n and pager.pageCount == some(n)   # the same pages as by number
    check pager.pageAt(at).isNone
    check not pager.atEnd(TextPos())
