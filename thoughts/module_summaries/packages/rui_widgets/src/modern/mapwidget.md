# packages/rui_widgets/src/modern/mapwidget.nim

## Purpose

Interactive geographic view: pan, zoom, markers and a coordinate readout.
**No tile fetching** — it draws a graticule and your markers over a flat
background. Point it at a tile server by drawing tiles before the markers in
`render`.

## Public interface

- `MapCoord*` — `lat` (-90..+90), `lon` (-180..+180).
- `MapMarker*` — `id`, `coord`, `title`, `icon`, `color`, `size`, `data`.
- `MapProjection*` — `mpMercator` (Web Mercator), `mpEquirectangular`.
- `MarkerShape*` — `msCircle`, `msSquare`, `msPin`.
- `MapView*` — the projection, as a plain value.
- `newMapWidget*(initialCenter, initialZoom = 2.0, minZoom = 1.0,
  maxZoom = 18.0, projection = mpMercator, showCoordinates, showZoomControls,
  enablePan, enableZoom, markerShape = msPin, gridLines, intent,
  onZoomChanged, onCenterChanged, onMarkerClick, onMapClick)`.
- `addMarker*(widget, marker)`, `clearMarkers*(widget)`.
- `view*(widget: MapWidget): MapView` and the template `viewOf*(widget)`.
- `worldToScreen*(view, coord): Point`, `screenToWorld*(view, x, y): MapCoord`.
- `zoomInRect*(bounds)`, `zoomOutRect*(bounds)` — the zoom buttons' hit targets.

`initialCenter` and `initialZoom` seed `center` and `zoom` **in the
constructor**, via the DSL's `initial<StateField>` convention — no layout pass
needed, and a `layout`-time seeding block would be dead code.

## Usage pattern

```nim
let map = newMapWidget(initialCenter = MapCoord(lat: 20.0, lon: 0.0),
                       initialZoom = 2.0, maxZoom = 12.0, markerShape = msPin)
map.bounds = Rect(x: 0, y: 0, width: 680, height: 400)
map.addMarker(MapMarker(id: "lon", coord: MapCoord(lat: 51.5074, lon: -0.1278),
                        title: "London", color: red, size: 8.0,
                        data: newJObject()))
map.onMarkerClick = some(proc(marker: MapMarker) {.closure.} = ...)
```

## Circumstances

Restored 2026-09-15 from `a4bcc18`, where the projection was a nested proc
inside `render` and the interaction was polled there.

**Latitude is clamped to ±85.05112878 in Mercator**, because `tan()` diverges
at the poles and an unclamped projection produces an infinity or a NaN that
then propagates into every marker position. `tests/test_restored_widgets.nim`
checks the pole case stays finite.

`MapView` is a separate value for the same reason as Timeline's `TimelineAxis`:
a proc taking `MapWidget` cannot exist before the macro creates the type.
</content>
