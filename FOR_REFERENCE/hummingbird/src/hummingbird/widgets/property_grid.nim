
# Value inspector (property grid)
defineWidget PropertyGrid:
  props:
    properties: Table[string, Property]
    onChange: proc(name: string, value: any)

  render:
    for name, prop in widget.properties:
      case prop.kind
      of pkString:
        var value = prop.strVal
        if GuiTextBox(
          widget.getPropertyRect(name),
          value,
          100,
          true
        ):
          widget.properties[name].strVal = value
          widget.onChange(name, value)

      of pkNumber:
        var value = prop.numVal
        if GuiSpinner(
          widget.getPropertyRect(name),
          name,
          addr value,
          low(float),
          high(float),
          true
        ):
          widget.properties[name].numVal = value
          widget.onChange(name, value)

      of pkBool:
        var value = prop.boolVal
        if GuiCheckBox(
          widget.getPropertyRect(name),
          name,
          addr value
        ):
          widget.properties[name].boolVal = value
          widget.onChange(name, value)

      of pkColor:
        var value = prop.colorVal
        if GuiColorPicker(
          widget.getPropertyRect(name),
          name,
          addr value
        ):
          widget.properties[name].colorVal = value
          widget.onChange(name, value)

  state:
    fields:
      properties: Table[string, Property]
