## Widget DSL Module - Public API
##
## Macro-based domain-specific language for defining widgets.
##
## Usage:
##   import modules/widget_dsl/api
##
##   definePrimitive(MyLabel):
##     props:
##       text: string = "Hello"
##     render:
##       drawText(widget.text, widget.bounds)
##
##   defineWidget(MyPanel):
##     props:
##       title: string
##     layout:
##       # position children
##     render:
##       drawBackground(widget.bounds)
##
## Two macros:
##   definePrimitive - For leaf widgets (drawing only, no children)
##   defineWidget     - For composite widgets (with children and layout)

import ./widget_dsl
import ./widget_dsl_helpers

export widget_dsl
export widget_dsl_helpers
