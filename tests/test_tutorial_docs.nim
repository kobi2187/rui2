## docs/tutorial.md shows the real example files, not copies that can drift.
## Each `<!-- file: PATH -->` marker is followed by a ```nim block, which must be
## exactly that file. (The files themselves are built with every other example.)

import std/[unittest, strutils, os]

suite "tutorial":

  test "every code block is the file it names":
    let doc = readFile("docs/tutorial.md")
    var checked = 0
    var rest = doc
    while true:
      let m = rest.find("<!-- file: ")
      if m < 0: break
      rest = rest[m + 11 .. ^1]
      let path = rest[0 ..< rest.find(" -->")]
      let start = rest.find("```nim\n") + 7
      let stop = rest.find("\n```", start)
      let body = rest[start ..< stop]
      check fileExists(path)
      check body == readFile(path).strip(leading = false, chars = {'\n'})
      inc checked
      rest = rest[stop .. ^1]
    check checked == 3
