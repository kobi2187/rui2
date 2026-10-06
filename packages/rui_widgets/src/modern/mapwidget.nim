## MapWidget - RUI2
##
## Interactive geographic view: pan, zoom, markers and a coordinate readout.
## There is no tile fetching -- this draws a graticule and your markers over a
## flat background. Point it at a tile server by drawing tiles before the
## markers in `render`.
##
## The projection and the viewport geometry live in map_projection.nim, which
## needs neither a widget nor a window. What is here is event handling and
## drawing.

import rui_core
import rui_drawing
import std/[options, math, json]

import raylib
import map_projection
import map_render
export map_projection

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

template zoomAbout(widget: untyped, newZoom: float, atX, atY: float32) =
  ## Change the zoom keeping the place under (x, y) under it -- what every
  ## map does with the wheel. Without a point, about the middle.
  block:
    let z = clamp(newZoom, widget.minZoom, widget.maxZoom)
    if z != widget.zoom:
      let place = viewOf(widget).screenToWorld(atX, atY)
      widget.zoom = z
      let view = viewOf(widget)
      let nowAt = view.worldToScreen(place)
      widget.center = view.pannedCenter(widget.center, nowAt.x, nowAt.y, atX, atY)
      widget.isDirty = true
      if widget.onZoomChanged != nil:
        widget.onZoomChanged(z)
      if widget.onCenterChanged != nil:
        widget.onCenterChanged(widget.center)

template panBy(widget: untyped, dx, dy: float32) =
  ## Move the view by (dx, dy) pixels.
  block:
    let view = viewOf(widget)
    let cx = widget.bounds.x + widget.bounds.width / 2
    let cy = widget.bounds.y + widget.bounds.height / 2
    widget.center = view.pannedCenter(widget.center, cx, cy, cx - dx, cy - dy)
    widget.isDirty = true
    if widget.onCenterChanged != nil:
      widget.onCenterChanged(widget.center)

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
          if widget.onZoomChanged != nil:
            widget.onZoomChanged(widget.zoom)
          return true
        if zoomOutRect(widget.bounds).contains(event.mousePos.x, event.mousePos.y):
          widget.zoom = clamp(widget.zoom - 1.0, widget.minZoom, widget.maxZoom)
          widget.isDirty = true
          if widget.onZoomChanged != nil:
            widget.onZoomChanged(widget.zoom)
          return true

      # Markers are hit-tested before the map itself.
      for marker in widget.markers:
        let p = view.worldToScreen(marker.coord)
        let half = max(marker.size, 8.0'f32)
        if abs(event.mousePos.x - p.x) <= half and abs(event.mousePos.y - p.y) <= half:
          widget.selectedMarker = marker.id
          widget.isDirty = true
          if widget.onMarkerClick != nil:
            widget.onMarkerClick(marker)
          return true

      if widget.enablePan:
        widget.isPanning = true
        widget.panStart = Point(x: event.mousePos.x, y: event.mousePos.y)
        widget.panStartCenter = widget.center

      if widget.onMapClick != nil:
        widget.onMapClick(view.screenToWorld(event.mousePos.x, event.mousePos.y))
      return true

    on_mouse_move:
      let view = viewOf(widget)
      let here = view.screenToWorld(event.mousePos.x, event.mousePos.y)
      widget.pointerLat = here.lat
      widget.pointerLon = here.lon

      if widget.isPanning:
        widget.center = view.pannedCenter(widget.panStartCenter,
                                          widget.panStart.x, widget.panStart.y,
                                          event.mousePos.x, event.mousePos.y)
        widget.isDirty = true
        if widget.onCenterChanged != nil:
          widget.onCenterChanged(widget.center)
        return true

      widget.hoveredMarker = view.markerAt(widget.markers, event.mousePos.x,
                                           event.mousePos.y)
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
      widget.zoomAbout(widget.zoom + float(event.wheelDelta) * 0.5,
                       event.mousePos.x, event.mousePos.y)
      return true

    on_key_down:
      # Arrows pan an eighth of the view; +/- zoom about the middle.
      if not widget.focused:
        return false
      let stepX = widget.bounds.width / 8
      let stepY = widget.bounds.height / 8
      let midX = widget.bounds.x + widget.bounds.width / 2
      let midY = widget.bounds.y + widget.bounds.height / 2
      case event.key
      of KeyboardKey.Left: (if widget.enablePan: widget.panBy(-stepX, 0) else: return false)
      of KeyboardKey.Right: (if widget.enablePan: widget.panBy(stepX, 0) else: return false)
      of KeyboardKey.Up: (if widget.enablePan: widget.panBy(0, -stepY) else: return false)
      of KeyboardKey.Down: (if widget.enablePan: widget.panBy(0, stepY) else: return false)
      of KeyboardKey.Equal, KeyboardKey.KpAdd:
        if not widget.enableZoom: return false
        widget.zoomAbout(widget.zoom + 1.0, midX, midY)
      of KeyboardKey.Minus, KeyboardKey.KpSubtract:
        if not widget.enableZoom: return false
        widget.zoomAbout(widget.zoom - 1.0, midX, midY)
      else:
        return false
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
    drawRect(widget.bounds, WaterColor)

    let view = viewOf(widget)
    let clip = beginClip(widget.bounds)

    if widget.gridLines:
      drawGraticule(view, widget.bounds)

    for marker in widget.markers:
      let highlighted = marker.id == widget.selectedMarker or
                        marker.id == widget.hoveredMarker
      drawMarker(view, widget.bounds, marker, widget.markerShape, highlighted)

    endClip(clip)

    if widget.showZoomControls and widget.enableZoom:
      drawButton(zoomInRect(widget.bounds), "+", props)
      drawButton(zoomOutRect(widget.bounds), "-", props)

    if widget.showCoordinates:
      drawCoordinateReadout(widget.bounds, widget.pointerLat,
                            widget.pointerLon, widget.zoom)

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
