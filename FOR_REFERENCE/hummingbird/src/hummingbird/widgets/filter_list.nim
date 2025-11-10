# Quick filter list
defineWidget FilterList:
  props:
    items*: seq[Item]
    filter*: string
    multiSelect*: bool
    selected*: HashSet[string]
    onSelect*: proc(selected: HashSet[string])

  type Item* = object
    id*: string
    text*: string
    tags*: seq[string]
    data*: JsonNode

  render:
    # Filter input
    var filter = widget.filter
    if GuiTextBox(
      Rectangle(
        x: widget.rect.x,
        y: widget.rect.y,
        width: widget.rect.width,
        height: 24
      ),
      filter,
      100,
      true
    ):
      widget.filter = filter

    # Filtered list
    var y = widget.rect.y + 30
    for item in widget.items:
      if widget.filter.len > 0:
        let filterLower = widget.filter.toLowerAscii
        let textLower = item.text.toLowerAscii
        let tagsLower = item.tags.mapIt(it.toLowerAscii)

        if not (filterLower in textLower or
                tagsLower.anyIt(filterLower in it)):
          continue

      let itemRect = Rectangle(
        x: widget.rect.x,
        y: y,
        width: widget.rect.width,
        height: 24
      )

      if GuiButton(itemRect, item.text, item.id in widget.selected):
        if widget.multiSelect:
          if item.id in widget.selected:
            widget.selected.excl(item.id)
          else:
            widget.selected.incl(item.id)
        else:
          widget.selected = [item.id].toHashSet

        if widget.onSelect != nil:
          widget.onSelect(widget.selected)

      y += 24

# Usage example:
let table = DataTable(
  columns: @[
    Column(
      id: "id",
      title: "ID",
      width: 60,
      sortable: true,
      filterable: true,
      filterKinds: {fkEquals, fkGreater, fkLess}
    ),
    Column(
      id: "name",
      title: "Name",
      width: 200,
      sortable: true,
      filterable: true,
      filterKinds: {fkContains, fkStartsWith}
    ),
    Column(
      id: "status",
      title: "Status",
      width: 100,
      sortable: true,
      filterable: true,
      filterKinds: {fkEquals, fkIn}
    )
  ],
  onSort: proc(col: string, asc: bool) =
    echo "Sort by ", col, " ", if asc: "asc" else: "desc",
  onFilter: proc(filters: Table[string, Filter]) =
    echo "Filters: ", filters
)

let filterList = FilterList(
  items: @[
    Item(id: "1", text: "Item 1", tags: @["tag1", "tag2"]),
    Item(id: "2", text: "Item 2", tags: @["tag2", "tag3"]),
    Item(id: "3", text: "Item 3", tags: @["tag1", "tag3"])
  ],
  onSelect: proc(selected: HashSet[string]) =
    echo "Selected: ", selected
)
