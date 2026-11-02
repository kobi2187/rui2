## Fuzzy matching: "opf" finds "Open File", "sav as" finds "Save As...".
##
## The letters typed must appear in the text in order (case ignored), not
## necessarily together. Among the texts that match, the better ones come first:
## letters at the start of words, letters next to each other, a match near the
## start, and a shorter text. Pure, for a command palette, a quick-open, a
## filter box.

import std/[strutils, algorithm]

type FuzzyMatch* = object
  score*: int            ## higher is better
  positions*: seq[int]   ## where each typed letter matched in the text (byte index)

proc isWordStart(text: string, i: int): bool =
  i == 0 or text[i - 1] in {' ', '_', '-', '.', '/', '\\', ':'} or
    (text[i].isUpperAscii and text[i - 1].isLowerAscii)

proc fuzzyMatch*(query, text: string): (bool, FuzzyMatch) =
  ## Whether `query` matches `text`, and how well. Spaces in the query are
  ## skipped (they only help the reader). An empty query matches everything,
  ## equally.
  var m: FuzzyMatch
  let q = query.toLowerAscii.replace(" ", "")
  if q.len == 0: return (true, m)
  let t = text.toLowerAscii
  # Greedy, but each letter prefers a word start ahead of a plain letter:
  # look for the next word start that has it before taking the first one.
  var ti = 0
  for qi in 0 ..< q.len:
    let c = q[qi]
    var found = -1
    var firstAny = -1
    var k = ti
    while k < t.len:
      if t[k] == c:
        if firstAny < 0: firstAny = k
        if isWordStart(text, k):
          found = k
          break
      inc k
    # A word start too far ahead is not worth breaking a run for.
    if found < 0 or (firstAny >= 0 and m.positions.len > 0 and
                     firstAny == m.positions[^1] + 1):
      found = firstAny
    if found < 0: return (false, m)
    m.positions.add found
    ti = found + 1
  # Score it.
  var score = 100
  for i, p in m.positions:
    if isWordStart(text, p): score += 12
    if i > 0 and p == m.positions[i - 1] + 1: score += 8
  score -= m.positions[0] * 2               # a match near the start
  score -= (m.positions[^1] - m.positions[0]) # spread out
  score -= text.len div 4                   # longer texts a little lower
  if t.startsWith(q): score += 25
  m.score = score
  (true, m)

proc fuzzyRank*(query: string, texts: openArray[string], limit = 0):
    seq[tuple[index: int, match: FuzzyMatch]] =
  ## The texts that match, best first (ties keep their order); at most
  ## `limit` (0: all).
  for i, t in texts:
    let (ok, m) = fuzzyMatch(query, t)
    if ok: result.add (i, m)
  result.sort(proc(a, b: tuple[index: int, match: FuzzyMatch]): int =
    result = cmp(b.match.score, a.match.score)
    if result == 0: result = cmp(a.index, b.index))
  if limit > 0 and result.len > limit: result.setLen(limit)
