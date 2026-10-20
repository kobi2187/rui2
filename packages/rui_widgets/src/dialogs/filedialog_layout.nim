## What a file dialog is for, and what its parts say.
##
## Split out of filedialog.nim so the words and the mode can be tested and
## reused without building the dialog.

import std/[os, strutils]

type
  FileDialogMode* = enum
    fdOpen              # Open existing files
    fdSave              # Save a file (a new name is allowed)
    fdDirectory         # Choose directories

const
  ChosenPaneWidth* = 250.0'f32   ## the "Chosen" pane, open
  FooterHeight* = 34.0'f32

proc okLabelFor*(mode: FileDialogMode, chosen = 0): string =
  ## The affirmative button says what it will do -- and, once files are
  ## chosen, how many: "Open (3)". That is the difference between a dialog you
  ## can use without reading the title bar and one you cannot.
  result = case mode
           of fdOpen: "Open"
           of fdSave: "Save"
           of fdDirectory: "Select"
  if chosen > 0: result &= " (" & $chosen & ")"

proc chosenLabel*(path: string): string =
  ## A row of the Chosen pane: the name first, then the folder it came from --
  ## enough to tell two "notes.md" apart without the whole path.
  let dir = path.parentDir.lastPathPart
  let name = path.lastPathPart
  if dir.len > 0: name & "  —  " & dir else: name

proc asLines*(paths: seq[string]): string =
  ## The answer as text: one path per line, in the order they were chosen.
  paths.join("\n")
