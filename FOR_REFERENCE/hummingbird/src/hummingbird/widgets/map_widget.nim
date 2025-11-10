# map_widget.nim
type
  MapCoord* = object
    lat*, lon*: float64

  MapTile* = object
    x*, y*: int
    zoom*: int
    image*: Texture2D

  MapWidget* = ref object of Widget
    center*: MapCoord
    zoom*: float32
    tileCache: Table[tuple[x,y,z: int], MapTile]
    dragStart: Option[Point]
    isDragging: bool

proc worldToScreen*(map: MapWidget, coord: MapCoord): Point =
  # Convert geographic coordinates to screen coordinates
  let worldPoint = geoToWorld(coord, map.zoom)
  result = worldToScreen(worldPoint, map.rect)

proc screenToWorld*(map: MapWidget, point: Point): MapCoord =
  # Convert screen coordinates to geographic coordinates
  let worldPoint = screenToWorld(point, map.rect)
  result = worldToGeo(worldPoint, map.zoom)

defineWidget MapWidget:
  props:
    onZoomChanged: proc(newZoom: float32)
    onCenterChanged: proc(newCenter: MapCoord)
    onMarkerClicked: proc(marker: MapMarker)

  state:
    markers: seq[MapMarker]
    visibleBounds: tuple[min, max: MapCoord]
    tileGrid: seq[MapTile]

  render:
    # Draw visible map tiles
    for tile in widget.tileGrid:
      drawTexture(tile.image,
        Rectangle(x: tile.x.float32, y: tile.y.float32,
                 width: TileSize, height: TileSize),
        WHITE)

    # Draw markers
    for marker in widget.markers:
      let pos = widget.worldToScreen(marker.coord)
      drawMarker(pos, marker.style)

    # Draw custom overlays
    for overlay in widget.overlays:
      overlay.draw()

  update:
    # Handle pan/zoom input
    if isMouseButtonDown(MOUSE_LEFT_BUTTON):
      if widget.dragStart.isNone:
        widget.dragStart = some(getMousePosition())
      else:
        let current = getMousePosition()
        let delta = current - widget.dragStart.get
        widget.center = widget.screenToWorld(delta)
        widget.onCenterChanged(widget.center)

    let wheel = getMouseWheelMove()
    if wheel != 0:
      widget.zoom = clamp(widget.zoom + wheel * 0.1, MinZoom, MaxZoom)
      widget.onZoomChanged(widget.zoom)

    # Update visible tiles
    widget.updateVisibleTiles()

proc updateVisibleTiles(map: MapWidget) =
  let bounds = map.getVisibleBounds()
  let tileRange = getTileRange(bounds, map.zoom)

  # Fetch/update needed tiles
  for x in tileRange.minX..tileRange.maxX:
    for y in tileRange.minY..tileRange.maxY:
      let key = (x, y, map.zoom.int)
      if key notin map.tileCache:
        asyncCheck map.loadTile(key)

# Map overlay example
type
  RouteOverlay* = ref object of MapOverlay
    points*: seq[MapCoord]
    color*: Color
    thickness*: float32

method draw*(overlay: RouteOverlay, map: MapWidget) =
  var screenPoints: seq[Point]
  for coord in overlay.points:
    screenPoints.add(map.worldToScreen(coord))

  # Draw route line
  for i in 0..screenPoints.high-1:
    drawLineEx(screenPoints[i], screenPoints[i+1],
              overlay.thickness, overlay.color)

# Usage example
let map = MapWidget(
  center: MapCoord(lat: 0.0, lon: 0.0),
  zoom: 1.0
)

let route = RouteOverlay(
  points: @[
    MapCoord(lat: 40.7128, lon: -74.0060),  # NYC
    MapCoord(lat: 51.5074, lon: -0.1278),   # London
    MapCoord(lat: 48.8566, lon: 2.3522)     # Paris
  ],
  color: BLUE,
  thickness: 2.0
)

map.overlays.add(route)

map.onMarkerClicked = proc(marker: MapMarker) =
  echo "Clicked marker at: ", marker.coord

type
  MapSource* = ref object of RootObj

  OSMSource* = ref object of MapSource
  GoogleMapsSource* = ref object of MapSource
  CustomTileSource* = ref object of MapSource

type
  MapLayer* = ref object of RootObj
    visible*: bool
    opacity*: float32
    zIndex*: int

  MarkerLayer* = ref object of MapLayer
  HeatmapLayer* = ref object of MapLayer
  VectorLayer* = ref object of MapLayer


# Clustering
proc clusterMarkers*(map: MapWidget) =
  # Group nearby markers at current zoom level

# Geometry
proc drawPolygon*(map: MapWidget, points: seq[MapCoord]) =
  # Draw filled polygon on map

# Custom Controls
type MapControls* = object
  enableZoom*: bool
  enablePan*: bool
  enableRotation*: bool
  customButtons*: seq[MapButton]
