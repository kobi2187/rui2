## Modifier keys and key chords.
##
## A GuiEvent carries the modifiers that were held (`mods`), filled by the
## event source. This module is the vocabulary around that: which physical key
## is which modifier, the `shift`/`ctrl` shorthands widgets test with, and
## "Ctrl+Shift+Z"-style chords for scripts and tests.

import std/[strutils, options]
import types
from raylib import KeyboardKey

proc modOf*(key: KeyboardKey): Option[KeyMod] =
  ## The modifier a physical key is, if it is one.
  case key
  of LeftShift, RightShift: some(kmShift)
  of LeftControl, RightControl: some(kmCtrl)
  of LeftAlt, RightAlt: some(kmAlt)
  of LeftSuper, RightSuper: some(kmSuper)
  else: none(KeyMod)

proc shift*(e: GuiEvent): bool = kmShift in e.mods
proc ctrl*(e: GuiEvent): bool = kmCtrl in e.mods
proc alt*(e: GuiEvent): bool = kmAlt in e.mods

proc parseMod(name: string): Option[KeyMod] =
  case name.toLowerAscii()
  of "shift": some(kmShift)
  of "ctrl", "control": some(kmCtrl)
  of "alt": some(kmAlt)
  of "super", "cmd", "meta": some(kmSuper)
  else: none(KeyMod)

proc parseKeyChord*(chord: string): Option[tuple[key: KeyboardKey,
                                                 mods: set[KeyMod]]] =
  ## "Tab", "Shift+Tab", "ctrl+z". The last part is the key, named as in
  ## raylib's KeyboardKey (case-insensitive); the rest are modifiers.
  ## `none` for anything it does not recognise.
  let parts = chord.split('+')
  var mods: set[KeyMod]
  for part in parts[0 ..< ^1]:
    let m = parseMod(part.strip())
    if m.isNone:
      return none(tuple[key: KeyboardKey, mods: set[KeyMod]])
    mods.incl m.get
  let keyName = parts[^1].strip()
  if keyName.len == 0:
    return none(tuple[key: KeyboardKey, mods: set[KeyMod]])
  # parseEnum ignores case and underscores except in the first letter, and
  # KeyboardKey is a holey enum, which rules out iterating it.
  try:
    some((key: parseEnum[KeyboardKey](keyName[0].toUpperAscii & keyName[1..^1]),
          mods: mods))
  except ValueError:
    none(tuple[key: KeyboardKey, mods: set[KeyMod]])
