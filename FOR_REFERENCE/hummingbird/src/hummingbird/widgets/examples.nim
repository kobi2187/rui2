
# Example usage with raygui:
defineWidget Button:
  props:
    text: string
    onClick: proc()
    isPressed: bool
    
  render:
    if GuiButton(Rectangle(
      x: widget.rect.x,
      y: widget.rect.y,
      width: widget.rect.width,
      height: widget.rect.height
    ), widget.text):
      if widget.enabled and widget.onClick != nil:
        widget.onClick()

  input:
    if event.kind == ieMousePress and widget.enabled:
      widget.isPressed = true
      true
    elif event.kind == ieMouseRelease and widget.isPressed:
      widget.isPressed = false
      if widget.containsPoint(event.mousePos):
        widget.onClick()
      true
    else:
      false

  state:
    fields:
      text: string
      enabled: bool
      pressed: bool






# Example usage:
let form = container:
  vstack:
    TextInput(
      placeholder: "Enter name",
      onTextChanged: proc(text: string) =
        echo "Text changed: ", text
    )
    
    Checkbox(
      text: "Agree to terms",
      onToggle: proc(checked: bool) =
        echo "Checkbox: ", checked
    )
    
    Slider(
      minValue: 0,
      maxValue: 100,
      onChange: proc(value: float32) =
        echo "Slider: ", value
    )
    
    ProgressBar(
      value: 75,
      maxValue: 100,
      showText: true
    )
    
    hstack:
      Button(
        text: "Save",
        onClick: proc() =
          echo "Save clicked"
      )
      
      Button(
        text: "Cancel",
        onClick: proc() =
          echo "Cancel clicked"
      )





# Usage example:
let form = container:
  vstack:
    GroupBox(title: "Input Controls"):
      vstack:
        NumberInput(
          value: 0.0,
          minValue: 0.0,
          maxValue: 100.0,
          step: 1.0,
          onChange: proc(v: float) = echo v
        )

        ComboBox(
          items: @["Option 1", "Option 2", "Option 3"],
          onSelect: proc(idx: int) = echo idx
        )

        ListView(
          items: @["Item 1", "Item 2", "Item 3"],
          multiSelect: true,
          onSelect: proc(sel: HashSet[int]) = echo sel
        )

    TabControl(
      tabs: @["General", "Colors", "Advanced"],
      onTabChanged: proc(tab: int) = echo tab
    ):
      vstack:  # Tab 1
        # General settings...

      vstack:  # Tab 2
        ColorPicker(
          color: RED,
          onChange: proc(c: Color) = echo c
        )

      PropertyGrid(  # Tab 3
        properties: {
          "name": Property(kind: pkString, strVal: "Test"),
          "size": Property(kind: pkNumber, numVal: 100),
          "enabled": Property(kind: pkBool, boolVal: true),
          "color": Property(kind: pkColor, colorVal: BLUE)
        }.toTable
      )
