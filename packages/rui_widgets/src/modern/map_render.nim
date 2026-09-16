## Drawing for MapWidget: graticule, markers, coordinate readout.
##
## Split out of mapwidget.nim's `render`, which was 70 lines of drawing inside a
## macro body. Everything here takes plain values -- a MapView, a MapMarker, a
## Rect -- so none of it names the widget type, and the widget body is left
## saying what to draw rather than how.

import rui_core
import rui_drawing
import std/[strutils]

import raylib
import map_projection

const
  GridColor* = Color(r: 200, g: 200, b: 200, a: 100)
  WaterColor* = Color(r: 170, g: 211, b: 223, a: 255)
  ReadoutInk* = Color(r: 40, g: 40, b: 40, a: 255)
  ReadoutHeight* = 20.0'f32
  GraticuleStep = 30.0
    ## Every 30 degrees: enough to read the projection at any zoom without
    ## turning the view into graph paper.
  MaxGraticuleLat = 60.0
    ## Beyond this Mercator stretches the spacing so far that the lines stop
    ## telling you anything.

proc drawMeridians(view: MapView, bounds: Rect) =
  var lon = -180.0
  while lon <= 180.0:
    let p = view.worldToScreen(MapCoord(lat: 0.0, lon: lon))
    if p.x >= bounds.x and p.x <= bounds.x + bounds.width:
      drawLine(p.x, bounds.y, p.x, bounds.y + bounds.height, GridColor)
    lon += GraticuleStep

proc drawParallels(view: MapView, bounds: Rect) =
  var lat = -MaxGraticuleLat
  while lat <= MaxGraticuleLat:
    let p = view.worldToScreen(MapCoord(lat: lat, lon: 0.0))
    if p.y >= bounds.y and p.y <= bounds.y + bounds.height:
      drawLine(bounds.x, p.y, bounds.x + bounds.width, p.y, GridColor)
    lat += GraticuleStep

proc drawGraticule*(view: MapView, bounds: Rect) =
  ## Meridians and parallels, each clipped to the visible rectangle.
  drawMeridians(view, bounds)
  drawParallels(view, bounds)

proc markerRadius*(marker: MapMarker, highlighted: bool): float32 =
  ## A marker with no size of its own gets the default; a highlighted one grows
  ## by a quarter, which reads as emphasis without moving anything around it.
  let size = if marker.size > 0: marker.size else: 10.0'f32
  if highlighted: size * 1.25 else: size

proc isVisible*(p: Point, bounds: Rect): bool =
  p.x >= bounds.x and p.x <= bounds.x + bounds.width and
  p.y >= bounds.y and p.y <= bounds.y + bounds.height

proc drawMarkerShape(p: Point, radius: float32, shape: MarkerShape,
                     color: Color) =
  case shape
  of msCircle:
    drawPie(p.x, p.y, radius, 0.0, 360.0, color)
  of msSquare:
    drawRect(Rect(x: p.x - radius, y: p.y - radius,
                  width: radius * 2, height: radius * 2), color)
  of msPin:
    # Teardrop: a disc with a stem down to the actual coordinate, so the point
    # of the pin is the thing the marker means.
    drawPie(p.x, p.y - radius, radius, 0.0, 360.0, color)
    drawLine(p.x, p.y - radius, p.x, p.y, color, 2.0)

proc drawMarker*(view: MapView, bounds: Rect, marker: MapMarker,
                 shape: MarkerShape, highlighted: bool) =
  ## Draws one marker, or nothing if it projects outside the view.
  let p = view.worldToScreen(marker.coord)
  if not p.isVisible(bounds):
    return

  let radius = markerRadius(marker, highlighted)
  drawMarkerShape(p, radius, shape, marker.color)

  if marker.icon.len > 0:
    drawText(marker.icon, p.x - 6.0, p.y - radius - 7.0, 12.0, WHITE)

  # The title is only shown for the marker under the pointer or selected,
  # because every title at once is unreadable at any useful marker density.
  if highlighted and marker.title.len > 0:
    drawText(marker.title, p.x + radius + 4.0, p.y - 6.0, 12.0, ReadoutInk)

proc coordinateReadout*(lat, lon, zoom: float): string =
  ## Four decimals is about 11 metres, which is the point past which a reading
  ## off a pan-and-zoom map is not telling the truth anyway.
  formatFloat(lat, ffDecimal, 4) & ", " & formatFloat(lon, ffDecimal, 4) &
    "  z" & formatFloat(zoom, ffDecimal, 1)

proc drawCoordinateReadout*(bounds: Rect, lat, lon, zoom: float) =
  let barRect = Rect(x: bounds.x, y: bounds.y + bounds.height - ReadoutHeight,
                     width: bounds.width, height: ReadoutHeight)
  drawRect(barRect, Color(r: 255, g: 255, b: 255, a: 180))
  drawText(coordinateReadout(lat, lon, zoom), barRect.x + 6.0, barRect.y + 4.0,
           11.0, ReadoutInk)
