# List view
defineWidget ListView:
  props:
    items: seq[string]
    selected: int
    onSelect: proc(index: int)
    scrollIndex: int

  render:
    var selected = widget.selected
    if GuiListView(
      widget.toRaylibRect(),
      widget.items.join(";"),
      addr widget.scrollIndex,
      addr selected
    ):
      widget.selected = selected
      if widget.onSelect != nil:
        widget.onSelect(selected)

# Example usage:
let form = container:
  vstack:
    Label(text: "Personal Information", fontSize: some(24))

    TextInput(
      placeholder: "Name",
      maxLength: 50,
      onTextChanged: proc(text: string) = echo "Name: ", text
    )

    TextInput(
      placeholder: "Password",
      password: true,
      maxLength: 30,
      onSubmit: proc(text: string) = echo "Password entered"
    )

    RadioGroup(
      options: @["Male", "Female", "Other"],
      onSelect: proc(idx: int) = echo "Selected gender: ", idx
    )

    Checkbox(
      text: "Subscribe to newsletter",
      onToggle: proc(checked: bool) = echo "Subscribe: ", checked
    )

    Label(text: "Volume")
    Slider(
      minValue: 0,
      maxValue: 100,
      value: 50,
      showValue: true,
      format: "%.0f%%",
      onChange: proc(v: float32) = echo "Volume: ", v
    )

    ProgressBar(
      value: 75,
      maxValue: 100,
      showPercentage: true
    )

    ComboBox(
      items: @["Small", "Medium", "Large"],
      onSelect: proc(idx: int) = echo "Selected size: ", idx
    )

    ListView(
      items: @["Item 1", "Item 2", "Item 3"],
      onSelect: proc(idx: int) = echo "Selected item: ", idx
    )
