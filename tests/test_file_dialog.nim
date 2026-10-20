## The file dialog and what it is built from -- Breadcrumbs, the name filter,
## the icon list, SidePane -- driven like a user through the real router, over
## a directory made for the test.

import std/[os, sets, strutils, unittest]
import rui
import ../packages/rui_widgets/src/basic/listbox
import ui_harness
from raylib import KeyboardKey

let root = getTempDir() / "rui_file_dialog_test"
removeDir(root)
createDir(root / "docs")
createDir(root / "src")
for f in ["notes.md", "todo.txt", "main.nim"]: writeFile(root / f, "")
for f in ["guide.md", "api.md"]: writeFile(root / "docs" / f, "")
writeFile(root / "src" / "app.nim", "")

proc findWidget(w: Widget, pred: proc(w: Widget): bool): Widget =
  if pred(w): return w
  for c in w.children:
    let hit = c.findWidget(pred)
    if hit != nil: return hit

proc buttonNamed(root: Widget, text: string): Widget =
  root.findWidget(proc(w: Widget): bool = w of Button and Button(w).text == text)

proc rowCentre(list: ListBox, i: int): Point =
  let v = listbox.viewportOf(list)
  Point(x: list.bounds.x + 40, y: v.rowTop(i) + v.rowHeight / 2)

proc rowOf(p: FilePicker, name: string): int =
  ## The row showing `name`, as listed (a folder without its "/").
  p.list.items.find(name)

proc click(r: Rig, p: Point) = r.click(p.x, p.y)

proc doubleClick(r: Rig, p: Point) =
  r.click(p); r.click(p)

suite "file names and paths":
  test "the name filter: a piece of the name, or a glob; case ignored; '..' always":
    check "Notes.md".matchesName("note")
    check "notes.md".matchesName("*.MD")
    check not "notes.md".matchesName("*.nim")
    check "draft1".matchesName("draft?")
    check not "draft12".matchesName("draft?")
    check "docs/".matchesName("doc")            # a folder's "/" is not in its name
    check not "docs/".matchesName("*/")
    check "..".matchesName("anything")
    check "x".matchesName("  ")

  test "breadcrumb steps carry the path up to each one":
    check steps("/home/ada") == @[("/", "/"), ("home", "/home"), ("ada", "/home/ada")]
    check steps("rel/dir") == @[("rel", "rel"), ("dir", "rel/dir")]

  test "the Chosen pane names a file by name and folder; the answer is one path a line":
    check chosenLabel("/a/docs/guide.md") == "guide.md  —  docs"
    check asLines(@["/a/x", "/b/y"]) == "/a/x\n/b/y"
    check okLabelFor(fdOpen, 3) == "Open (3)" and okLabelFor(fdSave) == "Save"

suite "Breadcrumbs":
  test "clicking a step navigates to the path up to it; the end shows when narrow":
    var went = ""
    let b = newBreadcrumbs(path = "/home/ada/notes/2026",
                           onNavigate = proc(p: string) = went = p)
    let r = newRig(stack(b), 400, 120)
    let ada = b.findWidget(proc(w: Widget): bool = w of Crumb and Crumb(w).text == "ada")
    r.click(ada)
    check went == "/home/ada"
    let narrow = newBreadcrumbs(path = "/home/ada/notes/2026").frame(width = 110)
    discard newRig(stack(narrow), 400, 120)
    check narrow.children[^1].visible           # "2026", where you are
    check not narrow.children[0].visible        # "/" gave way to "…""

suite "FilePicker":
  test "lists folders then files with icons; the filter narrows as you type":
    let p = newFilePicker(initialPath = root)
    let r = newRig(stack(p.frame(height = 260)), 500, 300)
    check p.list.items == @["..", "docs", "src", "main.nim", "notes.md", "todo.txt"]
    check p.list.icons == @[riParent, riFolder, riFolder, riFile, riFile, riFile]
    r.click(p.filterBox)
    r.typeText("*.md")
    check p.list.items == @["..", "notes.md"]
    r.key(KeyboardKey.Escape)                   # the search field clears
    check p.list.items.len == 6

  test "a double-click opens a folder; the breadcrumbs follow; '..' goes back":
    var paths: seq[string]
    let p = newFilePicker(initialPath = root)
    p.onPathChange = proc(path: string) = paths.add path
    let r = newRig(stack(p.frame(height = 260)), 500, 300)
    r.doubleClick(p.list.rowCentre(p.rowOf("docs")))
    check p.currentPath == root / "docs"
    check p.crumbs.path == root / "docs"
    check p.list.items == @["..", "api.md", "guide.md"]
    r.doubleClick(p.list.rowCentre(0))
    check p.currentPath == root
    check paths[^1] == root

  test "two single clicks are not a double-click; a double-click on a file activates it":
    var activated = ""
    let p = newFilePicker(initialPath = root)
    p.onActivate = proc(path: string) = activated = path
    let r = newRig(stack(p.frame(height = 260)), 500, 300)
    let a = p.list.rowCentre(p.rowOf("main.nim"))
    let b = p.list.rowCentre(p.rowOf("notes.md"))
    r.click(a.x, a.y); r.click(b.x, b.y)        # two rows: two selections
    check activated == ""
    check p.selectedPaths == @[root / "notes.md"]
    r.doubleClick(b)
    check activated == root / "notes.md"

