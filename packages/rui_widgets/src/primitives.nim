## Primitive Widgets - Aggregator Module
##
## Imports and exports all primitive widgets (drawing primitives)

# Label is TextArea with editable = false -- one text widget, limited by
# properties. It lives with the rest of the text code in input/textarea.
import input/textarea
export textarea

import primitives/rectangle
export rectangle

import primitives/circle
export circle
