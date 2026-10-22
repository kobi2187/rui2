## Decorations: something drawn along a widget's outline -- or the window's --
## that can move: lights running round a border, a glow that breathes,
## marching ants.
##
## A decoration is its own object on the overlay layer, not part of the widget
## it is on. It follows the widget (as a focus ring does), repaints only
## itself each frame, and may reach past the widget's edge -- so a button with
## lights round it keeps its own cached picture, and a glow is not clipped.
##
## ```nim
## saveButton.adorn(leds())                       # Christmas lights, running round
## card.adorn(glowPulse(Gold))                    # "look here", breathing
## card.adorn(proc(path: Path, t: float32) =      # anything of your own
##   let p = path.pointAt(t * 80)
##   discard drawSdfBox(Rect(x: p.x - 3, y: p.y - 3, width: 6, height: 6), 3, 0, Pink, Pink))
## app.adornWindow(leds())                        # round the window: a shaped
##                                                # one's traced outline
## ```
##
## The painter gets the path in the decoration's own coordinates and `t`, the
## seconds it has been running. It follows the user's motion preference:
## `reduced` still runs effects (it only stops easing); with `none` a
## decorative effect is not drawn at all and an `informative` one -- one that
## says something, like "this needs you" -- is drawn still. Nothing is drawn
## while its widget is hidden, or on a page frozen behind a modal.

import rui_core
import rui_drawing
import std/[monotimes, times, math, options]
from raylib import Vector2, drawCircle, drawLine

type
  Painter* = proc(path: Path, t: float32) {.closure.}

  Effect* = object
    paint*: Painter
    reach*: float32       ## how far past the outline it draws (a glow's spread)
    informative*: bool    ## says something: shown still, not hidden, with `motion: none`