suite "FileDialog":
  proc openDialog(multiple = true, mode = fdOpen): (Rig, FileDialog, ptr seq[string]) =
    var got = new seq[string]
    let d = newFileDialog(initialPath = root, multiple = multiple, mode = mode,
                          dialogWidth = 760, dialogHeight = 460)
    d.onSelect = proc(files: seq[string]) = got[] = files
    GC_ref(got)
    let r = newRig(stack(newLabel(text = "page"), d), 900, 600)
    d.show()
    r.frame()
    (r, d, addr got[])

  test "files gathered from several folders come back in order, as a list and as lines":
    let (r, d, got) = openDialog()
    let p = d.picker
    r.doubleClick(p.list.rowCentre(p.rowOf("notes.md")))      # a double-click adds
    r.doubleClick(p.list.rowCentre(p.rowOf("docs")))          # into docs
    r.click(p.list.rowCentre(p.rowOf("guide.md")))
    r.click(d.buttonNamed("Add selected"))                    # Add takes the selection
    check d.chosen == @[root / "notes.md", root / "docs" / "guide.md"]
    check d.pane.summary == "2"
    check Button(d.okButton).text == "Open (2)"
    r.doubleClick(p.list.rowCentre(p.rowOf("guide.md")))      # twice is still once
    check d.chosen.len == 2
    r.click(d.okButton)
    check got[] == @[root / "notes.md", root / "docs" / "guide.md"]
    check d.answerText == root / "notes.md" & "\n" & root / "docs" / "guide.md"
    check not d.isVisible

  test "Remove and Clear take files back out":
    let (r, d, _) = openDialog()
    let p = d.picker
    for name in ["main.nim", "notes.md", "todo.txt"]:
      r.doubleClick(p.list.rowCentre(p.rowOf(name)))
    check d.chosen.len == 3
    r.click(d.chosenList.rowCentre(1))
    r.click(d.buttonNamed("Remove"))
    check d.chosen == @[root / "main.nim", root / "todo.txt"]
    r.click(d.buttonNamed("Clear"))
    check d.chosen.len == 0 and Button(d.okButton).text == "Open"

  test "the Chosen pane folds to a strip that keeps the count, and opens again":
    let (r, d, _) = openDialog()
    r.doubleClick(d.picker.list.rowCentre(d.picker.rowOf("notes.md")))
    r.click(d.pane.bounds.x + 60, d.pane.bounds.y + 10)      # its header
    check not d.pane.expanded
    # It eases to the strip over the theme's transition time; what it is
    # heading for is its measured size (headless frames do not advance easing).
    check d.pane.measure(unbounded()).width == d.pane.stripWidth
    check d.pane.summary == "1"
    r.click(d.pane.bounds.x + 8, d.pane.bounds.y + 60)       # anywhere on the strip
    check d.pane.expanded

  test "Escape from the name filter cancels the dialog":
    var cancelled = false
    let (r, d, _) = openDialog()
    d.onCancel = proc() = cancelled = true
    r.click(d.picker.filterBox)
    r.key(KeyboardKey.Escape)
    check cancelled and not d.isVisible

  test "with multiple = false there is no pane, and a double-click answers":
    let (r, d, got) = openDialog(multiple = false)
    check d.pane == nil
    r.doubleClick(d.picker.list.rowCentre(d.picker.rowOf("todo.txt")))
    check got[] == @[root / "todo.txt"] and not d.isVisible

  test "Save answers with the typed name in the folder you are in":
    let (r, d, got) = openDialog(mode = fdSave)
    check d.pane == nil
    r.doubleClick(d.picker.list.rowCentre(d.picker.rowOf("src")))
    r.click(d.nameBox)
    r.typeText("report.txt")
    r.click(d.buttonNamed("Save"))
    check got[] == @[root / "src" / "report.txt"]
