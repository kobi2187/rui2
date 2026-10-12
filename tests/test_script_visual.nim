## The `visual` scripting verb: commands that span frames, and the pixel
## arithmetic behind the answers. No window: the manager is driven with a fake
## host, and Shot is built by hand.

import std/[unittest, os, strutils, options, monotimes, times]
import rui

let dir = getTempDir() / "rui_visual_test"

proc newManager(): ScriptManager =
  removeDir(dir)
  createDir(dir)
  result = newScriptManager(dir, WidgetTree())
  result.setPolling(0.0)

proc send(sm: ScriptManager, lines: openArray[string]) =
  writeFile(dir / "commands.txt", lines.join("\n") & "\n")
  sm.poll()

proc responses(): seq[string] =
  if fileExists(dir / "responses.txt"):
    for line in lines(dir / "responses.txt"):
      if line.len > 0: result.add line

suite "visual commands":

  test "an immediate answer is written in the same poll":
    let sm = newManager()
    sm.onVisual = proc(selector, what: string): VisualReply =
      VisualReply(ok: true, value: selector & ":" & what)
    sm.send(["1 pane visual clock", "2 * visual frames"])
    check responses() == @["1 pane:clock", "2 *:frames"]
    check not fileExists(dir / "commands.txt")

  test "a waiting command pauses the batch, one poll per frame, then continues":
    let sm = newManager()
    var frame = 0
    sm.onVisual = proc(selector, what: string): VisualReply =
      if what == "wait":
        let started = frame
        return VisualReply(wait: proc(): Option[VisualReply] =
          if frame - started >= 3: some(VisualReply(ok: true, value: "waited " & $(frame - started)))
          else: none(VisualReply))
      VisualReply(ok: true, value: what)
    sm.send(["1 a visual before", "2 a visual wait", "3 a visual after"])
    check responses().len == 0                  # paused: nothing written yet
    check fileExists(dir / ".lock")
    for i in 0 ..< 2:
      inc frame
      sm.poll()
      check responses().len == 0
    inc frame
    sm.poll()
    check responses() == @["1 before", "2 waited 3", "3 after"]
    check not fileExists(dir / ".lock")

  test "a wait may answer with another wait":
    let sm = newManager()
    var phase = 0
    sm.onVisual = proc(selector, what: string): VisualReply =
      VisualReply(wait: proc(): Option[VisualReply] =
        inc phase
        if phase == 1:
          some(VisualReply(wait: proc(): Option[VisualReply] =
            inc phase
            if phase >= 3: some(VisualReply(ok: true, value: "done")) else: none(VisualReply)))
        else: none(VisualReply))
    sm.send(["1 a visual two-step"])
    while responses().len == 0 and phase < 10: sm.poll()
    check responses() == @["1 done"]

  test "a failed wait is a Fail line and the batch goes on":
    let sm = newManager()
    sm.onVisual = proc(selector, what: string): VisualReply =
      if what == "late":
        return VisualReply(wait: proc(): Option[VisualReply] =
          some(VisualReply(ok: false, value: "no visual change in 10ms")))
      VisualReply(ok: true, value: "fine")
    sm.send(["1 a visual late", "2 a visual ok"])
    check responses() == @["1 no visual change in 10ms", "2 fine"]

  test "without a host, visual says so":
    let sm = newManager()
    sm.send(["1 a visual clock"])
    check "not available" in responses()[0]

  test "the next command file waits for the paused batch":
    let sm = newManager()
    var release = false
    sm.onVisual = proc(selector, what: string): VisualReply =
      if what == "hold":
        return VisualReply(wait: proc(): Option[VisualReply] =
          if release: some(VisualReply(ok: true, value: "held")) else: none(VisualReply))
      VisualReply(ok: true, value: what)
    sm.send(["1 a visual hold"])
    writeFile(dir / "commands2.txt", "x")      # a second file must not be mistaken for it
    release = true
    sm.poll()
    check responses() == @["1 held"]

suite "pixels":

  proc shotOf(w, h: int, f: proc(x, y: int): array[4, byte]): Shot =
    result.width = w
    result.height = h
    result.pixels = newSeq[byte](w * h * 4)
    for y in 0 ..< h:
      for x in 0 ..< w:
        let c = f(x, y)
        for k in 0 ..< 4: result.pixels[(y * w + x) * 4 + k] = c[k]

  test "equal regions hash equal; one pixel different hashes differently":
    let flat = shotOf(20, 10, proc(x, y: int): array[4, byte] = [10'u8, 20, 30, 255])
    var bumped = flat
    bumped.pixels[(5 * 20 + 7) * 4] = 11
    check flat.regionStats(0, 0, 20, 10).hash == flat.regionStats(0, 0, 20, 10).hash
    check flat.regionStats(0, 0, 20, 10).hash != bumped.regionStats(0, 0, 20, 10).hash
    # a region that does not include the pixel is unaffected
    check flat.regionStats(0, 0, 5, 10).hash == bumped.regionStats(0, 0, 5, 10).hash

  test "mean colour, and clamping to the shot":
    let s = shotOf(10, 10, proc(x, y: int): array[4, byte] =
      if x < 5: [100'u8, 0, 0, 255] else: [0'u8, 100, 200, 255])
    check s.regionStats(0, 0, 5, 10).mean == [100, 0, 0, 255]
    check s.regionStats(0, 0, 10, 10).mean == [50, 50, 100, 255]
    check s.regionStats(-5, -5, 100, 100).hash == s.regionStats(0, 0, 10, 10).hash

  test "hash text is 16 hex digits even for a large value":
    check hex(0xFFFFFFFFFFFFFFFF'u64) == "ffffffffffffffff"
    check hex(1'u64) == "0000000000000001"

suite "a script's write is an edit":

  test "write reaches the change handler, so what is bound follows":
    var heard = ""
    let input = newTextInput(onChange = proc(t: string) = heard = t)
    check input.handleScriptAction("write", %*{"value": "hello"})["success"].getBool()
    check heard == "hello"

  test "a field other than the default does not fire it":
    var calls = 0
    let input = newTextInput(onChange = proc(t: string) = inc calls)
    discard input.handleScriptAction("write", %*{"field": "placeholder", "value": "x"})
    check calls == 0

  test "toggling a Switch flips it and notifies":
    var seen: seq[bool]
    let s = newSwitch(text = "x", onToggle = proc(on: bool) = seen.add on)
    discard s.handleScriptAction("toggle", newJObject())
    discard s.handleScriptAction("toggle", newJObject())
    check seen == @[true, false]
    check not s.on

  test "writing a Slider tells onChange the new value":
    var v = -1.0'f32
    let s = newSlider(onChange = proc(x: float32) = v = x)
    discard s.handleScriptAction("write", %*{"value": "42"})
    check v == 42.0'f32
