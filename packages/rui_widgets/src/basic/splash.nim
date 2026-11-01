## Splash -- what the window shows while the app gets ready: a logo, a name,
## and how far along it is.
##
## ```nim
## var splash: Splash
## let root = ui:
##   Stack(fit = StackFit.expand):
##     mainPage()                                  # the app, built at once
##     splash = Splash(title = "Atlas", subtitle = "Loading maps...",
##                     logoPath = "logo.png")
## runInBackground(proc(): Maps = loadMaps(),     # the slow part, off the UI thread
##                 proc(m: Maps) = (showMaps(m); splash.finish()))
## ```
##
## It covers the window and takes every press and key while it is up, so
## nothing underneath is touched half-ready. `progress` from 0 to 1 shows a
## bar (set it as work goes, from a Mailbox for a thread of your own); below 0
## it shows a turning arc instead. `message` says what is happening.
## `finish()` fades it away (at once with motion reduced or none) and calls
## `onDone`; then it is hidden and out of the way.

import rui_core
import rui_drawing
import ../dialogs/modal        # ModalLayer: above the page, as a dialog is
import std/[options, monotimes, times, math]
import raylib

proc fadeLeft*(sinceFinish, seconds: float): float32 =
  ## How much of the splash still shows, `sinceFinish` seconds into a fade of
  ## `seconds`: 1 down to 0.
  if seconds <= 0: return 0
  float32(clamp(1 - sinceFinish / seconds, 0.0, 1.0))

definePrimitive(Splash):
  props:
    title: string = ""
    subtitle: string = ""
    logoPath: string = ""
    message: string = ""
    progress: float32 = -1.0       ## 0 .. 1 for a bar; below 0 an arc that turns
    fadeSeconds: float32 = 0.35
    intent: ThemeIntent = Default

  state:
    born: MonoTime
    finishing: bool
    finishedAt: MonoTime
    tookFocus: bool

  actions:
    onDone()

  init:
    widget.born = getMonoTime()
    widget.focusable = true         # so it takes the keys while it is up
    widget.hitLayer = ModalLayer    # above the page: the app underneath, nested
                                    # deeper, would otherwise win every press

  events:
    on_event:
      return widget.visible         # nothing reaches the app until it is gone

  layout:
    if not widget.tookFocus and widget.visible:
      widget.tookFocus = true
      wantFocus(widget)             # the keys too, once, as it appears
    if widget.finishing:
      let left = if easingAllowed():
                   fadeLeft(float((getMonoTime() - widget.finishedAt).inMilliseconds) / 1000,
                            widget.fadeSeconds)
                 else: 0'f32
      if left <= 0:
        widget.visible = false
        widget.finishing = false
        # Hidden, it is skipped by layout: the parent asks for the pass that
        # takes it out of the hit-test tree (as modal.closeModal).
        if widget.parent != nil: widget.parent.layoutDirty = true
        widget.markDirtyToRoot()
        if widget.onDone != nil: widget.onDone()
      else:
        widget.repaintAfter(1.0 / 60.0, relayout = true)   # the next step of the fade

  render:
    let props = currentTheme.getThemeProps(widget.intent, Normal)
    let a = if widget.finishing and easingAllowed():
              fadeLeft(float((getMonoTime() - widget.finishedAt).inMilliseconds) / 1000,
                       widget.fadeSeconds)
            else: 1'f32
    proc fade(c: Color): Color = c.withAlpha(float32(c.a) / 255 * a)
    let b = widget.bounds
    let ink = props.foregroundColor.get(BLACK)
    let accent = props.activeColor.get(ink)
    drawRect(b, fade(currentTheme.canvasColor()))
    var y = b.y + b.height * 0.32
    let cx = b.x + b.width / 2
    let tex = textureFor(widget.logoPath)
    if tex != nil:
      let side = min(96'f32, b.height * 0.2)
      let w = tex[].width.float32
      let h = tex[].height.float32
      let s = side / max(w, h)
      drawTexture(tex[], Rectangle(x: 0, y: 0, width: w, height: h),
                  Rectangle(x: cx - w * s / 2, y: y - h * s, width: w * s, height: h * s),
                  Vector2(x: 0, y: 0), 0, fade(WHITE))
      y += 16
    if widget.title.len > 0:
      let t = props.headingStyle(fade(ink), 2)      # a heading: twice the theme's text
      drawStyledText(widget.title, cx, y, t, centered = true)
      y += t.fontSize * 1.4
    if widget.subtitle.len > 0:
      let s = props.captionStyle(fade(ink.withAlpha(0.7)))
      drawStyledText(widget.subtitle, cx, y, s, centered = true)
      y += s.fontSize * 1.6
    y += 12
    if widget.progress >= 0:
      let bar = Rect(x: cx - 120, y: y, width: 240, height: 6)
      drawBox(bar, 3, fade(ink.withAlpha(0.12)), fade(ink.withAlpha(0.12)), 0)
      let p = clamp(widget.progress, 0, 1)
      if p > 0:
        drawBox(Rect(x: bar.x, y: bar.y, width: bar.width * p, height: bar.height), 3,
                fade(accent), fade(accent), 0)
      y += 18
    else:
      # A quarter arc going round; still (a full faint ring) when motion is none.
      let r = 14'f32
      let c = Vector2(x: cx, y: y + r)
      drawRing(c, r - 3, r, 0, 360, 48, fade(ink.withAlpha(0.12)))
      if effectsAllowed():
        let turn = float32((getMonoTime() - widget.born).inMilliseconds mod 1000) / 1000 * 360
        drawRing(c, r - 3, r, turn, turn + 90, 24, fade(accent))
      y += 2 * r + 10
    if widget.message.len > 0:
      var m = props.captionStyle(fade(ink.withAlpha(0.6)))
      m.fontSize = max(10'f32, m.fontSize - 2)
      drawStyledText(widget.message, cx, y, m, centered = true)
    # The arc keeps turning (the fade's steps come from layout).
    if not widget.finishing and widget.progress < 0 and effectsAllowed():
      widget.repaintAfter(1.0 / 60.0)

proc finish*(widget: Splash) =
  ## The app is ready: fade the splash away, then hide it and call `onDone`.
  if widget.finishing or not widget.visible: return
  widget.finishing = true
  widget.finishedAt = getMonoTime()
  widget.layoutDirty = true
  widget.markDirtyToRoot()
