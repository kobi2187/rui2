

# Property editor grid
defineWidget PropertyGrid:
  props:
    properties: Table[string, Property]
    categories: Table[string, seq[string]]
    onPropertyChange: proc(name: string, value: JsonNode)

  type
    Property* = object
      name*: string
      value*: JsonNode
      kind*: PropertyKind
      options*: PropertyOptions

    PropertyKind* = enum
      pkString, pkNumber, pkBool, pkEnum,
      pkColor, pkFont, pkVector2, pkRect

    PropertyOptions* = object
      readOnly*: bool
      case kind*: PropertyKind
      of pkString:
        multiline*: bool
        maxLength*: int
      of pkNumber:
        min*, max*: float
        step*: float
      of pkEnum:
        choices*: seq[string]
      else: discard

