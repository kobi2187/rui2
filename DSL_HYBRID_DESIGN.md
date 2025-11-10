# Hybrid DSL Design: Primitives + Composition

Exploring how to combine RUI2's drawing primitives with Hummingbird's composition model.

## The Apparent Contradiction

### RUI2's Approach: Drawing Primitives
```nim
defineWidget(Button):
  render:
    # Widget draws itself using primitives
    let style = getButtonStyle(widget)
    drawRoundedRect(widget.bounds, style.cornerRadius, style.bgColor)
    drawText(widget.text, widget.bounds, style.textColor)
    drawBorder(widget.bounds, style.borderWidth, style.borderColor)
```

**Philosophy**: Each widget knows how to draw itself using low-level primitives.

### Hummingbird's Approach: Widget Composition
```nim
defineWidget SettingsPanel:
  render:
    # Widget composes other widgets
    vstack:
      Label(text: "Settings")
      Checkbox(text: "Enable", checked: true)
      Slider(value: 50)
      Button(text: "Save", onClick: save)
```

**Philosophy**: Build complex widgets from simpler widget components.

## The Resolution: Both Are Valid!

**There's no contradiction** - they solve different problems at different levels:

1. **Primitive Widgets** (leaf nodes) - Draw themselves
2. **Composite Widgets** (containers) - Compose other widgets

## The Widget Hierarchy

```
App (composite)
├─ MainPanel (composite)
│  ├─ Header (composite)
│  │  ├─ Logo (primitive - draws image)
│  │  └─ Title (primitive - draws text)
│  ├─ Content (composite)
│  │  ├─ Sidebar (composite)
│  │  │  └─ Button (primitive - draws rect + text)
│  │  └─ MainArea (composite)
│  │     ├─ TextInput (primitive - draws input box)
│  │     └─ Slider (primitive - draws track + thumb)
│  └─ Footer (composite)
│     └─ StatusBar (primitive - draws bar)
```

**Key Insight**:
- **Primitive widgets** = Draw using drawing_primitives
- **Composite widgets** = Arrange other widgets (primitive or composite)

## Hybrid Widget Examples

### Example 1: Primitive Widget (Button)

Uses drawing primitives:

```nim
defineWidget(Button):
  props:
    text: string
    onClick: proc()

  render:
    # Uses drawing primitives
    let theme = getTheme(widget)
    let props = theme.getProps(widget.intent, widget.state)

    # Draw background
    if props.cornerRadius.isSome:
      drawRoundedRect(widget.bounds, props.cornerRadius.get(), props.backgroundColor.get())
    else:
      drawRect(widget.bounds, props.backgroundColor.get())

    # Draw text
    drawText(widget.text, widget.bounds, props.foregroundColor.get(), props.fontSize.get())

    # Draw border
    if props.borderWidth.isSome:
      drawBorder(widget.bounds, props.borderWidth.get(), props.borderColor.get())
```

**Characteristics**:
- Leaf node in widget tree
- Draws directly with primitives
- No children (or children are decorative)
- Fully themed via drawing_primitives

### Example 2: Composite Widget (SettingsPanel)

Uses widget composition:

```nim
defineWidget(SettingsPanel):
  props:
    settings: Settings
    onSave: proc()

  render:
    # Uses widget composition
    vstack:
      spacing = 16
      padding = EdgeInsets(all: 20)

      # Header
      hstack:
        Label(text: "Settings", fontSize: 24)
        Spacer()  # Push button to right
        Button(text: "Save", onClick: widget.onSave)

      Separator()

      # Form fields (using primitive widgets)
      FormRow:
        Label(text: "Username:")
        TextInput(
          value: widget.settings.username,
          onChange: proc(v: string) = widget.settings.username = v
        )

      FormRow:
        Label(text: "Theme:")
        ComboBox(
          items: @["Light", "Dark", "Auto"],
          selected: widget.settings.theme,
          onSelect: proc(idx: int) = widget.settings.theme = idx
        )

      FormRow:
        Label(text: "Notifications:")
        Checkbox(
          checked: widget.settings.notifications,
          onToggle: proc(v: bool) = widget.settings.notifications = v
        )
```

**Characteristics**:
- Container node
- Composes primitive widgets
- Defines layout (vstack, hstack)
- Doesn't draw directly (children do the drawing)

### Example 3: Hybrid Widget (TabControl)

Mix of both approaches:

```nim
defineWidget(TabControl):
  props:
    tabs: seq[string]
    activeTab: int
    onTabChange: proc(idx: int)

  state:
    fields:
      hoverTab: int

  render:
    # Part 1: Draw tab bar using primitives
    let tabBarHeight = 40.0
    let tabBarRect = Rect(
      x: widget.bounds.x,
      y: widget.bounds.y,
      width: widget.bounds.width,
      height: tabBarHeight
    )

    # Draw tab bar background
    drawRect(tabBarRect, theme.surface)

    # Draw each tab
    var x = widget.bounds.x
    let tabWidth = widget.bounds.width / widget.tabs.len.float

    for i, tab in widget.tabs:
      let tabRect = Rect(x: x, y: widget.bounds.y, width: tabWidth, height: tabBarHeight)

      # Tab background (primitive drawing)
      let bgColor = if i == widget.activeTab: theme.primaryLight
                    elif i == widget.hoverTab: theme.surfaceHover
                    else: theme.surface
      drawRect(tabRect, bgColor)

      # Tab text (primitive drawing)
      drawText(tab, tabRect, theme.onSurface)

      x += tabWidth

    # Part 2: Render active tab content (composition)
    let contentRect = Rect(
      x: widget.bounds.x,
      y: widget.bounds.y + tabBarHeight,
      width: widget.bounds.width,
      height: widget.bounds.height - tabBarHeight
    )

    # Draw content area background
    drawRect(contentRect, theme.background)

    # Render active child widget (composition)
    if widget.activeTab >= 0 and widget.activeTab < widget.children.len:
      let child = widget.children[widget.activeTab]
      child.bounds = contentRect  # Position child
      child.render()  # Child draws itself
```

