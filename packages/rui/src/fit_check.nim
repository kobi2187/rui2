## Does the UI fit the screen? A laid-out tree, checked for what goes wrong
## when a screen is smaller (or shaped differently) than the one it was
## designed on -- the question a phone's many sizes ask.
##
## - **offscreen**: part of a widget lies outside the screen, and no scroll
##   view or clip is there to own that part (so the user can never see it).
## - **overflow**: a widget sticks out of its parent (Flutter's "RenderFlex
##   overflowed by N pixels"): drawn over its neighbours or cut by an edge.
## - **cut**: a label or button has less room than its text needs, so the
##   text is cut off (a wrapping label: fewer lines than it needs).
## - **sideways**: a scroll view's content is wider than the view, so a list
##   meant to scroll down scrolls sideways too (on a phone, nearly always a
##   mistake: `ScrollView(wrapToWidth = true)` lays it out at the view's width).
## - **small target** (a warning): something to tap is under `touchTarget`
##   pixels on a side (44: Apple's minimum; Material asks 48).
##
## Each problem is reported once, at the widget where it starts, not again for
## everything inside it. Pure apart from measuring (which some widgets do by
## laying out): the geometry it disturbs is put back.
##
## `RUI_FIT_CHECK=<file>` makes an app write this for its first layout and
## exit; `RUI_WINDOW_SIZE=WxH` sets the screen. `tools/fit_check.sh` runs an
## app through a list of phones that way.

import rui_core
import rui_widgets
import inspect
import std/[json, strutils, options, math]

type
  FitKind* = enum
    fkOffscreen = "offscreen"
    fkOverflow = "overflow"
    fkCut = "cut"
    fkSideways = "sideways"
    fkSmallTarget = "small-target"

  FitIssue* = object
    kind*: FitKind
    path*: string          ## where in the tree: Column/Row[2]/Button "save"
    rect*: Rect            ## the widget's rect, in window coordinates
    by*: float32           ## how far over (offscreen, overflow) or short (cut, small)
    detail*: string

proc isError*(i: FitIssue): bool = i.kind != fkSmallTarget

proc name(w: Widget): string =
  result = w.getTypeName()
  if w.stringId.len > 0: result.add " \"" & w.stringId & "\""

