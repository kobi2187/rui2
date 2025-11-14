## CSS-like Selector System
##
## Implements path-based widget selection with wildcards.
## Supports patterns like:
##   "buttonId"              - Direct ID lookup
##   "window/form/button"    - Path traversal
##   "form/*"                - All direct children
##   "form/**"               - All descendants
##   "*/buttonId"            - Any parent with this child

import std/[strutils, sequtils, options]
import ../core/types

# ============================================================================
# Path Segment Types
# ============================================================================

type
  SegmentKind* = enum
    skId          # Specific ID: "loginButton"
    skWildcard    # Single level wildcard: "*"
    skDeepWildcard  # Multi-level wildcard: "**"
    skType        # Type name: "Button" (future)

  PathSegment* = object
    kind*: SegmentKind
    value*: string

  ParsedPath* = object
    segments*: seq[PathSegment]

# ============================================================================
# Path Parsing
# ============================================================================

proc parsePathSegment(s: string): PathSegment =
  ## Parse a single path segment
  if s == "*":
    return PathSegment(kind: skWildcard, value: "")
  elif s == "**":
    return PathSegment(kind: skDeepWildcard, value: "")
  elif s.len > 0 and s[0].isUpperAscii():
    # Starts with uppercase - treat as type name (future feature)
    return PathSegment(kind: skType, value: s)
  else:
    # Regular ID
    return PathSegment(kind: skId, value: s)

proc parsePath*(path: string): ParsedPath =
  ## Parse a path string into segments
  ## Examples:
  ##   "button" -> [skId("button")]
  ##   "window/form/button" -> [skId("window"), skId("form"), skId("button")]
  ##   "form/*" -> [skId("form"), skWildcard]
  ##   "form/**" -> [skId("form"), skDeepWildcard]

  result.segments = @[]

  if path.len == 0:
    return

  let parts = path.split('/')
  for part in parts:
    if part.len > 0:  # Skip empty parts
      result.segments.add(parsePathSegment(part))

# ============================================================================
# Widget Matching
# ============================================================================

proc matchesSegment(widget: Widget, segment: PathSegment): bool =
  ## Check if widget matches a single path segment
  case segment.kind
  of skWildcard, skDeepWildcard:
    return true  # Wildcard matches anything
  of skId:
    return widget.stringId == segment.value
  of skType:
    # TODO: Implement type matching
    # For now, just return false
    return false

proc findChildrenMatching(widget: Widget, segment: PathSegment): seq[Widget] =
  ## Find all direct children matching segment
  result = @[]
  for child in widget.children:
    if child.matchesSegment(segment):
      result.add(child)

proc findDescendantsMatching(widget: Widget, segment: PathSegment): seq[Widget] =
  ## Find all descendants (recursive) matching segment
  result = @[]

  # Check direct children
  for child in widget.children:
    if child.matchesSegment(segment):
      result.add(child)

    # Recurse into children
    result.add(child.findDescendantsMatching(segment))

# ============================================================================
# Path Resolution
# ============================================================================

proc resolvePathFrom(widget: Widget, segments: seq[PathSegment],
                    startIdx: int): seq[Widget] =
  ## Resolve path starting from a widget
  ## Recursive implementation

  if startIdx >= segments.len:
    # End of path - return current widget
    return @[widget]

  let segment = segments[startIdx]

  case segment.kind
  of skId:
    # Look for child with specific ID
    let matches = widget.findChildrenMatching(segment)
    if matches.len == 0:
      return @[]
    # Continue path from each match
    result = @[]
    for match in matches:
      result.add(resolvePathFrom(match, segments, startIdx + 1))

  of skWildcard:
    # Match all direct children
    result = @[]
    for child in widget.children:
      result.add(resolvePathFrom(child, segments, startIdx + 1))

  of skDeepWildcard:
    # Match all descendants
    # This is tricky - ** can match zero or more levels
    result = @[]

    # Option 1: Match zero levels (skip this segment)
    result.add(resolvePathFrom(widget, segments, startIdx + 1))

    # Option 2: Match one or more levels
    for child in widget.children:
      # Try continuing from this child (with ** still active)
      result.add(resolvePathFrom(child, segments, startIdx))

  of skType:
    # TODO: Implement type matching
    result = @[]

proc resolvePath*(root: Widget, path: string): seq[Widget] =
  ## Resolve a path from root widget
  ## Returns all widgets matching the path

  let parsed = parsePath(path)

  if parsed.segments.len == 0:
    return @[]

  # Special case: if first segment is not a wildcard, try direct ID lookup first
  if parsed.segments[0].kind == skId and parsed.segments.len == 1:
    # Simple ID lookup
    if root.stringId == parsed.segments[0].value:
      return @[root]

    # Search children recursively for single ID
    return root.findDescendantsMatching(parsed.segments[0])

  # Full path resolution
  return resolvePathFrom(root, parsed.segments, 0)

proc resolvePathInTree*(tree: WidgetTree, path: string): seq[Widget] =
  ## Resolve a path in a widget tree
  ## This is the main entry point for path resolution

  # Try direct stringId lookup first (optimization)
  if tree.widgetsByStringId.hasKey(path):
    return @[tree.widgetsByStringId[path]]

  # Otherwise, resolve path from root
  if tree.root.isNil:
    return @[]

  return resolvePath(tree.root, path)

# ============================================================================
# Convenience Functions
# ============================================================================

proc findWidget*(tree: WidgetTree, path: string): Option[Widget] =
  ## Find a single widget by path
  ## Returns the first match, or None if not found
  let matches = resolvePathInTree(tree, path)
  if matches.len > 0:
    return some(matches[0])
  return none(Widget)

proc findWidgets*(tree: WidgetTree, path: string): seq[Widget] =
  ## Find all widgets matching path
  ## Returns empty seq if none found
  return resolvePathInTree(tree, path)

proc hasWidget*(tree: WidgetTree, path: string): bool =
  ## Check if any widget matches path
  return findWidget(tree, path).isSome

# ============================================================================
# Query Helpers
# ============================================================================

proc getWidgetById*(tree: WidgetTree, id: string): Option[Widget] =
  ## Get widget by exact string ID (fast lookup)
  if tree.widgetsByStringId.hasKey(id):
    return some(tree.widgetsByStringId[id])
  return none(Widget)

proc getAllChildren*(widget: Widget): seq[Widget] =
  ## Get all children recursively
  result = widget.children
  for child in widget.children:
    result.add(child.getAllChildren())

proc getChildrenWithId*(widget: Widget, id: string): seq[Widget] =
  ## Find all descendants with specific ID
  result = @[]
  for child in widget.children:
    if child.stringId == id:
      result.add(child)
    result.add(child.getChildrenWithId(id))
