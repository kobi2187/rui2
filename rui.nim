## RUI2 - Reactive UI Framework
##
## Main module that exports the complete RUI2 API.
## Import this single module to get access to all RUI2 functionality.
##
## Example:
##   import rui
##
##   let app = newApp("My App", 800, 600)
##   # ... use widgets, themes, etc
##   app.run()

# ============================================================================
# Core Framework
# ============================================================================

import core/types
export types

import core/app
export app

import core/link
export link

# ============================================================================
# Event System
# ============================================================================

import managers/event_manager
export event_manager

# ============================================================================
# Drawing & Layout Primitives
# ============================================================================

import drawing_primitives/drawing_primitives
export drawing_primitives

import drawing_primitives/layout_primitives
export layout_primitives

# Note: These have issues and are not actively used:
# - layout_core: circular dependencies with Widget
# - layout_calcs: syntax errors

# ============================================================================
# Theme System
# ============================================================================

import drawing_primitives/theme_sys_core
export theme_sys_core

import drawing_primitives/builtin_themes
export builtin_themes

# ============================================================================
# Widgets - Basic
# ============================================================================

import widgets/basic/label
export label

import widgets/basic/button
export button

import widgets/basic/button_yaml
export button_yaml

# ============================================================================
# Widgets - Input
# ============================================================================

import widgets/input/textinput
export textinput

# ============================================================================
# Widgets - Containers
# ============================================================================

import widgets/containers/hstack
export hstack

import widgets/containers/vstack
export vstack

import widgets/containers/column
export column

# ============================================================================
# Graphics Backend (Raylib)
# ============================================================================

when defined(useGraphics):
  import raylib
  export raylib

# ============================================================================
# Version Info
# ============================================================================

const
  RuiVersionMajor* = 0
  RuiVersionMinor* = 1
  RuiVersionPatch* = 0
  RuiVersion* = "0.1.0"
  RuiAuthor* = "RUI2 Contributors"

proc ruiVersionString*(): string =
  ## Get the RUI2 version string
  result = "RUI2 v" & RuiVersion

# ============================================================================
# Quick Start Template
# ============================================================================

template quickApp*(title: string, width, height: int, body: untyped): untyped =
  ## Quick app template for simple applications
  ##
  ## Example:
  ##   quickApp("My App", 800, 600):
  ##     # Your app setup code here
  ##     let myButton = newButton()
  ##     app.setRootWidget(myButton)

  let app {.inject.} = newApp(title, width, height)
  body
  app.run()
