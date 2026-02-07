## Event Manager Module - Public API
##
## Time-budgeted event processing with pattern-based coalescing.
## Includes focus management for keyboard navigation.
##
## Usage:
##   import modules/event_manager/api
##
##   var em = newEventManager(defaultBudget = initDuration(milliseconds = 8))
##   em.addEvent(event)
##   em.update()  # Flush replaceable/batched events
##   em.processEvents(budget, handler)
##
## Focus management:
##   var fm = newFocusManager()
##   fm.setFocus(widget)
##   fm.nextFocus(rootWidget)  # Tab navigation
##
## Event patterns:
##   epNormal      - Process immediately
##   epReplaceable - Only last matters (mouse move)
##   epDebounced   - Wait for quiet period (window resize)
##   epThrottled   - Rate limited (scroll)
##   epBatched     - Collect related (touch gestures)
##   epOrdered     - Sequence matters (keyboard combos)

import ./event_manager
import ./event_manager_helpers
import ./focus_manager

export event_manager
export event_manager_helpers
export focus_manager