definePrimitive(Decoration):
  props:
    inset: float32 = 0.0     ## move the path inwards (keep lights inside a hard edge)
    radius: float32 = -1.0   ## corner radius of a widget's outline; < 0: the theme's

  state:
    target: Widget           ## nil: the window
    effect: Effect
    ownPath: Option[Path]    ## the window's outline, in window coordinates
    owner: pointer           ## a window decoration: the App it belongs to
    born: MonoTime

  render:
    let e = widget.effect
    if e.paint == nil: return
    var path: Path
    if widget.ownPath.isSome:
      path = widget.ownPath.get           # the window's: its overlay sits at (0, 0)
    else:
      let r = if widget.radius >= 0: widget.radius
              else: currentTheme.getThemeProps(Default).cornerRadius.get(4.0)
      let m = e.reach + max(0'f32, -widget.inset)   # the margin syncDecorations gave it
      path = rectPath(Rect(x: widget.bounds.x + m, y: widget.bounds.y + m,
                           width: widget.bounds.width - 2 * m,
                           height: widget.bounds.height - 2 * m), r)
    if widget.inset != 0: path = path.inset(widget.inset)
    let moving = effectsAllowed()
    let t = if moving: float32((getMonoTime() - widget.born).inNanoseconds) / 1e9'f32
            else: 0'f32
    e.paint(path, t)
    if moving:
      widget.repaintAfter(1.0 / 60.0)    # the next step; stops when it is hidden

proc margin(d: Decoration): float32 =
  ## How far the decoration's area reaches past its widget: the effect's own
  ## reach, and more if its path is moved outwards (a negative inset).
  d.effect.reach + max(0'f32, -d.inset)

var decorations: seq[Decoration]

proc showing(d: Decoration): bool =
  effectsAllowed() or d.effect.informative

proc rootOf(w: Widget): Widget =
  result = w
  while result.parent != nil: result = result.parent

proc syncDecorations*(owner: pointer, root: Widget, window: Rect) =
  ## Each frame, after layout, for the App `owner` showing `root`: every
  ## decoration on a widget in that tree follows it, and the App's window
  ## decorations cover its window; hidden when there is nothing to see. One
  ## on a widget taken out of the tree is not shown.
  for d in decorations:
    if d.target != nil:
      if root != nil and d.target.rootOf == root:
        d.followWidget(d.target, d.margin, d.showing)
      elif d in overlays():
        hideOverlay(d)
    elif d.owner != owner:
      continue
    elif d.showing:
      if d.bounds != window:
        d.bounds = window
        d.isDirty = true
      if d notin overlays(): showOverlay(d)
    elif d in overlays():
      hideOverlay(d)

proc remove*(d: Decoration) =
  ## Take the decoration away.
  hideOverlay(d)
  let i = decorations.find(d)
  if i >= 0: decorations.delete(i)

proc newDecorationFor(target: Widget, effect: Effect, inset, radius: float32): Decoration =
  result = newDecoration(inset = inset, radius = radius)
  result.target = target
  result.effect = effect
  result.born = getMonoTime()
  decorations.add result
  if target != nil:
    let d = result
    target.disposers.add proc() = d.remove()   # goes with its widget

proc adorn*(target: Widget, effect: Effect, inset = 0.0'f32, radius = -1.0'f32): Decoration {.discardable.} =
  ## Draw `effect` along `target`'s outline (its rounded rectangle) until
  ## `remove`d or the widget goes.
  newDecorationFor(target, effect, inset, radius)

proc adorn*(target: Widget, paint: Painter, reach = 0.0'f32,
            informative = false): Decoration {.discardable.} =
  ## Your own painter along `target`'s outline.
  newDecorationFor(target, Effect(paint: paint, reach: reach, informative: informative), 0, -1)

proc adornPath*(owner: pointer, path: Path, effect: Effect, inset = 0.0'f32): Decoration {.discardable.} =
  ## `effect` along `path`, in window coordinates, over the window of the App
  ## `owner`: what the App's `adornWindow` calls with the window's outline.
  result = newDecorationFor(nil, effect, inset, -1)
  result.ownPath = some(path)
  result.owner = owner

# ----------------------------------------------------------------------------
# Effects
# ----------------------------------------------------------------------------

proc glowDot(p: Point, r: float32, c: Color, glow: float32) =
  ## A round light: a soft halo, then the bulb.
  if glow > 0:
    discard drawSdfShadow(Rect(x: p.x - r, y: p.y - r, width: 2 * r, height: 2 * r), r, 0, 0,
                          glow, 0, Color(r: c.r, g: c.g, b: c.b, a: uint8(c.a.float32 * 0.55)))
  if not drawSdfBox(Rect(x: p.x - r, y: p.y - r, width: 2 * r, height: 2 * r), r, 0, c, c):
    drawCircle(p.x.int32, p.y.int32, r, c)

proc dim(c: Color, k: float32): Color =
  Color(r: uint8(c.r.float32 * k), g: uint8(c.g.float32 * k), b: uint8(c.b.float32 * k), a: c.a)

proc leds*(spacing = 16.0'f32, size = 3.0'f32, speed = 24.0'f32,
           colors = @[Color(r: 230, g: 40, b: 40, a: 255), Color(r: 40, g: 200, b: 70, a: 255),
                      Color(r: 255, g: 200, b: 40, a: 255), Color(r: 60, g: 130, b: 255, a: 255)],
           twinkle = 1.5'f32): Effect =
  ## Christmas lights round the outline: bulbs every `spacing` pixels (evened
  ## out so they meet at the start), creeping along at `speed` px/s, each
  ## brightening and fading `twinkle` times a second, the colours in turn.
  Effect(reach: size * 3, paint: proc(path: Path, t: float32) =
    let total = path.length
    if total <= 0: return
    let n = max(1, int(total / spacing))
    let gap = total / n.float32
    for i in 0 ..< n:
      let p = path.pointAt(i.float32 * gap + t * speed)
      let phase = sin((t * twinkle + i.float32 * 0.37) * 2 * PI)
      let c = colors[i mod colors.len]
      glowDot(p, size, dim(c, 0.65 + 0.35 * phase), size * (1.5 + phase)))

proc glowPulse*(color = Color(r: 255, g: 190, b: 40, a: 255), width = 6.0'f32,
                period = 1.6'f32): Effect =
  ## A soft band along the outline that breathes once every `period` seconds:
  ## "look here". Informative: held at full strength, still, with `motion: none`.
  Effect(reach: width * 2, informative: true, paint: proc(path: Path, t: float32) =
    let strength = if t == 0: 1.0'f32 else: 0.55 + 0.45 * sin(t / period * 2 * PI)
    let a = uint8(110 * strength)
    let step = max(2.0'f32, width / 2)
    var s = 0.0'f32
    while s < path.length:
      let p = path.pointAt(s)
      discard drawSdfShadow(Rect(x: p.x - 2, y: p.y - 2, width: 4, height: 4), 2, 0, 0,
                            width, 0, Color(r: color.r, g: color.g, b: color.b, a: a))
      s += step)

proc marchingAnts*(color = Color(r: 20, g: 20, b: 20, a: 255), dash = 6.0'f32,
                   gap = 4.0'f32, speed = 30.0'f32, width = 1.5'f32): Effect =
  ## A dashed line walking round the outline: a selection, a drop target.
  ## Informative: shown still with `motion: none`.
  Effect(reach: width, informative: true, paint: proc(path: Path, t: float32) =
    let period = dash + gap
    var s = (t * speed) mod period - period
    while s < path.length:
      # each dash in short pieces, so it bends round corners
      var a = max(s, 0'f32)
      let stop = min(s + dash, path.length)
      while a < stop:
        let b = min(a + 3, stop)
        let p = path.pointAt(a)
        let q = path.pointAt(b)
        if not drawSdfSegment(Vector2(x: p.x, y: p.y), Vector2(x: q.x, y: q.y), width, color):
          drawLine(Vector2(x: p.x, y: p.y), Vector2(x: q.x, y: q.y), width, color)
        a = b
      s += period)
