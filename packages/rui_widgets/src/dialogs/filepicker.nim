## FilePicker Widget - RUI2
##
## An embeddable file browser, built from real widgets: Breadcrumbs for the
## path (click a step to go back up to it), a SearchInput that filters the
## names as you type ("draft", "*.nim"), and a ListBox of the directory with a
## folder or page icon on each row. Not modal and without buttons -- drop it
## into any container; FileDialog is this picker in a modal with buttons.
##
## A click selects (ctrl-click adds, with `multiSelect`); a double-click or
## Enter opens a folder, or *activates* a file (`onActivate`): what a dialog
## takes as "open this one".

import rui_core
import rui_drawing
import file_listing
import ../basic/[breadcrumbs, listbox]
import ../input/textarea
import ../layout/flex
import std/[os, sets]

export file_listing

type
  FilePickerMode* = enum
    fpOpen              # Open an existing file
    fpSave              # Save a file
    fpDirectory         # Choose a directory

const FilterWidth = 170.0'f32

proc iconFor(entry: string): RowIcon =
  if entry == ParentEntry: riParent
  elif entry.isDirectoryEntry: riFolder
  else: riFile

proc rebuildList(widget: Widget)
proc openDirectory*(widget: Widget, path: string)
proc pathOf*(widget: Widget, entry: string): string

definePrimitive(FilePicker):
  props:
    mode: FilePickerMode = fpOpen
    filters: seq[string] = @[]   # e.g. @["*.txt", "*.nim"]
    initialPath: string = "."
    multiSelect: bool = false
    intent: ThemeIntent = Default

  state:
    currentPath: string
    fileList: seq[string]        # the directory, ".." first, before the name filter
    shown: seq[string]           # what the list shows: fileList through the name filter
    nameFilter: string
    selectedFiles: HashSet[string]
    crumbs: Breadcrumbs
    filterBox: TextInput
    list: ListBox
    loaded: bool                 # the directory has been read at least once

  actions:
    onSelect(paths: HashSet[string])
    onPathChange(path: string)
    onActivate(path: string)     # a double-click or Enter on a file

  init:
    let picker = widget
    widget.crumbs = newBreadcrumbs(intent = widget.intent)
    widget.crumbs.onNavigate = proc(path: string) = picker.openDirectory(path)
    widget.filterBox = newSearchInput(placeholder = "Filter names")
    widget.filterBox.onChange = proc(text: string) =
      picker.nameFilter = text
      picker.rebuildList()
    widget.list = newListBox(multiSelect = widget.multiSelect, intent = widget.intent)
    widget.list.onSelect = proc(rows: HashSet[int]) =
      picker.selectedFiles.clear()
      for i in rows:
        if i < picker.shown.len and picker.shown[i] != ParentEntry:
          picker.selectedFiles.incl picker.pathOf(picker.shown[i])
      if picker.onSelect != nil: picker.onSelect(picker.selectedFiles)
    widget.list.onItemActivate = proc(i: int) =
      if i >= picker.shown.len: return
      let entry = picker.shown[i]
      let dest = navigatedPath(picker.currentPath, entry)
      if dest.len > 0: picker.openDirectory(dest)
      elif picker.onActivate != nil: picker.onActivate(picker.pathOf(entry))
    let bar = newRow(spacing = 8.0, crossAxisAlignment = CrossAxisAlignment.center)
    bar.addChild(widget.crumbs.flex())
    bar.addChild(widget.filterBox.frame(width = FilterWidth))
    let column = newVStack(spacing = 6.0)
    column.addChild(bar)
    column.addChild(widget.list.flex())
    widget.addChild(column)

  layout:
    # First layout is also when the directory gets read: a picker built from the
    # DSL constructor has no chance to run code of its own before this.
    if not widget.loaded:
      widget.loaded = true
      widget.openDirectory(if widget.currentPath.len > 0: widget.currentPath
                           else: widget.initialPath)
    if widget.bounds.width <= 0: widget.bounds.width = 420.0
    if widget.bounds.height <= 0: widget.bounds.height = 300.0
    widget.children[0].arrange(widget.bounds)

proc pathOf*(widget: Widget, entry: string): string =
  ## The full path of a listed entry, without a directory's trailing "/".
  let picker = FilePicker(widget)
  picker.currentPath / (if entry.isDirectoryEntry and entry != ParentEntry: entry[0 ..< ^1]
                        else: entry)

proc rebuildList(widget: Widget) =
  ## Show the directory through the name filter, with an icon per row. The
  ## selection belonged to the rows that were there, so it goes.
  let picker = FilePicker(widget)
  picker.shown.setLen(0)
  var icons: seq[RowIcon]
  var names: seq[string]
  for entry in picker.fileList:
    if entry.matchesName(picker.nameFilter):
      picker.shown.add entry
      icons.add iconFor(entry)
      # the folder icon says it is a folder; the "/" listEntries marks it with need not
      names.add (if entry != ParentEntry and entry.isDirectoryEntry: entry[0 ..< ^1] else: entry)
  let list = picker.list
  list.items = names                    # props: their setters redraw
  list.icons = icons
  list.selection.clear()               # changed in place: no setter runs, so repaint by hand
  list.focusIndex = 0
  list.scrollY = 0
  list.markDirtyToRoot()
  if picker.selectedFiles.len > 0:
    picker.selectedFiles.clear()
    if picker.onSelect != nil: picker.onSelect(picker.selectedFiles)

proc openDirectory*(widget: Widget, path: string) =
  ## Go to `path` and read it: the breadcrumbs follow, the selection and scroll
  ## belong to the directory you left. The name filter stays, as it does in
  ## every file manager: you are looking for the same kind of thing.
  let picker = FilePicker(widget)
  let full = try: absolutePath(path).normalizedPath except OSError: path
  picker.currentPath = full
  picker.fileList = listEntries(full, picker.filters, picker.mode == fpDirectory)
  picker.crumbs.path = full
  picker.rebuildList()
  if picker.onPathChange != nil: picker.onPathChange(full)

proc refresh*(widget: FilePicker) =
  ## Re-read the current directory, e.g. after something on disk changed.
  widget.openDirectory(widget.currentPath)

proc selectedPaths*(widget: FilePicker): seq[string] =
  ## The selected entries as full paths, in the order they are listed.
  for i, entry in widget.shown:
    if i in widget.list.selection and entry != ParentEntry:
      result.add widget.pathOf(entry)
