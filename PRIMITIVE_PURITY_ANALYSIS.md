# Primitive Purity Analysis

Should primitives be pure atoms (no children), or can they use layout containers internally?

## The Question

**Pure Primitive** (no layout/children):
```nim
definePrimitive(Button):
  render:
    # Draw everything directly, no children
    drawRoundedRect(...)
    drawText(widget.text, ...)
    if widget.icon.isSome:
      drawImage(widget.icon.get(), ...)
```

**Hybrid Primitive** (uses layout internally):
```nim
definePrimitive(Button):
  layout:
    hstack:
      spacing = 8
      if widget.icon.isSome:
        Icon(image: widget.icon.get())
      Label(text: widget.text)

  render:
    # Draw button background/border around children
    drawRoundedRect(widget.bounds, bgColor)
```

## Arguments For Purity (No Layout in Primitives)

### 1. Clear Conceptual Boundary
- **Primitives** = atomic, indivisible, draw themselves
- **Composites** = composed of other widgets, use layout
- No confusion about widget type

### 2. Performance
```nim
# Pure primitive: Direct drawing
drawRect(bounds, color)
drawText(text, pos, fontSize)
# ~2 draw calls

# Hybrid: Widget overhead
let icon = newIcon(...)      # Allocate widget
let label = newLabel(...)    # Allocate widget
icon.measure(...)            # Layout calculation
label.measure(...)           # Layout calculation
icon.render()                # Indirection
label.render()               # Indirection
# More memory, more calls, more indirection
```

**Pure is faster** - no widget allocation, no layout overhead, direct drawing.

### 3. Simpler Mental Model
```nim
"If it's a primitive, it draws itself directly"
"If it's composite, it arranges children"
```

Clear, simple rule. No exceptions.

### 4. No Recursive Complexity
Pure primitives = leaf nodes. Tree terminates cleanly.

Hybrid primitives = can contain primitives that contain... wait, that's still finite.

Actually, this isn't a strong argument. Recursion is fine.

### 5. Theme Control
Pure primitive has full control over every pixel:
```nim
render:
  # Exactly how to draw pressed state
  if widget.pressed:
    drawRect(bounds, darken(bgColor, 0.2))
    drawShadow(bounds, inset: true)
  else:
    drawRect(bounds, bgColor)
    drawShadow(bounds, inset: false)
```

Hybrid delegates to children, less pixel-perfect control.

## Arguments Against Purity (Allow Layout)

### 1. Code Reuse
Why reimplement text rendering when Label exists?

```nim
# Pure: Duplicate text rendering logic
definePrimitive(Button):
  render:
    # Manually measure and draw text
    let textSize = measureText(widget.text, fontSize)
    let textPos = centerInRect(widget.bounds, textSize)
    drawText(widget.text, textPos, color, fontSize)

# Hybrid: Reuse Label
definePrimitive(Button):
  layout:
    Label(text: widget.text, fontSize: widget.fontSize, color: widget.color)
```

**Less code, fewer bugs.**

### 2. Flexibility for Widget Authors
Let them choose:
- Need performance? → Pure primitive
- Want composition? → Hybrid primitive
- Complex layout? → Composite widget

Don't force one approach.

### 3. Reality: Some Primitives Are Complex

Examples:
- **Checkbox**: Box + checkmark + label text
- **RadioButton**: Circle + dot + label text
- **Slider**: Track + fill + thumb + value label
- **ProgressBar**: Background + fill + text overlay

These have internal structure! Do we really want to draw all pieces manually?

```nim
# Pure Slider - complex manual layout
definePrimitive(Slider):
  render:
    # Calculate track rect
    let trackRect = Rect(...)
    drawRoundedRect(trackRect, theme.track)

    # Calculate fill rect based on value
    let fillWidth = (widget.value / widget.maxValue) * trackRect.width
    let fillRect = Rect(x: trackRect.x, y: trackRect.y, width: fillWidth, height: trackRect.height)
    drawRoundedRect(fillRect, theme.primary)

    # Calculate thumb position
    let thumbX = trackRect.x + fillWidth - thumbRadius
    let thumbY = trackRect.y + trackRect.height / 2
    drawCircle(thumbX, thumbY, thumbRadius, theme.thumb)

    # Draw value label
    let labelText = formatValue(widget.value)
    let labelSize = measureText(labelText, fontSize)
    let labelPos = Point(x: thumbX - labelSize.width / 2, y: thumbY + thumbRadius + 5)
    drawText(labelText, labelPos, color, fontSize)

# Hybrid Slider - clearer structure
definePrimitive(Slider):
  layout:
    zstack:
      SliderTrack(value: widget.value, maxValue: widget.maxValue)
      SliderThumb(position: widget.value / widget.maxValue)
      SliderLabel(text: formatValue(widget.value))
```

