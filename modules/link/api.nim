## Link Module - Public API
##
## Reactive unidirectional data binding with O(1) widget dirty marking.
##
## Usage:
##   import modules/link/api
##
##   var counter = newLink(0)
##   counter.addDependent(myWidget)
##   counter.set(42)  # myWidget.isDirty is now true
##
## Pattern:
##   Store (Link[T] fields) -> Widget reads on render -> Link marks dirty on change
##
## Performance: O(n) where n = widgets bound to THIS link, not total widgets.

import ./link

export link
