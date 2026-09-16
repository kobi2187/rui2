## MapWidget - RUI2
##
## Interactive geographic view: pan, zoom, markers and a coordinate readout.
## There is no tile fetching -- this draws a graticule and your markers over a
## flat background. Point it at a tile server by drawing tiles before the
## markers in `render`.
##
## The projection lives in a separate `MapView` value rather than in procs over
## the widget, for the same reason as Timeline's axis: the widget type does not
## exist until definePrimitive has expanded, and the widget body needs the
## geometry helpers.

import rui_core
import rui_drawing
import std/[options, math, json]

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

template viewOf*(widget: untyped): MapView =
  ## The widget's current projection. A template, not a proc: the MapWidget type
  ## does not exist until the macro below has expanded.
  MapView(
    center: widget.center,
    zoom: widget.zoom,
    projection: widget.projection,
    originX: widget.bounds.x,
    originY: widget.bounds.y,
    width: widget.bounds.width,
    height: widget.bounds.height
  )

definePrimitive(MapWidget):
  props:
    initialCenter: MapCoord = MapCoord(lat: 0.0, lon: 0.0)
    initialZoom: float = 2.0
    minZoom: float = 1.0
    maxZoom: float = 18.0
    projection: MapProjection = mpMercator
    showCoordinates: bool = true
    showZoomControls: bool = true
    enablePan: bool = true
    enableZoom: bool = true
    markerShape: MarkerShape = msPin
    gridLines: bool = true
    intent: ThemeIntent = Default

  state:
    center: MapCoord
    zoom: float
    markers: seq[MapMarker]
    selectedMarker: string
    hoveredMarker: string
    isPanning: bool
    panStart: Point              # Screen position where the drag began
    panStartCenter: MapCoord     # Map centre at that moment
    pointerLat: float64          # Last pointer position, for the readout
    pointerLon: float64

  actions:
    onZoomChanged(newZoom: float)
    onCenterChanged(newCenter: MapCoord)
    onMarkerClick(marker: MapMarker)
    onMapClick(coord: MapCoord)

  init:
    widget.focusable = true

  events:
    on_mouse_down:
      let view = viewOf(widget)

      if widget.showZoomControls and widget.enableZoom:
        if zoomInRect(widget.bounds).contains(event.mousePos.x, event.mousePos.y):
          widget.zoom = clamp(widget.zoom + 1.0, widget.minZoom, widget.maxZoom)
          widget.isDirty = true
          if widget.onZoomChanged.isSome:
            widget.onZoomChanged.get()(widget.zoom)
          return true
        if zoomOutRect(widget.bounds).contains(event.mousePos.x, event.mousePos.y):
          widget.zoom = clamp(widget.zoom - 1.0, widget.minZoom, widget.maxZoom)
          widget.isDirty = true
          if widget.onZoomChanged.isSome:
            widget.onZoomChanged.get()(widget.zoom)
          return true

      # Markers are hit-tested before the map itself.
      for marker in widget.markers:
        let p = view.worldToScreen(marker.coord)
        let half = max(marker.size, 8.0'f32)
        if abs(event.mousePos.x - p.x) <= half and abs(event.mousePos.y - p.y) <= half:
          widget.selectedMarker = marker.id
          widget.isDirty = true
          if widget.onMarkerClick.isSome:
            widget.onMarkerClick.get()(marker)
          return true

      if widget.enablePan:
        widget.isPanning = true
        widget.panStart = Point(x: event.mousePos.x, y: event.mousePos.y)
        widget.panStartCenter = widget.center

      if widget.onMapClick.isSome:
        widget.onMapClick.get()(view.screenToWorld(event.mousePos.x, event.mousePos.y))
      return true

    on_mouse_move:
      let view = viewOf(widget)
      let here = view.screenToWorld(event.mousePos.x, event.mousePos.y)
      widget.pointerLat = here.lat
      widget.pointerLon = here.lon

      if widget.isPanning:
        # Pan by moving the centre the opposite way to the drag, in map units.
        var startView = view
        startView.center = widget.panStartCenter
        let grabbed = startView.screenToWorld(widget.panStart.x, widget.panStart.y)
        let nowAt = startView.screenToWorld(event.mousePos.x, event.mousePos.y)
        widget.center = MapCoord(
          lat: clamp(widget.panStartCenter.lat + (grabbed.lat - nowAt.lat), -90.0, 90.0),
          lon: clamp(widget.panStartCenter.lon + (grabbed.lon - nowAt.lon), -180.0, 180.0)
        )
        widget.isDirty = true
        if widget.onCenterChanged.isSome:
          widget.onCenterChanged.get()(widget.center)
        return true

      var newHover = ""
      for marker in widget.markers:
        let p = view.worldToScreen(marker.coord)
        let half = max(marker.size, 8.0'f32)
        if abs(event.mousePos.x - p.x) <= half and abs(event.mousePos.y - p.y) <= half:
          newHover = marker.id
          break
      if newHover != widget.hoveredMarker:
        widget.hoveredMarker = newHover
      widget.isDirty = true
      return false

    on_mouse_up:
      if widget.isPanning:
        widget.isPanning = false
        return true
      return false

    on_mouse_wheel:
      if not widget.enableZoom:
        return false
      let newZoom = clamp(widget.zoom + float(event.wheelDelta) * 0.5,
                          widget.minZoom, widget.maxZoom)
      if newZoom != widget.zoom:
        widget.zoom = newZoom
        widget.isDirty = true
        if widget.onZoomChanged.isSome:
          widget.onZoomChanged.get()(newZoom)
      return true

  layout:
    # No seeding needed here: the DSL constructor already copies `initialCenter`
    # into `center` and `initialZoom` into `zoom` via the initialX convention.
    if widget.bounds.width <= 0:
      widget.bounds.width = 400.0'f32
    if widget.bounds.height <= 0:
      widget.bounds.height = 300.0'f32

  render:
    let props = currentTheme.getThemeProps(widget.intent, Normal)
    drawRect(widget.bounds, Color(r: 170, g: 211, b: 223, a: 255))   # water

    let view = viewOf(widget)
    let clip = beginClip(widget.bounds)

    if widget.gridLines:
      let gridColor = Color(r: 200, g: 200, b: 200, a: 100)
      # Graticule every 30 degrees; enough to read the projection at any zoom.
      var lon = -180.0
      while lon <= 180.0:
        let p = view.worldToScreen(MapCoord(lat: 0.0, lon: lon))
        if p.x >= widget.bounds.x and p.x <= widget.bounds.x + widget.bounds.width:
          drawLine(p.x, widget.bounds.y, p.x,
                   widget.bounds.y + widget.bounds.height, gridColor)
        lon += 30.0
      var lat = -60.0
      while lat <= 60.0:
        let p = view.worldToScreen(MapCoord(lat: lat, lon: 0.0))
        if p.y >= widget.bounds.y and p.y <= widget.bounds.y + widget.bounds.height:
          drawLine(widget.bounds.x, p.y,
                   widget.bounds.x + widget.bounds.width, p.y, gridColor)
        lat += 30.0

    for marker in widget.markers:
      let p = view.worldToScreen(marker.coord)
      if p.x < widget.bounds.x or p.x > widget.bounds.x + widget.bounds.width or
         p.y < widget.bounds.y or p.y > widget.bounds.y + widget.bounds.height:
        continue

      let size = if marker.size > 0: marker.size else: 10.0'f32
      let highlighted = marker.id == widget.selectedMarker or
                        marker.id == widget.hoveredMarker
      let radius = if highlighted: size * 1.25 else: size

      case widget.markerShape
      of msCircle:
        drawPie(p.x, p.y, radius, 0.0, 360.0, marker.color)
      of msSquare:
        drawRect(Rect(x: p.x - radius, y: p.y - radius,
                      width: radius * 2, height: radius * 2), marker.color)
      of msPin:
        # Teardrop: a disc with a stem down to the actual coordinate.
        drawPie(p.x, p.y - radius, radius, 0.0, 360.0, marker.color)
        drawLine(p.x, p.y - radius, p.x, p.y, marker.color, 2.0)

      if marker.icon.len > 0:
        drawText(marker.icon, p.x - 6.0, p.y - radius - 7.0, 12.0, WHITE)

      if highlighted and marker.title.len > 0:
        drawText(marker.title, p.x + radius + 4.0, p.y - 6.0, 12.0,
                 Color(r: 40, g: 40, b: 40, a: 255))

    endClip(clip)

    if widget.showZoomControls and widget.enableZoom:
      drawButton(zoomInRect(widget.bounds), "+", props)
      drawButton(zoomOutRect(widget.bounds), "-", props)

    if widget.showCoordinates:
      let readout = formatFloat(widget.pointerLat, ffDecimal, 4) & ", " &
                    formatFloat(widget.pointerLon, ffDecimal, 4) &
                    "  z" & formatFloat(widget.zoom, ffDecimal, 1)
      let barRect = Rect(x: widget.bounds.x,
                         y: widget.bounds.y + widget.bounds.height - 20,
                         width: widget.bounds.width, height: 20)
      drawRect(barRect, Color(r: 255, g: 255, b: 255, a: 180))
      drawText(readout, barRect.x + 6.0, barRect.y + 4.0, 11.0,
               Color(r: 40, g: 40, b: 40, a: 255))

    drawThemedBorder(widget.bounds, props, widget.focused)

proc addMarker*(widget: MapWidget, marker: MapMarker) =
  ## Add a marker and repaint.
  widget.markers.add(marker)
  widget.isDirty = true

proc clearMarkers*(widget: MapWidget) =
  ## Drop every marker.
  widget.markers.setLen(0)
  widget.selectedMarker = ""
  widget.hoveredMarker = ""
  widget.isDirty = true

proc view*(widget: MapWidget): MapView =
  ## The widget's current projection, for callers outside this module.
  viewOf(widget)