proc beyond(inner, outer: Rect): float32 =
  ## How far `inner` reaches past `outer`, on its worst side (0 if inside).
  max(max(outer.x - inner.x, (inner.x + inner.width) - (outer.x + outer.width)),
      max(outer.y - inner.y, (inner.y + inner.height) - (outer.y + outer.height))).max(0'f32)

proc sides(inner, outer: Rect): string =
  ## Which sides `inner` crosses.
  var s: seq[string]
  if inner.x < outer.x - 0.5: s.add "left"
  if inner.x + inner.width > outer.x + outer.width + 0.5: s.add "right"
  if inner.y < outer.y - 0.5: s.add "top"
  if inner.y + inner.height > outer.y + outer.height + 0.5: s.add "bottom"
  s.join(", ")

type Saved = seq[tuple[w: Widget, bounds: Rect, ownW, ownH: float32]]

proc save(w: Widget, into: var Saved) =
  into.add (w, w.bounds, w.ownWidth, w.ownHeight)
  for c in w.children: save(c, into)

proc restore(saved: Saved) =
  for s in saved:
    s.w.bounds = s.bounds
    s.w.ownWidth = s.ownW
    s.w.ownHeight = s.ownH

proc needs(w: Widget, c: Constraints): Size =
  ## What `w` would like within `c`, without disturbing the laid-out tree.
  var saved: Saved
  save(w, saved)
  result = w.measure(c)
  restore(saved)

proc cutText(w: Widget): Option[(float32, string)] =
  ## A label or button with less room than its text needs.
  let b = w.bounds
  if w of TextArea:
    let t = TextArea(w)
    if t.editable or t.text.len == 0: return
    if not t.wrap:
      let need = w.needs(unbounded())
      if need.width > b.width + 1:
        return some((need.width - b.width, "text needs " & $int(need.width) &
                     " px, has " & $int(b.width)))
    else:
      let need = w.needs(unbounded().withWidth(b.width))
      if need.height > b.height + 1:
        return some((need.height - b.height, "wrapped text needs " & $int(need.height) &
                     " px of height, has " & $int(b.height)))
  elif w of Button:
    let need = w.needs(unbounded())
    if need.width > b.width + 1:
      return some((need.width - b.width, "caption needs " & $int(need.width) &
                   " px, has " & $int(b.width)))

proc fitIssues*(root: Widget, window: Rect, touchTarget = 44.0'f32): seq[FitIssue] =
  ## Everything about `root`, laid out in `window`, that does not fit.
  var issues: seq[FitIssue]
  proc walk(w: Widget, path: string, overReported: bool) =
    if not w.visible: return                 # a hidden page, an offstage child
    let here = path & (if path.len > 0: "/" else: "") & w.name
    var reported = overReported
    let seen = w.visibleRect                 # after scroll views and clips
    if seen.width <= 0 or seen.height <= 0:
      return                                 # scrolled or clipped out of view: fine
    if not reported and not w.floating:
      let off = beyond(seen, window)
      if off > 0.5:
        issues.add FitIssue(kind: fkOffscreen, path: here, rect: w.bounds, by: off,
                            detail: "past the screen's " & sides(seen, window) & " edge by " &
                                    $int(ceil(off)) & " px")
        reported = true
      elif w.parent != nil and w.parent.childClip.isNone:
        let over = beyond(w.bounds, w.parent.bounds)
        if over > 0.5:
          issues.add FitIssue(kind: fkOverflow, path: here, rect: w.bounds, by: over,
                              detail: "sticks out of its " & w.parent.getTypeName() & " (" &
                                      sides(w.bounds, w.parent.bounds) & ") by " &
                                      $int(ceil(over)) & " px")
          reported = true
    if w of ScrollView:
      let sv = ScrollView(w)
      let inner = scrollBarsFor(sv.extent).innerWidth
      if sv.contentWidth > inner + 0.5:
        issues.add FitIssue(kind: fkSideways, path: here, rect: w.bounds,
                            by: sv.contentWidth - inner,
                            detail: "content is " & $int(ceil(sv.contentWidth - inner)) &
                                    " px wider than the view, so it scrolls sideways" &
                                    (if sv.wrapToWidth: "" else: " (wrapToWidth = true fits it)"))
    let cut = w.cutText
    if cut.isSome:
      issues.add FitIssue(kind: fkCut, path: here, rect: w.bounds, by: cut.get[0],
                          detail: cut.get[1])
    if w.focusable and w.enabled and not w.focusGroup and
       (w.bounds.width < touchTarget or w.bounds.height < touchTarget):
      let short = touchTarget - min(w.bounds.width, w.bounds.height)
      issues.add FitIssue(kind: fkSmallTarget, path: here, rect: w.bounds, by: short,
                          detail: $int(w.bounds.width) & "x" & $int(w.bounds.height) &
                                  " px; fingers want " & $int(touchTarget))
    for i, c in w.children:
      walk(c, here & (if w.children.len > 1: "[" & $i & "]" else: ""), reported)
  if root != nil:
    walk(root, "", false)
  issues

proc fitReport*(root: Widget, window: Rect, touchTarget = 44.0'f32): JsonNode =
  ## The issues as JSON, with counts: what RUI_FIT_CHECK writes.
  let issues = fitIssues(root, window, touchTarget)
  var errors, warnings = 0
  var list = newJArray()
  for i in issues:
    if i.isError: inc errors else: inc warnings
    list.add %*{"kind": $i.kind, "path": i.path, "by": i.by, "detail": i.detail,
                "rect": [i.rect.x, i.rect.y, i.rect.width, i.rect.height]}
  %*{"window": [window.width, window.height], "errors": errors,
     "warnings": warnings, "issues": list}