Which is more maintainable?

### 4. Internal Implementation Detail

If primitive uses layout internally, **users don't see it**:

```nim
// User code - looks the same either way
let slider = newSlider(value: 50, maxValue: 100, onChange: handleChange)
```

The implementation detail (pure vs hybrid) is hidden.

## The Real Question

**What's the true boundary between primitive and composite?**

### Option A: By Implementation
- Primitive = draws directly (no layout)
- Composite = uses layout

**Problem**: Forces implementation choice onto users.

### Option B: By API
- Primitive = leaf widget in user's mental model (single unit of interaction)
- Composite = container widget (holds multiple distinct children)

**Better**: User doesn't care about internal implementation.

## Examples Under Each Definition

| Widget | Option A (impl) | Option B (API) |
|--------|-----------------|----------------|
| Label | Primitive (draws text) | Primitive (single unit) |
| Button | Primitive (draws rect+text) | Primitive (single unit) |
| Button with icon | ??? (could use layout) | Primitive (still single unit) |
| Checkbox with label | ??? (box + text = layout?) | Primitive (single unit) |
| Slider | ??? (complex parts) | Primitive (single unit) |
| VStack | Composite (arranges children) | Composite (holds children) |
| Panel | ??? (decoration + content) | Composite (holds children) |
| Dialog | Composite (complex) | Composite (holds children) |

**Option B is clearer**: A primitive is a single interactive unit from the user's perspective.

## Recommendation: Practical Purity

**Guideline**: Primitives SHOULD avoid layout, but CAN use it when practical.

### Rules:
1. **Prefer pure drawing** when simple
2. **Allow layout** for complex internals (Slider, Checkbox with label)
3. **Never expose children** publicly (primitive = leaf in user's mental model)
4. **Document the distinction**:
   - Pure Primitive: Draws everything itself
   - Hybrid Primitive: Uses layout internally, still a leaf widget
   - Composite: Public children, user adds widgets

### Examples

**Pure Primitive** (recommended for simple cases):
```nim
definePrimitive(Label):
  render:
    drawText(widget.text, widget.bounds, theme.foreground, widget.fontSize)
```

**Hybrid Primitive** (when complexity warrants):
```nim
definePrimitive(Slider):
  layout:
    # Internal composition - NOT exposed to user
    zstack:
      SliderTrack(...)
      SliderThumb(...)
      SliderLabel(...)

  render:
    # Optional: Draw decorations around internal layout
    pass
```

**Composite** (public children):
```nim
defineWidget(VStack):
  layout:
    # Children added by USER
    # panel.addChild(widget)
```

## Macro Implications

### definePrimitive Should:
- Support `render:` block (pure path)
- Support `layout:` block (hybrid path)
- **NOT allow public addChild()** - internal only
- Generate `children: seq[Widget]` but mark as private

### defineWidget Should:
- Require `layout:` block
- Generate public `addChild()` method
- Children are public API

## Decision: Pragmatic Flexibility

**Allow layout in primitives**, but:
1. Document as "internal implementation"
2. Never expose children publicly
3. Recommend pure drawing for simple widgets
4. Use layout for complex widgets (Slider, ComboBox, DatePicker)

**Principle**: "Make the easy thing easy, make the complex thing possible"

- Easy: Pure primitive (just draw)
- Complex: Hybrid primitive (internal layout)
- Flexible: Composite widget (public children)

## Analogy

Think of primitives like **encapsulated components** in OOP:
- Public interface: single unit
- Private implementation: may use internal objects
- User doesn't see internals

A Button might use internal Label and Icon widgets, but user treats it as one widget.

## Final Answer

**Yes, primitives can use layout internally**, but:
- It's an implementation detail
- Children are private
- From user's perspective, it's still a leaf widget
- Prefer pure drawing for simplicity
- Use layout when it reduces complexity

**Purity matters for the API, not the implementation.**
