
# Data grid with sorting, filtering
defineWidget DataGrid:
  props:
    columns: seq[Column]
    data: seq[Row]
    selected: HashSet[int]  # Selected row indices
    sortColumn: int
    sortAscending: bool
    onSort: proc(column: int, ascending: bool)
    onSelect: proc(selected: HashSet[int])

  type
    Column* = object
      title*: string
      width*: float32
      sortable*: bool
      filterable*: bool
      formatFunc*: proc(value: JsonNode): string

    Row* = object
      id*: string
      values*: seq[JsonNode]

  render:
    # Draw header
    var headerY = widget.rect.y
    var x = widget.rect.x

    for i, col in widget.columns:
      let headerRect = Rectangle(
        x: x,
        y: headerY,
        width: col.width,
        height: 24
      )

      let headerText = col.title &
        (if i == widget.sortColumn:
          if widget.sortAscending: " ▲" else: " ▼"
        else: "")

      if col.sortable and GuiButton(headerRect, headerText):
        if i == widget.sortColumn:
          widget.sortAscending = not widget.sortAscending
        else:
          widget.sortColumn = i
          widget.sortAscending = true

        if widget.onSort != nil:
          widget.onSort(i, widget.sortAscending)

      x += col.width

    # Draw rows
    var y = headerY + 24
    for rowIdx, row in widget.data:
      x = widget.rect.x
      let isSelected = rowIdx in widget.selected

      for colIdx, value in row.values:
        let col = widget.columns[colIdx]
        let cellRect = Rectangle(
          x: x,
          y: y,
          width: col.width,
          height: 24
        )

        let cellText = if col.formatFunc != nil:
                        col.formatFunc(value)
                      else:
                        $value

        if GuiButton(cellRect, cellText, isSelected):
          if isSelected:
            widget.selected.excl(rowIdx)
          else:
            widget.selected.incl(rowIdx)

          if widget.onSelect != nil:
            widget.onSelect(widget.selected)

        x += col.width
      y += 24
