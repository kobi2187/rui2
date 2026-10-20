## FileDialog Widget - RUI2
##
## A modal open / save / choose-directory dialog, built from real widgets: a
## FilePicker (breadcrumbs, a name filter, a list with icons) and, for opening
## several, a "Chosen" SidePane that collects files from any number of
## folders. Move between folders, Add what you want (or double-click it), and
## Open hands the app the whole list -- as `onSelect(files)`, and as text, one
## path per line, with `asLines`. The pane folds to a strip that keeps the
## count when you want the room.
##
## With `multiple = false`, or to save, there is no pane: a double-click (or
## Open) answers with the one file; Save takes the name typed at the bottom.
##
## Like every modal it covers the screen to dim what is behind (modal.nim),
## and Escape -- from anywhere inside it -- cancels.
##
## ```nim
## let dlg = newFileDialog(title = "Attach files", filters = @["*.pdf", "*.png"])
## dlg.onSelect = proc(files: seq[string]) = attach(files.asLines)
## dlg.show()
## ```

import rui_core
import rui_drawing
import modal
import file_listing
import filepicker
import ../basic/[button, listbox]
import ../containers/sidepane
import ../input/textarea
import ../layout/flex
import std/[os, sets]
from raylib import KeyboardKey

import filedialog_layout
export filedialog_layout

const Pad = 12.0'f32

proc collects(mode: FileDialogMode, multiple: bool): bool =
  ## Whether the dialog has a Chosen pane: to open or pick several.
  multiple and mode != fdSave

proc addChosen*(widget: Widget, paths: seq[string])
proc removeChosen(widget: Widget, rows: HashSet[int])
proc accept(widget: Widget)
proc dismiss(widget: Widget)
proc chosenChanged(widget: Widget)

definePrimitive(FileDialog):
  props:
    title: string = "Select File"
    mode: FileDialogMode = fdOpen
    filters: seq[string] = @[]   # e.g. @["*.txt", "*.nim"]
    initialPath: string = "."
    multiple: bool = true        # collect several files in the Chosen pane
    defaultName: string = ""     # Save: the name offered
    dialogWidth: float32 = 780.0
    dialogHeight: float32 = 500.0

  state:
    isVisible: bool
    accepted: bool               # True when the last close was Open/Save
    chosen: seq[string]          # the Chosen pane, in the order added
    answer: seq[string]          # what the last Open/Save handed over
    picker: FilePicker
    chosenList: ListBox
    pane: SidePane
    nameBox: TextInput
    okButton: Button
    addButton: Button

  actions:
    onSelect(files: seq[string])
    onCancel()

  init:
    initModal(widget)
    let dlg = widget
    let pickerMode = case widget.mode
                     of fdOpen: fpOpen
                     of fdSave: fpSave
                     of fdDirectory: fpDirectory
    widget.picker = newFilePicker(mode = pickerMode, filters = widget.filters,
                                  initialPath = widget.initialPath,
                                  multiSelect = collects(widget.mode, widget.multiple))
    widget.picker.onActivate = proc(path: string) =
      if collects(dlg.mode, dlg.multiple): dlg.addChosen(@[path])
      elif dlg.mode == fdSave: dlg.nameBox.replaceText(path.lastPathPart)
      else:
        dlg.picker.selectedFiles = [path].toHashSet
        dlg.accept()
    widget.picker.onSelect = proc(paths: HashSet[string]) =
      if dlg.mode == fdSave and paths.len == 1:
        for p in paths:
          if not dirExists(p): dlg.nameBox.replaceText(p.lastPathPart)
      if dlg.addButton != nil:
        dlg.addButton.disabled = paths.len == 0     # a prop: the setter redraws it

    var body: Widget = widget.picker.flex()
    if collects(widget.mode, widget.multiple):
      widget.chosenList = newListBox(multiSelect = true)
      widget.chosenList.onItemActivate = proc(i: int) = dlg.removeChosen([i].toHashSet)
      let remove = newButton(text = "Remove")
      remove.onClick = proc() = dlg.removeChosen(dlg.chosenList.selection)
      let clear = newButton(text = "Clear")
      clear.onClick = proc() =
        dlg.chosen.setLen(0)
        dlg.chosenChanged()
      let tools = newRow(spacing = 6.0)
      tools.addChild(remove)
      tools.addChild(clear)
      let paneBody = newVStack(spacing = 6.0, padding = 6.0)
      paneBody.addChild(widget.chosenList.flex())
      paneBody.addChild(tools)
      widget.pane = newSidePane(title = "Chosen", width = ChosenPaneWidth, side = psRight)
      widget.pane.addChild(paneBody)
      let row = newHStack(spacing = 10.0)
      row.addChild(widget.picker.flex())
      row.addChild(widget.pane)
      body = row.flex()

    let footer = newRow(spacing = 8.0, crossAxisAlignment = CrossAxisAlignment.center)
    if collects(widget.mode, widget.multiple):
      widget.addButton = newButton(text = "Add selected", disabled = true)
      widget.addButton.onClick = proc() = dlg.addChosen(dlg.picker.selectedPaths)
      footer.addChild(widget.addButton)
    if widget.mode == fdSave:
      widget.nameBox = newTextInput(initialText = widget.defaultName, placeholder = "File name",
                                    onSubmit = proc(t: string) = dlg.accept())
      footer.addChild(widget.nameBox.flex())
    else:
      footer.addChild(newRow().flex())                 # push the buttons right
    let cancel = newButton(text = "Cancel")
    cancel.onClick = proc() = dlg.dismiss()
    widget.okButton = newButton(text = okLabelFor(widget.mode), intent = ThemeIntent.Info)
    widget.okButton.onClick = proc() = dlg.accept()
    footer.addChild(cancel)
    footer.addChild(widget.okButton)

    let column = newVStack(spacing = 10.0)
    column.addChild(body)
    column.addChild(footer.frame(height = FooterHeight))
    widget.addChild(column)

  events:
    on_mouse_down:
      # A modal takes every click; those on its controls reach them first.
      return widget.isVisible

    on_key_down:
      if not widget.isVisible: return false
      if event.key == KeyboardKey.Escape:
        widget.dismiss()
        return true
      return false

  layout:
    widget.bounds = overlayBounds(widget)
    let panel = panelRect(widget.bounds, min(widget.dialogWidth, widget.bounds.width - 20),
                          min(widget.dialogHeight, widget.bounds.height - 20))
    widget.children[0].arrange(Rect(x: panel.x + Pad, y: panel.y + TitleBarHeight + Pad,
                                    width: panel.width - Pad * 2,
                                    height: panel.height - TitleBarHeight - Pad * 2))

  render:
    if not widget.isVisible: return
    let panel = panelRect(widget.bounds, min(widget.dialogWidth, widget.bounds.width - 20),
                          min(widget.dialogHeight, widget.bounds.height - 20))
    discard drawModalFrame(widget.bounds, panel, widget.title)

