## Fuzzy matching (rui_widgets fuzzy.nim): letters in order, word starts and
## runs ranked first.

import std/unittest
import ../packages/rui_widgets/src/fuzzy

proc names(query: string, texts: openArray[string]): seq[string] =
  for r in fuzzyRank(query, texts): result.add texts[r.index]

suite "fuzzy":
  test "the letters must come in order; case and spaces in the query are ignored":
    check fuzzyMatch("opf", "Open File")[0]
    check fuzzyMatch("OPF", "open file")[0]
    check fuzzyMatch("sav as", "Save As...")[0]
    check not fuzzyMatch("xyz", "Open File")[0]
    check not fuzzyMatch("elif", "Open File")[0]
    check fuzzyMatch("", "anything")[0]

  test "letters prefer the starts of words; positions say where they matched":
    let (_, m) = fuzzyMatch("of", "Open File")
    check m.positions == @[0, 5]                  # the O of Open, the F of File

  test "word starts and runs rank first; a prefix is best":
    check names("of", ["Toggle Comments Off", "Open File", "Go Forward"]) ==
          @["Open File", "Go Forward", "Toggle Comments Off"]
    check names("sav", ["Revert Saved", "Save", "Save As..."])[0] == "Save"
    check names("ws", ["Window: Split", "Wrap Selection", "Words"])[0 .. 1] ==
          @["Wrap Selection", "Window: Split"]

  test "camelCase humps count as word starts":
    let (_, m) = fuzzyMatch("gfn", "getFileName")
    check m.positions == @[0, 3, 7]

  test "limit keeps the best":
    check fuzzyRank("e", ["a", "be", "ce", "de"], limit = 2).len == 2
