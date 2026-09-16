## Map projection and viewport geometry.
##
## Split out of mapwidget.nim: none of this needs a widget, a window or a GL
## context, so it is ordinary code you can test with a table of coordinates.
## What is left in the widget is event handling and drawing.
##
## The projection lives in a `MapView` value rather than in procs over the
## widget for a reason that is structural, not stylistic: the widget type does
## not exist until definePrimitive has expanded, and the widget body needs the
## geometry. A value the widget can build from itself (see `viewOf`) is the way
## round that.

import rui_core
import std/[math, json]

import raylib

type
  MapCoord* = object
    lat*: float64    # Latitude, -90 .. +90
    lon*: float64    # Longitude, -180 .. +180

  MapMarker* = object
    id*: string
    coord*: MapCoord
    title*: string
    icon*: string           # Icon glyph
    color*: Color
    size*: float32
    data*: JsonNode

  MapProjection* = enum
    mpMercator          # Web Mercator
    mpEquirectangular   # Plain lat/lon

  MarkerShape* = enum
    msCircle
    msSquare
    msPin

  MapView* = object
    ## Everything needed to turn a coordinate into a pixel.
    center*: MapCoord
    zoom*: float
    projection*: MapProjection
    originX*, originY*: float32    # Widget top-left
    width*, height*: float32

const
  TileSize = 256.0
  ZoomButtonSize = 24.0'f32
  MaxMercatorLat = 85.05112878   ## Web Mercator is undefined at the poles.

proc worldScale(zoom: float): float =
  pow(2.0, zoom) * TileSize

proc mercatorY(lat: float64): float64 =
  ## Normalised 0..1 Mercator y. Clamped, because tan() blows up at the poles.
  let clamped = clamp(lat, -MaxMercatorLat, MaxMercatorLat)
  let rad = clamped * PI / 180.0
  (1.0 - ln(tan(rad) + 1.0 / cos(rad)) / PI) / 2.0

proc projectNormalised(view: MapView, coord: MapCoord): (float64, float64) =
  ## Coordinate to 0..1 in projection space.
  let nx = (coord.lon + 180.0) / 360.0
  let ny = case view.projection
           of mpMercator: mercatorY(coord.lat)
           of mpEquirectangular: (90.0 - coord.lat) / 180.0
  (nx, ny)

proc worldToScreen*(view: MapView, coord: MapCoord): Point =
  ## Geographic coordinate to a pixel inside the widget.
  let scale = worldScale(view.zoom)
  let (nx, ny) = view.projectNormalised(coord)
  let (cx, cy) = view.projectNormalised(view.center)
  Point(
    x: view.originX + view.width / 2 + float32((nx - cx) * scale),
    y: view.originY + view.height / 2 + float32((ny - cy) * scale)
  )

proc screenToWorld*(view: MapView, x, y: float32): MapCoord =
  ## Pixel back to a geographic coordinate.
  let scale = worldScale(view.zoom)
  let (cx, cy) = view.projectNormalised(view.center)
  let nx = cx + float64(x - view.originX - view.width / 2) / scale
  let ny = cy + float64(y - view.originY - view.height / 2) / scale

  let lon = nx * 360.0 - 180.0
  let lat = case view.projection
            of mpEquirectangular:
              90.0 - ny * 180.0
            of mpMercator:
              # Inverse Web Mercator.
              radToDeg(arctan(sinh(PI * (1.0 - 2.0 * ny))))
  MapCoord(lat: clamp(lat, -90.0, 90.0), lon: clamp(lon, -180.0, 180.0))

proc zoomInRect*(bounds: Rect): Rect =
  Rect(x: bounds.x + bounds.width - ZoomButtonSize - 8, y: bounds.y + 8,
       width: ZoomButtonSize, height: ZoomButtonSize)

proc zoomOutRect*(bounds: Rect): Rect =
  let inR = zoomInRect(bounds)
  Rect(x: inR.x, y: inR.y + ZoomButtonSize + 4,
       width: ZoomButtonSize, height: ZoomButtonSize)


proc pannedCenter*(view: MapView, startCenter: MapCoord,
                   grabX, grabY, nowX, nowY: float32): MapCoord =
  ## Where the centre goes when a drag that grabbed (grabX, grabY) has reached
  ## (nowX, nowY): the coordinate that puts the grabbed point back under the
  ## pointer.
  ##
  ## Done by unprojecting the *pixel delta* rather than by subtracting two
  ## latitudes, and that distinction is the whole proc. Mercator is nonlinear
  ## in latitude, so `startCenter.lat + (grabbedLat - nowLat)` is only correct
  ## at the equator -- at 5 degrees north with a 120px drag it is already 0.7
  ## degrees out, and the map slides out from under the pointer. In normalised
  ## projection space the relationship is linear at any latitude, and reading
  ## the delta off the widget centre is how you get there without exposing the
  ## normalised coordinates.
  ##
  ## Both points are unprojected through the view the drag *started* in. Using
  ## the live view would feed each frame's new centre into the next frame's
  ## calculation, so the map would accelerate away instead of staying put.
  var startView = view
  startView.center = startCenter
  let moved = startView.screenToWorld(
    startView.originX + startView.width / 2 + (grabX - nowX),
    startView.originY + startView.height / 2 + (grabY - nowY))
  MapCoord(lat: clamp(moved.lat, -90.0, 90.0),
           lon: clamp(moved.lon, -180.0, 180.0))

proc markerAt*(view: MapView, markers: openArray[MapMarker],
               x, y: float32): string =
  ## Id of the marker under (x, y), or "". Square hit box around the projected
  ## point, at least 8px each way so a small marker is still clickable.
  for marker in markers:
    let p = view.worldToScreen(marker.coord)
    let half = max(marker.size, 8.0'f32)
    if abs(x - p.x) <= half and abs(y - p.y) <= half:
      return marker.id
  ""