**Characteristics**:
- Mix of primitive drawing (tab bar) and composition (content)
- Custom drawing for unique UI elements
- Delegates to children for content
- Best of both worlds!

## The Pattern: When to Use Each

### Use Primitive Drawing When:
- **Leaf widgets** (Button, Label, TextInput, Slider, Checkbox)
- **Performance critical** (avoid widget overhead)
- **Unique visuals** (custom shapes, animations)
- **Theme integration** (leverage drawing_primitives theming)
- **Simple widgets** (no internal structure)

### Use Widget Composition When:
- **Container widgets** (Panel, TabControl, ScrollView)
- **Form layouts** (SettingsPanel, DialogBox)
- **Complex UIs** (entire application screens)
- **Reusable patterns** (FormRow, Card, MenuItem)
- **Data-driven** (ListViews, DataGrids with item widgets)

### Use Hybrid Approach When:
- **Complex containers** (TabControl, Accordion, Wizard)
- **Custom chrome + content** (Window with titlebar + content)
- **Themed containers** (GroupBox with border + children)

## Implementation Strategy

### 1. Primitive Widgets (Phase 1)
Port using drawing_primitives:
- Button
- Label
- TextInput
- Checkbox
- RadioButton
- Slider
- ProgressBar

**Render method**: Direct primitive calls

### 2. Layout Helpers (Phase 2)
Enable composition:
- VStack (already exists)
- HStack (already exists)
- Grid
- Spacer
- Divider

**Render method**: Position children, let them draw

### 3. Composite Widgets (Phase 3)
Build from primitives:
- FormRow = HStack(Label + InputWidget)
- Card = VStack with background
- Panel = Themed container
- Dialog = Panel + ButtonRow

**Render method**: Compose other widgets

### 4. Complex Widgets (Phase 4)
Hybrid approach:
- TabControl (custom tabs + child content)
- TreeView (custom tree lines + node widgets)
- DataGrid (custom grid + cell widgets)
- Accordion (custom headers + panel content)

**Render method**: Mix primitive drawing + composition

## DSL Syntax Support

The defineWidget macro should support both:

### Primitive Drawing Syntax
```nim
defineWidget(Button):
  render:
    # Direct primitive calls
    drawRect(widget.bounds, theme.primary)
    drawText(widget.text, widget.bounds, WHITE)
```

### Composition Syntax
```nim
defineWidget(SettingsPanel):
  render:
    # Widget composition DSL
    vstack:
      Label(text: "Title")
      Button(text: "Click", onClick: handler)
```

### Hybrid Syntax
```nim
defineWidget(TabControl):
  render:
    # Mix both!

    # Custom drawing for tabs
    drawTabBar(widget.tabs, widget.activeTab)

    # Compose for content
    if widget.activeTab < widget.children.len:
      widget.children[widget.activeTab].render()
```

## Key Realization

**The "contradiction" is actually complementary design patterns**:

1. **Primitive widgets** use `drawing_primitives` → Maximum control, themed, efficient
2. **Composite widgets** use composition → Declarative, reusable, maintainable
3. **Real apps** use both → Primitives for leaves, composition for structure

## Benefits of Hybrid Approach

### From Drawing Primitives:
- ✓ Full theming support
- ✓ Performance (no extra widget overhead)
- ✓ Pixel-perfect control
- ✓ Custom visuals

### From Widget Composition:
- ✓ Declarative structure
- ✓ Reusable components
- ✓ Less boilerplate
- ✓ App-as-widget pattern

### Together:
- ✓ Theme primitive widgets
- ✓ Compose them into complex UIs
- ✓ Each widget does what it does best
- ✓ No contradiction!

## Recommendation

**Implement both in RUI2's DSL**:

1. **Keep drawing_primitives** for leaf widgets
2. **Add composition syntax** for containers
3. **Support hybrid widgets** that use both
4. **Let widget authors choose** the right approach

This gives maximum flexibility:
- Simple widgets → primitives
- Complex layouts → composition
- Advanced widgets → hybrid

**No contradiction, just different tools for different jobs!**

## Next Steps

1. Enhance defineWidget macro to support composition syntax
2. Port primitive widgets using drawing_primitives (Button, Label, etc.)
3. Create layout widgets (VStack, HStack, Grid)
4. Build composite widgets from primitives
5. Create hybrid widgets (TabControl, etc.)

The hybrid approach gives us the best of both Hummingbird and RUI2!
