
# Tab container
defineWidget TabContainer:
  props:
    tabs: seq[Tab]
    activeTab: int
    onTabChange: proc(index: int)

  type Tab* = object
    title*: string
    closeable*: bool
    content*: Widget

  render:
    var active = widget.activeTab

    # Draw tab bar
    if GuiTabBar(
      Rectangle(
        x: widget.rect.x,
        y: widget.rect.y,
        width: widget.rect.width,
        height: 24
      ),
      widget.tabs.mapIt(it.title).join(";"),
      addr active
    ):
      widget.activeTab = active
      if widget.onTabChange != nil:
        widget.onTabChange(active)

    # Draw active tab content
    if widget.activeTab >= 0 and
       widget.activeTab < widget.tabs.len:
      let content = widget.tabs[widget.activeTab].content
      content.rect = Rectangle(
        x: widget.rect.x,
        y: widget.rect.y + 24,
        width: widget.rect.width,
        height: widget.rect.height - 24
      )
      content.draw()

# Tree and Grid example
let mainWindow = container:
  hsplit:
    # Left side: Tree
    TreeView(
      rootNode: TreeNode(
        id: "root",
        text: "Root",
        expanded: true,
        children: @[
          TreeNode(
            id: "folder1",
            text: "Folder 1",
            children: @[
              TreeNode(id: "item1", text: "Item 1"),
              TreeNode(id: "item2", text: "Item 2")
            ]
          ),
          TreeNode(id: "folder2", text: "Folder 2")
        ]
      ),
      onSelect: proc(id: string) = echo "Selected: ", id
    )

    # Right side: Grid in scroll view
    ScrollView(
      scrollY: true,
      child: DataGrid(
        columns: @[
          Column(title: "ID", width: 60),
          Column(title: "Name", width: 150),
          Column(title: "Value", width: 100, sortable: true)
        ],
        data: @[
          Row(id: "1", values: @[%"1", %"Item 1", %100]),
          Row(id: "2", values: @[%"2", %"Item 2", %200])
        ],
        onSort: proc(col: int, asc: bool) = echo "Sort: ", col
      )
    )

# Tab container example
let tabs = TabContainer(
  tabs: @[
    Tab(
      title: "General",
      content: vstack:
        Label(text: "Settings")
        Checkbox(text: "Enable feature")
    ),
    Tab(
      title: "Advanced",
      content: DataGrid(...)
    ),
    Tab(
      title: "Log",
      content: ScrollView(
        scrollY: true,
        child: Label(text: "Log content...")
      )
    )
  ]
)
