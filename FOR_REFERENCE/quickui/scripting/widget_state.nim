# widget_state.nim
import macros, typeinfo

proc getFieldValues*[T: object](obj: T): JsonNode =
  ## Automatically get all fields of an object as JSON
  result = newJObject()
  for name, value in obj.fieldPairs:
    when value is ref:
      if not value.isNil:
        result[name] = %*getFieldValues(value[])
    else:
      result[name] = %*value

proc getWidgetState*(widget: Widget): JsonNode =
  result = %*{
    "id": widget.id,
    "kind": $widget.type.name,
    "fields": getFieldValues(widget)
  }

# Example usage:
type Button = ref object of Widget
  text: string
  enabled: bool
  style: ButtonStyle

type TextInput = ref object of Widget
  text: string
  placeholder: string
  multiline: bool
  maxLength: int

# The state is automatically generated
let button = Button(
  text: "Save",
  enabled: true,
  style: ButtonStyle(...)
)

echo button.getWidgetState()
# Output:
# {
#   "id": "saveButton",
#   "kind": "Button",
#   "fields": {
#     "text": "Save",
#     "enabled": true,
#     "style": {
#       "backgroundColor": "#3498db",
#       "textColor": "#ffffff",
#       ...
#     }
#   }
# }
