## Hit Testing Module - Public API
##
## Efficient spatial queries using dual interval trees.
## Finds widgets at a point in O(log n) time.
##
## Usage:
##   import modules/hit_testing/api
##
##   var system = newHitTestSystem()
##   system.insertWidget(myWidget)
##   let widgets = system.findWidgetsAt(100.0, 200.0)
##   let topWidget = system.getWidgetAt(100.0, 200.0)
##
## For testing without graphics:
##   Compile with default flags (no -d:useGraphics).
##   Widgets can be created in memory with bounds set manually.
##   All hit-test operations work without a GPU or window.

import ./interval_tree
import ./hittest_system

export interval_tree
export hittest_system
