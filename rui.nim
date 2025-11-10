## RUI2 - Reactive UI Framework
##
## Simple, explicit, non-magic API for building reactive UIs.
##
## Standard app structure:
##   import rui
##
##   # 1. Define your app state (store)
##   type AppStore = object
##     counter: Link[int]
##     message: Link[string]
##
##   var store = AppStore(
##     counter: newLink(0),
##     message: newLink("Hello")
##   )
##
##   # 2. Define your widget tree
##   proc buildUI(): Widget =
##     VStack(spacing = 10):
##       Label(text = store.message.get())
##       Button(text = "Click", onClick = proc() =
##         store.counter.set(store.counter.get() + 1)
##       )
##
##   # 3. Create app and run
##   let app = newApp("My App", 800, 600)
##   app.setRootWidget(buildUI())
##   app.run()

# ============================================================================
# Core Framework - The Essentials
# ============================================================================

# Types: Widget, Store, Theme, etc.
import core/types
export types

# App: Main application object and loop
import core/app
export app

# Link[T]: Reactive state primitive
import core/link
export link

# Widget DSL v2: definePrimitive, defineWidget macros
import core/widget_dsl_v2
export widget_dsl_v2

# ============================================================================
# Event System
# ============================================================================

import managers/event_manager
export event_manager

# ============================================================================
# Drawing Primitives
# ============================================================================

import drawing_primitives/drawing_primitives
export drawing_primitives

import drawing_primitives/primitives/text_cache
export text_cache

# ============================================================================
# Theme System
# ============================================================================

import drawing_primitives/theme_sys_core
export theme_sys_core

import drawing_primitives/builtin_themes
export builtin_themes

# ============================================================================
# Widgets - Import the new DSL v2 widgets
# ============================================================================

# Note: Old widgets (button.nim, label.nim, etc.) use the old DSL.
# New widgets use DSL v2 and are in specific subdirectories.
# Users can create their own widgets using definePrimitive/defineWidget.

# Basic widgets
import widgets/basic/checkbox
export checkbox

import widgets/basic/radiobutton
export radiobutton

import widgets/basic/slider
export slider

import widgets/basic/progressbar
export progressbar

import widgets/basic/image
export image

# Containers
import widgets/containers/vstack
export vstack

import widgets/containers/hstack
export hstack

# Add more v2 widgets as needed...

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
  RuiVersionMinor* = 2
  RuiVersionPatch* = 0
  RuiVersion* = "0.2.0"
  RuiAuthor* = "RUI2 Contributors"

proc ruiVersionString*(): string =
  ## Get the RUI2 version string
  "RUI2 v" & RuiVersion

# ============================================================================
# App Lifecycle Helper
# ============================================================================

proc start*(app: App) =
  ## Start the application main loop
  ## Alias for app.run() for cleaner API
  app.run()

# ============================================================================
# Usage Example (documentation)
# ============================================================================

when false:
  # This is example code showing the recommended app structure

  # 1. Define store (reactive state)
  type MyStore = object
    count: Link[int]
    name: Link[string]

  var store = MyStore(
    count: newLink(0),
    name: newLink("World")
  )

  # 2. Define widget tree (can use procs/functions)
  proc buildCounter(): Widget =
    VStack(spacing = 10):
      Label(text = &"Count: {store.count.get()}")
      Button(
        text = "Increment",
        onClick = proc() = store.count.set(store.count.get() + 1)
      )

  # 3. Create app, set root, and start
  let app = newApp("Counter App", 400, 300)
  app.setRootWidget(buildCounter())
  app.start()  # or app.run()
