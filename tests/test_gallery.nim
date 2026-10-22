## The gallery shows every widget: a widget added to the toolkit and left out of
## examples/gallery has no place to be looked at, so this fails until it has one.

import std/[unittest, sets, strutils, algorithm]
import rui
import "../examples/gallery/gallery_ui"

const notInTheGallery = {
  # owned by the App rather than placed in a tree
  "Toast": "shown by app.toast(...)",
  "FocusRing": "the App's own focus outline",
  "Decoration": "drawn along another widget (`adorn`): examples/widgets/decorations.nim",
  "HelpOverlay": "the App's keyboard help",
  # parts of other widgets, shown inside them when opened
  "CalendarPopup": "DatePicker's popup",
  "ColorPopup": "ColorPicker's popup",
  "ComboList": "ComboBox's list",
  "TooltipTip": "Tooltip's bubble",
}

proc typesIn(w: Widget, seen: var HashSet[string]) =
  seen.incl w.getTypeName()
  # TextInput, PasswordInput and SearchInput are one widget with flags, and
  # report one type; the flags say which role a given one plays.
  if w of TextArea:
    if TextArea(w).secret: seen.incl "PasswordInput"
    if TextArea(w).clearable: seen.incl "SearchInput"
  for c in w.children: typesIn(c, seen)

suite "gallery":

  test "every registered widget appears in it":
    let g = buildGallery()
    var seen: HashSet[string]
    typesIn(g.root, seen)
    var missing: seq[string]
    for name in registeredWidgets():
      var excused = false
      for (n, why) in notInTheGallery:
        if n == name: excused = true
      if name notin seen and not excused: missing.add name
    missing.sort()
    check missing.len == 0
    if missing.len > 0: echo "not in the gallery: ", missing.join(" ")

  test "one tab per title, and the ids a script uses exist":
    let g = buildGallery()
    check g.tabs.tabs.len == tabTitles.len
    check g.tabs.children.len == tabTitles.len
    for id in ["basics.save", "input.text", "live.echo", "live.bump", "live.tick",
               "graphics.plot", "data.table", "menus.openDialog"]:
      var found = false
      proc walk(w: Widget) =
        if w.stringId == id: found = true
        for c in w.children: walk(c)
      walk(g.root)
      check found

  test "the ticker advances only while running, at its interval":
    let g = buildGallery()
    g.live.intervalMs = 10
    let start = g.live.tick.value
    g.stepLive()
    check g.live.tick.value == start               # not running
    g.live.running.value = true
    g.stepLive()
    check g.live.tick.value == start + 1
    g.stepLive()                                    # not yet due
    check g.live.tick.value == start + 1

suite "idle with tabs":

  test "an inactive tab page's dirt does not keep the window repainting":
    # Hidden pages are never painted, so nothing ever cleared their flags and the
    # whole tree reported itself dirty at 60 frames a second.
    let tabs = newTabControl(tabs = @["a", "b"])
    let shown = newVStack()
    let hidden = newVStack()
    let label = newLabel(text = "x")
    hidden.addChild label
    tabs.addChild shown
    tabs.addChild hidden
    tabs.bounds = Rect(x: 0, y: 0, width: 200, height: 100)
    tabs.layout()                       # page 1 is now hidden
    check not hidden.visible
    for w in [Widget(tabs), shown, hidden, label]:
      w.isDirty = false
      w.layoutDirty = false
    label.isDirty = true                # something changes on the hidden page
    label.layoutDirty = true
    check not tabs.anyChildDirty()
    check not tabs.anyChildLayoutDirty()
    hidden.visible = true               # shown again: it is dirty and counts
    check tabs.anyChildDirty()
