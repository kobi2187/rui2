
# Filterable data table
defineWidget DataTable:
  props:
    columns*: seq[Column]
    data*: seq[Row]
    filters*: Table[string, Filter]
    sortColumn*: string
    sortAscending*: bool
    onSort*: proc(column: string, ascending: bool)
    onFilter*: proc(filters: Table[string, Filter])
    onSelect*: proc(selected: HashSet[string])

  type
    Column* = object
      id*: string
      title*: string
      width*: float32
      sortable*: bool
      filterable*: bool
      filterKinds*: set[FilterKind]  # Allowed filter types
      formatFunc*: proc(value: JsonNode): string

    FilterKind* = enum
      fkEquals, fkContains, fkGreater, fkLess,
      fkBetween, fkIn, fkStartsWith, fkEndsWith

    Filter* = object
      column*: string
      case kind*: FilterKind
      of fkEquals, fkContains, fkStartsWith, fkEndsWith:
        text*: string
      of fkGreater, fkLess:
        value*: float
      of fkBetween:
        min*, max*: float
      of fkIn:
        values*: seq[string]

  render:
    # Filter bar
    var y = widget.rect.y
    if widget.filters.len > 0:
      for col in widget.columns:
        if col.filterable:
          let filter = widget.filters.getOrDefault(col.id)
          let filterRect = Rectangle(
            x: widget.rect.x,
            y: y,
            width: col.width,
            height: 24
          )

          # Filter type dropdown
          var filterKind = filter.kind
          if GuiComboBox(
            Rectangle(x: filterRect.x, y: filterRect.y, width: 100, height: 24),
            "=;~;>;<=;[]",
            addr filterKind.ord
          ):
            var newFilter = Filter(column: col.id, kind: filterKind)
            widget.filters[col.id] = newFilter
            if widget.onFilter != nil:
              widget.onFilter(widget.filters)

          # Filter value input
          let valueRect = Rectangle(
            x: filterRect.x + 110,
            y: filterRect.y,
            width: col.width - 110,
            height: 24
          )

          case filter.kind
          of fkEquals, fkContains, fkStartsWith, fkEndsWith:
            var text = filter.text
            if GuiTextBox(valueRect, text, 100, true):
              var newFilter = filter
              newFilter.text = text
              widget.filters[col.id] = newFilter
              if widget.onFilter != nil:
                widget.onFilter(widget.filters)

          of fkGreater, fkLess:
            var value = filter.value
            if GuiSpinner(valueRect, "", addr value, low(float), high(float), true):
              var newFilter = filter
              newFilter.value = value
              widget.filters[col.id] = newFilter
              if widget.onFilter != nil:
                widget.onFilter(widget.filters)

          of fkBetween:
            var min = filter.min
            var max = filter.max
            if GuiSpinner(
              Rectangle(x: valueRect.x, y: valueRect.y, width: 60, height: 24),
              "", addr min, low(float), high(float), true
            ):
              var newFilter = filter
              newFilter.min = min
              widget.filters[col.id] = newFilter
              if widget.onFilter != nil:
                widget.onFilter(widget.filters)

            if GuiSpinner(
              Rectangle(x: valueRect.x + 70, y: valueRect.y, width: 60, height: 24),
              "", addr max, low(float), high(float), true
            ):
              var newFilter = filter
              newFilter.max = max
              widget.filters[col.id] = newFilter
              if widget.onFilter != nil:
                widget.onFilter(widget.filters)

          of fkIn:
            # Show popup for multi-select
            if GuiButton(valueRect, filter.values.join(", ")):
              # TODO: Show multi-select popup
              discard

      y += 30

    # Table header
    for col in widget.columns:
      let headerRect = Rectangle(
        x: widget.rect.x + getColumnOffset(col.id),
        y: y,
        width: col.width,
        height: 24
      )

      let sortIndicator = if col.id == widget.sortColumn:
                           if widget.sortAscending: " ▲" else: " ▼"
                         else: ""

      if col.sortable and GuiButton(headerRect, col.title & sortIndicator):
        if col.id == widget.sortColumn:
          widget.sortAscending = not widget.sortAscending
        else:
          widget.sortColumn = col.id
          widget.sortAscending = true

        if widget.onSort != nil:
          widget.onSort(widget.sortColumn, widget.sortAscending)

    y += 24

    # Table body
    for row in widget.data:
      if not matchesFilters(row, widget.filters):
        continue

      for col in widget.columns:
        let cellRect = Rectangle(
          x: widget.rect.x + getColumnOffset(col.id),
          y: y,
          width: col.width,
          height: 24
        )

        let value = row[col.id]
        let text = if col.formatFunc != nil:
                    col.formatFunc(value)
                  else:
                    $value

        GuiLabel(cellRect, text)

      y += 24

