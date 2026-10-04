## What the keyboard help overlay says: the bindings in force, as plain text.
##
## Built from the user's actual KeyMap -- if they rebound Tab to F6, that is
## what the overlay shows -- plus whatever shortcuts the application adds.
## Pure, so the wording and the grouping are checkable without a window.

import std/strutils
import raylib
import types
import key_map

type
  HelpEntry* = tuple[keys, text: string]

  HelpSection* = object
    title*: string
    entries*: seq[HelpEntry]

const actionText*: array[NavAction, string] = [
  nextInGroup: "Next widget in the container",
  prevInGroup: "Previous widget in the container",
  leaveGroup: "Leave the container",
  nextGroup: "Next container",
  prevGroup: "Previous container",
  showHelp: "Show this help"]

proc display*(c: Chord): string =
  ## How a chord reads to a person: the chord itself, except that Shift+Slash
  ## is the "?" it types.
  if c.key == KeyboardKey.Slash and c.mods == {kmShift}: "?" else: $c

proc keysText*(map: KeyMap, action: NavAction): string =
  ## "Tab / F6" -- every chord bound to the action, or "(unbound)".
  var parts: seq[string]
  for c in map.bindings[action]:
    parts.add c.display
  if parts.len == 0: "(unbound)" else: parts.join(" / ")

proc helpSections*(map: KeyMap, extra: seq[HelpEntry] = @[]): seq[HelpSection] =
  ## The navigation keys, in the order a person reaches for them, then the
  ## application's own shortcuts if it registered any.
  var nav = HelpSection(title: "Moving around")
  for action in [nextGroup, prevGroup, nextInGroup, prevInGroup, leaveGroup]:
    nav.entries.add (map.keysText(action), actionText[action])
  result.add nav
  if extra.len > 0:
    result.add HelpSection(title: "This application", entries: extra)
  result.add HelpSection(title: "Help",
    entries: @[(map.keysText(showHelp), actionText[showHelp] & " (any key closes it)")])
