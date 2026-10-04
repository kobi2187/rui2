## KeyMap: which keys do the keyboard navigation, and how to change them.
##
## Navigation has two axes, each with its own keys:
##
## - **within a container** (a focus group): `nextInGroup` / `prevInGroup`
##   step through its widgets, `leaveGroup` steps out of it;
## - **between containers**: `nextGroup` / `prevGroup` move on to the next
##   or previous stop outside it.
##
## Every action takes any number of key chords, written the way people say
## them -- `"Tab"`, `"Shift+Tab"`, `"Ctrl+PageDown"`, `"J"`:
##
## ```nim
## app.keys.set(nextGroup, "Ctrl+Tab", "F6")     # replace
## app.keys.add(nextInGroup, "J")                # keep the arrows, add vim
## app.keys.add(prevInGroup, "K")
## app.keys.clear(leaveGroup)                    # Escape no longer leaves
## ```
##
## A chord matches exactly: `Tab` does not fire on `Shift+Tab`, so the two can
## be bound to different actions. `conflicts` lists a chord bound twice.
## `keyMapFromJson` reads the same names from a settings file.

import std/[options, strutils, json]
import raylib
import rui_core

type
  NavAction* = enum
    nextInGroup   ## next widget within the current group
    prevInGroup
    leaveGroup    ## step out of the group (one level)
    nextGroup     ## on to the next stop outside the current group
    prevGroup

  Chord* = tuple[key: KeyboardKey, mods: set[KeyMod]]

  KeyMap* = object
    bindings*: array[NavAction, seq[Chord]]

proc chord*(spec: string): Chord =
  ## "Ctrl+Shift+Tab" -> a key and its modifiers. Raises ValueError for a key
  ## or modifier it does not know, naming it.
  let parsed = parseKeyChord(spec)
  if parsed.isNone:
    raise newException(ValueError, "unknown key chord '" & spec &
      "' (write it like Tab, Shift+Tab, Ctrl+PageDown, J)")
  (parsed.get.key, parsed.get.mods)

proc `$`*(c: Chord): string =
  var parts: seq[string]
  if kmCtrl in c.mods: parts.add "Ctrl"
  if kmAlt in c.mods: parts.add "Alt"
  if kmShift in c.mods: parts.add "Shift"
  parts.add $c.key
  parts.join("+")

proc defaultKeyMap*(): KeyMap =
  ## Tab and Shift+Tab between containers; the arrows within one; Escape
  ## leaves it.
  result.bindings[nextGroup] = @[chord("Tab")]
  result.bindings[prevGroup] = @[chord("Shift+Tab")]
  result.bindings[nextInGroup] = @[chord("Down"), chord("Right")]
  result.bindings[prevInGroup] = @[chord("Up"), chord("Left")]
  result.bindings[leaveGroup] = @[chord("Escape")]

proc set*(map: var KeyMap, action: NavAction, specs: varargs[string]) =
  ## Replace what triggers `action`.
  map.bindings[action].setLen(0)
  for s in specs:
    map.bindings[action].add chord(s)

proc add*(map: var KeyMap, action: NavAction, specs: varargs[string]) =
  ## Also trigger `action` from these chords, keeping the existing ones.
  for s in specs:
    let c = chord(s)
    if c notin map.bindings[action]:
      map.bindings[action].add c

proc remove*(map: var KeyMap, action: NavAction, specs: varargs[string]) =
  for s in specs:
    let c = chord(s)
    let i = map.bindings[action].find(c)
    if i >= 0:
      map.bindings[action].delete(i)

proc clear*(map: var KeyMap, action: NavAction) =
  ## Nothing triggers `action` any more.
  map.bindings[action].setLen(0)

proc matches*(map: KeyMap, action: NavAction, key: KeyboardKey,
              mods: set[KeyMod]): bool =
  ## Whether this exact key-and-modifiers triggers `action`.
  for c in map.bindings[action]:
    if c.key == key and c.mods == mods:
      return true

proc matches*(map: KeyMap, action: NavAction, event: GuiEvent): bool =
  map.matches(action, event.key, event.mods)

proc conflicts*(map: KeyMap): seq[string] =
  ## One line for each chord bound to two different actions, e.g.
  ## "Tab is bound to nextGroup and nextInGroup". Empty when it is consistent.
  for a in NavAction:
    for b in NavAction:
      if b <= a: continue
      for c in map.bindings[a]:
        if c in map.bindings[b]:
          result.add $c & " is bound to " & $a & " and " & $b

proc keyMapFromJson*(node: JsonNode, base = defaultKeyMap()): KeyMap =
  ## `{"nextGroup": ["Tab", "Ctrl+Tab"], "prevInGroup": ["Up", "K"]}`.
  ## Actions it names are replaced; the rest keep `base`. An unknown action or
  ## chord is an error that says which.
  result = base
  if node.kind != JObject:
    raise newException(ValueError, "keys must be a mapping of action to chords")
  for name, chords in node:
    var action: NavAction
    var known = false
    for a in NavAction:
      if $a == name:
        action = a
        known = true
    if not known:
      var all: seq[string]
      for a in NavAction: all.add $a
      raise newException(ValueError, "unknown key action '" & name &
        "'; allowed: " & all.join(", "))
    result.bindings[action].setLen(0)
    let list = if chords.kind == JArray: chords.elems else: @[chords]
    for c in list:
      result.bindings[action].add chord(c.getStr)
