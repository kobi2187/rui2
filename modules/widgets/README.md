# Widgets Module

All RUI2 UI components organized by complexity level.

## Public API

```nim
import modules/widgets/api          # Everything
import modules/widgets/primitives   # Just drawing primitives
import modules/widgets/basic        # Just basic controls
import modules/widgets/containers   # Just layout containers
```

### Primitives (leaf widgets, drawing only)

| Widget | Description |
|---|---|
| `Label` | Text display |
| `Rectangle` | Filled/outlined rectangle |
| `Circle` | Filled/outlined circle |

### Basic Controls (interactive)

| Widget | Description |
|---|---|
| `Button` | Click button with text |
| `Checkbox` | Toggle on/off |
| `RadioButton` | Exclusive selection |
| `Slider` | Value range selection |
| `ProgressBar` | Progress display |
| `Hyperlink` | Clickable link |
| `ComboBox` | Dropdown selection |
| `ListBox` | Scrollable list |
| `Spinner` | Numeric up/down |
| `NumberInput` | Numeric text input |
| `Separator` | Visual divider |
| `ScrollBar` | Scroll indicator |
| `Image` | Image display |
| `IconButton` | Button with icon |
| `ToolButton` | Toolbar button |
| `Tooltip` | Hover tooltip |

### Containers (composite, manage children)

| Widget | Description |
|---|---|
| `VStack` | Vertical stack |
| `HStack` | Horizontal stack |
| `ZStack` | Layered/overlapping |
| `ScrollView` | Scrollable content |
| `Panel` | Bordered panel |
| `TabControl` | Tab pages |
| `GroupBox` | Titled group |
| `RadioGroup` | Radio button group |
| `Toolbar` | Toolbar container |
| `StatusBar` | Status bar |
| `Column` | Column layout |
| `Spacer` | Flexible space |

### Creating Custom Widgets

Use the widget_dsl module:

```nim
import modules/widget_dsl/api

definePrimitive(MyWidget):
  props:
    value: int = 0
  render:
    # drawing code
```

### Dependencies
- `core/types`, `core/widget_dsl` (Widget base, DSL macros)
- `drawing_primitives/` (rendering functions)
