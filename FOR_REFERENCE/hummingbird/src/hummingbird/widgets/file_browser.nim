

# File browser
defineWidget FileBrowser:
  props:
    currentPath: string
    filter: string
    multiSelect: bool
    selected: HashSet[string]
    onSelect: proc(paths: HashSet[string])
    onDoubleClick: proc(path: string)

  render:
    # Path navigation
    let pathRect = Rectangle(
      x: widget.rect.x,
      y: widget.rect.y,
      width: widget.rect.width,
      height: 24
    )
    var path = widget.currentPath
    if GuiTextBox(pathRect, path, 1024, false):
      widget.currentPath = path

    # File list
    let files = getDirectoryFiles(widget.currentPath, widget.filter)
    var y = widget.rect.y + 30

    for file in files:
      let fileRect = Rectangle(
        x: widget.rect.x,
        y: y,
        width: widget.rect.width,
        height: 24
      )

      if GuiButton(fileRect, file.name, file.path in widget.selected):
        if widget.multiSelect:
          if file.path in widget.selected:
            widget.selected.excl(file.path)
          else:
            widget.selected.incl(file.path)
        else:
          widget.selected = [file.path].toHashSet

        if widget.onSelect != nil:
          widget.onSelect(widget.selected)

      y += 24
