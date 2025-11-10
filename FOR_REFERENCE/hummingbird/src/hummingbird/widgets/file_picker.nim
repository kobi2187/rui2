
# File/Directory picker
defineWidget FilePicker:
  props:
    path*: string
    filter*: string
    dialogType*: FileDialogType
    onSelect*: proc(path: string)

  type FileDialogType = enum
    fdOpen, fdSave, fdDir

  render:
    # Path input
    var currentPath = widget.path
    if GuiTextBox(widget.getPathRect(), currentPath, 1024, true):
      widget.path = currentPath

    # File list
    let entries = getDirectoryEntries(widget.path, widget.filter)
    var selected = -1
    if GuiListView(
      widget.getListRect(),
      entries.join(";"),
      addr selected
    ):
      if selected >= 0:
        let newPath = entries[selected]
        if dirExists(newPath):
          widget.path = newPath
        elif widget.onSelect != nil:
          widget.onSelect(newPath)
