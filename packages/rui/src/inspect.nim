## What a test can ask about the framework, as opposed to about the UI.
##
## The public scripting verbs -- read, write, invoke -- address a control and
## operate it. They answer questions an application's own logic might ask.
##
## These answer questions only a test asks: where a widget actually ends up on
## screen once clipping is applied, which frame it last repainted on, what sits
## under a point, the shape of the tree. An application has no use for any of
## it, so it is gated behind `-d:ruiInspect` and wired in `enableScripting`
## exactly as key injection is.
##
## ## Why text rather than a screenshot
##
## The harness already captures a screenshot, and for appearance -- a wrong
## colour, an upside-down composite, a font that failed to load -- a picture is
## the honest answer and no amount of JSON substitutes for it.
##
## Structure and geometry are the other way round. `visible` was pixel-checked
## by sampling columns across a scrollbar gutter and reasoning about the
## numbers; `render` cannot be checked from a picture at all, because a frame
## that repainted the whole tree unnecessarily looks identical to one that did
## not.
##
## So: text carries structure and geometry, pixels carry appearance.

import rui_core
import rui_hittest
import std/[json, options, strutils]

# ---------------------------------------------------------------------------
# Effective visibility
# ---------------------------------------------------------------------------

proc label(widget: Widget): string =
  ## How a widget is named in a report: its scripting id when it has one, its
  ## type otherwise. Most primitives inside a composite have no id.
  if widget.stringId.len > 0: widget.stringId else: widget.getTypeName()


proc absoluteClip(widget: Widget): Option[Rect] =
  ## A widget's own childClip in screen coordinates. Stored widget-local,
  ## because renderPass zeroes bounds.x/y while compositing.
  if widget.childClip.isNone:
    return none(Rect)
  let clip = widget.childClip.get()
  some(Rect(x: widget.bounds.x + clip.x, y: widget.bounds.y + clip.y,
            width: clip.width, height: clip.height))

proc clippingAncestor*(widget: Widget): Widget =
  ## The nearest ancestor whose childClip actually cuts this widget down, or
  ## nil. Names the culprit, so a test that finds a row invisible is told it is
  ## the ScrollView doing it rather than left to work that out.
  var w = widget.parent
  var remaining = widget.bounds
  while w != nil:
    let clip = w.absoluteClip
    if clip.isSome:
      let narrowed = intersect(remaining, clip.get())
      if narrowed != remaining:
        return w
      remaining = narrowed
    w = w.parent
  nil

proc visibleRect*(widget: Widget): Rect =
  ## Where this widget actually lands on screen, after every ancestor's clip.
  ##
  ## A zero-sized result means genuinely not visible. This is the number
  ## `visible` sounds like it reports and does not: that field is a flag, and
  ## it stays true for a row scrolled out of a viewport, a widget behind an
  ## overlay, or one sitting off the edge of the window.
  result = widget.bounds
  var w = widget.parent
  while w != nil:
    let clip = w.absoluteClip
    if clip.isSome:
      result = intersect(result, clip.get())
    w = w.parent

proc isShowing*(widget: Widget): bool =
  ## Visible in the sense a person means it: flagged visible, enabled ancestors
  ## aside, and with somewhere on screen left after clipping.
  if not widget.visible:
    return false
  let r = widget.visibleRect
  r.width > 0 and r.height > 0

proc inspectVisible*(widget: Widget): JsonNode =
  let seen = widget.visibleRect
  let culprit = widget.clippingAncestor
  result = %*{
    "id": widget.stringId,
    "visibleFlag": widget.visible,
    "showing": widget.isShowing,
    "bounds": {"x": widget.bounds.x, "y": widget.bounds.y,
               "width": widget.bounds.width, "height": widget.bounds.height},
    "visibleRect": {"x": seen.x, "y": seen.y,
                    "width": seen.width, "height": seen.height},
    "fullyVisible": seen == widget.bounds
  }
  result["clippedBy"] = if culprit == nil: newJNull() else: %culprit.label

# ---------------------------------------------------------------------------
# What is under a point
# ---------------------------------------------------------------------------

proc focusTargetOf(widget: Widget): Widget =
  ## Where a click on this widget would actually put the focus -- the same
  ## outward walk event_routing does.
  var w = widget
  while w != nil:
    if w.focusable and w.visible and w.enabled:
      return w
    w = w.parent
  nil

proc bubbleChain*(widget: Widget): seq[string] =
  ## The widget and each ancestor, innermost first -- the order an event is
  ## offered to them.
  var w = widget
  while w != nil:
    result.add(w.label)
    w = w.parent

proc inspectHit*(hitTest: HitTestSystem, x, y: float32): JsonNode =
  ## What a click here would land on, and where it would bubble.
  ##
  ## Hit-testing lands on the innermost primitive, which is rarely the widget a
  ## test means -- a click on a Button lands on its Rectangle. Seeing the chain
  ## is what makes that obvious rather than surprising, and it is how the
  ## focus-target bug would have been spotted directly.
  var system = hitTest
  let widget = system.getWidgetAt(x, y)
  if widget == nil:
    return %*{"at": {"x": x, "y": y}, "hit": newJNull(), "chain": newJArray()}

  let focusTarget = widget.focusTargetOf
  %*{
    "at": {"x": x, "y": y},
    "hit": widget.label,
    "type": widget.getTypeName(),
    "chain": widget.bubbleChain,
    "focusTarget": (if focusTarget == nil: newJNull() else: %focusTarget.label)
  }

# ---------------------------------------------------------------------------
# The shape of the tree
# ---------------------------------------------------------------------------

proc flagNames(widget: Widget): seq[string] =
  ## The flags worth seeing in a diff. Only the ones that are set, so a line
  ## stays short and a change stands out -- `hidden` and `disabled` are the
  ## absence of a flag for the same reason.
  let flags = {
    "hidden": not widget.visible,
    "disabled": not widget.enabled,
    "focused": widget.focused,
    "tabstop": widget.focusable,
    "group": widget.focusGroup,
  }
  for (name, isSet) in flags:
    if isSet:
      result.add(name)

proc describe(widget: Widget): string =
  ## One widget, on one line: type, id, bounds, and the flags worth diffing.
  let id = if widget.stringId.len > 0: widget.stringId else: "-"
  let seen = widget.visibleRect
  result = widget.getTypeName() & " " & id &
    " @" & $int(widget.bounds.x) & "," & $int(widget.bounds.y) &
    " " & $int(widget.bounds.width) & "x" & $int(widget.bounds.height)
  if seen != widget.bounds:
    result.add(" clipped=" & $int(seen.width) & "x" & $int(seen.height))
  for flag in widget.flagNames:
    result.add(" " & flag)

proc appendTree(widget: Widget, depth: int, dest: var string) =
  dest.add(repeat("  ", depth))
  dest.add(widget.describe)
  dest.add("\n")
  for child in widget.children:
    appendTree(child, depth + 1, dest)

proc inspectTree*(root: Widget): string =
  ## The whole hierarchy in one round trip, in a stable order.
  ##
  ## Wildcard selectors can walk the tree already, but at one command per
  ## query. The point of a single dump is that it diffs: snapshot it, act,
  ## snapshot again, and the diff names the widget that moved instead of
  ## leaving you to find the changed pixels.
  if root == nil:
    return ""
  appendTree(root, 0, result)
