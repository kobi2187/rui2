## MapWidget - RUI2
##
## Interactive map widget for geographic data visualization.
## Supports pan, zoom, markers, and custom overlays.
## Simplified implementation - can be extended with tile servers.

import ../../core/widget_dsl
import std/[options, tables, math, json]

when defined(useGraphics):
  import raylib

type
  MapCoord* = object
    lat*: float64    # Latitude (-90 to +90)
    lon*: float64    # Longitude (-180 to +180)

  MapMarker* = object
    id*: string
    coord*: MapCoord
    title*: string
    icon*: string           # Icon text (emoji/unicode)
    color*: Color
    size*: float
    data*: JsonNode

  MapProjection* = enum
    mpMercator          # Web Mercator (most common)
    mpEquirectangular   # Simple lat/lon projection

  MarkerShape* = enum
    msCircle
    msSquare
    msPin
    msCustom

defineWidget(MapWidget):
  props:
    initialCenter: MapCoord = MapCoord(lat: 0.0, lon: 0.0)
    initialZoom: float = 2.0
    minZoom: float = 1.0
    maxZoom: float = 18.0
    projection: MapProjection = mpMercator
    showCoordinates: bool = true
    showZoomControls: bool = true
    showScaleBar: bool = true
    enablePan: bool = true
    enableZoom: bool = true
    markerShape: MarkerShape = msPin
    gridLines: bool = true
    gridColor: Color = Color(r: 200, g: 200, b: 200, a: 100)
    waterColor: Color = Color(r: 170, g: 211, b: 223, a: 255)
    landColor: Color = Color(r: 242, g: 239, b: 233, a: 255)

  state:
    center: MapCoord
    zoom: float
    markers: seq[MapMarker]
    selectedMarker: string
    hoveredMarker: string
    isPanning: bool
    panStart: Vector2
    panOffset: Vector2

  actions:
    onZoomChanged(newZoom: float)
    onCenterChanged(newCenter: MapCoord)
    onMarkerClick(marker: MapMarker)
    onMarkerDoubleClick(marker: MapMarker)
    onMapClick(coord: MapCoord)

  layout:
    discard

  render:
    when defined(useGraphics):
      # Initialize state if first render
      if widget.center.lat == 0.0 and widget.center.lon == 0.0:
        widget.center = widget.initialCenter
        widget.zoom = widget.initialZoom

      # Coordinate conversion functions
      proc worldToScreen(coord: MapCoord): Vector2 =
        ## Convert geographic coordinates to screen pixels
        let centerCoord = widget.center
        let z = widget.zoom
        let offset = widget.panOffset

        case widget.projection
        of mpMercator:
          # Web Mercator projection
          let scale = pow(2.0, z) * 256.0
          let centerX = (centerCoord.lon + 180.0) / 360.0 * scale
          let centerY = (1.0 - ln(tan(centerCoord.lat * PI / 180.0) + 1.0 / cos(centerCoord.lat * PI / 180.0)) / PI) / 2.0 * scale

          let pointX = (coord.lon + 180.0) / 360.0 * scale
          let pointY = (1.0 - ln(tan(coord.lat * PI / 180.0) + 1.0 / cos(coord.lat * PI / 180.0)) / PI) / 2.0 * scale

          result = Vector2(
            x: widget.bounds.x + widget.bounds.width / 2.0 + (pointX - centerX) + offset.x,
            y: widget.bounds.y + widget.bounds.height / 2.0 + (pointY - centerY) + offset.y
          )

        of mpEquirectangular:
          # Simple equirectangular projection
          let scale = pow(2.0, z) * 10.0
          let dx = (coord.lon - centerCoord.lon) * scale
          let dy = (centerCoord.lat - coord.lat) * scale

          result = Vector2(
            x: widget.bounds.x + widget.bounds.width / 2.0 + dx + offset.x,
            y: widget.bounds.y + widget.bounds.height / 2.0 + dy + offset.y
          )

      proc screenToWorld(screenPos: Vector2): MapCoord =
        ## Convert screen pixels to geographic coordinates
        let centerCoord = widget.center
        let z = widget.zoom
        let offset = widget.panOffset

        case widget.projection
        of mpMercator:
          let scale = pow(2.0, z) * 256.0
          let centerX = (centerCoord.lon + 180.0) / 360.0 * scale
          let centerY = (1.0 - ln(tan(centerCoord.lat * PI / 180.0) + 1.0 / cos(centerCoord.lat * PI / 180.0)) / PI) / 2.0 * scale

          let pointX = centerX + (screenPos.x - widget.bounds.x - widget.bounds.width / 2.0) - offset.x
          let pointY = centerY + (screenPos.y - widget.bounds.y - widget.bounds.height / 2.0) - offset.y

          result.lon = pointX / scale * 360.0 - 180.0
          let n = PI - 2.0 * PI * pointY / scale
          result.lat = 180.0 / PI * arctan(0.5 * (exp(n) - exp(-n)))

        of mpEquirectangular:
          let scale = pow(2.0, z) * 10.0
          let dx = (screenPos.x - widget.bounds.x - widget.bounds.width / 2.0) - offset.x
          let dy = (screenPos.y - widget.bounds.y - widget.bounds.height / 2.0) - offset.y

          result.lon = centerCoord.lon + dx / scale
          result.lat = centerCoord.lat - dy / scale

      # Draw map background (simplified - normally would draw tiles)
      DrawRectangleRec(widget.bounds, widget.waterColor)

      # Draw simplified land masses (just draw center area as land)
      let landRect = Rectangle(
        x: widget.bounds.x + widget.bounds.width * 0.2,
        y: widget.bounds.y + widget.bounds.height * 0.2,
        width: widget.bounds.width * 0.6,
        height: widget.bounds.height * 0.6
      )
      DrawRectangleRec(landRect, widget.landColor)

      # Draw grid lines
      if widget.gridLines:
        # Latitude lines
        for lat in countup(-80, 80, 20):
          let start = worldToScreen(MapCoord(lat: lat.float64, lon: -180.0))
          let endPos = worldToScreen(MapCoord(lat: lat.float64, lon: 180.0))
          DrawLineEx(start, endPos, 1.0, widget.gridColor)

        # Longitude lines
        for lon in countup(-180, 180, 20):
          let start = worldToScreen(MapCoord(lat: -85.0, lon: lon.float64))
          let endPos = worldToScreen(MapCoord(lat: 85.0, lon: lon.float64))
          DrawLineEx(start, endPos, 1.0, widget.gridColor)

      # Begin scissor mode for clipping
      BeginScissorMode(
        widget.bounds.x.cint,
        widget.bounds.y.cint,
        widget.bounds.width.cint,
        widget.bounds.height.cint
      )

      # Draw markers
      let mousePos = GetMousePosition()
      let mouseInBounds = CheckCollisionPointRec(mousePos, widget.bounds)
      var newHoveredMarker = ""

      for marker in widget.markers:
        let screenPos = worldToScreen(marker.coord)

        # Skip if outside viewport
        if screenPos.x < widget.bounds.x or screenPos.x > widget.bounds.x + widget.bounds.width or
           screenPos.y < widget.bounds.y or screenPos.y > widget.bounds.y + widget.bounds.height:
          continue

        let markerSize = marker.size
        let isSelected = marker.id == widget.selectedMarker
        let isHovered = marker.id == widget.hoveredMarker

        var displayColor = marker.color
        if isSelected:
          displayColor = Color(
            r: min(255, marker.color.r + 40),
            g: min(255, marker.color.g + 40),
            b: min(255, marker.color.b + 40),
            a: marker.color.a
          )
        elif isHovered:
          displayColor = Color(
            r: min(255, marker.color.r + 20),
            g: min(255, marker.color.g + 20),
            b: min(255, marker.color.b + 20),
            a: marker.color.a
          )

        # Draw marker shape
        case widget.markerShape
        of msCircle:
          DrawCircleV(screenPos, markerSize, displayColor)
          DrawCircleLines(
            screenPos.x.cint,
            screenPos.y.cint,
            markerSize,
            Color(r: 0, g: 0, b: 0, a: 150)
          )

        of msSquare:
          let rect = Rectangle(
            x: screenPos.x - markerSize,
            y: screenPos.y - markerSize,
            width: markerSize * 2.0,
            height: markerSize * 2.0
          )
          DrawRectangleRec(rect, displayColor)
          DrawRectangleLinesEx(rect, 1.5, Color(r: 0, g: 0, b: 0, a: 150))

        of msPin:
          # Draw pin shape (circle on top of triangle)
          DrawCircleV(
            Vector2(x: screenPos.x, y: screenPos.y - markerSize),
            markerSize * 0.6,
            displayColor
          )
          DrawTriangle(
            Vector2(x: screenPos.x - markerSize * 0.5, y: screenPos.y - markerSize * 0.3),
            Vector2(x: screenPos.x + markerSize * 0.5, y: screenPos.y - markerSize * 0.3),
            screenPos,
            displayColor
          )

        of msCustom:
          # Use icon if provided
          if marker.icon.len > 0:
            DrawText(
              marker.icon.cstring,
              (screenPos.x - 8.0).cint,
              (screenPos.y - 16.0).cint,
              20,
              displayColor
            )
          else:
            DrawCircleV(screenPos, markerSize, displayColor)

        # Check hover
        let markerRect = Rectangle(
          x: screenPos.x - markerSize,
          y: screenPos.y - markerSize * 2.0,
          width: markerSize * 2.0,
          height: markerSize * 2.0
        )

        if mouseInBounds and CheckCollisionPointRec(mousePos, markerRect):
          newHoveredMarker = marker.id

          # Draw tooltip
          let tooltipText = marker.title
          let textWidth = MeasureText(tooltipText.cstring, 12)
          let tooltipRect = Rectangle(
            x: screenPos.x - textWidth.float / 2.0 - 4.0,
            y: screenPos.y - markerSize * 2.0 - 20.0,
            width: textWidth.float + 8.0,
            height: 18.0
          )

          DrawRectangleRec(tooltipRect, Color(r: 255, g: 255, b: 255, a: 230))
          DrawRectangleLinesEx(tooltipRect, 1.0, Color(r: 100, g: 100, b: 100, a: 255))
          DrawText(
            tooltipText.cstring,
            (tooltipRect.x + 4.0).cint,
            (tooltipRect.y + 3.0).cint,
            12,
            Color(r: 40, g: 40, b: 40, a: 255)
          )

        # Handle marker click
        if mouseInBounds and IsMouseButtonPressed(MOUSE_LEFT_BUTTON):
          if CheckCollisionPointRec(mousePos, markerRect):
            widget.selectedMarker = marker.id

            if widget.onMarkerClick.isSome:
              widget.onMarkerClick.get()(marker)

      widget.hoveredMarker = newHoveredMarker

      EndScissorMode()

      # Handle panning
      if widget.enablePan and mouseInBounds:
        if IsMouseButtonPressed(MOUSE_LEFT_BUTTON) and newHoveredMarker.len == 0:
          widget.isPanning = true
          widget.panStart = mousePos

        if widget.isPanning and IsMouseButtonDown(MOUSE_LEFT_BUTTON):
          let delta = Vector2(
            x: mousePos.x - widget.panStart.x,
            y: mousePos.y - widget.panStart.y
          )
          widget.panOffset = delta

        if IsMouseButtonReleased(MOUSE_LEFT_BUTTON) and widget.isPanning:
          widget.isPanning = false

          # Apply pan to center
          let offset = widget.panOffset
          if offset.x != 0.0 or offset.y != 0.0:
            let screenCenter = Vector2(
              x: widget.bounds.x + widget.bounds.width / 2.0 - offset.x,
              y: widget.bounds.y + widget.bounds.height / 2.0 - offset.y
            )
            let newCenter = screenToWorld(screenCenter)
            widget.center = newCenter
            widget.panOffset = Vector2(x: 0.0, y: 0.0)

            if widget.onCenterChanged.isSome:
              widget.onCenterChanged.get()(newCenter)

      # Handle zoom with mouse wheel
      if widget.enableZoom and mouseInBounds:
        let wheel = GetMouseWheelMove()
        if wheel != 0.0:
          let currentZoom = widget.zoom
          let newZoom = clamp(
            currentZoom + wheel * 0.5,
            widget.minZoom,
            widget.maxZoom
          )
          widget.zoom = newZoom

          if widget.onZoomChanged.isSome:
            widget.onZoomChanged.get()(newZoom)

      # Draw zoom controls
      if widget.showZoomControls:
        let controlX = widget.bounds.x + widget.bounds.width - 40.0
        let controlY = widget.bounds.y + 10.0

        # Zoom in button
        let zoomInRect = Rectangle(
          x: controlX,
          y: controlY,
          width: 30.0,
          height: 30.0
        )
        DrawRectangleRec(zoomInRect, Color(r: 255, g: 255, b: 255, a: 230))
        DrawRectangleLinesEx(zoomInRect, 1.0, Color(r: 150, g: 150, b: 150, a: 255))
        DrawText(
          "+".cstring,
          (controlX + 8.0).cint,
          (controlY + 4.0).cint,
          20,
          Color(r: 60, g: 60, b: 60, a: 255)
        )

        if mouseInBounds and CheckCollisionPointRec(mousePos, zoomInRect) and IsMouseButtonPressed(MOUSE_LEFT_BUTTON):
          let newZoom = clamp(widget.zoom + 1.0, widget.minZoom, widget.maxZoom)
          widget.zoom = newZoom

        # Zoom out button
        let zoomOutRect = Rectangle(
          x: controlX,
          y: controlY + 35.0,
          width: 30.0,
          height: 30.0
        )
        DrawRectangleRec(zoomOutRect, Color(r: 255, g: 255, b: 255, a: 230))
        DrawRectangleLinesEx(zoomOutRect, 1.0, Color(r: 150, g: 150, b: 150, a: 255))
        DrawText(
          "-".cstring,
          (controlX + 10.0).cint,
          (controlY + 39.0).cint,
          20,
          Color(r: 60, g: 60, b: 60, a: 255)
        )

        if mouseInBounds and CheckCollisionPointRec(mousePos, zoomOutRect) and IsMouseButtonPressed(MOUSE_LEFT_BUTTON):
          let newZoom = clamp(widget.zoom - 1.0, widget.minZoom, widget.maxZoom)
          widget.zoom = newZoom

      # Draw coordinates display
      if widget.showCoordinates:
        let center = widget.center
        let coordText = &"Lat: {center.lat:.4f}, Lon: {center.lon:.4f}, Zoom: {widget.zoom:.1f}"
        DrawText(
          coordText.cstring,
          (widget.bounds.x + 10.0).cint,
          (widget.bounds.y + widget.bounds.height - 20.0).cint,
          11,
          Color(r: 60, g: 60, b: 60, a: 200)
        )

      # Draw border
      DrawRectangleLinesEx(
        widget.bounds,
        1.0,
        Color(r: 180, g: 180, b: 180, a: 255)
      )

    else:
      # Non-graphics mode
      echo "MapWidget:"
      let center = widget.center
      echo "  Center: (", center.lat, ", ", center.lon, ")"
      echo "  Zoom: ", widget.zoom
      echo "  Markers: ", widget.markers.len
      echo "  Selected: ", widget.selectedMarker
      echo "  Panning: ", widget.isPanning

      for marker in widget.markers:
        let sel = if marker.id == widget.selectedMarker: "[X]" else: "[ ]"
        echo "  ", sel, " ", marker.title, " at (", marker.coord.lat, ", ", marker.coord.lon, ")"
