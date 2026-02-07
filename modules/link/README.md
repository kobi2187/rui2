# Link Module

Reactive unidirectional data binding with O(1) per-widget dirty marking using direct widget references.

## Public API

```nim
import modules/link/api
```

### Core Type
- `Link[T]` — Generic reactive value container with dependent widget tracking

### Key Functions

| Function | Description |
|---|---|
| `newLink[T](initialValue)` | Create a Link with initial value |
| `link.get()` / `link.value` | Read current value |
| `link.set(val)` / `link.value = val` | Set value and mark dependents dirty |
| `link.addDependent(widget)` | Register widget as dependent |
| `link.removeDependent(widget)` | Unregister widget |
| `link.setOnChange(callback)` | Optional side-effect callback |
| `link.dependentCount()` | Number of dependent widgets |

### How It Works

```
Store (Link[T] fields)
    |
    v
Widget reads link.value during render
    |
    v
link.addDependent(widget) registers direct reference
    |
    v
link.set(newVal) marks ALL dependent widgets dirty (O(1) per widget)
    |
    v
Next frame: dirty widgets re-render, read new value
```

### Testing Without Graphics

```nim
var link = newLink(0)
var w = Widget(isDirty: false)
link.addDependent(w)
link.set(42)
assert w.isDirty == true
assert link.get() == 42
```

### Dependencies
- `core/types` (Widget, Link[T] type definition)