proc chosenChanged(widget: Widget) =
  ## The Chosen pane, its count and the Open button follow the list.
  let dlg = FileDialog(widget)
  if dlg.chosenList != nil:
    var rows: seq[string]
    var icons: seq[RowIcon]
    for p in dlg.chosen:
      rows.add chosenLabel(p)
      icons.add (if dirExists(p): riFolder else: riFile)
    dlg.chosenList.items = rows                 # props: their setters redraw
    dlg.chosenList.icons = icons
    dlg.chosenList.selection.clear()            # state: no setter, so repaint by hand
    dlg.chosenList.markDirtyToRoot()
    dlg.pane.summary = (if dlg.chosen.len > 0: $dlg.chosen.len else: "")
  dlg.okButton.text = okLabelFor(dlg.mode, dlg.chosen.len)

proc addChosen*(widget: Widget, paths: seq[string]) =
  ## Add `paths` to the Chosen pane, once each, in order. Directories are only
  ## taken when choosing directories.
  let dlg = FileDialog(widget)
  for p in paths:
    if p notin dlg.chosen and (dlg.mode == fdDirectory) == dirExists(p):
      dlg.chosen.add p
  dlg.chosenChanged()

proc removeChosen(widget: Widget, rows: HashSet[int]) =
  let dlg = FileDialog(widget)
  var kept: seq[string]
  for i, p in dlg.chosen:
    if i notin rows: kept.add p
  dlg.chosen = kept
  dlg.chosenChanged()

proc close(dlg: FileDialog, accepted: bool) =
  dlg.isVisible = false
  dlg.accepted = accepted
  closeModal(dlg)

proc accept(widget: Widget) =
  ## Open/Save: hand over the Chosen list, or else what is selected (the
  ## directory you are in, choosing directories; the typed name, saving).
  ## Nothing to hand over keeps the dialog open.
  let dlg = FileDialog(widget)
  var files: seq[string]
  if dlg.mode == fdSave:
    let name = dlg.nameBox.text
    if name.len > 0: files = @[dlg.picker.currentPath / name]
  elif dlg.chosen.len > 0:
    files = dlg.chosen
  else:
    for p in dlg.picker.selectedPaths:
      if (dlg.mode == fdDirectory) == dirExists(p): files.add p
    if files.len == 0 and dlg.mode == fdDirectory:
      files = @[dlg.picker.currentPath]
  if files.len == 0: return
  dlg.answer = files
  dlg.close(accepted = true)
  if dlg.onSelect != nil: dlg.onSelect(files)

proc dismiss(widget: Widget) =
  let dlg = FileDialog(widget)
  dlg.close(accepted = false)
  if dlg.onCancel != nil: dlg.onCancel()

proc show*(widget: FileDialog) =
  ## Open the dialog on its starting directory, with nothing chosen yet.
  widget.isVisible = true
  widget.accepted = false
  widget.chosen.setLen(0)
  widget.answer.setLen(0)
  widget.chosenChanged()
  widget.picker.openDirectory(if widget.picker.currentPath.len > 0: widget.picker.currentPath
                              else: widget.initialPath)
  openModal(widget)

proc answerText*(widget: FileDialog): string =
  ## The last answer as text, one path per line.
  widget.answer.asLines
