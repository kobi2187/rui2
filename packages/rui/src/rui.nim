## RUI2 - Reactive UI Framework
##
## Umbrella package: re-exports every RUI2 subsystem and provides the
## application entry point. Each subsystem is also usable on its own:
##   rui_core, rui_hittest, rui_events, rui_drawing, rui_scripting, rui_widgets
##
## Quick start:
##   import rui
##
##   let app = newApp("My App", 800, 600)
##   app.setRootWidget(buildUI())
##   app.run()

import rui_core;      export rui_core       # types, Link[T], two-pass loop, widget DSL
import rui_hittest;   export rui_hittest    # interval tree + spatial hit testing
import rui_events;    export rui_events     # event manager + focus manager
import rui_drawing;   export rui_drawing    # drawing primitives + theme system
import rui_scripting; export rui_scripting  # GUI automation (query/set values)
import rui_widgets;   export rui_widgets    # label, button, stacks, image, ...
import app;           export app            # App object + main loop integrator

const
  RuiVersionMajor* = 0
  RuiVersionMinor* = 2
  RuiVersionPatch* = 0
  RuiVersion* = "0.2.0"

proc ruiVersionString*(): string =
  ## Get the RUI2 version string
  "RUI2 v" & RuiVersion

proc start*(application: App) =
  ## Start the application main loop (alias for app.run()).
  application.run()
