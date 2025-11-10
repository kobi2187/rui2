# Radio button group
defineWidget RadioGroup:
  props:
    options: seq[string]
    selected: int
    onSelect: proc(index: int)

  render:
    var selected = widget.selected
    for i, opt in widget.options:
      if GuiRadioButton(
        Rectangle(
          x: widget.rect.x,
          y: widget.rect.y + float32(i * 24),
          width: 20,
          height: 20
        ),
        opt,
        selected == i
      ):
        widget.selected = i
        if widget.onSelect != nil:
          widget.onSelect(i)