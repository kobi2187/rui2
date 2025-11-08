
type Rect* = object
  x*, y*: float32
  width*, height*: float32

proc newRect*(x, y, width, height: float32): Rect =
  result = Rect(x: x, y: y, width: width, height: height)
  
# type WidgetId* = distinct int

type Widget* = ref object of RootObj
  # id*: WidgetId
  rect*: Rect
  children*: seq[Widget]

method validate*(w:Widget)  {.base.} =
  assert w.rect.width > 0 and w.rect.height > 0



# ======================= move to separate module =======================
type EdgeInsets* = object
  left*, top*, right*, bottom*: float32

proc newEdgeInsets*(all: float32): EdgeInsets =
  EdgeInsets(left: all, top: all, right: all, bottom: all)
  
proc newEdgeInsets*(horizontal, vertical: float32): EdgeInsets =
  EdgeInsets(
    left: horizontal,
    right: horizontal, 
    top: vertical,
    bottom: vertical
  )