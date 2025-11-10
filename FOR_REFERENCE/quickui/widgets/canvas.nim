
# canvas.nim
type
  Canvas* = ref object of Widget
    ## Basic drawing surface
    renderTarget: RenderTexture2D
    drawCommands: seq[DrawCommand]

  DrawCommand* = object
    case kind*: DrawCommandKind
    of dcLine: 
      startPos, endPos: Point
      color: Color
      thickness: float32
    of dcCircle:
      center: Point
      radius: float32
      color: Color
    of dcRect:
      rect: Rect
      color: Color
    # etc...