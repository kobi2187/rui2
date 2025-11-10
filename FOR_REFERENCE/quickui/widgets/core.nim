# widgets/core.nim
type
  Widget* = ref object of RootObj
    id*: string
    rect*: Rect
    visible*: bool
    enabled*: bool
    parent*: Widget
    children*: seq[Widget]
    focused*: bool
    style*: Option[Style]

  WidgetKind* = enum
    wkButton, wkLabel, wkTextInput, wkCheckbox,
    wkRadio, wkSlider, wkProgress
