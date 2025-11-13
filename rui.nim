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

# Widget DSL v3: definePrimitive, defineWidget macros (cleaner, modular)
import core/widget_dsl_v3
export widget_dsl_v3

# ============================================================================
# Event System
# ============================================================================

import managers/event_manager_refactored
export event_manager_refactored

# ============================================================================
# Drawing Primitives
# ============================================================================

import drawing_primitives/drawing_primitives
export drawing_primitives

import drawing_primitives/widget_primitives
export widget_primitives

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
# Widgets - Layered Import
# ============================================================================

# Primitives (drawing widgets)
import widgets/primitives
export primitives

# Basic widgets
import widgets/basic
export basic

# Containers
import widgets/containers
export containers

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

when defined(useGraphics):
  proc start*(application: App) =
    ## Start the application main loop
    ## Alias for app.run() for cleaner API
    application.run()
else:
  proc start*(application: App, frames: int = -1) =
    ## Start the application main loop (headless mode)
    ## Alias for app.runHeadless() for cleaner API
    application.runHeadless(frames)

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
