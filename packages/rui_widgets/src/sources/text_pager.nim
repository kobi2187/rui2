## TextPager -- a long text, a page at a time, read only as far as it is needed.
##
## A book is too big to hand to a Label. A pager takes it from a row source --
## one paragraph per row, so `newLinesSource("book.txt")` reads a plain text
## file lazily, in the background, a stretch at a time -- and lays out pages
## that fit a given width and height, when they are asked for:
##
## ```nim
## let book = newTextPager(newLinesSource("book.txt"), style)
## book.setArea(width, height)
## let p = book.page(41)          # some(text), or none while its rows are still coming
## ```
##
## - **Read lazily:** a page asks the source only for the paragraphs it shows
##   (and a stretch beyond, for the next). A paragraph not read yet makes the
##   page `none` for now; the source fetches it, and the next try has it. A
##   frame never waits for the disk.
## - **Laid out lazily:** pages are found in order and only where each one
##   starts is kept (a few integers a page). `pageAt(pos)` lays out one page
##   from any position, without the pages before it -- to open a book where it
##   was left.
## - Each page is its lines joined by newlines, every line already fitting the
##   width, so a wrapped Label of that width shows exactly that page.
## - A blank row is a blank line (the space between paragraphs).
##
## Memory: the source keeps a bounded cache of what it has read, the pager a
## bounded cache of wrapped paragraphs and the page starts it has found.

import rui_core
import rui_drawing
import std/[options, tables, strutils]
import row_source

type
  TextPos* = object
    ## A place in the text: a paragraph (source row), and a line within it as
    ## wrapped to the pager's width.
    row*, line*: int

  PageText* = tuple[text: string, next: TextPos]

  TextPager* = ref object
    source*: RowSource
    style*: TextStyle
    width, height: float32
    starts: seq[TextPos]                 # where page i starts; starts[0] is the beginning
    lastPage: int                        # -1 until the end has been found
    wrapped: Table[int, seq[string]]     # paragraphs as lines, at this width
    wrapOrder: seq[int]                  # oldest first, to keep the cache bounded

const
  WrapCacheSize = 512                    # paragraphs kept wrapped
  ReadAhead = 64                         # rows asked for past the one needed

proc newTextPager*(source: RowSource, style: TextStyle): TextPager =
  TextPager(source: source, style: style, starts: @[TextPos()], lastPage: -1)

proc setArea*(p: TextPager, width, height: float32) =
  ## The size a page must fit. A different size lays the text out afresh
  ## (page numbers change; positions do not).
  if width == p.width and height == p.height: return
  p.width = width
  p.height = height
  p.starts = @[TextPos()]
  p.lastPage = -1
  p.wrapped.clear()
  p.wrapOrder.setLen(0)

proc linesPerPage*(p: TextPager): int =
  max(1, int(p.height / lineHeight(p.style)))

proc atEnd(p: TextPager, row: int): bool =
  ## Past the last paragraph -- known only once the source has finished counting.
  row >= p.source.count and not p.source.busy

proc atEnd*(p: TextPager, pos: TextPos): bool =
  ## `pos` is past the last line of the text (false while that is not known yet).
  p.atEnd(pos.row)

proc paragraph(p: TextPager, row: int): Option[seq[string]] =
  ## Row `row` as lines at the pager's width, or none while it is not read yet
  ## (it is asked for, with a stretch after it).
  if row in p.wrapped: return some(p.wrapped[row])
  if row >= p.source.count or p.source.rowState(row) == rsPending:
    p.source.want(row, row + ReadAhead)
    return none(seq[string])
  let lines = wrapLines(p.source.text(row), p.style, p.width)
  if p.wrapOrder.len >= WrapCacheSize:
    p.wrapped.del p.wrapOrder[0]
    p.wrapOrder.delete(0)
  p.wrapped[row] = lines
  p.wrapOrder.add row
  some(lines)

proc pageAt*(p: TextPager, pos: TextPos): Option[PageText] =
  ## The page that starts at `pos`, and where the one after it starts; none
  ## while a paragraph it needs has not been read yet, or past the end.
  if p.width <= 0 or p.height <= 0 or p.atEnd(pos.row): return none(PageText)
  var lines: seq[string]
  var at = pos
  let room = p.linesPerPage
  while lines.len < room:
    if p.atEnd(at.row): break
    let para = p.paragraph(at.row)
    if para.isNone: return none(PageText)   # not here yet: try again when it is
    let ls = para.get
    while at.line < ls.len and lines.len < room:
      lines.add ls[at.line]
      inc at.line
    if at.line >= ls.len:
      at = TextPos(row: at.row + 1, line: 0)
  if lines.len == 0: return none(PageText)
  some((text: lines.join("\n"), next: at))

proc page*(p: TextPager, n: int): Option[string] =
  ## Page `n` (from 0): laid out after the pages before it, which are found on
  ## the way and remembered by where they start. none while something it needs
  ## is still being read, or past the last page.
  if n < 0 or (p.lastPage >= 0 and n > p.lastPage): return none(string)
  while p.starts.len <= n:
    let prev = p.pageAt(p.starts[^1])
    if prev.isNone:
      if p.atEnd(p.starts[^1].row): p.lastPage = p.starts.len - 2
      return none(string)
    p.starts.add prev.get.next
  let got = p.pageAt(p.starts[n])
  if got.isNone:
    if p.atEnd(p.starts[n].row): p.lastPage = n - 1
    return none(string)
  if p.atEnd(got.get.next.row): p.lastPage = n
  some(got.get.text)

proc start*(p: TextPager, n: int): Option[TextPos] =
  ## Where page `n` starts, once it has been found -- to remember a place.
  if n < p.starts.len: some(p.starts[n]) else: none(TextPos)

proc pageCount*(p: TextPager): Option[int] =
  ## How many pages, once the last one has been found.
  if p.lastPage >= 0: some(p.lastPage + 1) else: none(int)

proc pagesFound*(p: TextPager): int =
  ## Pages laid out so far (whose starts are known).
  p.starts.len
